import SwiftUI

// MARK: - Composer Block Row

/// A single editable block row in the menu bar composer sheet.
/// Receives bindings to the block at a fixed index so the parent
/// sheet only needs to manage the overall configuration.
struct MenuBarComposerBlockRowView: View {
    let index: Int
    let block: MenuBarComposerBlock
    let isFirst: Bool
    let isLast: Bool
    let theme: SettingsTheme
    let auxiliaryPanelPresentationHandler: ((Bool) -> Void)?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onToggleEnabled: (Bool) -> Void
    let onUpdateText: (String) -> Void
    let onUpdateLabel: (String) -> Void
    let onUpdateFormat: (MenuBarMetricDisplayFormat) -> Void
    let onUpdateColor: (UInt32) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            headerRow
            controlsRow
        }
        .padding(10)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .opacity(block.isEnabled ? 1 : 0.68)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { block.isEnabled },
                set: { onToggleEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(theme.toggleTint)

            Text(block.kind.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textMain)

            Spacer(minLength: 8)

            Button { onMoveUp() } label: { Image(systemName: "arrow.up") }
                .buttonStyle(.borderless)
                .disabled(isFirst)

            Button { onMoveDown() } label: { Image(systemName: "arrow.down") }
                .buttonStyle(.borderless)
                .disabled(isLast)

            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsRow: some View {
        if block.kind == .text {
            TextField("Text or emoji", text: Binding(
                get: { block.text ?? "" },
                set: { onUpdateText($0) }
            ))
            .textFieldStyle(.roundedBorder)
        } else {
            metricControls
        }
    }

    private var metricControls: some View {
        HStack(spacing: 8) {
            TextField("Label", text: Binding(
                get: { block.label ?? "" },
                set: { onUpdateLabel($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)

            formatMenu
            colorSwatch
        }
    }

    private var formatMenu: some View {
        Menu {
            ForEach(block.kind.supportedFormats, id: \.self) { format in
                Button { onUpdateFormat(format) } label: { Text(format.title) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(block.format.title)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .disabled(block.kind.supportedFormats.count <= 1)
        .opacity(block.kind.supportedFormats.count <= 1 ? 0.6 : 1)
    }

    private var colorSwatch: some View {
        PopoverColorSwatchButton(
            selection: Binding(
                get: { Color(hex: block.colorHex ?? block.kind.defaultColorHex) },
                set: { selectedColor in
                    if let hex = colorHexValue(from: selectedColor) { onUpdateColor(hex) }
                }
            ),
            accessibilityLabel: "Block color",
            helpText: "Color",
            onPresentationChange: auxiliaryPanelPresentationHandler
        ) { color in
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        }
    }
}
