import XCTest
@testable import MacMonitor

final class MenuBarDisplayFormatterTests: XCTestCase {
    func testIconModeReturnsNil() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 4, memoryTotal: 8, storageUsed: 40, storageTotal: 100),
            mode: .icon,
            memoryFormat: .percentUsage,
            storageFormat: .numberLeft
        )

        XCTAssertNil(title)
    }

    func testMemoryPercentUsageTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 0, storageTotal: 1),
            mode: .memory,
            memoryFormat: .percentUsage,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: 75%")
    }

    func testMemoryPercentUsageLeftTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 0, storageTotal: 1),
            mode: .memory,
            memoryFormat: .percentUsageLeft,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: 75% / 25% left")
    }

    func testStorageNumberLeftTitle() {
        let snapshot = makeSnapshot(
            memoryUsed: 0,
            memoryTotal: 1,
            storageUsed: 80,
            storageTotal: 100
        )

        let title = MenuBarDisplayFormatter.valueText(
            for: snapshot,
            mode: .storage,
            memoryFormat: .percentUsage,
            storageFormat: .numberLeft
        )

        XCTAssertEqual(title, "SSD: \(MetricFormatter.bytes(20)) left")
    }

    func testStorageNumberUsageLeftTitle() {
        let snapshot = makeSnapshot(
            memoryUsed: 0,
            memoryTotal: 1,
            storageUsed: 80,
            storageTotal: 100
        )

        let title = MenuBarDisplayFormatter.valueText(
            for: snapshot,
            mode: .storage,
            memoryFormat: .percentUsage,
            storageFormat: .numberUsageLeft
        )

        XCTAssertEqual(title, "SSD: \(MetricFormatter.bytes(80)) / \(MetricFormatter.bytes(20)) left")
    }

    func testBothMetricsTitle() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 80, storageTotal: 100),
            mode: .both,
            memoryFormat: .percentUsage,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: 75% | SSD: 80%")
    }

    func testPlaceholderWhenSnapshotMissing() {
        let title = MenuBarDisplayFormatter.valueText(
            for: nil,
            mode: .memory,
            memoryFormat: .numberUsage,
            storageFormat: .percentUsage
        )

        XCTAssertEqual(title, "RAM: --")
    }

    func testCPUAndNetworkFallbackWhenSnapshotMissing() {
        let cpuTitle = MenuBarDisplayFormatter.valueText(
            for: nil,
            mode: .cpu,
            memoryFormat: .percentUsage,
            storageFormat: .percentUsage
        )
        let networkTitle = MenuBarDisplayFormatter.valueText(
            for: nil,
            mode: .network,
            memoryFormat: .percentUsage,
            storageFormat: .percentUsage
        )

        let expectedRate = MetricFormatter.menuBarBitsPerSecond(nil)
        XCTAssertEqual(cpuTitle, "CPU: 0%")
        XCTAssertEqual(networkTitle, "NET: D \(expectedRate) U \(expectedRate)")
    }

    func testMemoryNumberUsageTitleDoesNotUsePercentSymbol() {
        let title = MenuBarDisplayFormatter.valueText(
            for: makeSnapshot(
                memoryUsed: 1_073_741_824,
                memoryTotal: 2_147_483_648,
                storageUsed: 0,
                storageTotal: 1
            ),
            mode: .memory,
            memoryFormat: .numberUsage,
            storageFormat: .percentUsage
        )

        XCTAssertNotNil(title)
        XCTAssertFalse(title?.contains("%") ?? true)
    }

    func testHighlightedRangesMemoryModeHighlightsOnlyValueWhenExceeded() {
        let text = "RAM: 92%"
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: text,
            mode: .memory,
            highlightRAM: true,
            highlightStorage: false
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual((text as NSString).substring(with: ranges[0]), "92%")
    }

    func testHighlightedRangesBothModeCanHighlightOnlyRAMValue() {
        let text = "RAM: 92% | SSD: 50%"
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: text,
            mode: .both,
            highlightRAM: true,
            highlightStorage: false
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual((text as NSString).substring(with: ranges[0]), "92%")
    }

    func testHighlightedRangesBothModeCanHighlightOnlyStorageValue() {
        let text = "RAM: 50% | SSD: 93%"
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: text,
            mode: .both,
            highlightRAM: false,
            highlightStorage: true
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual((text as NSString).substring(with: ranges[0]), "93%")
    }

    func testHighlightedRangesStorageNumberLeftExcludesLeftSuffix() {
        let text = "SSD: 20 GB left"
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: text,
            mode: .storage,
            highlightRAM: false,
            highlightStorage: true
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual((text as NSString).substring(with: ranges[0]), "20 GB")
    }

    func testHighlightedRangesReturnsEmptyWhenNothingExceeded() {
        let text = "RAM: 60% | SSD: 60%"
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: text,
            mode: .both,
            highlightRAM: false,
            highlightStorage: false
        )

        XCTAssertTrue(ranges.isEmpty)
    }

    func testComposedValueSupportsCustomOrderAndTextBlocks() {
        let output = MenuBarDisplayFormatter.composedValue(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 80, storageTotal: 100),
            configuration: MenuBarComposerConfiguration(
                separator: "🔥",
                blocks: [
                    .metric(.storage, format: .percentUsage),
                    .text("🚀"),
                    .metric(.memory, format: .percentUsage)
                ]
            )
        )

        XCTAssertEqual(output.text, "SSD: 80%🚀RAM: 75%")
        XCTAssertEqual(output.metricSpans.map(\.kind), [.storage, .memory])
    }

    func testComposedHighlightRangesDoNotDependOnHardcodedSeparator() {
        let output = MenuBarDisplayFormatter.composedValue(
            for: makeSnapshot(memoryUsed: 92, memoryTotal: 100, storageUsed: 93, storageTotal: 100),
            configuration: MenuBarComposerConfiguration(
                separator: "✨",
                blocks: [
                    .metric(.memory, format: .percentUsage),
                    .text("🔥"),
                    .metric(.storage, format: .percentUsage)
                ]
            )
        )
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: output,
            highlightRAM: true,
            highlightStorage: true
        )

        XCTAssertEqual(ranges.count, 2)
        let rendered = output.text as NSString
        XCTAssertEqual(rendered.substring(with: ranges[0]), "92%")
        XCTAssertEqual(rendered.substring(with: ranges[1]), "93%")
    }

    func testComposedHighlightRangeForNumberLeftExcludesLeftSuffix() {
        let output = MenuBarDisplayFormatter.composedValue(
            for: makeSnapshot(memoryUsed: 50, memoryTotal: 100, storageUsed: 80, storageTotal: 100),
            configuration: MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [
                    .metric(.storage, format: .numberLeft)
                ]
            )
        )
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: output,
            highlightRAM: false,
            highlightStorage: true
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(
            (output.text as NSString).substring(with: ranges[0]),
            MetricFormatter.bytes(20)
        )
    }

    func testComposedHighlightRangeForNumberUsageLeftExcludesLeftSuffixWord() {
        let output = MenuBarDisplayFormatter.composedValue(
            for: makeSnapshot(memoryUsed: 50, memoryTotal: 100, storageUsed: 80, storageTotal: 100),
            configuration: MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [
                    .metric(.storage, format: .numberUsageLeft)
                ]
            )
        )
        let ranges = MenuBarDisplayFormatter.highlightedRanges(
            in: output,
            highlightRAM: false,
            highlightStorage: true
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(
            (output.text as NSString).substring(with: ranges[0]),
            "\(MetricFormatter.bytes(80)) / \(MetricFormatter.bytes(20))"
        )
    }

    func testComposedValueRangeIgnoresColonInCustomLabel() {
        var memoryBlock = MenuBarComposerBlock.metric(.memory, format: .percentUsage)
        memoryBlock.label = "RAM: Avg"
        let output = MenuBarDisplayFormatter.composedValue(
            for: makeSnapshot(memoryUsed: 3, memoryTotal: 4, storageUsed: 0, storageTotal: 1),
            configuration: MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [memoryBlock]
            )
        )

        let rendered = output.text as NSString
        XCTAssertEqual(output.text, "RAM: Avg: 75%")
        XCTAssertEqual(output.metricSpans.count, 1)
        XCTAssertEqual(rendered.substring(with: output.metricSpans[0].valueRange), "75%")
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
