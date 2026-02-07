import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    let onOpenPolicyManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            policySection
            refreshSection
            startupSection
            thermalSection
        }
        .onAppear {
            ramPolicyViewModel.refresh()
        }
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(
                text: "RAM Policy",
                symbol: "shield.lefthalf.filled.badge.checkmark",
                tint: PopoverTheme.blue
            )

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
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PopoverTheme.blue)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(
                text: "Refresh",
                symbol: "arrow.clockwise",
                tint: PopoverTheme.textPrimary
            )

            settingRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update interval")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PopoverTheme.textPrimary)
                    Text("How often metrics are collected")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
            } trailing: {
                Picker("Update interval", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(refreshTitle(for: interval)).tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PopoverTheme.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(PopoverTheme.borderMedium, lineWidth: 1)
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PopoverTheme.textPrimary)
            }
        }
        .padding(14)
        .background(sectionBackground)
        .overlay(sectionBorder)
    }

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(
                text: "Startup",
                symbol: "power",
                tint: PopoverTheme.textPrimary
            )

            settingRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PopoverTheme.textPrimary)

                    if let launchError = settings.launchAtLoginError {
                        Text(launchError)
                            .font(.system(size: 10))
                            .foregroundStyle(PopoverTheme.red)
                            .lineLimit(2)
                    }
                }
            } trailing: {
                PopoverToggle(isOn: $settings.launchAtLoginEnabled)
            }
        }
        .padding(14)
        .background(sectionBackground)
        .overlay(sectionBorder)
    }

    private var thermalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(
                text: "Thermal",
                symbol: "thermometer.medium",
                tint: PopoverTheme.orange
            )

            Text("Uses official Apple API: Nominal / Fair / Serious / Critical states.")
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(14)
        .background(sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.orange.opacity(0.15), lineWidth: 1)
        )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(PopoverTheme.bgCard)
    }

    private var sectionBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
    }

    private func sectionLabel(text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.bottom, 10)
    }

    private func settingRow<Leading: View, Trailing: View>(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            leading()
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func refreshTitle(for interval: RefreshInterval) -> String {
        switch interval {
        case .oneMinute:
            return "1 minute"
        case .threeMinutes:
            return "3 minutes"
        case .fiveMinutes:
            return "5 minutes"
        case .tenMinutes:
            return "10 minutes"
        }
    }
}
