import SwiftUI

// MARK: - Advanced Battery Card

/// Renders sleep-aware battery controls gated behind helper availability.
struct SettingsBatteryCard: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    let theme: SettingsTheme

    var body: some View {
        let helperAvailability = batteryPolicyCoordinator.helperAvailability
        let helperAvailable: Bool
        switch helperAvailability {
        case .available:   helperAvailable = true
        case .unavailable: helperAvailable = false
        }

        return SettingsCard(theme: theme) {
            settingsSectionHeader("Advanced Battery (Gated)", symbol: "shield.lefthalf.filled", theme: theme)

            Text("These controls only apply on lifecycle events (sleep/wake) or fallback battery parsing paths.")
                .font(.system(size: 11))
                .foregroundStyle(theme.textMuted)

            if case .unavailable(let reason) = helperAvailability {
                settingsInfoBanner(
                    text: "Helper unavailable: \(reason)",
                    tint: PopoverTheme.orange,
                    background: PopoverTheme.orangeDim
                )

                if batteryPolicyCoordinator.isInstallingHelper {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Installing helper...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.textMuted)
                    }
                }

                installHelperButton
            }

            SettingsToggleRow(
                title: "Sleep-aware Stop Charging",
                subtitle: "Pause charging before system sleep transitions.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.sleepAwareStopChargingEnabled },
                    set: { value in mutateFlags { $0.sleepAwareStopChargingEnabled = value } }
                ),
                isEnabled: helperAvailable,
                theme: theme
            )

            settingsDivider(theme: theme)

            SettingsToggleRow(
                title: "Block Sleep Until Limit",
                subtitle: "Attempt limit recovery before sleep when below charge target.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.blockSleepUntilLimitEnabled },
                    set: { value in mutateFlags { $0.blockSleepUntilLimitEnabled = value } }
                ),
                isEnabled: helperAvailable,
                theme: theme
            )

            settingsDivider(theme: theme)

            SettingsToggleRow(
                title: "Hardware Percentage Refinement",
                subtitle: "Use fallback percentage parsing only when standard percentage is unavailable.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.hardwarePercentageRefinementEnabled },
                    set: { value in mutateFlags { $0.hardwarePercentageRefinementEnabled = value } }
                ),
                isEnabled: helperAvailable,
                theme: theme
            )
        }
    }

    // MARK: - Helpers

    private func mutateFlags(_ block: (inout BatteryAdvancedControlFeatureFlags) -> Void) {
        var flags = settings.batteryAdvancedControlFeatureFlags
        block(&flags)
        settings.batteryAdvancedControlFeatureFlags = flags
    }

    private var installHelperButton: some View {
        Button {
            Task { await batteryPolicyCoordinator.installHelperIfNeededAsync() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 10, weight: .semibold))
                Text("Install Helper")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PopoverTheme.accentContrastText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(PopoverTheme.blue)
            )
        }
        .buttonStyle(.plain)
        .disabled(batteryPolicyCoordinator.isInstallingHelper)
        .opacity(batteryPolicyCoordinator.isInstallingHelper ? 0.6 : 1.0)
        .help("Install or update the privileged helper used for battery control.")
    }
}
