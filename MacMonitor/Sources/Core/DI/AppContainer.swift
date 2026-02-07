import Foundation

@MainActor
final class AppContainer {
    private let settingsStore: SettingsStore
    private let metricsEngine: MetricsEngine
    private let snapshotStore: SnapshotStore
    private let summaryViewModel: SystemSummaryViewModel
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
        let menuBar = MenuBarController(viewModel: viewModel)

        self.settingsStore = settings
        self.metricsEngine = engine
        self.snapshotStore = store
        self.summaryViewModel = viewModel
        self.menuBarController = menuBar
    }

    func start() {
        menuBarController.install()
        summaryViewModel.start()
    }

    func stop() {
        summaryViewModel.stop()
        menuBarController.uninstall()
    }
}
