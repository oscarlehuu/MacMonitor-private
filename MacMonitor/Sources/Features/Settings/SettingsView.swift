import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Refresh") {
                Picker("Update interval", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Temperature Unit") {
                Picker("Unit", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
            }

            Section("Launch") {
                Toggle("Launch at login", isOn: $settings.launchAtLoginEnabled)
                if let launchError = settings.launchAtLoginError {
                    Text("Launch-at-login error: \(launchError)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Heat Model") {
                Text("v1 uses official thermal state (Nominal/Fair/Serious/Critical).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
