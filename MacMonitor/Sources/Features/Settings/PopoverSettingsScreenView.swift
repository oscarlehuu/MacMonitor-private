import SwiftUI

// MARK: - Settings Screen

/// Root settings screen composing all settings cards.
/// Owns the local state for diagnostics status, composer presentation,
/// and composer draft configuration.
struct PopoverSettingsScreenView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    let snapshot: SystemSnapshot?
    let history: [SystemSnapshot]
    let diagnosticsExporter: DiagnosticsExporter
    let auxiliaryPanelPresentationHandler: ((Bool) -> Void)?
    let onShowSettings: () -> Void
    let onRAMPolicyRefresh: () -> Void

    @State private var diagnosticsStatusMessage: String?
    @State private var isMenuBarComposerPresented = false
    @State private var menuBarComposerDraftConfiguration: MenuBarComposerConfiguration = .default

    private var theme: SettingsTheme { SettingsTheme(appTheme: settings.appTheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsMenuBarCard(
                settings: settings,
                snapshot: snapshot,
                theme: theme,
                isComposerPresented: $isMenuBarComposerPresented,
                composerDraftConfiguration: $menuBarComposerDraftConfiguration
            )
            .sheet(isPresented: $isMenuBarComposerPresented) {
                MenuBarComposerSheetView(
                    settings: settings,
                    snapshot: snapshot,
                    auxiliaryPanelPresentationHandler: auxiliaryPanelPresentationHandler,
                    theme: theme,
                    isPresented: $isMenuBarComposerPresented,
                    draftConfiguration: $menuBarComposerDraftConfiguration
                )
            }

            SettingsAlertsCard(
                settings: settings,
                auxiliaryPanelPresentationHandler: auxiliaryPanelPresentationHandler,
                theme: theme
            )

            SettingsBatteryCard(
                settings: settings,
                batteryPolicyCoordinator: batteryPolicyCoordinator,
                theme: theme
            )

            SettingsGeneralCard(
                settings: settings,
                appUpdateController: appUpdateController,
                diagnosticsStatusMessage: diagnosticsStatusMessage,
                theme: theme,
                onExportDiagnostics: exportDiagnostics
            )

            SettingsAboutCard(
                theme: theme,
                onOpenReleasePage: openPublicReleasePage
            )

            quitButton
        }
        .onAppear {
            onShowSettings()
            onRAMPolicyRefresh()
        }
    }

    // MARK: - Quit Button

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit MacMonitor", systemImage: "power")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textMain)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func exportDiagnostics() {
        do {
            let bundleURL = try diagnosticsExporter.exportDiagnosticsBundle(
                settings: settings,
                snapshot: snapshot,
                history: history,
                recentBatteryEvents: batteryPolicyCoordinator.recentEvents,
                updateStatusMessage: appUpdateController.statusMessage,
                helperAvailability: batteryPolicyCoordinator.helperAvailability
            )
            diagnosticsStatusMessage = "Saved: \(bundleURL.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
        } catch {
            diagnosticsStatusMessage = "Diagnostics export failed: \(error.localizedDescription)"
        }
    }

    private func openPublicReleasePage() {
        guard let url = URL(string: "https://github.com/oscarlehuu/macmonitor-open/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }
}
