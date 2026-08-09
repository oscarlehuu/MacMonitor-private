import SwiftUI

// MARK: - Settings Theme Colors

/// Provides theme-aware colors scoped to the current AppTheme.
struct SettingsTheme {
    let appTheme: AppTheme

    var textMain: Color {
        appTheme.isDark ? Color(hex: 0xF5F5F7) : Color(hex: 0x1D1D1F)
    }

    var textMuted: Color {
        appTheme.isDark ? Color(hex: 0xA1A1A6) : Color(hex: 0x86868B)
    }

    var cardFill: Color {
        appTheme.isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.62)
    }

    var cardBorder: Color {
        appTheme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var inputBackground: Color {
        appTheme.isDark ? Color.black.opacity(0.26) : Color.black.opacity(0.04)
    }

    var toggleTint: Color {
        Color(hex: 0x32D74B)
    }

    static let pickerWidth: CGFloat = 96

    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = 0
        return formatter
    }()
}

// MARK: - Settings Card Container

/// Wraps settings content in the standard card background + border.
struct SettingsCard<Content: View>: View {
    let theme: SettingsTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Shared Row Components

/// Section header with icon + uppercase label.
func settingsSectionHeader(_ title: String, symbol: String, theme: SettingsTheme) -> some View {
    HStack(spacing: 6) {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.45)
    }
    .foregroundStyle(theme.textMuted)
}

/// Thin 1pt divider using the card border color.
func settingsDivider(theme: SettingsTheme) -> some View {
    Rectangle()
        .fill(theme.cardBorder)
        .frame(height: 1)
}

/// Standard row label with icon + title.
func settingsCompactRowLabel(_ title: String, symbol: String, theme: SettingsTheme) -> some View {
    HStack(spacing: 8) {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.textMuted)
            .frame(width: 14)
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.textMain)
    }
}

/// Compact pill action button used in row-level settings.
@MainActor
func settingsCompactActionButton(
    _ title: String,
    tint: Color = PopoverTheme.accent,
    isEnabled: Bool = true,
    theme: SettingsTheme,
    action: @escaping @MainActor () -> Void
) -> some View {
    Button {
        action()
    } label: {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isEnabled ? PopoverTheme.accentContrastText : theme.textMain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? tint : theme.inputBackground)
            )
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1.0 : 0.65)
}

/// Info banner for warnings/status messages within settings cards.
func settingsInfoBanner(text: String, tint: Color, background: Color) -> some View {
    Text(text)
        .font(.system(size: 11))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(background.opacity(0.7))
        )
}

/// Formats popover width as a human-readable string (e.g. "380 pt").
func formattedMainPopoverWidth(_ width: CGFloat) -> String {
    "\(Int(width.rounded())) pt"
}

// MARK: - Toggle Row

/// Toggle row with title + subtitle, optionally disabled.
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    var subtitleColor: Color = PopoverTheme.textMuted
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    let theme: SettingsTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textMain)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(theme.toggleTint)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.6)
        }
    }
}
