import SwiftUI

// MARK: - Menu Bar Composer Sheet

/// Full-screen sheet for composing the menu bar display configuration.
struct MenuBarComposerSheetView: View {
    @ObservedObject var settings: SettingsStore
    let snapshot: SystemSnapshot?
    let auxiliaryPanelPresentationHandler: ((Bool) -> Void)?
    let theme: SettingsTheme
    @Binding var isPresented: Bool
    @Binding var draftConfiguration: MenuBarComposerConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            settingsDivider(theme: theme)
            previewSection
            instructionText
            addBlockButtons
            settingsDivider(theme: theme)
            blockList
        }
        .padding(16)
        .frame(width: 700, height: 520, alignment: .topLeading)
        .background(PopoverTheme.bgPanel)
        .onAppear {
            draftConfiguration = settings.menuBarComposerConfiguration
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Menu Bar Composer")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textMain)
            Spacer(minLength: 8)
            Button("Cancel") { isPresented = false }
                .buttonStyle(.bordered)
            Button("Done") {
                settings.menuBarComposerConfiguration = draftConfiguration
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textMain)
            Text(
                menuBarComposerPreviewAttributedString(
                    configuration: draftConfiguration,
                    snapshot: snapshot,
                    baseColor: theme.textMuted
                )
            )
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .lineLimit(1)
        }
    }

    private var instructionText: some View {
        Text("Compose freely with metric and text blocks. Use text blocks for separators, emoji, or any wording.")
            .font(.system(size: 11))
            .foregroundStyle(theme.textMuted)
            .lineLimit(2)
    }

    // MARK: - Add Block Buttons

    private var addBlockButtons: some View {
        HStack(spacing: 6) {
            addMetricButton(kind: .memory, symbol: "memorychip.fill")
            addMetricButton(kind: .storage, symbol: "internaldrive.fill")
            addMetricButton(kind: .cpu, symbol: "cpu.fill")
            addMetricButton(kind: .network, symbol: "network")
            Button {
                mutate { $0.blocks.append(.text("•")) }
            } label: {
                Label("Text", systemImage: "textformat")
            }
            .buttonStyle(.bordered)
        }
    }

    private func addMetricButton(kind: MenuBarComposerBlockKind, symbol: String) -> some View {
        Button {
            guard kind.isMetric else { return }
            mutate { $0.blocks.append(.metric(kind)) }
        } label: {
            Label(kind.title, systemImage: symbol)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Block List

    private var blockList: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(draftConfiguration.blocks.enumerated()), id: \.element.id) { index, block in
                    MenuBarComposerBlockRowView(
                        index: index,
                        block: block,
                        isFirst: index == 0,
                        isLast: index == draftConfiguration.blocks.count - 1,
                        theme: theme,
                        auxiliaryPanelPresentationHandler: auxiliaryPanelPresentationHandler,
                        onMoveUp: { mutate { swap(&$0, index, index - 1) } },
                        onMoveDown: { mutate { swap(&$0, index, index + 1) } },
                        onDelete: { mutate { guard $0.blocks.indices.contains(index) else { return }; $0.blocks.remove(at: index) } },
                        onToggleEnabled: { v in mutate { guard $0.blocks.indices.contains(index) else { return }; $0.blocks[index].isEnabled = v } },
                        onUpdateText: { v in mutate { guard $0.blocks.indices.contains(index) else { return }; $0.blocks[index].text = v } },
                        onUpdateLabel: { v in mutate { guard $0.blocks.indices.contains(index) else { return }; $0.blocks[index].label = v } },
                        onUpdateFormat: { v in mutate { guard $0.blocks.indices.contains(index) else { return }; $0.blocks[index].format = v } },
                        onUpdateColor: { v in mutate { guard $0.blocks.indices.contains(index) else { return }; $0.blocks[index].colorHex = v } }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Helpers

    private func mutate(_ mutation: (inout MenuBarComposerConfiguration) -> Void) {
        var config = draftConfiguration
        mutation(&config)
        draftConfiguration = config.normalized()
    }

    private func swap(_ config: inout MenuBarComposerConfiguration, _ i: Int, _ j: Int) {
        guard config.blocks.indices.contains(i), config.blocks.indices.contains(j) else { return }
        config.blocks.swapAt(i, j)
    }
}
