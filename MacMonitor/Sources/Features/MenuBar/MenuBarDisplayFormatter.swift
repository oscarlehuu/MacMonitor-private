import Foundation

struct MenuBarComposedMetricSpan {
    let kind: MenuBarComposerBlockKind
    let fullRange: NSRange
    let valueRange: NSRange
    let colorHex: UInt32
}

struct MenuBarComposedOutput {
    let text: String
    let metricSpans: [MenuBarComposedMetricSpan]
}

enum MenuBarDisplayFormatter {
    static func composedValue(
        for snapshot: SystemSnapshot?,
        configuration: MenuBarComposerConfiguration
    ) -> MenuBarComposedOutput {
        let normalizedConfiguration = configuration.normalized()
        let enabledBlocks = normalizedConfiguration.blocks.filter(\.isEnabled)

        var text = ""
        var metricSpans: [MenuBarComposedMetricSpan] = []

        for block in enabledBlocks {
            switch block.kind {
            case .text:
                text.append(block.text)
            case .memory, .storage, .cpu, .network:
                let label = block.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? block.kind.defaultLabel
                    : block.label.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = metricText(for: snapshot, kind: block.kind, format: block.format)
                let segment = "\(label): \(value)"
                let segmentStart = text.endIndex
                text.append(segment)
                let segmentEnd = text.endIndex
                let segmentRange = segmentStart..<segmentEnd
                let valueStart = text.index(segmentStart, offsetBy: label.count + 2)
                let valueEnd = text.index(valueStart, offsetBy: value.count)
                metricSpans.append(
                    MenuBarComposedMetricSpan(
                        kind: block.kind,
                        fullRange: NSRange(segmentRange, in: text),
                        valueRange: valueRangeWithOptionalLeftSuffix(
                            in: text,
                            valueRange: valueStart..<valueEnd,
                            segmentRange: segmentRange
                        ),
                        colorHex: block.colorHex & 0x00FF_FFFF
                    )
                )
            }
        }

        return MenuBarComposedOutput(text: text, metricSpans: metricSpans)
    }

    static func highlightedRanges(
        in composedOutput: MenuBarComposedOutput,
        highlightRAM: Bool,
        highlightStorage: Bool
    ) -> [NSRange] {
        composedOutput.metricSpans.compactMap { span in
            switch span.kind {
            case .memory where highlightRAM:
                return span.valueRange
            case .storage where highlightStorage:
                return span.valueRange
            case .cpu, .network, .text, .memory, .storage:
                return nil
            }
        }
    }

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
        let cpuText = MetricFormatter.percentValue(snapshot?.cpu.normalizedPercent ?? 0)
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

    private static func valueRangeWithOptionalLeftSuffix(
        in text: String,
        valueRange: Range<String.Index>,
        segmentRange: Range<String.Index>
    ) -> NSRange {
        var valueEnd = valueRange.upperBound
        if let leftSuffix = text.range(of: " left", options: [.backwards], range: segmentRange),
           leftSuffix.lowerBound > valueRange.lowerBound {
            valueEnd = min(valueEnd, leftSuffix.lowerBound)
        }
        return NSRange(valueRange.lowerBound..<valueEnd, in: text)
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
        case .percentUsageLeft:
            let usagePercent = MetricFormatter.percent(used: normalizedUsedBytes, total: totalBytes)
            let leftPercent = MetricFormatter.percent(used: freeBytes, total: totalBytes)
            return "\(usagePercent) / \(leftPercent) left"
        case .numberUsage:
            return MetricFormatter.bytes(normalizedUsedBytes)
        case .numberLeft:
            return "\(MetricFormatter.bytes(freeBytes)) left"
        case .numberUsageLeft:
            return "\(MetricFormatter.bytes(normalizedUsedBytes)) / \(MetricFormatter.bytes(freeBytes)) left"
        }
    }

    private static func metricText(
        for snapshot: SystemSnapshot?,
        kind: MenuBarComposerBlockKind,
        format: MenuBarMetricDisplayFormat
    ) -> String {
        switch kind {
        case .memory:
            return metricText(
                usedBytes: snapshot?.memory.usedBytes,
                totalBytes: snapshot?.memory.totalBytes,
                format: format
            )
        case .storage:
            return metricText(
                usedBytes: snapshot?.storage.usedBytes,
                totalBytes: snapshot?.storage.totalBytes,
                format: format
            )
        case .cpu:
            return MetricFormatter.percentValue(snapshot?.cpu.normalizedPercent ?? 0)
        case .network:
            let networkDownText = MetricFormatter.bytesPerSecond(snapshot?.network.downloadBytesPerSecond)
            let networkUpText = MetricFormatter.bytesPerSecond(snapshot?.network.uploadBytesPerSecond)
            return "D \(networkDownText) U \(networkUpText)"
        case .text:
            return ""
        }
    }
}
