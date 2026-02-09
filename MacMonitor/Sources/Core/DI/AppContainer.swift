import Combine
import Foundation

@MainActor
final class AppContainer {
    private let settingsStore: SettingsStore
    private let metricsEngine: MetricsEngine
    private let snapshotStore: SnapshotStore
    private let summaryViewModel: SystemSummaryViewModel
    private let ramDetailsViewModel: RAMDetailsViewModel
    private let ramPolicyViewModel: RAMPolicySettingsViewModel
    private let ramPolicyMonitor: RAMPolicyMonitor
    private let batteryPolicyCoordinator: BatteryPolicyCoordinator
    private let batteryScheduleCoordinator: BatteryScheduleCoordinator
    private let batteryLifecycleCoordinator: BatteryLifecycleCoordinator
    private let menuBarController: MenuBarController
    private var batterySnapshotCancellable: AnyCancellable?

    init() {
        let settings = SettingsStore(launchAtLoginManager: LaunchAtLoginManager())
        let memoryCollector = MemoryCollector()
        let storageCollector = StorageCollector()
        let batteryCollector = BatteryCollector()
        let thermalCollector = ThermalCollector()

        let engine = MetricsEngine(
            memoryCollector: memoryCollector,
            storageCollector: storageCollector,
            batteryCollector: batteryCollector,
            thermalCollector: thermalCollector,
            settings: settings
        )

        let store = SnapshotStore()
        let viewModel = SystemSummaryViewModel(engine: engine, snapshotStore: store, settings: settings)
        let processProtectionPolicy = DefaultProcessProtectionPolicy()
        let processCollector = LibprocProcessListCollector(protectionPolicy: processProtectionPolicy)
        let processTerminator = SignalProcessTerminator()
        let ramDetails = RAMDetailsViewModel(
            processCollector: processCollector,
            processTerminator: processTerminator
        )
        let policyStore = FileRAMPolicyStore()
        let eventStore = FileRAMPolicyEventStore()
        let appRAMCollector = LibprocAppRAMCollector()
        let policyEvaluator = RAMPolicyEvaluator()
        let notifier = UserNotificationRAMPolicyNotifier()
        let policyMonitor = RAMPolicyMonitor(
            policyStore: policyStore,
            eventStore: eventStore,
            usageCollector: appRAMCollector,
            evaluator: policyEvaluator,
            notifier: notifier
        )
        let policyViewModel = RAMPolicySettingsViewModel(
            policyStore: policyStore,
            eventStore: eventStore,
            monitor: policyMonitor
        )

        let helperInstaller = SMJobBlessBatteryHelperInstaller()
        let backend: BatteryControlBackend = XPCBatteryControlBackend(helperInstaller: helperInstaller)

        let batteryEventStore = FileBatteryEventStore()
        let batteryControlService = BatteryControlService(
            backend: backend,
            eventStore: batteryEventStore
        )
        let batteryReconciliationManager = BatteryReconciliationManager(
            policyEngine: BatteryPolicyEngine(),
            controlService: batteryControlService
        )
        let batteryPolicyCoordinator = BatteryPolicyCoordinator(
            settings: settings,
            controlService: batteryControlService,
            reconciliationManager: batteryReconciliationManager
        )
        let batteryScheduleCoordinator = BatteryScheduleCoordinator(
            store: FileBatteryScheduleStore(),
            queueEngine: BatteryScheduleEngine(),
            policyCoordinator: batteryPolicyCoordinator
        )
        let batteryLifecycleCoordinator = BatteryLifecycleCoordinator { event in
            batteryPolicyCoordinator.handleLifecycleEvent(event)
            if event == .didWake || event == .userSessionDidBecomeActive {
                batteryScheduleCoordinator.processWakeCatchUp()
            }
        }

        BatteryIntentBridge.shared.handler = { command in
            switch command {
            case .setChargeLimit(let limit):
                let result = batteryPolicyCoordinator.setChargeLimit(limit)
                return result.accepted
                ? .success("Charge limit set to \(min(max(limit, 50), 95))%.")
                : .failure(result.message ?? "Failed to set charge limit.")
            case .pauseCharging:
                let result = batteryPolicyCoordinator.pauseChargingNow()
                return result.accepted
                ? .success("Charging paused.")
                : .failure(result.message ?? "Failed to pause charging.")
            case .startTopUp:
                let result = batteryPolicyCoordinator.startTopUpNow()
                return result.accepted
                ? .success("Top Up started.")
                : .failure(result.message ?? "Failed to start Top Up.")
            case .startDischarge(let target):
                let result = batteryPolicyCoordinator.startDischargeNow(targetPercent: target)
                return result.accepted
                ? .success("Discharge started toward \(min(max(target, 50), 95))%.")
                : .failure(result.message ?? "Failed to start discharge.")
            case .getState:
                return .success(batteryPolicyCoordinator.statusText())
            }
        }

        let menuBar = MenuBarController(
            viewModel: viewModel,
            ramDetailsViewModel: ramDetails,
            ramPolicyViewModel: policyViewModel,
            batteryPolicyCoordinator: batteryPolicyCoordinator
        )

        self.settingsStore = settings
        self.metricsEngine = engine
        self.snapshotStore = store
        self.summaryViewModel = viewModel
        self.ramDetailsViewModel = ramDetails
        self.ramPolicyViewModel = policyViewModel
        self.ramPolicyMonitor = policyMonitor
        self.batteryPolicyCoordinator = batteryPolicyCoordinator
        self.batteryScheduleCoordinator = batteryScheduleCoordinator
        self.batteryLifecycleCoordinator = batteryLifecycleCoordinator
        self.menuBarController = menuBar
    }

    func start() {
        menuBarController.install()
        batteryPolicyCoordinator.start()
        batteryScheduleCoordinator.start()
        batterySnapshotCancellable = metricsEngine.$latestSnapshot
            .compactMap { $0?.battery }
            .sink { [weak self] snapshot in
                self?.batteryPolicyCoordinator.handle(snapshot: snapshot)
            }
        summaryViewModel.start()
        ramPolicyMonitor.start()
        batteryLifecycleCoordinator.start()
    }

    func stop() {
        batteryLifecycleCoordinator.stop()
        batterySnapshotCancellable?.cancel()
        batterySnapshotCancellable = nil
        batteryScheduleCoordinator.stop()
        batteryPolicyCoordinator.stop()
        summaryViewModel.stop()
        ramDetailsViewModel.stop()
        ramPolicyMonitor.stop()
        menuBarController.uninstall()
    }
}
