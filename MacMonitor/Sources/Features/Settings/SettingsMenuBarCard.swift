import SwiftUI

// MARK: - Menu Bar Card

/// Renders the menu bar display preview + composer launch button.
struct SettingsMenuBarCard: View {
    @ObservedObject var settings: SettingsStore
    let snapshot: SystemSnapshot?
    let theme: SettingsTheme
    @Binding var isComposerPresented: Bool
    @Binding var composerDraftConfiguration: MenuBarComposerConfiguration

    var body: some View {
        SettingsCard(theme: theme) {
            settingsSectionHeader("Menu Bar Display", symbol: "rectangle.topthird.inset.filled", theme: theme)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textMain)

                    Text(previewAttributedString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    composerDraftConfiguration = settings.menuBarComposerConfiguration
                    isComposerPresented = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textMain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Preview

    private var previewAttributedString: AttributedString {
        menuBarComposerPreviewAttributedString(
            configuration: settings.menuBarComposerConfiguration,
            snapshot: snapshot,
            baseColor: theme.textMuted
        )
    }
}

// MARK: - Composer Preview Helper

/// Builds an attributed preview string for a MenuBarComposerConfiguration.
func menuBarComposerPreviewAttributedString(
    configuration: MenuBarComposerConfiguration,
    snapshot: SystemSnapshot?,
    baseColor: Color
) -> AttributedString {
    let output = MenuBarDisplayFormatter.composedValue(
        for: snapshot,
        configuration: configuration
    )
    let renderedText = output.text.isEmpty ? "--" : output.text
    var attributed = AttributedString(renderedText)
    if !attributed.characters.isEmpty {
        attributed[attributed.startIndex..<attributed.endIndex].foregroundColor = baseColor
    }

    guard !output.text.isEmpty else { return attributed }

    for span in output.metricSpans {
        guard let stringRange = Range(span.valueRange, in: output.text),
              let start = AttributedString.Index(stringRange.lowerBound, within: attributed),
              let end = AttributedString.Index(stringRange.upperBound, within: attributed) else {
            continue
        }
        attributed[start..<end].foregroundColor = Color(hex: span.colorHex)
    }

    return attributed
}
