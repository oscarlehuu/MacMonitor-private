import SwiftUI

struct RAMDetailsView: View {
    @ObservedObject var viewModel: RAMDetailsViewModel
    let memorySnapshot: MemorySnapshot?
    let onBack: () -> Void
    let showsBackButton: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsBackButton {
                backHeader
            }

            if let memorySnapshot {
                summaryStrip(memorySnapshot)
            }

            scopeControls

            Text(listSummaryText)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.red)
                    .lineLimit(2)
            }

            if let resultMessage = viewModel.resultMessage {
                Text(resultMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .lineLimit(2)
            }

            processList

            terminateBar
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .alert("Terminate selected processes?", isPresented: $viewModel.showingTerminateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Terminate", role: .destructive) {
                Task { await viewModel.terminateSelected() }
            }
        } message: {
            Text("MacMonitor will proceed with allowed processes only. Protected items are skipped.")
        }
    }

    private var backHeader: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textSecondary)

            Spacer(minLength: 0)
        }
    }

    private func summaryStrip(_ memory: MemorySnapshot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RAM \(MetricFormatter.percent(used: memory.usedBytes, total: memory.totalBytes)) \u{2014} \(MetricFormatter.usage(used: memory.usedBytes, total: memory.totalBytes))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text(summaryUsageText(memory: memory))
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }

            Spacer(minLength: 6)

            Text(memory.pressure.title)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(pressureFill(for: memory.pressure))
                )
                .foregroundStyle(pressureTint(for: memory.pressure))
                .help(memory.pressure.explanation)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private var scopeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                scopeButton(title: "My Processes", mode: .sameUserOnly)
                scopeButton(title: "All Discoverable", mode: .allDiscoverable)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )

            if viewModel.canToggleAllMine {
                Button(viewModel.showAllMine ? "Show Top \(viewModel.defaultTopRows)" : "Show All Mine (\(viewModel.myProcessCount))") {
                    viewModel.setShowAllMine(!viewModel.showAllMine)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PopoverTheme.textSecondary)
            }

            if viewModel.scopeMode == .allDiscoverable
                && viewModel.areDisplayedRowsCurrentUserOnly
                && viewModel.hasMoreAllRowsThanDisplayed {
                Text("Top rows are currently all from your user.")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
    }

    private func scopeButton(title: String, mode: ProcessScopeMode) -> some View {
        Button {
            viewModel.setScopeMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.scopeMode == mode ? PopoverTheme.blue : PopoverTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(viewModel.scopeMode == mode ? PopoverTheme.blueDim : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var processList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading processes...")
                    .tint(PopoverTheme.blue)
                    .font(.system(size: 11))
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(listCardBackground)
            } else if viewModel.processes.isEmpty {
                Text("No processes available.")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(listCardBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.processes) { process in
                            ProcessRowView(
                                process: process,
                                isSelected: viewModel.selectedProcessIDs.contains(process.pid),
                                onToggle: {
                                    viewModel.toggleSelection(for: process.pid)
                                }
                            )
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: 255, alignment: .top)
            }
        }
    }

    private var terminateBar: some View {
        HStack {
            Text("\(viewModel.selectedAllowedCount) selected \u{2022} \(MetricFormatter.bytes(viewModel.selectedAllowedBytes))")
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

            Spacer(minLength: 8)

            Button {
                viewModel.requestTerminateSelected()
            } label: {
                Text(viewModel.isTerminating ? "Terminating..." : "Terminate (\(viewModel.selectedAllowedCount))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.canTerminateSelection ? Color.white : PopoverTheme.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(viewModel.canTerminateSelection ? PopoverTheme.red : Color.white.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canTerminateSelection)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var listCardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(PopoverTheme.bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )
    }

    private func pressureTint(for pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal:
            return PopoverTheme.green
        case .warning:
            return PopoverTheme.yellow
        case .critical:
            return PopoverTheme.red
        case .unknown:
            return PopoverTheme.textSecondary
        }
    }

    private func pressureFill(for pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal:
            return PopoverTheme.greenDim
        case .warning:
            return PopoverTheme.yellowDim
        case .critical:
            return PopoverTheme.redDim
        case .unknown:
            return Color.white.opacity(0.08)
        }
    }

    private func summaryUsageText(memory: MemorySnapshot) -> String {
        switch viewModel.scopeMode {
        case .sameUserOnly:
            return "\(MetricFormatter.bytes(viewModel.myProcessBytes)) user / \(MetricFormatter.bytes(viewModel.allProcessBytes)) total / \(MetricFormatter.bytes(memory.totalBytes))"
        case .allDiscoverable:
            return "\(MetricFormatter.bytes(viewModel.allProcessBytes)) total / \(MetricFormatter.bytes(memory.totalBytes))"
        }
    }

    private var totalProcessesInScope: Int {
        switch viewModel.scopeMode {
        case .sameUserOnly:
            return viewModel.myProcessCount
        case .allDiscoverable:
            return viewModel.allProcessCount
        }
    }

    private var listSummaryText: String {
        let listed = MetricFormatter.bytes(viewModel.listedRowsBytes)
        if viewModel.scopeMode == .sameUserOnly && viewModel.showAllMine {
            return "All mine \(viewModel.processes.count) of \(viewModel.myProcessCount) \u{2022} Listed \(listed)"
        }
        return "Top \(viewModel.processes.count) of \(totalProcessesInScope) \u{2022} Listed \(listed)"
    }
}

private struct ProcessRowView: View {
    let process: ProcessMemoryItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 8) {
                checkbox

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(process.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(processNameColor)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(MetricFormatter.bytes(process.rankingBytes))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textPrimary)
                    }

                    HStack(spacing: 6) {
                        Text("PID \(process.pid) \u{2022} \(process.userName)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .lineLimit(1)

                        if let reason = process.protectionReason {
                            Text(reason.description)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(PopoverTheme.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(PopoverTheme.orangeDim)
                                )
                        }

                        Spacer(minLength: 4)

                        Text(metricSummary)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? PopoverTheme.blueDim : PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(process.isProtected)
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isSelected ? PopoverTheme.blue : .clear)
            .frame(width: 16, height: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isSelected ? PopoverTheme.blue : PopoverTheme.textMuted, lineWidth: 1.5)
            }
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .opacity(process.isProtected ? 0.3 : 1)
            .padding(.top, 1)
    }

    private var borderColor: Color {
        if isSelected {
            return PopoverTheme.borderActive
        }
        if process.isProtected {
            return PopoverTheme.orange.opacity(0.2)
        }
        return PopoverTheme.borderSubtle
    }

    private var processNameColor: Color {
        process.isProtected ? PopoverTheme.textMuted : PopoverTheme.textPrimary
    }

    private var metricSummary: String {
        if let footprintBytes = process.footprintBytes, footprintBytes > 0 {
            return "\(MetricFormatter.bytes(footprintBytes)) PSS"
        }
        return "\(MetricFormatter.bytes(process.residentBytes)) Resident"
    }
}

private extension MemoryPressureLevel {
    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        case .unknown:
            return "Unknown"
        }
    }

    var explanation: String {
        switch self {
        case .normal:
            return "Memory pressure is normal."
        case .warning:
            return "Memory pressure warning: macOS is reclaiming memory more aggressively."
        case .critical:
            return "Memory pressure is critical: apps may be terminated by the system."
        case .unknown:
            return "Memory pressure is currently unavailable."
        }
    }
}
