import Foundation

enum MenuBarDisplayFormatter {
    static func valueText(
        for snapshot: SystemSnapshot?,
        mode: MenuBarDisplayMode,
        valueMode: MenuBarMetricValueMode,
        format: MenuBarMetricFormat
    ) -> String? {
        switch mode {
        case .icon:
            return nil
        case .ram:
            return metricValue(
                usedBytes: snapshot?.memory.usedBytes,
                totalBytes: snapshot?.memory.totalBytes,
                valueMode: valueMode,
                format: format
            )
        case .storage:
            return metricValue(
                usedBytes: snapshot?.storage.usedBytes,
                totalBytes: snapshot?.storage.totalBytes,
                valueMode: valueMode,
                format: format
            )
        }
    }

    private static func metricValue(
        usedBytes: UInt64?,
        totalBytes: UInt64?,
        valueMode: MenuBarMetricValueMode,
        format: MenuBarMetricFormat
    ) -> String {
        guard let usedBytes, let totalBytes else {
            return "--"
        }

        let normalizedUsedBytes = min(usedBytes, totalBytes)
        let freeBytes = totalBytes > normalizedUsedBytes ? totalBytes - normalizedUsedBytes : 0
        let valueBytes = valueMode == .used ? normalizedUsedBytes : freeBytes

        let valueText: String
        switch format {
        case .percent:
            valueText = MetricFormatter.percent(used: valueBytes, total: totalBytes)
        case .number:
            valueText = MetricFormatter.bytes(valueBytes)
        }

        return valueText
    }
}
