import SwiftUI

// MARK: - Alerts Card

/// Renders all alert threshold controls plus the highlight color picker.
struct SettingsAlertsCard: View {
    @ObservedObject var settings: SettingsStore
    let auxiliaryPanelPresentationHandler: ((Bool) -> Void)?
    let theme: SettingsTheme

    var body: some View {
        SettingsCard(theme: theme) {
            HStack(spacing: 8) {
                settingsSectionHeader("Alerts", symbol: "bell.badge", theme: theme)
                Spacer(minLength: 6)
                highlightColorPicker
            }

            settingsAlertPickerToggleRow(
                title: "Thermal Pressure Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.thermalThreshold },
                    set: { v in mutate { $0.thermalThreshold = v } }
                ),
                options: [.fair, .serious, .critical],
                isOn: Binding(
                    get: { settings.systemAlertSettings.thermalAlertEnabled },
                    set: { v in mutate { $0.thermalAlertEnabled = v } }
                ),
                theme: theme,
                optionTitle: { $0.title }
            )

            settingsDivider(theme: theme)

            settingsAlertPercentToggleRow(
                title: "RAM Alert Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.ramUsagePercentThreshold },
                    set: { v in mutate { $0.ramUsagePercentThreshold = min(max(v, 60), 99) } }
                ),
                isOn: Binding(
                    get: { settings.systemAlertSettings.ramAlertEnabled },
                    set: { v in mutate { $0.ramAlertEnabled = v } }
                ),
                theme: theme
            )

            settingsAlertPercentToggleRow(
                title: "Storage Alert Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.storageUsagePercentThreshold },
                    set: { v in mutate { $0.storageUsagePercentThreshold = min(max(v, 60), 99) } }
                ),
                isOn: Binding(
                    get: { settings.systemAlertSettings.storageAlertEnabled },
                    set: { v in mutate { $0.storageAlertEnabled = v } }
                ),
                theme: theme
            )

            settingsDivider(theme: theme)

            settingsAlertPickerToggleRow(
                title: "Battery Health Drop Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.batteryHealthDropPercentThreshold },
                    set: { v in mutate { $0.batteryHealthDropPercentThreshold = v } }
                ),
                options: [5, 10, 15, 20, 25, 30, 35, 40],
                isOn: Binding(
                    get: { settings.systemAlertSettings.batteryHealthDropAlertEnabled },
                    set: { v in mutate { $0.batteryHealthDropAlertEnabled = v } }
                ),
                theme: theme,
                optionTitle: { "\($0)%" }
            )

            settingsDivider(theme: theme)

            settingsAlertPickerRow(
                title: "Alert Cooldown (All)",
                selection: Binding(
                    get: { settings.systemAlertSettings.cooldownMinutes },
                    set: { v in mutate { $0.cooldownMinutes = v } }
                ),
                options: [5, 10, 15, 30],
                theme: theme,
                optionTitle: { "\($0)m" }
            )
        }
    }

    // MARK: - Helpers

    private func mutate(_ block: (inout SystemAlertSettings) -> Void) {
        var s = settings.systemAlertSettings
        block(&s)
        settings.systemAlertSettings = s
    }

    private var highlightColorPicker: some View {
        let selection = Binding<Color>(
            get: { Color(hex: settings.systemAlertSettings.exceededThresholdHighlightColor) },
            set: { color in
                guard let hex = colorHexValue(from: color) else { return }
                mutate { $0.exceededThresholdHighlightColor = hex }
            }
        )
        return PopoverColorSwatchButton(
            selection: selection,
            accessibilityLabel: "Exceeded threshold color",
            helpText: "Exceeded threshold color",
            onPresentationChange: auxiliaryPanelPresentationHandler
        ) { color in
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
        }
    }
}
