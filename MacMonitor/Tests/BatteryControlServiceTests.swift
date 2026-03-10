import XCTest
@testable import MacMonitor

@MainActor
final class BatteryControlServiceTests: XCTestCase {
    func testRefreshRecentEventsPublishesNewestCompletedRequestOnly() {
        let oldEvent = BatteryControlEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            source: .policy,
            state: .chargingToLimit,
            command: nil,
            accepted: true,
            message: "old",
            batteryPercent: 60
        )
        let newEvent = BatteryControlEvent(
            timestamp: Date(timeIntervalSince1970: 20),
            source: .manual,
            state: .topUp,
            command: nil,
            accepted: true,
            message: "new",
            batteryPercent: 70
        )
        let eventStore = SequencedEventStore(
            responses: [
                ([oldEvent], 250_000),
                ([newEvent], 10_000)
            ]
        )
        let service = BatteryControlService(
            backend: NoOpBatteryBackend(),
            eventStore: eventStore,
            now: { newEvent.timestamp }
        )

        service.recordState(
            .topUp,
            source: .manual,
            reason: "latest",
            batteryPercent: newEvent.batteryPercent
        )

        let latestExpectation = expectation(description: "latest events published")
        Task { @MainActor in
            while service.recentEvents.first?.message != "new" {
                await Task.yield()
            }
            latestExpectation.fulfill()
        }
        wait(for: [latestExpectation], timeout: 1.0)

        let stableExpectation = expectation(description: "stale refresh ignored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(service.recentEvents.first?.message, "new")
            stableExpectation.fulfill()
        }
        wait(for: [stableExpectation], timeout: 1.0)
    }

    func testRecordEventSchedulesPeriodicPruningDuringLongRunningSession() {
        var now = Date(timeIntervalSince1970: 1_000)
        let eventStore = TrackingEventStore()
        let service = BatteryControlService(
            backend: NoOpBatteryBackend(),
            eventStore: eventStore,
            now: { now },
            pruneInterval: 60
        )

        let initialPrune = expectation(description: "initial prune scheduled")
        waitForCondition(timeout: 1.0) {
            if eventStore.pruneCallCount == 1 {
                initialPrune.fulfill()
                return true
            }
            return false
        }
        wait(for: [initialPrune], timeout: 1.0)

        service.recordState(.chargingToLimit, source: .policy, reason: "first", batteryPercent: 70)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(eventStore.pruneCallCount, 1)

        now.addTimeInterval(120)
        service.recordState(.pausedAtLimit, source: .policy, reason: "second", batteryPercent: 71)

        let secondPrune = expectation(description: "follow-up prune scheduled")
        waitForCondition(timeout: 1.0) {
            if eventStore.pruneCallCount == 2 {
                secondPrune.fulfill()
                return true
            }
            return false
        }
        wait(for: [secondPrune], timeout: 1.0)
    }

    private func waitForCondition(timeout: TimeInterval, condition: @escaping @Sendable () -> Bool) {
        Task.detached {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if condition() {
                    return
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }
}

private final class NoOpBatteryBackend: BatteryControlBackend {
    var availability: BatteryControlAvailability = .available

    func execute(_ command: BatteryControlCommand) -> BatteryControlCommandResult {
        .success()
    }

    func installHelperIfNeeded() -> BatteryControlCommandResult {
        .success()
    }
}

private final class SequencedEventStore: BatteryEventStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [([BatteryControlEvent], useconds_t)]
    private var events: [BatteryControlEvent] = []

    init(responses: [([BatteryControlEvent], useconds_t)]) {
        self.responses = responses
    }

    func append(_ event: BatteryControlEvent) throws {
        lock.withLock {
            events.append(event)
        }
    }

    func recentEvents(limit: Int) -> [BatteryControlEvent] {
        let response = lock.withLock {
            if !responses.isEmpty {
                return responses.removeFirst()
            }
            return (Array(events.suffix(limit)), 0)
        }
        usleep(response.1)
        return response.0
    }

    func pruneExpiredEvents(referenceDate: Date) {}
}

private final class TrackingEventStore: BatteryEventStoring, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var pruneCallCount = 0

    func append(_ event: BatteryControlEvent) throws {}

    func recentEvents(limit: Int) -> [BatteryControlEvent] { [] }

    func pruneExpiredEvents(referenceDate: Date) {
        lock.withLock {
            pruneCallCount += 1
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
