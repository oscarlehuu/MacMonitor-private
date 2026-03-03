import Combine
import XCTest
@testable import MacMonitor

@MainActor
final class SystemSummaryViewModelTests: XCTestCase {
    func testScreenDefaultsToRAM() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.screen, .ram)
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

        viewModel.showStorageManagement()
        XCTAssertEqual(viewModel.screen, .storage)

        viewModel.showRAMPolicyManager()
        XCTAssertEqual(viewModel.screen, .ramPolicyManager)

        viewModel.showSummary()
        XCTAssertEqual(viewModel.screen, .ram)
    }

    func testChangingAlertSettingsReevaluatesAlertsImmediately() async {
        let defaults = UserDefaults(suiteName: "SystemSummaryViewModelTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: DummyLaunchAtLoginManager())
        let notifier = RecordingSystemAlertNotifier()

        let viewModel = SystemSummaryViewModel(
            engine: MetricsEngine(
                memoryCollector: DummyMemoryCollector(),
                storageCollector: DummyStorageCollector(),
                batteryCollector: DummyBatteryCollector(),
                thermalCollector: SeriousThermalCollector(),
                cpuCollector: DummyCPUCollector(),
                networkCollector: DummyNetworkCollector(),
                settings: settings
            ),
            snapshotStore: SnapshotStore(baseDirectoryURL: FileManager.default.temporaryDirectory),
            settings: settings,
            alertNotifier: notifier
        )

        viewModel.start()
        let baselineInvocations = notifier.invocationCount
        XCTAssertGreaterThanOrEqual(baselineInvocations, 1)

        var alertSettings = settings.systemAlertSettings
        alertSettings.thermalAlertEnabled = false
        settings.systemAlertSettings = alertSettings
        await Task.yield()

        XCTAssertEqual(notifier.invocationCount, baselineInvocations + 1)
        viewModel.stop()
    }

    func testChangingAlertHighlightColorDoesNotReevaluateAlerts() async {
        let defaults = UserDefaults(suiteName: "SystemSummaryViewModelTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: DummyLaunchAtLoginManager())
        let notifier = RecordingSystemAlertNotifier()

        let viewModel = SystemSummaryViewModel(
            engine: MetricsEngine(
                memoryCollector: DummyMemoryCollector(),
                storageCollector: DummyStorageCollector(),
                batteryCollector: DummyBatteryCollector(),
                thermalCollector: SeriousThermalCollector(),
                cpuCollector: DummyCPUCollector(),
                networkCollector: DummyNetworkCollector(),
                settings: settings
            ),
            snapshotStore: SnapshotStore(baseDirectoryURL: FileManager.default.temporaryDirectory),
            settings: settings,
            alertNotifier: notifier
        )

        viewModel.start()
        let baselineInvocations = notifier.invocationCount
        XCTAssertGreaterThanOrEqual(baselineInvocations, 1)

        var alertSettings = settings.systemAlertSettings
        alertSettings.exceededThresholdHighlightColor = 0xBF5AF2
        settings.systemAlertSettings = alertSettings
        await Task.yield()

        XCTAssertEqual(notifier.invocationCount, baselineInvocations)
        viewModel.stop()
    }

    func testTrendInlineAlertResolverLatestBatchUsesExactTimestampOnly() {
        let latestTimestamp = Date(timeIntervalSince1970: 1_000)
        let nearTimestamp = latestTimestamp.addingTimeInterval(-0.2)
        let oldTimestamp = latestTimestamp.addingTimeInterval(-5)

        let latestStorage = makeAlert(kind: .storage, timestamp: latestTimestamp)
        let latestRAM = makeAlert(kind: .ram, timestamp: latestTimestamp)
        let nearThermal = makeAlert(kind: .thermal, timestamp: nearTimestamp)
        let oldBattery = makeAlert(kind: .batteryHealth, timestamp: oldTimestamp)

        let latestBatch = TrendInlineAlertResolver.latestBatch(from: [latestStorage, nearThermal, latestRAM, oldBattery])

        XCTAssertEqual(latestBatch.count, 2)
        XCTAssertEqual(Set(latestBatch.map(\.id)), Set([latestStorage.id, latestRAM.id]))
    }

    func testTrendInlineAlertResolverSlotMappingCoversAllAlertKinds() {
        XCTAssertEqual(TrendInlineAlertResolver.slot(for: .ram), .memory)
        XCTAssertEqual(TrendInlineAlertResolver.slot(for: .storage), .storage)
        XCTAssertEqual(TrendInlineAlertResolver.slot(for: .thermal), .cpu)
        XCTAssertEqual(TrendInlineAlertResolver.slot(for: .batteryHealth), .battery)
    }

    func testTrendInlineAlertResolverInlineAlertReturnsOnlyMatchingSlot() {
        let timestamp = Date(timeIntervalSince1970: 2_000)
        let thermalAlert = makeAlert(kind: .thermal, timestamp: timestamp)
        let storageAlert = makeAlert(kind: .storage, timestamp: timestamp)
        let alerts = [thermalAlert, storageAlert]

        XCTAssertEqual(
            TrendInlineAlertResolver.inlineAlert(for: .cpu, from: alerts)?.id,
            thermalAlert.id
        )
        XCTAssertEqual(
            TrendInlineAlertResolver.inlineAlert(for: .storage, from: alerts)?.id,
            storageAlert.id
        )
        XCTAssertNil(TrendInlineAlertResolver.inlineAlert(for: .memory, from: alerts))
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
                cpuCollector: DummyCPUCollector(),
                networkCollector: DummyNetworkCollector(),
                settings: settings
            ),
            snapshotStore: SnapshotStore(baseDirectoryURL: FileManager.default.temporaryDirectory),
            settings: settings
        )
    }

    private func makeAlert(kind: SystemAlertKind, timestamp: Date) -> SystemAlert {
        SystemAlert(
            id: UUID(),
            timestamp: timestamp,
            kind: kind,
            title: "\(kind.rawValue)-title",
            message: "\(kind.rawValue)-message"
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

private struct SeriousThermalCollector: ThermalCollecting {
    func collect() -> ThermalSnapshot {
        ThermalSnapshot(state: .serious)
    }

    var stateDidChangePublisher: AnyPublisher<ThermalState, Never> {
        Empty<ThermalState, Never>().eraseToAnyPublisher()
    }
}

private struct DummyCPUCollector: CPUCollecting {
    func collect() -> CPUSnapshot {
        CPUSnapshot(usagePercent: 12)
    }
}

private struct DummyNetworkCollector: NetworkCollecting {
    func collect() -> NetworkSnapshot {
        NetworkSnapshot(downloadBytesPerSecond: 1_000, uploadBytesPerSecond: 500)
    }
}

private struct DummyLaunchAtLoginManager: LaunchAtLoginManaging {
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

@MainActor
private final class RecordingSystemAlertNotifier: SystemAlertNotifying {
    private(set) var invocationCount = 0

    func notify(alerts: [SystemAlert], cooldown: TimeInterval) {
        invocationCount += 1
    }
}
