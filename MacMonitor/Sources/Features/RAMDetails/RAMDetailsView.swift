import SwiftUI

struct RAMDetailsView: View {
    @ObservedObject var viewModel: RAMDetailsViewModel
    let memorySnapshot: MemorySnapshot?
    let onBack: () -> Void
    let showsBackButton: Bool

    @State private var hoveredSegmentKey: MemoryBreakdownSegmentKey?
    @State private var hoverPoint: CGPoint = .zero
    @State private var chartAreaFrame: CGRect = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsBackButton {
                backHeader
            }

            if let memorySnapshot {
                summaryStrip(memorySnapshot)
            }

            modeControls
            searchField

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

            if viewModel.mode == .processes {
                processList
            } else {
                portsList
            }

            terminateBar
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .alert(
            viewModel.mode == .ports ? "Terminate selected port owners?" : "Terminate selected processes?",
            isPresented: $viewModel.showingTerminateConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button(viewModel.mode == .ports ? "Terminate Owners" : "Terminate", role: .destructive) {
                Task { await viewModel.terminateSelected() }
            }
        } message: {
            Text(
                viewModel.mode == .ports
                    ? "MacMonitor will deduplicate selected ports into unique PIDs and terminate allowed owners only. Protected owners are skipped."
                    : "MacMonitor will proceed with allowed processes only. Protected items are skipped."
            )
        }
        .alert("Force kill remaining processes?", isPresented: $viewModel.showingForceKillConfirmation) {
            Button("Force Kill Remaining", role: .destructive) {
                Task { await viewModel.confirmForceKillRemainingPorts() }
            }
            Button("Skip Remaining") {
                viewModel.skipForceKillRemainingPorts()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelForceKillPrompt()
            }
        } message: {
            Text(viewModel.forceKillPromptMessage)
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
        let segments = breakdownSegments(memory)
        let usedPercent = percentString(used: memory.usedBytes, total: memory.totalBytes, fractionDigits: 1)
        let usedUsage = "\(MetricFormatter.bytes(memory.usedBytes)) / \(MetricFormatter.bytes(memory.totalBytes))"
        let appMemoryText = byteText(memory.appMemoryBytes.map { min($0, memory.totalBytes) })
        let wiredMemoryText = byteText(memory.wiredMemoryBytes.map { min($0, memory.totalBytes) })
        let compressedText = byteText(memory.compressedBytes.map { min($0, memory.totalBytes) })
        let cachedFilesText = byteText((memory.cachedFilesBytes ?? memory.inactiveBytes).map { min($0, memory.totalBytes) })
        let swapUsedText = byteText(memory.swapUsedBytes)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("RAM \(usedPercent) — \(usedUsage)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textPrimary)

                        infoIcon
                    }

                    Text("Physical Memory: \(MetricFormatter.bytes(memory.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textSecondary)

                    Text("Memory Used: \(MetricFormatter.bytes(memory.usedBytes)) (\(usedPercent))")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                }

                Spacer(minLength: 6)

                pressureBadge(memory.pressure)
            }

            VStack(alignment: .leading, spacing: 8) {
                barTrack(segments: segments)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(segments) { segment in
                        legendItem(for: segment, totalBytes: memory.totalBytes)
                    }
                }
            }
            .padding(.top, 2)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            chartAreaFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { _, newValue in
                            chartAreaFrame = newValue
                        }
                }
            )
            .overlay(alignment: .topLeading) {
                if let hoveredSegmentKey,
                   let hoveredSegment = segments.first(where: { $0.key == hoveredSegmentKey }) {
                    chartTooltip(segment: hoveredSegment, totalBytes: memory.totalBytes)
                        .offset(x: tooltipOffsetX, y: tooltipOffsetY)
                }
            }

            Divider()
                .overlay(PopoverTheme.borderSubtle)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    summaryMetricRow(title: "Physical Memory", value: MetricFormatter.bytes(memory.totalBytes))
                    summaryMetricRow(title: "Memory Used", value: MetricFormatter.bytes(memory.usedBytes))
                    summaryMetricRow(title: "Cached Files", value: cachedFilesText)
                    summaryMetricRow(title: "Swap Used", value: swapUsedText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    summaryMetricRow(title: "App Memory", value: appMemoryText)
                    summaryMetricRow(title: "Wired Memory", value: wiredMemoryText)
                    summaryMetricRow(title: "Compressed", value: compressedText)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var infoIcon: some View {
        ZStack {
            Circle()
                .stroke(PopoverTheme.textMuted, lineWidth: 1)
                .frame(width: 14, height: 14)
            Text("i")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PopoverTheme.textMuted)
        }
        .help("Memory Used = Physical - (Cached Files + Free)\nApp Memory = Internal memory pages\nWired Memory = Kernel-locked pages\nCompressed = Pages compressed by macOS VM")
    }

    private func pressureBadge(_ pressure: MemoryPressureLevel) -> some View {
        Text(pressure.title)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(pressureFill(for: pressure))
            )
            .foregroundStyle(pressureTint(for: pressure))
            .help(pressure.explanation)
    }

    private func barTrack(segments: [MemoryBreakdownSegment]) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: max(0, geometry.size.width * segment.ratio))
                        .opacity(segmentOpacity(for: segment.key))
                        .brightness(hoveredSegmentKey == segment.key ? 0.08 : 0)
                        .onContinuousHover(coordinateSpace: .global) { phase in
                            switch phase {
                            case .active(let location):
                                hoveredSegmentKey = segment.key
                                hoverPoint = location
                            case .ended:
                                hoveredSegmentKey = nil
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 8)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(PopoverTheme.borderMedium)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func legendItem(for segment: MemoryBreakdownSegment, totalBytes: UInt64) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(segment.color)
                .frame(width: 8, height: 8)

            Text(segment.name)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textSecondary)
                .lineLimit(1)

            Text(segment.valueText(totalBytes: totalBytes))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(PopoverTheme.textMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(hoveredSegmentKey == segment.key ? Color.white.opacity(0.04) : .clear)
        )
        .opacity(segmentOpacity(for: segment.key))
        .onContinuousHover(coordinateSpace: .global) { phase in
            switch phase {
            case .active(let location):
                hoveredSegmentKey = segment.key
                hoverPoint = location
            case .ended:
                hoveredSegmentKey = nil
            }
        }
    }

    private func chartTooltip(segment: MemoryBreakdownSegment, totalBytes: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(segment.name): \(segment.valueText(totalBytes: totalBytes))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Text(segment.description)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderMedium, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func summaryMetricRow(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PopoverTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func byteText(_ value: UInt64?) -> String {
        guard let value else { return "--" }
        return MetricFormatter.bytes(value)
    }

    private var tooltipOffsetX: CGFloat {
        let localX = hoverPoint.x - chartAreaFrame.minX + 12
        return max(0, min(localX, max(chartAreaFrame.width - 210, 0)))
    }

    private var tooltipOffsetY: CGFloat {
        let localY = hoverPoint.y - chartAreaFrame.minY - 42
        return max(0, localY)
    }

    private func breakdownSegments(_ memory: MemorySnapshot) -> [MemoryBreakdownSegment] {
        let usedBytes = min(memory.usedBytes, memory.totalBytes)
        let cachedBytes = min(memory.cachedFilesBytes ?? memory.inactiveBytes ?? 0, memory.totalBytes)
        let fallbackFreeBytes = max(memory.totalBytes - min(memory.totalBytes, usedBytes + cachedBytes), 0)
        let freeBytes = min(memory.freeBytes ?? fallbackFreeBytes, memory.totalBytes)

        let rawSegments: [(MemoryBreakdownSegmentKey, String, UInt64, Color, String)] = [
            (.used, "Memory Used", usedBytes, PopoverTheme.blue, "Physical memory currently in-use"),
            (.cached, "Cached Files", cachedBytes, PopoverTheme.purple, "Reclaimable file-backed cache"),
            (.free, "Free", freeBytes, PopoverTheme.green, "Immediately available pages")
        ]

        let filtered = rawSegments.filter { $0.2 > 0 }
        let sumBytes = filtered.reduce(UInt64(0)) { $0 + $1.2 }
        let normalizer = sumBytes > 0 ? Double(sumBytes) : 1.0

        return filtered
            .map { key, name, bytes, color, description in
                MemoryBreakdownSegment(
                    key: key,
                    name: name,
                    bytes: bytes,
                    color: color,
                    description: description,
                    ratio: Double(bytes) / normalizer
                )
            }
    }

    private func segmentOpacity(for key: MemoryBreakdownSegmentKey) -> Double {
        guard let hoveredSegmentKey else { return 1 }
        return hoveredSegmentKey == key ? 1 : 0.25
    }

    private func percentString(used: UInt64, total: UInt64, fractionDigits: Int) -> String {
        guard total > 0 else { return "0%" }
        let ratio = (Double(used) / Double(total)) * 100
        return String(format: "%0.*f%%", fractionDigits, ratio)
    }

    private var modeControls: some View {
        HStack(spacing: 2) {
            modeButton(mode: .processes)
            modeButton(mode: .ports)
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
    }

    private func modeButton(mode: RAMDetailsMode) -> some View {
        Button {
            viewModel.setMode(mode)
        } label: {
            Text(mode.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.mode == mode ? PopoverTheme.accentContrastText : PopoverTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(viewModel.mode == mode ? PopoverTheme.accent : Color.white.opacity(0.001))
                )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PopoverTheme.textMuted)

            TextField(searchPlaceholder, text: searchBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textPrimary)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.setSearchQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var searchPlaceholder: String {
        viewModel.mode == .ports ? "Search process, port, PID..." : "Search process or PID..."
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.searchQuery },
            set: { viewModel.setSearchQuery($0) }
        )
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
            } else if viewModel.filteredProcesses.isEmpty {
                Text(viewModel.hasActiveSearch ? "No matching processes." : "No processes available.")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(listCardBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.filteredProcesses) { process in
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

    private var portsList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading listening ports...")
                    .tint(PopoverTheme.blue)
                    .font(.system(size: 11))
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(listCardBackground)
            } else if viewModel.filteredListeningPorts.isEmpty {
                Text(viewModel.hasActiveSearch ? "No matching ports." : "No listening TCP ports found.")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(listCardBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.filteredListeningPorts) { row in
                            PortRowView(
                                row: row,
                                isSelected: viewModel.selectedPortIDs.contains(row.id),
                                onToggle: {
                                    viewModel.togglePortSelection(for: row.id)
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
            Text(terminateSummaryText)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

            Spacer(minLength: 8)

            Button {
                viewModel.requestTerminateSelected()
            } label: {
                Text(terminateButtonTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.canTerminateSelection ? Color.white : PopoverTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(viewModel.canTerminateSelection ? PopoverTheme.red : Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canTerminateSelection)
            .help(viewModel.terminationInfoTooltip)
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

    private var terminateSummaryText: String {
        if viewModel.mode == .processes {
            return "\(viewModel.selectedAllowedCount) selected • \(MetricFormatter.bytes(viewModel.selectedAllowedBytes))"
        }
        return "\(viewModel.selectedAllowedCount) ports selected • \(viewModel.selectedAllowedPIDCount) PID(s)"
    }

    private var terminateButtonTitle: String {
        if viewModel.isTerminating {
            return "Terminating..."
        }
        if viewModel.mode == .processes {
            return "Terminate (\(viewModel.selectedAllowedCount))"
        }
        return "Terminate Owners (\(viewModel.selectedAllowedCount))"
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

    private var listSummaryText: String {
        if viewModel.mode == .ports {
            let visibleRows = viewModel.filteredListeningPorts
            let selectableRows = visibleRows.filter { !$0.isProtected }.count
            if viewModel.hasActiveSearch {
                return "Matches \(visibleRows.count) of \(viewModel.listeningPorts.count) • Selectable \(selectableRows)"
            }
            return "TCP LISTEN rows \(visibleRows.count) • Selectable \(selectableRows)"
        }

        let visibleRows = viewModel.filteredProcesses
        let listed = MetricFormatter.bytes(viewModel.filteredRowsBytes)
        let totalInScope = viewModel.scopeMode == .allDiscoverable ? viewModel.allProcessCount : viewModel.myProcessCount
        if viewModel.hasActiveSearch {
            return "Matches \(visibleRows.count) of \(viewModel.processes.count) • Listed \(listed)"
        }
        if viewModel.scopeMode == .sameUserOnly && viewModel.showAllMine {
            return "All mine \(visibleRows.count) of \(viewModel.myProcessCount) • Listed \(listed)"
        }
        return "Top \(visibleRows.count) of \(totalInScope) • Listed \(listed)"
    }
}

private struct ProcessRowView: View {
    let process: ProcessMemoryItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 8) {
                checkbox

                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(processNameColor)
                        .lineLimit(1)

                    Text(processMetaLine)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(MetricFormatter.bytes(process.rankingBytes))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textPrimary)

                    Text(metricSummary)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? PopoverTheme.accentDim : PopoverTheme.bgCard)
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
            .fill(isSelected ? PopoverTheme.accent : .clear)
            .frame(width: 16, height: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isSelected ? PopoverTheme.accent : PopoverTheme.textMuted, lineWidth: 1.5)
            }
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PopoverTheme.accentContrastText)
                }
            }
            .opacity(process.isProtected ? 0.3 : 1)
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

    private var processMetaLine: String {
        if let reason = process.protectionReason {
            return "PID \(process.pid) • \(process.userName) • \(reason.description)"
        }
        return "PID \(process.pid) • \(process.userName)"
    }

    private var metricSummary: String {
        if let footprintBytes = process.footprintBytes, footprintBytes > 0 {
            return "\(MetricFormatter.bytes(footprintBytes)) PSS"
        }
        return "\(MetricFormatter.bytes(process.residentBytes)) Resident"
    }
}

private struct PortRowView: View {
    let row: ListeningPort
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 8) {
                checkbox

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.processName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(processNameColor)
                        .lineLimit(1)

                    portMetaLine
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(row.protocolName) :\(row.port)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textPrimary)

                    Text("PID \(row.pid)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? PopoverTheme.accentDim : PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(row.isProtected)
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isSelected ? PopoverTheme.accent : .clear)
            .frame(width: 16, height: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isSelected ? PopoverTheme.accent : PopoverTheme.textMuted, lineWidth: 1.5)
            }
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PopoverTheme.accentContrastText)
                }
            }
            .opacity(row.isProtected ? 0.3 : 1)
    }

    private var borderColor: Color {
        if isSelected {
            return PopoverTheme.borderActive
        }
        if row.isProtected {
            return PopoverTheme.orange.opacity(0.2)
        }
        return PopoverTheme.borderSubtle
    }

    private var processNameColor: Color {
        row.isProtected ? PopoverTheme.textMuted : PopoverTheme.textPrimary
    }

    private var portMetaLine: some View {
        HStack(spacing: 4) {
            endpointWithHighlightedPort
            Text("•")
            Text(row.userName)
            if let reason = row.protectionReason {
                Text("•")
                Text(reason.description)
            }
        }
    }

    @ViewBuilder
    private var endpointWithHighlightedPort: some View {
        if let endpoint = endpointSplit {
            HStack(spacing: 0) {
                Text(endpoint.host)
                Text(endpoint.port)
                    .foregroundStyle(PopoverTheme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PopoverTheme.accent.opacity(0.14))
                    )
            }
        } else {
            Text(row.endpoint)
        }
    }

    private var endpointSplit: (host: String, port: String)? {
        guard let separator = row.endpoint.lastIndex(of: ":") else { return nil }
        let hostPart = String(row.endpoint[..<separator])
        let portStart = row.endpoint.index(after: separator)
        let portPart = String(row.endpoint[portStart...])

        guard !hostPart.isEmpty, !portPart.isEmpty else { return nil }
        return ("\(hostPart):", portPart)
    }
}

private enum MemoryBreakdownSegmentKey: String {
    case used
    case cached
    case free
}

private struct MemoryBreakdownSegment: Identifiable {
    let key: MemoryBreakdownSegmentKey
    let name: String
    let bytes: UInt64
    let color: Color
    let description: String
    let ratio: Double

    var id: MemoryBreakdownSegmentKey { key }

    func valueText(totalBytes: UInt64) -> String {
        let percent = totalBytes > 0 ? Double(bytes) / Double(totalBytes) * 100 : 0
        return "\(MetricFormatter.bytes(bytes)) (\(String(format: "%.1f", percent))%)"
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
            return "Memory pressure is normal — no swap activity."
        case .warning:
            return "macOS is reclaiming memory more aggressively."
        case .critical:
            return "Critical pressure: apps may be terminated."
        case .unknown:
            return "Memory pressure is currently unavailable."
        }
    }
}
