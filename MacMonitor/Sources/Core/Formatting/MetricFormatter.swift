import Foundation

enum MetricFormatter {
    private static func makeByteFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter
    }

    private static func makePercentFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private static func makeRelativeFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    static func bytes(_ value: UInt64) -> String {
        makeByteFormatter().string(fromByteCount: Int64(value))
    }

    static func usage(used: UInt64, total: UInt64) -> String {
        "\(bytes(used)) / \(bytes(total))"
    }

    static func percent(used: UInt64, total: UInt64) -> String {
        guard total > 0 else { return "0%" }
        let ratio = Double(used) / Double(total)
        let nsNumber = NSNumber(value: ratio)
        return makePercentFormatter().string(from: nsNumber) ?? "0%"
    }

    static func thermalText(for state: ThermalState) -> String {
        state.title
    }

    static func relativeTime(from date: Date, reference: Date = Date()) -> String {
        makeRelativeFormatter().localizedString(for: date, relativeTo: reference)
    }

    static func bytesPerSecond(_ value: Double?) -> String {
        guard let value else { return "--/s" }
        let bitsPerSecond = max(0, value) * 8

        switch bitsPerSecond {
        case 1_000_000_000...:
            return String(format: "%.1f Gbps", bitsPerSecond / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1f Mbps", bitsPerSecond / 1_000_000)
        case 1_000...:
            return String(format: "%.0f Kbps", bitsPerSecond / 1_000)
        default:
            return String(format: "%.0f bps", bitsPerSecond)
        }
    }

    static func menuBarBitsPerSecond(_ value: Double?) -> String {
        guard let value else { return "--.-" }

        let bitsPerSecond = max(0, value) * 8
        switch bitsPerSecond {
        case 1_000_000_000...:
            let gigabitsPerSecond = bitsPerSecond / 1_000_000_000
            if gigabitsPerSecond < 10 {
                return String(format: "%3.1fG", gigabitsPerSecond)
            }
            return String(format: "%3.0fG", min(gigabitsPerSecond, 999))
        case 1_000_000...:
            let megabitsPerSecond = bitsPerSecond / 1_000_000
            if megabitsPerSecond < 10 {
                return String(format: "%3.1fM", megabitsPerSecond)
            }
            return String(format: "%3.0fM", min(megabitsPerSecond, 999))
        case 1_000...:
            let kilobitsPerSecond = bitsPerSecond / 1_000
            if kilobitsPerSecond < 10 {
                return String(format: "%3.1fK", kilobitsPerSecond)
            }
            return String(format: "%3.0fK", min(kilobitsPerSecond, 999))
        default:
            return String(format: "%3.0fb", min(bitsPerSecond, 999))
        }
    }

    static func percentValue(_ value: Double?) -> String {
        guard let value else { return "--" }
        let clamped = min(max(value, 0), 100)
        return "\(Int(clamped.rounded()))%"
    }
}
