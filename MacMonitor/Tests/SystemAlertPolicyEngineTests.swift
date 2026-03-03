import XCTest
@testable import MacMonitor

final class SystemAlertPolicyEngineTests: XCTestCase {
    func testEvaluateAddsRAMAlertWhenUsageExceedsThreshold() {
        let engine = SystemAlertPolicyEngine()
        var settings = SystemAlertSettings.default
        settings.ramAlertEnabled = true
        settings.ramUsagePercentThreshold = 80

        let snapshot = makeSnapshot(memoryUsed: 88, memoryTotal: 100, storageUsed: 50, storageTotal: 100)
        let alerts = engine.evaluate(
            snapshot: snapshot,
            history: [snapshot],
            settings: settings,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(alerts.contains(where: { $0.kind == .ram }))
    }

    func testEvaluateSkipsRAMAlertWhenDisabled() {
        let engine = SystemAlertPolicyEngine()
        var settings = SystemAlertSettings.default
        settings.ramAlertEnabled = false
        settings.ramUsagePercentThreshold = 70

        let snapshot = makeSnapshot(memoryUsed: 95, memoryTotal: 100, storageUsed: 50, storageTotal: 100)
        let alerts = engine.evaluate(
            snapshot: snapshot,
            history: [snapshot],
            settings: settings,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertFalse(alerts.contains(where: { $0.kind == .ram }))
    }

    func testEvaluateUsesStorageThresholdFromSettings() {
        let engine = SystemAlertPolicyEngine()
        var settings = SystemAlertSettings.default
        settings.storageAlertEnabled = true
        settings.storageUsagePercentThreshold = 85

        let snapshot = makeSnapshot(memoryUsed: 50, memoryTotal: 100, storageUsed: 86, storageTotal: 100)
        let alerts = engine.evaluate(
            snapshot: snapshot,
            history: [snapshot],
            settings: settings,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(alerts.contains(where: { $0.kind == .storage }))
    }

    private func makeSnapshot(
        memoryUsed: UInt64,
        memoryTotal: UInt64,
        storageUsed: UInt64,
        storageTotal: UInt64
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            memory: MemorySnapshot(usedBytes: memoryUsed, totalBytes: max(memoryTotal, 1), pressure: .normal),
            storage: StorageSnapshot(usedBytes: storageUsed, totalBytes: max(storageTotal, 1)),
            battery: .unavailable,
            thermal: ThermalSnapshot(state: .nominal),
            refreshReason: .manual
        )
    }
}
