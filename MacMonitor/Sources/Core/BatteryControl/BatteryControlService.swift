import Foundation

@MainActor
final class BatteryControlService: ObservableObject {
    @Published private(set) var availability: BatteryControlAvailability
    @Published private(set) var effectiveState: BatteryControlState = .unavailable
    @Published private(set) var lastCommand: BatteryControlCommand?
    @Published private(set) var lastCommandResult: BatteryControlCommandResult?
    @Published private(set) var recentEvents: [BatteryControlEvent] = []

    private let backend: BatteryControlBackend
    private let eventStore: BatteryEventStoring
    private let now: () -> Date
    private let pruneInterval: TimeInterval
    private var recentEventsRefreshSequence: UInt64 = 0
    private var lastPruneDate: Date?

    private struct SendableBackendBox: @unchecked Sendable {
        let backend: BatteryControlBackend
    }

    private struct SendableEventStoreBox: @unchecked Sendable {
        let eventStore: BatteryEventStoring
    }

    private final class WeakServiceBox: @unchecked Sendable {
        weak var service: BatteryControlService?

        init(_ service: BatteryControlService) {
            self.service = service
        }
    }

    init(
        backend: BatteryControlBackend,
        eventStore: BatteryEventStoring,
        now: @escaping () -> Date = Date.init,
        pruneInterval: TimeInterval = 6 * 60 * 60
    ) {
        self.backend = backend
        self.eventStore = eventStore
        self.now = now
        self.pruneInterval = pruneInterval
        self.availability = .unavailable(reason: "Checking battery helper status.")
        refreshRecentEvents()
        let referenceDate = now()
        if reservePruneIfNeeded(referenceDate: referenceDate, force: true) {
            let eventStoreBox = SendableEventStoreBox(eventStore: eventStore)
            Task.detached(priority: .utility) {
                eventStoreBox.eventStore.pruneExpiredEvents(referenceDate: referenceDate)
            }
        }

        Task { [weak self] in
            await self?.refreshAvailability()
        }
    }

    func execute(
        _ command: BatteryControlCommand,
        resultingState: BatteryControlState,
        source: BatteryControlEventSource,
        reason: String,
        batteryPercent: Int?
    ) async -> BatteryControlCommandResult {
        await refreshAvailability()
        let result: BatteryControlCommandResult

        switch availability {
        case .available:
            let backendBox = SendableBackendBox(backend: backend)
            result = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(returning: backendBox.backend.execute(command))
                }
            }
        case .unavailable(let unavailableReason):
            result = .failure(unavailableReason)
        }

        if result.accepted {
            effectiveState = resultingState
        }
        lastCommand = command
        lastCommandResult = result

        recordEvent(
            source: source,
            state: resultingState,
            command: command,
            accepted: result.accepted,
            message: [reason, result.message].compactMap { $0 }.joined(separator: " "),
            batteryPercent: batteryPercent
        )
        return result
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        let result = backend.installHelperIfNeeded()
        availability = backend.availability

        recordEvent(
            source: .system,
            state: effectiveState,
            command: nil,
            accepted: result.accepted,
            message: result.message ?? "Helper install request completed.",
            batteryPercent: nil
        )

        return result
    }

    func installHelperIfNeededAsync() async -> BatteryControlCommandResult {
        let backendBox = SendableBackendBox(backend: backend)
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BatteryControlCommandResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: backendBox.backend.installHelperIfNeeded())
            }
        }

        await refreshAvailability()
        recordEvent(
            source: .system,
            state: effectiveState,
            command: nil,
            accepted: result.accepted,
            message: result.message ?? "Helper install request completed.",
            batteryPercent: nil
        )

        return result
    }

    func recordState(
        _ state: BatteryControlState,
        source: BatteryControlEventSource,
        reason: String,
        batteryPercent: Int?
    ) {
        effectiveState = state
        recordEvent(
            source: source,
            state: state,
            command: nil,
            accepted: true,
            message: reason,
            batteryPercent: batteryPercent
        )
    }

    func refreshRecentEvents(limit: Int = 20) {
        let eventStoreBox = SendableEventStoreBox(eventStore: eventStore)
        let serviceBox = WeakServiceBox(self)
        recentEventsRefreshSequence &+= 1
        let refreshSequence = recentEventsRefreshSequence

        Task.detached(priority: .utility) {
            let events = eventStoreBox.eventStore.recentEvents(limit: limit)
            await MainActor.run {
                guard let service = serviceBox.service,
                      service.recentEventsRefreshSequence == refreshSequence else {
                    return
                }
                service.recentEvents = events
            }
        }
    }

    private func recordEvent(
        source: BatteryControlEventSource,
        state: BatteryControlState,
        command: BatteryControlCommand?,
        accepted: Bool,
        message: String,
        batteryPercent: Int?
    ) {
        let event = BatteryControlEvent(
            timestamp: now(),
            source: source,
            state: state,
            command: command,
            accepted: accepted,
            message: message,
            batteryPercent: batteryPercent
        )
        let shouldPrune = reservePruneIfNeeded(referenceDate: event.timestamp)
        let eventStoreBox = SendableEventStoreBox(eventStore: eventStore)
        let serviceBox = WeakServiceBox(self)

        Task.detached(priority: .utility) {
            do {
                try eventStoreBox.eventStore.append(event)
            } catch {
                // Keep control path resilient even when diagnostics persistence fails.
            }

            if shouldPrune {
                eventStoreBox.eventStore.pruneExpiredEvents(referenceDate: event.timestamp)
            }

            await MainActor.run {
                serviceBox.service?.refreshRecentEvents()
            }
        }
    }

    private func refreshAvailability() async {
        let backendBox = SendableBackendBox(backend: backend)
        let refreshedAvailability = await withCheckedContinuation {
            (continuation: CheckedContinuation<BatteryControlAvailability, Never>) in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: backendBox.backend.availability)
            }
        }

        availability = refreshedAvailability
    }

    private func reservePruneIfNeeded(referenceDate: Date, force: Bool = false) -> Bool {
        guard force || shouldPrune(referenceDate: referenceDate) else {
            return false
        }

        lastPruneDate = referenceDate
        return true
    }

    private func shouldPrune(referenceDate: Date) -> Bool {
        guard let lastPruneDate else {
            return true
        }
        return referenceDate.timeIntervalSince(lastPruneDate) >= pruneInterval
    }
}
