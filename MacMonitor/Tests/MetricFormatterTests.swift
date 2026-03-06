import XCTest
@testable import MacMonitor

final class MetricFormatterTests: XCTestCase {
    func testPercentFormatting() {
        XCTAssertEqual(MetricFormatter.percent(used: 50, total: 100), "50%")
    }

    func testUsageFormattingContainsSeparator() {
        let value = MetricFormatter.usage(used: 1_000_000_000, total: 2_000_000_000)
        XCTAssertTrue(value.contains("/"))
    }

    func testThermalText() {
        XCTAssertEqual(MetricFormatter.thermalText(for: .serious), "Serious")
    }

    func testBytesPerSecondFormatsMegabitsPerSecond() {
        XCTAssertEqual(MetricFormatter.bytesPerSecond(125_000), "1.0 Mbps")
    }

    func testBytesPerSecondFormatsGigabitsPerSecond() {
        XCTAssertEqual(MetricFormatter.bytesPerSecond(125_000_000), "1.0 Gbps")
    }

    func testBytesPerSecondFormatsKilobitsPerSecond() {
        XCTAssertEqual(MetricFormatter.bytesPerSecond(500), "4 Kbps")
    }
}
