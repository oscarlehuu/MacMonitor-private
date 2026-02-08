import XCTest
@testable import MacMonitor

final class MenuBarDisplayFormatterTests: XCTestCase {
    func testIconModeReturnsNil() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 4, memoryTotal: 8, storageUsed: 40, storageTotal: 100),
            mode: .icon,
            valueMode: .used,
            format: .percent
        )

        XCTAssertNil(title)
    }

    func testRAMUsedPercentTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 0, storageTotal: 1),
            mode: .ram,
            valueMode: .used,
            format: .percent
        )

        XCTAssertEqual(title, "75%")
    }

    func testStorageFreePercentTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 0, memoryTotal: 1, storageUsed: 80, storageTotal: 100),
            mode: .storage,
            valueMode: .free,
            format: .percent
        )

        XCTAssertEqual(title, "20%")
    }

    func testPlaceholderWhenSnapshotMissing() {
        let title = MenuBarDisplayFormatter.valueText(
            for: nil,
            mode: .ram,
            valueMode: .free,
            format: .number
        )

        XCTAssertEqual(title, "--")
    }

    func testRAMUsedNumberTitleDoesNotUsePercentSymbol() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(
                memoryUsed: 1_073_741_824,
                memoryTotal: 2_147_483_648,
                storageUsed: 0,
                storageTotal: 1
            ),
            mode: .ram,
            valueMode: .used,
            format: .number
        )

        XCTAssertNotNil(title)
        XCTAssertFalse(title?.contains("%") ?? true)
    }

    private func makeSnapshot(
        memoryUsed: UInt64,
        memoryTotal: UInt64,
        storageUsed: UInt64,
        storageTotal: UInt64
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(),
            memory: MemorySnapshot(
                usedBytes: memoryUsed,
                totalBytes: memoryTotal,
                pressure: .normal
            ),
            storage: StorageSnapshot(
                usedBytes: storageUsed,
                totalBytes: storageTotal
            ),
            thermal: ThermalSnapshot(state: .nominal),
            refreshReason: .manual
        )
    }
}
