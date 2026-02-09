import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    let onOpenPolicyManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            themeSection
            settingSeparator
            policySection
            settingSeparator
            refreshSection
            settingSeparator
            menuBarSection
            settingSeparator
            startupSection
            settingSeparator
            thermalSection
        }
        .onAppear {
            ramPolicyViewModel.refresh()
        }
    }

    private var settingSeparator: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
    }

    private var themeSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Theme")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text(settings.appTheme.title)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(AppTheme.allCases) { theme in
                    themeSwatch(theme)
                }
            }
        }
        .padding(14)
    }

    private func themeSwatch(_ theme: AppTheme) -> some View {
        let palette = PopoverTheme.palette(for: theme)
        let isSelected = settings.appTheme == theme

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.appTheme = theme
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.bgDeep)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(palette.accent)
                            .frame(width: 10, height: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isSelected ? PopoverTheme.accent : palette.bgPanel,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            }
        }
        .buttonStyle(.plain)
        .help(theme.title)
    }

    private var policySection: some View {
        settingSection(title: "RAM Policy", subtitle: "Keep your memory in check") {
            HStack {
                Text("\(ramPolicyViewModel.policies.filter(\.enabled).count) active of \(ramPolicyViewModel.policies.count) policies")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Spacer(minLength: 8)

                if let lastEvent = ramPolicyViewModel.recentEvents.first {
                    Text("Last: \(MetricFormatter.relativeTime(from: lastEvent.timestamp))")
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
                .foregroundStyle(PopoverTheme.accentContrastText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PopoverTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var refreshSection: some View {
        settingSection(title: "Auto Refresh", subtitle: "How obsessive are you") {
            optionGroup(
                selection: $settings.refreshInterval,
                options: RefreshInterval.allCases
            ) { interval, isSelected in
                Text(refreshTitle(for: interval))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
            }
        }
    }

    private var menuBarSection: some View {
        settingSection(title: "Menu Bar", subtitle: "The little guy up top") {
            optionGroup(
                selection: $settings.menuBarDisplayMode,
                options: MenuBarDisplayMode.allCases
            ) { mode, isSelected in
                HStack(spacing: 4) {
                    Image(systemName: menuBarDisplaySymbol(for: mode))
                        .font(.system(size: 10, weight: .semibold))
                    Text(mode.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
            }

            if settings.menuBarDisplayMode == .ram || settings.menuBarDisplayMode == .storage {
                settingDivider

                settingRow(
                    title: "Metric scope",
                    subtitle: "Glass half full or half empty"
                ) {
                    optionGroup(
                        selection: $settings.menuBarMetricValueMode,
                        options: MenuBarMetricValueMode.allCases
                    ) { mode, isSelected in
                        Text(mode.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
                    }
                }

                settingDivider

                settingRow(
                    title: "Format",
                    subtitle: "Numbers or vibes"
                ) {
                    optionGroup(
                        selection: $settings.menuBarMetricFormat,
                        options: MenuBarMetricFormat.allCases
                    ) { format, isSelected in
                        HStack(spacing: 4) {
                            Text(menuBarFormatBadge(for: format))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Text(format.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var startupSection: some View {
        settingSection(title: "Startup", subtitle: "Set it and forget it") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(settings.launchAtLoginError == nil ? PopoverTheme.textPrimary : PopoverTheme.red)

                    Text(settings.launchAtLoginError ?? "Start automatically after login")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $settings.launchAtLoginEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(PopoverTheme.accent)
            }
        }
    }

    private var thermalSection: some View {
        settingSection(title: "Thermal", subtitle: "Official Apple thermal states") {
            HStack(spacing: 6) {
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
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.10))
            )
    }

    private func settingSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            content()
        }
        .padding(14)
    }

    private func settingRow<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

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
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                } label: {
                    label(option, isSelected)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? PopoverTheme.accent : Color.white.opacity(0.001))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
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
        case .battery:
            return "battery.100"
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
