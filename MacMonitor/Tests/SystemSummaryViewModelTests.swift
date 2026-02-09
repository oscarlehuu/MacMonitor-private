import Combine
import XCTest
@testable import MacMonitor

@MainActor
final class SystemSummaryViewModelTests: XCTestCase {
    func testScreenDefaultsToTemperature() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.screen, .temperature)
    }

    func testScreenTransitionsAcrossSidebarRoutes() {
        let viewModel = makeViewModel()

        viewModel.showSettings()
        XCTAssertEqual(viewModel.screen, .settings)

        viewModel.showBattery()
        XCTAssertEqual(viewModel.screen, .battery)

        viewModel.showRAMDetails()
        XCTAssertEqual(viewModel.screen, .ram)

        viewModel.showStorage()
        XCTAssertEqual(viewModel.screen, .storage)

        viewModel.showRAMPolicyManager()
        XCTAssertEqual(viewModel.screen, .ramPolicyManager)

        viewModel.showSummary()
        XCTAssertEqual(viewModel.screen, .temperature)
    }

    private func makeViewModel() -> SystemSummaryViewModel {
        let defaults = UserDefaults(suiteName: "SystemSummaryViewModelTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: DummyLaunchAtLoginManager())

        return SystemSummaryViewModel(
            engine: MetricsEngine(
                memoryCollector: DummyMemoryCollector(),
                storageCollector: DummyStorageCollector(),
                batteryCollector: DummyBatteryCollector(),
                thermalCollector: DummyThermalCollector(),
                settings: settings
            ),
            snapshotStore: SnapshotStore(baseDirectoryURL: FileManager.default.temporaryDirectory),
            settings: settings
        )
    }
}

private struct DummyMemoryCollector: MemoryCollecting {
    func collect() -> MemorySnapshot? {
        MemorySnapshot(usedBytes: 1, totalBytes: 2, pressure: .normal)
    }
}

private struct DummyStorageCollector: StorageCollecting {
    func collect() -> StorageSnapshot? {
        StorageSnapshot(usedBytes: 1, totalBytes: 2)
    }
}

private struct DummyBatteryCollector: BatteryCollecting {
    func collect() -> BatterySnapshot? {
        BatterySnapshot.unavailable
    }

    var stateDidChangePublisher: AnyPublisher<Void, Never> {
        Empty<Void, Never>().eraseToAnyPublisher()
    }
}

private struct DummyThermalCollector: ThermalCollecting {
    func collect() -> ThermalSnapshot {
        ThermalSnapshot(state: .nominal)
    }

    var stateDidChangePublisher: AnyPublisher<ThermalState, Never> {
        Empty<ThermalState, Never>().eraseToAnyPublisher()
    }
}

private struct DummyLaunchAtLoginManager: LaunchAtLoginManaging {
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}
