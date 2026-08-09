import AppKit
import SwiftUI

// MARK: - About Card

/// Renders the MacMonitor app icon, version label, and release notes link.
struct SettingsAboutCard: View {
    let theme: SettingsTheme
    let onOpenReleasePage: () -> Void

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return "v\(version)"
    }

    var body: some View {
        SettingsCard(theme: theme) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )

                Text("MacMonitor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textMain)

                Spacer(minLength: 8)

                Text(appVersionLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textMuted)

                Button {
                    onOpenReleasePage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open latest release notes")
                .help("Open latest public release notes")
            }
            .padding(.vertical, 3)
        }
    }
}
