import SwiftUI

// MARK: - Update State

enum SettingsCompactUpdateState: Equatable {
    case ready, disabled, checking, available, upToDate, failed

    var label: String {
        switch self {
        case .ready:     return "Ready"
        case .disabled:  return "Off"
        case .checking:  return "Checking"
        case .available: return "Available"
        case .upToDate:  return "Up to date"
        case .failed:    return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .ready:     return PopoverTheme.textMuted
        case .disabled:  return PopoverTheme.textMuted
        case .checking:  return PopoverTheme.orange
        case .available: return PopoverTheme.blue
        case .upToDate:  return PopoverTheme.green
        case .failed:    return PopoverTheme.red
        }
    }
}

// MARK: - General + Diagnostics Card

/// Renders the Launch at Login, Popover Width, Updates, and Diagnostics rows.
struct SettingsGeneralCard: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController
    let diagnosticsStatusMessage: String?
    let theme: SettingsTheme
    let onExportDiagnostics: () -> Void

    var body: some View {
        SettingsCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                launchAtLoginRow
                settingsDivider(theme: theme)
                popoverWidthRow
                settingsDivider(theme: theme)
                updatesRow
                settingsDivider(theme: theme)
                diagnosticsRow
            }
        }
    }

    // MARK: Launch at Login

    private var launchAtLoginRow: some View {
        HStack(spacing: 10) {
            settingsCompactRowLabel("Launch at Login", symbol: "power", theme: theme)
            Spacer(minLength: 8)
            if let error = settings.launchAtLoginError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.red)
                    .help(error)
            }
            Toggle("", isOn: $settings.launchAtLoginEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(theme.toggleTint)
        }
        .padding(.vertical, 7)
    }

    // MARK: Popover Width

    private var popoverWidthRow: some View {
        HStack(spacing: 10) {
            settingsCompactRowLabel("Popover Width", symbol: "arrow.left.and.right", theme: theme)
            Spacer(minLength: 8)
            Text(formattedMainPopoverWidth(settings.mainPopoverCurrentWidth))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textMuted)
            settingsCompactActionButton(
                "Save",
                tint: settings.hasUnsavedMainPopoverWidth ? PopoverTheme.accent : theme.textMuted,
                isEnabled: settings.hasUnsavedMainPopoverWidth,
                theme: theme
            ) {
                settings.saveCurrentPopoverWidthAsDefault()
            }
            .help(
                "Current \(formattedMainPopoverWidth(settings.mainPopoverCurrentWidth)) • " +
                "Default \(formattedMainPopoverWidth(settings.mainPopoverDefaultWidth))"
            )
        }
        .padding(.vertical, 7)
    }

    // MARK: Updates

    private var updateState: SettingsCompactUpdateState {
        let msg = appUpdateController.statusMessage.lowercased()
        if msg.contains("disabled") || msg.contains("unavailable") { return .disabled }
        if msg.contains("failed") || msg.contains("error") { return .failed }
        if msg.contains("checking") || msg.contains("downloading") { return .checking }
        if msg.contains("ready to check") { return .ready }
        if msg.contains("available") || msg.contains("ready") || msg.contains("downloaded") { return .available }
        if msg.contains("up to date") { return .upToDate }
        return .ready
    }

    private var updateActionTitle: String {
        if appUpdateController.canRestartToInstallUpdate { return "Restart" }
        if !appUpdateController.canCheckForUpdates { return "Off" }
        if updateState == .failed { return "Retry" }
        return "Check"
    }

    private var updateActionEnabled: Bool {
        appUpdateController.canRestartToInstallUpdate || appUpdateController.canCheckForUpdates
    }

    private var updatesRow: some View {
        HStack(spacing: 10) {
            settingsCompactRowLabel("Updates", symbol: "arrow.triangle.2.circlepath", theme: theme)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(updateState.color)
                    .frame(width: 7, height: 7)
                Text(updateState.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
            }
            settingsCompactActionButton(
                updateActionTitle,
                tint: updateState == .failed ? PopoverTheme.red : PopoverTheme.accent,
                isEnabled: updateActionEnabled,
                theme: theme
            ) {
                if appUpdateController.canRestartToInstallUpdate {
                    appUpdateController.restartToInstallUpdate()
                } else {
                    appUpdateController.checkForUpdates()
                }
            }
        }
        .padding(.vertical, 7)
        .help(appUpdateController.detailMessage ?? appUpdateController.statusMessage)
    }

    // MARK: Diagnostics

    private var diagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                settingsCompactRowLabel("Diagnostics", symbol: "square.and.arrow.up", theme: theme)
                Spacer(minLength: 8)
                settingsCompactActionButton("Export", theme: theme) {
                    onExportDiagnostics()
                }
                .help(diagnosticsStatusMessage ?? "Export diagnostics bundle")
            }
            if let msg = diagnosticsStatusMessage {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 7)
    }
}
