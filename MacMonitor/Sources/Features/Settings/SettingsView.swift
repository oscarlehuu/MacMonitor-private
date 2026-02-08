import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    let onOpenPolicyManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            policySection
            refreshSection
            menuBarSection
            startupSection
            thermalSection
        }
        .onAppear {
            ramPolicyViewModel.refresh()
        }
    }

    private var policySection: some View {
        sectionCard(
            title: "RAM Policy",
            symbol: "shield.lefthalf.filled.badge.checkmark",
            tint: PopoverTheme.blue
        ) {
            HStack {
                Text("\(ramPolicyViewModel.policies.filter(\.enabled).count) active of \(ramPolicyViewModel.policies.count) policies")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Spacer(minLength: 8)

                if let lastEvent = ramPolicyViewModel.recentEvents.first {
                    Text("Last alert: \(MetricFormatter.relativeTime(from: lastEvent.timestamp))")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                }
            }

            if let errorMessage = ramPolicyViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.red)
                    .lineLimit(2)
            }

            Button {
                onOpenPolicyManager()
            } label: {
                HStack(spacing: 6) {
                    Text("Manage Policies")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PopoverTheme.blue)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var refreshSection: some View {
        sectionCard(
            title: "Refresh",
            symbol: "arrow.clockwise",
            tint: PopoverTheme.textPrimary
        ) {
            settingRow(
                title: "Update interval",
                subtitle: "How often metrics are collected"
            ) {
                optionGroup(
                    selection: $settings.refreshInterval,
                    options: RefreshInterval.allCases
                ) { interval, isSelected in
                    Text(refreshTitle(for: interval))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : PopoverTheme.textSecondary)
                }
            }
        }
    }

    private var menuBarSection: some View {
        sectionCard(
            title: "Menu Bar",
            symbol: "menubar.rectangle",
            tint: PopoverTheme.textPrimary
        ) {
            settingRow(
                title: "Show in menu bar",
                subtitle: "Icon, RAM, or Storage"
            ) {
                optionGroup(
                    selection: $settings.menuBarDisplayMode,
                    options: MenuBarDisplayMode.allCases
                ) { mode, isSelected in
                    HStack(spacing: 6) {
                        Image(systemName: menuBarDisplaySymbol(for: mode))
                            .font(.system(size: 11, weight: .semibold))
                        Text(mode.title)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Color.white : PopoverTheme.textSecondary)
                }
            }

            if settings.menuBarDisplayMode != .icon {
                settingDivider

                settingRow(
                    title: "Metric scope",
                    subtitle: "Used or free capacity"
                ) {
                    optionGroup(
                        selection: $settings.menuBarMetricValueMode,
                        options: MenuBarMetricValueMode.allCases
                    ) { mode, isSelected in
                        Text(mode.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : PopoverTheme.textSecondary)
                    }
                }

                settingDivider

                settingRow(
                    title: "Format",
                    subtitle: "Percent or absolute number"
                ) {
                    optionGroup(
                        selection: $settings.menuBarMetricFormat,
                        options: MenuBarMetricFormat.allCases
                    ) { format, isSelected in
                        HStack(spacing: 6) {
                            Text(menuBarFormatBadge(for: format))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                            Text(format.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Color.white : PopoverTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var startupSection: some View {
        sectionCard(
            title: "Startup",
            symbol: "power",
            tint: PopoverTheme.textPrimary
        ) {
            settingRow(
                title: "Launch at login",
                subtitle: settings.launchAtLoginError ?? "Start MacMonitor automatically after login",
                subtitleColor: settings.launchAtLoginError != nil ? PopoverTheme.red : PopoverTheme.textMuted
            ) {
                Toggle("", isOn: $settings.launchAtLoginEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(PopoverTheme.blue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var thermalSection: some View {
        sectionCard(
            title: "Thermal",
            symbol: "thermometer.medium",
            tint: PopoverTheme.orange
        ) {
            Text("Uses official Apple API: Nominal / Fair / Serious / Critical states.")
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textSecondary)

            HStack(spacing: 8) {
                thermalTag(title: "Nominal", tint: PopoverTheme.green)
                thermalTag(title: "Fair", tint: PopoverTheme.yellow)
                thermalTag(title: "Serious", tint: PopoverTheme.orange)
                thermalTag(title: "Critical", tint: PopoverTheme.red)
            }
        }
    }

    private func thermalTag(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }

    private func sectionCard<Content: View>(
        title: String,
        symbol: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(tint)

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x171c27),
                            PopoverTheme.bgCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func settingRow<Content: View>(
        title: String,
        subtitle: String,
        subtitleColor: Color = PopoverTheme.textMuted,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(subtitleColor)

            content()
        }
    }

    private var settingDivider: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private func optionGroup<Option: Identifiable & Hashable, Label: View>(
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder label: @escaping (Option, Bool) -> Label
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                } label: {
                    label(option, isSelected)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? PopoverTheme.blue : PopoverTheme.bgElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    isSelected ? PopoverTheme.borderActive : PopoverTheme.borderMedium,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func refreshTitle(for interval: RefreshInterval) -> String {
        switch interval {
        case .oneMinute:
            return "1 min"
        case .threeMinutes:
            return "3 min"
        case .fiveMinutes:
            return "5 min"
        case .tenMinutes:
            return "10 min"
        }
    }

    private func menuBarDisplaySymbol(for mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .icon:
            return "app.fill"
        case .ram:
            return "memorychip.fill"
        case .storage:
            return "internaldrive.fill"
        }
    }

    private func menuBarFormatBadge(for format: MenuBarMetricFormat) -> String {
        switch format {
        case .percent:
            return "%"
        case .number:
            return "123"
        }
    }
}
