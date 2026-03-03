import SwiftUI

struct TrendsView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            trendGrid
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("System Trends")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Text("Window")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Picker("Window", selection: $viewModel.selectedTrendWindow) {
                        ForEach(TrendWindow.allCases) { window in
                            Text(window.title).tag(window)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            if viewModel.isTrendDataStale(for: viewModel.selectedTrendWindow) {
                Label("Trend data may be stale", systemImage: "clock.badge.exclamationmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.orange)
            }

            if let coverageMessage = viewModel.trendCoverageMessage(for: viewModel.selectedTrendWindow) {
                Label(coverageMessage, systemImage: "calendar.badge.clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
    }

    private var trendGrid: some View {
        let latestAlerts = TrendInlineAlertResolver.latestBatch(from: viewModel.recentSystemAlerts)
            .filter { isAlertEnabled($0.kind) }

        return VStack(spacing: 10) {
            trendCard(
                title: "Memory",
                subtitle: "Usage",
                samples: viewModel.memoryTrend(window: viewModel.selectedTrendWindow),
                tint: PopoverTheme.accent,
                unitSuffix: "%",
                inlineAlert: TrendInlineAlertResolver.inlineAlert(for: .memory, from: latestAlerts)
            )
            trendCard(
                title: "Storage",
                subtitle: "Usage",
                samples: viewModel.storageTrend(window: viewModel.selectedTrendWindow),
                tint: PopoverTheme.blue,
                unitSuffix: "%",
                inlineAlert: TrendInlineAlertResolver.inlineAlert(for: .storage, from: latestAlerts)
            )
            trendCard(
                title: "CPU",
                subtitle: "Usage",
                samples: viewModel.cpuTrend(window: viewModel.selectedTrendWindow),
                tint: PopoverTheme.green,
                unitSuffix: "%",
                inlineAlert: TrendInlineAlertResolver.inlineAlert(for: .cpu, from: latestAlerts)
            )
            trendCard(
                title: "Battery",
                subtitle: "Level",
                samples: viewModel.batteryTrend(window: viewModel.selectedTrendWindow),
                tint: PopoverTheme.orange,
                unitSuffix: "%",
                inlineAlert: TrendInlineAlertResolver.inlineAlert(for: .battery, from: latestAlerts)
            )
        }
    }

    private func isAlertEnabled(_ kind: SystemAlertKind) -> Bool {
        let settings = viewModel.settings.systemAlertSettings
        switch kind {
        case .thermal:
            return settings.thermalAlertEnabled
        case .ram:
            return settings.ramAlertEnabled
        case .storage:
            return settings.storageAlertEnabled
        case .batteryHealth:
            return settings.batteryHealthDropAlertEnabled
        }
    }

    private func trendCard(
        title: String,
        subtitle: String,
        samples: [TrendSample],
        tint: Color,
        unitSuffix: String,
        inlineAlert: SystemAlert?
    ) -> some View {
        let currentValue = samples.last?.value
        let averageValue = samples.isEmpty ? nil : samples.map(\.value).reduce(0, +) / Double(samples.count)
        let maxValue = samples.map(\.value).max()
        let alertHighlightColor = selectedAlertHighlightColor

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)
                Spacer(minLength: 6)
                Text(metricText(currentValue, unitSuffix: unitSuffix))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(inlineAlert == nil ? PopoverTheme.textSecondary : alertHighlightColor)
                if inlineAlert != nil {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(alertHighlightColor)
                        .help("Exceeded threshold")
                }
            }

            if samples.count >= 2 {
                Sparkline(samples: samples.map(\.value))
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PopoverTheme.bgElevated)
                    )
            } else {
                Text("Collecting trend points...")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 32)
            }

            HStack(spacing: 12) {
                trendMetricLabel(title: "Avg", value: metricText(averageValue, unitSuffix: unitSuffix))
                trendMetricLabel(title: "Peak", value: metricText(maxValue, unitSuffix: unitSuffix))
                trendMetricLabel(title: "Points", value: "\(samples.count)")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var selectedAlertHighlightColor: Color {
        Color(hex: viewModel.settings.systemAlertSettings.exceededThresholdHighlightColor)
    }

    private func trendMetricLabel(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PopoverTheme.textSecondary)
        }
    }

    private func metricText(_ value: Double?, unitSuffix: String) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))\(unitSuffix)"
    }
}

enum TrendInlineAlertSlot {
    case memory
    case storage
    case cpu
    case battery
}

struct TrendInlineAlertResolver {
    static func latestBatch(from alerts: [SystemAlert]) -> [SystemAlert] {
        guard let latestTimestamp = alerts.first?.timestamp else {
            return []
        }
        return alerts.filter { $0.timestamp == latestTimestamp }
    }

    static func inlineAlert(for slot: TrendInlineAlertSlot, from alerts: [SystemAlert]) -> SystemAlert? {
        alerts.first(where: { self.slot(for: $0.kind) == slot })
    }

    static func slot(for kind: SystemAlertKind) -> TrendInlineAlertSlot {
        switch kind {
        case .ram:
            return .memory
        case .storage:
            return .storage
        case .thermal:
            return .cpu
        case .batteryHealth:
            return .battery
        }
    }
}

private struct Sparkline: Shape {
    let samples: [Double]

    func path(in rect: CGRect) -> Path {
        guard samples.count >= 2 else { return Path() }
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? 1
        let span = max(maxValue - minValue, 0.0001)
        let step = rect.width / CGFloat(samples.count - 1)

        var path = Path()
        for (index, value) in samples.enumerated() {
            let x = CGFloat(index) * step
            let normalizedY = (value - minValue) / span
            let y = rect.height - (CGFloat(normalizedY) * rect.height)
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
