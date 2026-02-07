import SwiftUI

struct RAMDetailsView: View {
    @ObservedObject var viewModel: RAMDetailsViewModel
    let memorySnapshot: MemorySnapshot?
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let memorySnapshot {
                summaryStrip(memorySnapshot)
            }

            scopeControls

            if let resultMessage = viewModel.resultMessage {
                Text(resultMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            processList

            Divider()

            footer
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

    private var header: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text("RAM Details")
                .font(.headline.weight(.semibold))
        }
    }

    private func summaryStrip(_ memory: MemorySnapshot) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("RAM \(MetricFormatter.percent(used: memory.usedBytes, total: memory.totalBytes))")
                    .font(.subheadline.weight(.semibold))
                Text(summaryUsageText(memory: memory))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Text(memory.pressure.title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(pressureTint(for: memory.pressure).opacity(0.2))
                )
                .foregroundStyle(pressureTint(for: memory.pressure))
                .help(memory.pressure.explanation)

            if let lastUpdated = viewModel.lastUpdated {
                Text(relativeUpdateText(from: lastUpdated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    private var scopeControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Scope", selection: Binding(get: {
                viewModel.scopeMode
            }, set: { newValue in
                viewModel.setScopeMode(newValue)
            })) {
                ForEach(ProcessScopeMode.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.canToggleAllMine {
                HStack(spacing: 8) {
                    Button(viewModel.showAllMine ? "Show Top \(viewModel.defaultTopRows)" : "Show All Mine (\(viewModel.myProcessCount))") {
                        viewModel.setShowAllMine(!viewModel.showAllMine)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2.weight(.semibold))

                    Spacer(minLength: 0)
                }
            }

            Text(listSummaryText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if viewModel.scopeMode == .allDiscoverable
                && viewModel.areDisplayedRowsCurrentUserOnly
                && viewModel.hasMoreAllRowsThanDisplayed {
                Text("Top rows are currently all from your user.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var processList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading processes...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        viewModel.refresh()
                    }
                    .buttonStyle(.borderless)
                }
            } else if viewModel.processes.isEmpty {
                Text("No processes available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .frame(minHeight: 120, maxHeight: 250, alignment: .top)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Spacer()

            Text(MetricFormatter.bytes(viewModel.selectedAllowedBytes))
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .help(viewModel.terminationInfoTooltip)

            Button("Terminate (\(viewModel.selectedAllowedCount))") {
                viewModel.requestTerminateSelected()
            }
            .disabled(!viewModel.canTerminateSelection)
        }
        .font(.caption)
    }

    private func pressureTint(for pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .unknown:
            return .secondary
        }
    }

    private func relativeUpdateText(from date: Date) -> String {
        if Date().timeIntervalSince(date) < 1.5 {
            return "just now"
        }
        return MetricFormatter.relativeTime(from: date)
    }

    private func summaryUsageText(memory: MemorySnapshot) -> String {
        switch viewModel.scopeMode {
        case .sameUserOnly:
            return "\(MetricFormatter.bytes(viewModel.myProcessBytes)) / \(MetricFormatter.bytes(viewModel.allProcessBytes)) / \(MetricFormatter.bytes(memory.totalBytes))"
        case .allDiscoverable:
            return "\(MetricFormatter.bytes(viewModel.allProcessBytes)) / \(MetricFormatter.bytes(memory.totalBytes))"
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
            return "All mine \(viewModel.processes.count) of \(viewModel.myProcessCount) • Listed \(listed)"
        }
        return "Top \(viewModel.processes.count) of \(totalProcessesInScope) • Listed \(listed)"
    }
}

private struct ProcessRowView: View {
    let process: ProcessMemoryItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
            }
            .buttonStyle(.borderless)
            .disabled(process.isProtected)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(process.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(MetricFormatter.bytes(process.rankingBytes))
                        .font(.caption.weight(.semibold))
                }

                HStack(spacing: 6) {
                    Text("PID \(process.pid) • \(process.userName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let reason = process.protectionReason {
                        Text(reason.description)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.orange.opacity(0.15))
                            )
                    }

                    Spacer(minLength: 4)

                    Text(process.metricLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(process.isProtected ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
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
            return "Memory pressure warning: macOS is starting to reclaim memory more aggressively."
        case .critical:
            return "Memory pressure is critical: apps may be terminated by the system."
        case .unknown:
            return "Memory pressure is currently unavailable."
        }
    }
}
