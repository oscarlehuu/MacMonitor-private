import Combine
import Foundation

@MainActor
final class BatteryPolicyCoordinator: ObservableObject {
    @Published private(set) var state: BatteryControlState = .unavailable
    @Published private(set) var lastDecision: BatteryPolicyDecision?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var latestBatterySnapshot: BatterySnapshot = .unavailable
    @Published private(set) var recentEvents: [BatteryControlEvent] = []
    @Published private(set) var isInstallingHelper = false

    let settings: SettingsStore
    let controlService: BatteryControlService

    private let reconciliationManager: BatteryReconciliationManager
    private var hasStarted = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsStore,
        controlService: BatteryControlService,
        reconciliationManager: BatteryReconciliationManager
    ) {
        self.settings = settings
        self.controlService = controlService
        self.reconciliationManager = reconciliationManager
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        controlService.$effectiveState
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)

        controlService.$recentEvents
            .sink { [weak self] events in
                self?.recentEvents = events
            }
            .store(in: &cancellables)

        settings.$batteryPolicyConfiguration
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.reconcileNow(
                    source: .policy,
                    reason: "Policy configuration changed.",
                    force: true
                )
            }
            .store(in: &cancellables)

        controlService.refreshRecentEvents()
    }

    func stop() {
        hasStarted = false
        cancellables.removeAll()
    }

    func handle(snapshot: BatterySnapshot) {
        latestBatterySnapshot = snapshot
        reconcileNow(source: .policy, reason: "Telemetry updated.")
    }

    func handleLifecycleEvent(_ event: BatteryLifecycleEvent) {
        let reason = "Lifecycle event: \(event.rawValue)."

        if event == .appDidLaunch {
            reconciliationManager.clearLastAppliedState()
        }

        reconcileNow(source: .lifecycle, reason: reason, force: true)
    }

    func updateConfiguration(_ mutate: (inout BatteryPolicyConfiguration) -> Void) {
        var configuration = settings.batteryPolicyConfiguration
        mutate(&configuration)
        settings.batteryPolicyConfiguration = configuration.normalized()
    }

    func setAutomaticDischargeEnabled(_ enabled: Bool) {
        updateConfiguration { configuration in
            configuration.automaticDischargeEnabled = enabled
            if enabled {
                configuration.manualDischargeEnabled = false
            }
        }
    }

    func setManualDischargeEnabled(_ enabled: Bool) {
        updateConfiguration { configuration in
            configuration.manualDischargeEnabled = enabled
            if enabled {
                configuration.automaticDischargeEnabled = false
            }
        }
    }

    @discardableResult
    func applyScheduledAction(_ action: BatteryScheduledAction) -> BatteryControlCommandResult {
        switch action {
        case .setChargeLimit(let limit):
            return setChargeLimit(limit)
        case .startTopUp:
            return startTopUpNow()
        case .startDischarge(let targetPercent):
            return startDischargeNow(targetPercent: targetPercent)
        case .pauseCharging:
            return pauseChargingNow()
        }
    }

    @discardableResult
    func setChargeLimit(_ percent: Int) -> BatteryControlCommandResult {
        let normalizedLimit = min(max(percent, 50), 95)
        updateConfiguration { configuration in
            configuration.chargeLimitPercent = normalizedLimit
            configuration.manualDischargeEnabled = false
            configuration.topUpEnabled = false
        }

        return directCommand(
            .setChargeLimit(normalizedLimit),
            state: .chargingToLimit,
            source: .manual,
            reason: "Manual charge limit update."
        )
    }

    @discardableResult
    func pauseChargingNow() -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.topUpEnabled = false
            configuration.manualDischargeEnabled = false
        }

        return directCommand(
            .setChargingPaused(true),
            state: .pausedAtLimit,
            source: .manual,
            reason: "Manual pause charging request."
        )
    }

    @discardableResult
    func startChargingNow() -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.topUpEnabled = true
            configuration.manualDischargeEnabled = false
        }

        return directCommand(
            .startTopUp,
            state: .topUp,
            source: .manual,
            reason: "Manual resume charging request."
        )
    }

    @discardableResult
    func startTopUpNow() -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.topUpEnabled = true
            configuration.manualDischargeEnabled = false
        }

        return directCommand(
            .startTopUp,
            state: .topUp,
            source: .manual,
            reason: "Manual top up request."
        )
    }

    @discardableResult
    func startDischargeNow(targetPercent: Int) -> BatteryControlCommandResult {
        let normalizedTarget = min(max(targetPercent, 50), 95)
        updateConfiguration { configuration in
            configuration.topUpEnabled = false
            configuration.manualDischargeEnabled = true
            configuration.automaticDischargeEnabled = false
            configuration.chargeLimitPercent = normalizedTarget
        }

        return directCommand(
            .startDischarge(targetPercent: normalizedTarget),
            state: .dischargingToLimit,
            source: .manual,
            reason: "Manual discharge request."
        )
    }

    @discardableResult
    func stopDischargeNow() -> BatteryControlCommandResult {
        updateConfiguration { configuration in
            configuration.manualDischargeEnabled = false
        }

        return directCommand(
            .stopDischarge,
            state: .pausedAtLimit,
            source: .manual,
            reason: "Manual stop discharge request."
        )
    }

    func statusText() -> String {
        let availabilityText: String
        switch controlService.availability {
        case .available:
            availabilityText = "Backend ready"
        case .unavailable(let reason):
            availabilityText = "Backend unavailable: \(reason)"
        }

        let percent = latestBatterySnapshot.percentage.map { "\($0)%" } ?? "--"
        let decisionText = lastDecision?.reason ?? "No policy decision yet."
        return "\(state.rawValue) • \(percent) • \(availabilityText) • \(decisionText)"
    }

    var helperAvailability: BatteryControlAvailability {
        controlService.availability
    }

    @discardableResult
    func installHelperIfNeeded() -> BatteryControlCommandResult {
        let result = controlService.installHelperIfNeeded()
        if result.accepted {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = result.message
        }
        return result
    }

    func installHelperIfNeededAsync() async {
        guard !isInstallingHelper else { return }
        isInstallingHelper = true
        defer { isInstallingHelper = false }

        let result = await controlService.installHelperIfNeededAsync()
        if result.accepted {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = result.message
        }
    }

    private func reconcileNow(
        source: BatteryControlEventSource,
        reason: String,
        force: Bool = false
    ) {
        let result = reconciliationManager.reconcile(
            snapshot: latestBatterySnapshot,
            configuration: settings.batteryPolicyConfiguration,
            source: source,
            reason: reason,
            force: force
        )

        lastDecision = result.decision
        state = result.decision.state

        if let commandResult = result.commandResult, !commandResult.accepted {
            lastErrorMessage = commandResult.message
        } else {
            lastErrorMessage = nil
        }
    }

    private func directCommand(
        _ command: BatteryControlCommand,
        state: BatteryControlState,
        source: BatteryControlEventSource,
        reason: String
    ) -> BatteryControlCommandResult {
        let result = controlService.execute(
            command,
            resultingState: state,
            source: source,
            reason: reason,
            batteryPercent: latestBatterySnapshot.percentage
        )

        if result.accepted {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = result.message
        }

        return result
    }
}
