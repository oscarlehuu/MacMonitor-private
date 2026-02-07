import Combine
import XCTest
@testable import MacMonitor

@MainActor
final class SystemSummaryViewModelTests: XCTestCase {
    func testScreenDefaultsToSummary() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.screen, .summary)
    }

    func testScreenTransitionsBetweenSummaryAndSettings() {
        let viewModel = makeViewModel()

        viewModel.showSettings()
        XCTAssertEqual(viewModel.screen, .settings)

        viewModel.showSummary()
        XCTAssertEqual(viewModel.screen, .summary)
    }

    private func makeViewModel() -> SystemSummaryViewModel {
        let defaults = UserDefaults(suiteName: "SystemSummaryViewModelTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: DummyLaunchAtLoginManager())

        return SystemSummaryViewModel(
            engine: MetricsEngine(
                memoryCollector: DummyMemoryCollector(),
                storageCollector: DummyStorageCollector(),
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
