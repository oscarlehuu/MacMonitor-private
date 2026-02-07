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
    private let menuBarController: MenuBarController

    init() {
        let settings = SettingsStore(launchAtLoginManager: LaunchAtLoginManager())
        let memoryCollector = MemoryCollector()
        let storageCollector = StorageCollector()
        let thermalCollector = ThermalCollector()

        let engine = MetricsEngine(
            memoryCollector: memoryCollector,
            storageCollector: storageCollector,
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
        let menuBar = MenuBarController(
            viewModel: viewModel,
            ramDetailsViewModel: ramDetails,
            ramPolicyViewModel: policyViewModel
        )

        self.settingsStore = settings
        self.metricsEngine = engine
        self.snapshotStore = store
        self.summaryViewModel = viewModel
        self.ramDetailsViewModel = ramDetails
        self.ramPolicyViewModel = policyViewModel
        self.ramPolicyMonitor = policyMonitor
        self.menuBarController = menuBar
    }

    func start() {
        menuBarController.install()
        summaryViewModel.start()
        ramPolicyMonitor.start()
    }

    func stop() {
        summaryViewModel.stop()
        ramDetailsViewModel.stop()
        ramPolicyMonitor.stop()
        menuBarController.uninstall()
    }
}
