import Foundation

enum MenuBarDisplayFormatter {
    static func valueText(
        for snapshot: SystemSnapshot?,
        mode: MenuBarDisplayMode,
        memoryFormat: MenuBarMetricDisplayFormat,
        storageFormat: MenuBarMetricDisplayFormat
    ) -> String? {
        let memoryText = metricText(
            usedBytes: snapshot?.memory.usedBytes,
            totalBytes: snapshot?.memory.totalBytes,
            format: memoryFormat
        )
        let storageText = metricText(
            usedBytes: snapshot?.storage.usedBytes,
            totalBytes: snapshot?.storage.totalBytes,
            format: storageFormat
        )
        let cpuText = MetricFormatter.percentValue(snapshot?.cpu.normalizedPercent)
        let networkDownText = MetricFormatter.bytesPerSecond(snapshot?.network.downloadBytesPerSecond)
        let networkUpText = MetricFormatter.bytesPerSecond(snapshot?.network.uploadBytesPerSecond)

        switch mode {
        case .memory:
            return "RAM: \(memoryText)"
        case .storage:
            return "SSD: \(storageText)"
        case .cpu:
            return "CPU: \(cpuText)"
        case .network:
            return "NET: D \(networkDownText) U \(networkUpText)"
        case .both:
            return "RAM: \(memoryText) | SSD: \(storageText)"
        case .icon:
            return nil
        }
    }

    static func highlightedRanges(
        in text: String,
        mode: MenuBarDisplayMode,
        highlightRAM: Bool,
        highlightStorage: Bool
    ) -> [NSRange] {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        switch mode {
        case .memory:
            guard highlightRAM else { return [] }
            return valueRange(in: text, within: text.startIndex..<text.endIndex).map { [$0] } ?? [fullRange]
        case .storage:
            guard highlightStorage else { return [] }
            return valueRange(in: text, within: text.startIndex..<text.endIndex).map { [$0] } ?? [fullRange]
        case .both:
            return highlightedRangesForBothMode(
                text: text,
                highlightRAM: highlightRAM,
                highlightStorage: highlightStorage
            )
        case .cpu, .network, .icon:
            return []
        }
    }

    private static func highlightedRangesForBothMode(
        text: String,
        highlightRAM: Bool,
        highlightStorage: Bool
    ) -> [NSRange] {
        guard let separatorRange = text.range(of: " | ") else {
            return []
        }

        var ranges: [NSRange] = []
        if highlightRAM {
            let ramRange = text.startIndex..<separatorRange.lowerBound
            if let valueRange = valueRange(in: text, within: ramRange) {
                ranges.append(valueRange)
            } else {
                ranges.append(NSRange(ramRange, in: text))
            }
        }
        if highlightStorage {
            let storageRange = separatorRange.upperBound..<text.endIndex
            if let valueRange = valueRange(in: text, within: storageRange) {
                ranges.append(valueRange)
            } else {
                ranges.append(NSRange(storageRange, in: text))
            }
        }
        return ranges
    }

    private static func valueRange(
        in text: String,
        within segment: Range<String.Index>
    ) -> NSRange? {
        guard let separator = text.range(of: ": ", range: segment) else {
            return nil
        }

        let valueStart = separator.upperBound
        let valueEnd: String.Index
        if let leftSuffix = text.range(of: " left", options: [.backwards], range: segment),
           leftSuffix.lowerBound > valueStart {
            valueEnd = leftSuffix.lowerBound
        } else {
            valueEnd = segment.upperBound
        }

        guard valueStart < valueEnd else {
            return nil
        }

        return NSRange(valueStart..<valueEnd, in: text)
    }

    private static func metricText(
        usedBytes: UInt64?,
        totalBytes: UInt64?,
        format: MenuBarMetricDisplayFormat
    ) -> String {
        guard let usedBytes, let totalBytes else {
            return "--"
        }

        let normalizedUsedBytes = min(usedBytes, totalBytes)
        let freeBytes = totalBytes > normalizedUsedBytes ? totalBytes - normalizedUsedBytes : 0

        switch format {
        case .percentUsage:
            return MetricFormatter.percent(used: normalizedUsedBytes, total: totalBytes)
        case .numberUsage:
            return MetricFormatter.bytes(normalizedUsedBytes)
        case .numberLeft:
            return "\(MetricFormatter.bytes(freeBytes)) left"
        }
    }
}
