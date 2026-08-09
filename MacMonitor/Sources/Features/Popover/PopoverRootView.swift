import AppKit
import SwiftUI

private struct MemoryUsageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: UInt64
    let ratio: Double
    let color: Color
}

private struct StorageUsageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: UInt64
    let ratio: Double
    let color: Color
}

private struct StorageScanSourceChipView: View {
    let title: String
    let foreground: Color
    let fill: Color
    let stroke: Color
    let sources: [String]
    let emptyText: String

    @State private var isShowingSources = false
    @State private var isHoveringChip = false
    @State private var isHoveringPopover = false
    @State private var closeTask: Task<Void, Never>?

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .onHover { hovering in
                isHoveringChip = hovering
                if hovering {
                    closeTask?.cancel()
                    isShowingSources = true
                } else {
                    scheduleCloseIfNeeded()
                }
            }
            .popover(isPresented: $isShowingSources, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)

                    Divider()

                    if sources.isEmpty {
                        Text(emptyText)
                            .font(.system(size: 11))
                            .foregroundStyle(PopoverTheme.textMuted)
                    } else {
                        ScrollView(showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(sources, id: \.self) { source in
                                    Text(source)
                                        .font(.system(size: 11))
                                        .foregroundStyle(PopoverTheme.textSecondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                }
                .frame(width: 320, alignment: .leading)
                .padding(10)
                .background(PopoverTheme.bgCard)
                .onHover { hovering in
                    isHoveringPopover = hovering
                    if hovering {
                        closeTask?.cancel()
                    } else {
                        scheduleCloseIfNeeded()
                    }
                }
            }
            .onDisappear {
                closeTask?.cancel()
            }
    }

    private func scheduleCloseIfNeeded() {
        closeTask?.cancel()
        closeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            if !isHoveringChip && !isHoveringPopover {
                isShowingSources = false
            }
        }
    }
}


struct PopoverRootView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel
    @ObservedObject var ramDetailsViewModel: RAMDetailsViewModel
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    @ObservedObject var storageManagementViewModel: StorageManagementViewModel
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    @ObservedObject var batteryScheduleViewModel: BatteryScheduleViewModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController
    let popoverWindowProvider: (() -> NSWindow?)?
    let auxiliaryPanelPresentationHandler: ((Bool) -> Void)?
    let diagnosticsExporter: DiagnosticsExporter

    @State private var hasNormalizedLegacyScreen = false
    @State private var popoverResizeDragStartWidth: CGFloat?
    @State private var popoverResizePreviewWidth: CGFloat?
    @State private var didConfirmStorageDeletion = false
    @State private var hoveredStorageSegmentID: String?
    @State private var isMemorySummaryExpanded = false
    @State private var isStorageSummaryExpanded = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarNavigationView(
                activeTab: activeSidebarTab,
                onTabSelected: switchToSidebarTab
            )
            VStack(spacing: 0) {
                topBar
                content
                footer
            }
        }
        .frame(
            width: popoverResizePreviewWidth ?? settings.mainPopoverCurrentWidth,
            height: SettingsStore.mainPopoverFixedHeight
        )
        .background(popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            popoverResizeHandle
        }
        .overlay {
            if storageManagementViewModel.showingDeleteConfirmation {
                StorageDeleteConfirmationOverlay(
                    storageManagementViewModel: storageManagementViewModel,
                    didConfirmDeletion: $didConfirmStorageDeletion
                )
            }
        }
        .shadow(color: Color.black.opacity(0.45), radius: 28, y: 14)
        .preferredColorScheme(settings.appTheme.isDark ? .dark : .light)
        .id(settings.appTheme)
        .onAppear {
            isMemorySummaryExpanded = false
            isStorageSummaryExpanded = false
            hoveredStorageSegmentID = nil
            normalizeLegacyScreenIfNeeded()
            synchronizeRAMDetailsRefresh(for: viewModel.screen)
            storageManagementViewModel.loadIfNeeded()
        }
        .onDisappear {
            ramDetailsViewModel.stop()
            resetPopoverResizeDragState()
        }
        .onChange(of: viewModel.screen) { _, screen in
            synchronizeRAMDetailsRefresh(for: screen)
        }
    }

    private var popoverBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: settings.appTheme.isDark
                    ? [Color.black.opacity(0.52), Color.black.opacity(0.34)]
                    : [Color.white.opacity(0.72), Color.white.opacity(0.54)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: settings.appTheme.isDark
                    ? [Color.white.opacity(0.05), Color.clear, Color(hex: 0x5E5CE6, opacity: 0.12)]
                    : [Color.white.opacity(0.38), Color.clear, Color(hex: 0x5E5CE6, opacity: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            thermalStatusBadge

            Spacer(minLength: 8)

            Button {
                toggleTheme()
            } label: {
                Image(systemName: settings.appTheme.isDark ? "sun.max" : "moon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(PopoverTheme.bgCard.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle Light/Dark Theme")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(PopoverTheme.bgPanel.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var thermalStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(thermalColor(for: viewModel.thermalState))
                .frame(width: 8, height: 8)
                .shadow(color: thermalColor(for: viewModel.thermalState).opacity(0.6), radius: 6)

            Text(viewModel.thermalState.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)

            if viewModel.isStale {
                Text("Stale")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PopoverTheme.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PopoverTheme.orangeDim)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(PopoverTheme.bgCard.opacity(0.65))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }


    private var content: some View {
        Group {
            switch viewModel.screen {
            case .storageManagement, .storage:
                unifiedStorageScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
            case .ramPolicyManager:
                ScrollView(showsIndicators: true) {
                    policiesScreen
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            case .trends:
                ScrollView(showsIndicators: true) {
                    trendsOverviewScreen
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            case .settings:
                ScrollView(showsIndicators: true) {
                    settingsOverviewScreen
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            case .battery:
                ScrollView(showsIndicators: true) {
                    batteryOverviewScreen
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            case .temperature, .ram:
                ScrollView(showsIndicators: true) {
                    memoryOverviewScreen
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
        }
        .disabled(storageManagementViewModel.showingDeleteConfirmation)
    }

    private var batteryOverviewScreen: some View {
        BatteryScreenView(
            battery: viewModel.snapshot?.battery,
            settings: settings,
            coordinator: batteryPolicyCoordinator,
            scheduleViewModel: batteryScheduleViewModel
        )
    }

    private var memoryOverviewScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            memorySummaryCard
            RAMDetailsView(
                viewModel: ramDetailsViewModel,
                memorySnapshot: nil,
                onBack: viewModel.showRAM,
                showsBackButton: false
            )
        }
        .onAppear {
            if viewModel.screen != .ram {
                viewModel.showRAM()
            }
        }
    }

    @ViewBuilder
    private var memorySummaryCard: some View {
        if let memory = viewModel.snapshot?.memory {
            let segments = memorySegments(for: memory)
            let appMemoryText = memoryByteText(memory.appMemoryBytes.map { min($0, memory.totalBytes) })
            let wiredMemoryText = memoryByteText(memory.wiredMemoryBytes.map { min($0, memory.totalBytes) })
            let compressedText = memoryByteText(memory.compressedBytes.map { min($0, memory.totalBytes) })
            let cachedFilesText = memoryByteText((memory.cachedFilesBytes ?? memory.inactiveBytes).map { min($0, memory.totalBytes) })
            let swapUsedText = memoryByteText(memory.swapUsedBytes)

            panelCard {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .tracking(0.5)

                        Text("Memory Pressure")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .tracking(0.5)
                    }

                    Spacer(minLength: 8)

                    summaryDisclosureButton(
                        isExpanded: isMemorySummaryExpanded,
                        onToggle: { isMemorySummaryExpanded.toggle() }
                    )
                }

                HStack {
                    Text("Physical Memory: \(MetricFormatter.bytes(memory.totalBytes))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PopoverTheme.textSecondary)

                    Spacer(minLength: 8)

                    Text("Memory Used: \(MetricFormatter.bytes(memory.usedBytes)) / \(MetricFormatter.bytes(memory.totalBytes))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if isMemorySummaryExpanded {
                    usageTrack(segments: segments)
                        .frame(height: 10)

                    HStack(alignment: .top, spacing: 10) {
                        ForEach(segments) { segment in
                            memorySegmentCard(segment)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Divider()
                        .overlay(PopoverTheme.borderSubtle)

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            memoryStatRow(title: "Physical Memory", value: MetricFormatter.bytes(memory.totalBytes))
                            memoryStatRow(title: "Memory Used", value: MetricFormatter.bytes(memory.usedBytes))
                            memoryStatRow(title: "Cached Files", value: cachedFilesText)
                            memoryStatRow(title: "Swap Used", value: swapUsedText)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            memoryStatRow(title: "App Memory", value: appMemoryText)
                            memoryStatRow(title: "Wired Memory", value: wiredMemoryText)
                            memoryStatRow(title: "Compressed", value: compressedText)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isMemorySummaryExpanded)
        } else {
            panelCard {
                Text("Collecting memory metrics...")
                    .font(.system(size: 12))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
    }

    private var unifiedStorageScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            storageSummaryCard
            StorageManagementView(
                viewModel: storageManagementViewModel,
                onBack: viewModel.showStorage,
                showBackButton: false,
                showHeader: false
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            if viewModel.screen != .storage {
                viewModel.showStorage()
            }
            storageManagementViewModel.loadIfNeeded()
        }
    }

    private var storageTopActions: some View {
        HStack(spacing: 8) {
            Button {
                storageManagementViewModel.refresh()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textSecondary)
            .disabled(
                storageManagementViewModel.isScanning ||
                    storageManagementViewModel.isDeleteFlowInteractionLocked ||
                    storageManagementViewModel.showingDeleteConfirmation
            )

            Button {
                addStorageFoldersFromPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Folder")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.accentContrastText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(PopoverTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(
                storageManagementViewModel.isDeleteFlowInteractionLocked ||
                    storageManagementViewModel.showingDeleteConfirmation
            )
        }
    }

    private func addStorageFoldersFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Track"
        panel.message = "Choose folders to scan and manage."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK {
            for selectedURL in panel.urls {
                storageManagementViewModel.addCustomFolder(selectedURL)
            }
        }
    }

    private var storageSummaryCard: some View {
        let segments = storageSegments()
        let hoveredSegment = segments.first { $0.id == hoveredStorageSegmentID }
        let usedBytesText = MetricFormatter.bytes(storageManagementViewModel.currentUsedBytes)
        let totalBytesText = MetricFormatter.bytes(storageManagementViewModel.currentTotalBytes)

        return VStack(alignment: .leading, spacing: isStorageSummaryExpanded ? 8 : 0) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textMuted)

                Text("\(usedBytesText) / \(totalBytesText)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textPrimary)
                    .lineLimit(1)

                if isStorageSummaryExpanded, let hoveredSegment {
                    Text("\(hoveredSegment.title) \(MetricFormatter.bytes(hoveredSegment.bytes))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                        .transition(.opacity)
                }

                Spacer(minLength: 8)
                storageTopActions

                summaryDisclosureButton(
                    isExpanded: isStorageSummaryExpanded,
                    onToggle: {
                        isStorageSummaryExpanded.toggle()
                        if !isStorageSummaryExpanded {
                            hoveredStorageSegmentID = nil
                        }
                    }
                )
            }

            if isStorageSummaryExpanded {
                compactStorageUsageTrack(segments: segments)
                    .frame(height: 12)

                storageScanSourcesStrip
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.12), value: hoveredStorageSegmentID)
        .animation(.easeInOut(duration: 0.18), value: isStorageSummaryExpanded)
    }

    private var storageScanSourcesStrip: some View {
        let defaultSources = storageManagementViewModel.defaultScanSourcePaths
        let addedSources = storageManagementViewModel.addedScanSourcePaths

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Scan:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textSecondary)

                storageScanSourceChip(
                    title: "Default \(defaultSources.count)",
                    foreground: PopoverTheme.textPrimary,
                    fill: PopoverTheme.bgElevated,
                    stroke: PopoverTheme.borderSubtle,
                    sources: defaultSources,
                    emptyText: "No default scan folders."
                )

                storageScanSourceChip(
                    title: "Added \(addedSources.count)",
                    foreground: addedSources.isEmpty ? PopoverTheme.textMuted : PopoverTheme.accent,
                    fill: PopoverTheme.bgElevated,
                    stroke: PopoverTheme.borderSubtle,
                    sources: addedSources,
                    emptyText: "No custom folders added."
                )
            }
            .padding(.vertical, 1)
        }
    }

    private func storageScanSourceChip(
        title: String,
        foreground: Color,
        fill: Color,
        stroke: Color,
        sources: [String],
        emptyText: String
    ) -> some View {
        StorageScanSourceChipView(
            title: title,
            foreground: foreground,
            fill: fill,
            stroke: stroke,
            sources: sources,
            emptyText: emptyText
        )
    }

    private func compactStorageUsageTrack(segments: [StorageUsageSegment]) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PopoverTheme.borderMedium)

                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        let width = geometry.size.width * max(0, min(segment.ratio, 1))

                        Rectangle()
                            .fill(segment.color)
                            .frame(width: width)
                            .overlay {
                                if hoveredStorageSegmentID == segment.id {
                                    Rectangle()
                                        .stroke(PopoverTheme.textPrimary.opacity(0.7), lineWidth: 1)
                                }
                            }
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    hoveredStorageSegmentID = segment.id
                                } else if hoveredStorageSegmentID == segment.id {
                                    hoveredStorageSegmentID = nil
                                }
                            }
                            .help("\(segment.title): \(MetricFormatter.bytes(segment.bytes))")
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var settingsOverviewScreen: some View {
        PopoverSettingsScreenView(
            settings: settings,
            appUpdateController: appUpdateController,
            batteryPolicyCoordinator: batteryPolicyCoordinator,
            snapshot: viewModel.snapshot,
            history: viewModel.history,
            diagnosticsExporter: diagnosticsExporter,
            auxiliaryPanelPresentationHandler: auxiliaryPanelPresentationHandler,
            onShowSettings: {
                if viewModel.screen != .settings {
                    viewModel.showSettings()
                }
            },
            onRAMPolicyRefresh: ramPolicyViewModel.refresh
        )
    }

    private var trendsOverviewScreen: some View {
        TrendsView(viewModel: viewModel)
            .onAppear {
                if viewModel.screen != .trends {
                    viewModel.showTrends()
                }
            }
    }

    private var policiesScreen: some View {
        RAMPolicySettingsView(
            viewModel: ramPolicyViewModel,
            onBack: viewModel.showSettings
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if appUpdateController.canRestartToInstallUpdate {
                Button {
                    appUpdateController.restartToInstallUpdate()
                } label: {
                    Label("Restart to Update", systemImage: "arrow.clockwise.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0x0A84FF))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Label("Power Optimized", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            Spacer(minLength: 8)

            Text(appVersionLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(PopoverTheme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PopoverTheme.bgPanel.opacity(0.72))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var popoverResizeHandle: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .padding(.trailing, 4)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if popoverResizeDragStartWidth == nil {
                            popoverResizeDragStartWidth = activePopoverWindowContentWidth ?? settings.mainPopoverCurrentWidth
                        }
                        let startWidth = popoverResizeDragStartWidth ?? settings.mainPopoverCurrentWidth
                        let horizontalDelta = value.translation.width
                        let targetWidth = SettingsStore.normalizedMainPopoverWidth(startWidth + horizontalDelta)
                        if let previewWidth = popoverResizePreviewWidth,
                           abs(previewWidth - targetWidth) <= 0.5 {
                            return
                        }
                        popoverResizePreviewWidth = targetWidth
                        applyActivePopoverWindowWidth(targetWidth)
                    }
                    .onEnded { value in
                        let startWidth = popoverResizeDragStartWidth ?? settings.mainPopoverCurrentWidth
                        let horizontalDelta = value.translation.width
                        let finalWidth = SettingsStore.normalizedMainPopoverWidth(startWidth + horizontalDelta)
                        applyActivePopoverWindowWidth(finalWidth)
                        settings.updateMainPopoverCurrentWidth(finalWidth)
                        resetPopoverResizeDragState()
                    }
            )
            .help("Drag from the bottom-right corner to resize popover width")
    }

    private func resetPopoverResizeDragState() {
        popoverResizeDragStartWidth = nil
        popoverResizePreviewWidth = nil
    }

    private var activePopoverWindow: NSWindow? {
        if let providedWindow = popoverWindowProvider?() {
            return providedWindow
        }
        return NSApp.keyWindow ?? NSApp.mainWindow
    }

    private var activePopoverWindowContentWidth: CGFloat? {
        activePopoverWindow?.contentLayoutRect.width
    }

    private func applyActivePopoverWindowWidth(_ width: CGFloat) {
        guard let window = activePopoverWindow else { return }
        let normalizedWidth = SettingsStore.normalizedMainPopoverWidth(width)
        if abs(window.contentLayoutRect.width - normalizedWidth) <= 0.5 {
            return
        }
        window.setContentSize(
            NSSize(width: normalizedWidth, height: SettingsStore.mainPopoverFixedHeight)
        )
    }

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func usageTrack(segments: [MemoryUsageSegment]) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PopoverTheme.borderMedium)

                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: geometry.size.width * max(0, min(segment.ratio, 1)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func usageTrack(segments: [StorageUsageSegment]) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PopoverTheme.borderMedium)

                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: geometry.size.width * max(0, min(segment.ratio, 1)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func memoryStatRow(title: String, value: String) -> some View {
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

    private func summaryDisclosureButton(isExpanded: Bool, onToggle: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                onToggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PopoverTheme.textMuted)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PopoverTheme.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func memorySegmentCard(_ segment: MemoryUsageSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(segment.color)
                    .frame(width: 7, height: 7)

                Text(segment.title)
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .lineLimit(1)
            }

            Text(MetricFormatter.bytes(segment.bytes))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(PopoverTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func memoryByteText(_ value: UInt64?) -> String {
        guard let value else { return "--" }
        return MetricFormatter.bytes(value)
    }

    private func memorySegments(for memory: MemorySnapshot) -> [MemoryUsageSegment] {
        let total = max(memory.totalBytes, 1)
        let usedBytes = min(memory.usedBytes, total)
        let cachedBytes = min(memory.inactiveBytes ?? 0, total)
        let fallbackFreeBytes = max(total - min(total, usedBytes + cachedBytes), 0)
        let freeBytes = min(memory.freeBytes ?? fallbackFreeBytes, total)

        let rawSegments: [(id: String, title: String, bytes: UInt64, color: Color)] = [
            ("used", "Memory Used", usedBytes, PopoverTheme.accent),
            ("cached", "Cached Files", cachedBytes, PopoverTheme.orange),
            ("free", "Free", freeBytes, PopoverTheme.textMuted)
        ]

        return rawSegments.map { segment in
            MemoryUsageSegment(
                id: segment.id,
                title: segment.title,
                bytes: segment.bytes,
                ratio: Double(segment.bytes) / Double(total),
                color: segment.color
            )
        }
    }

    private func storageSegments() -> [StorageUsageSegment] {
        let total = max(storageManagementViewModel.currentTotalBytes, 1)
        let used = storageManagementViewModel.currentUsedBytes

        let appBytes = min(storageManagementViewModel.appGroups.reduce(UInt64(0)) { $0 + $1.totalBytes }, used)
        let cacheCandidates = storageManagementViewModel.looseItems
            .filter { $0.category == .cache }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }
        let cacheBytes = min(cacheCandidates, max(used - appBytes, 0))
        let folderBytes = max(used - appBytes - cacheBytes, 0)

        let rawSegments: [(id: String, title: String, bytes: UInt64, color: Color)] = [
            ("apps", "Apps", appBytes, PopoverTheme.blue),
            ("folders", "Folders", folderBytes, PopoverTheme.purple),
            ("cache", "Cache", cacheBytes, PopoverTheme.green)
        ]

        return rawSegments.map { segment in
            StorageUsageSegment(
                id: segment.id,
                title: segment.title,
                bytes: segment.bytes,
                ratio: Double(segment.bytes) / Double(total),
                color: segment.color
            )
        }
    }

    private var appSemanticVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var appVersionLabel: String {
        "v\(appSemanticVersion)"
    }

    private var activeSidebarTab: SidebarTab {
        switch viewModel.screen {
        case .storage, .storageManagement:
            return .storage
        case .trends:
            return .trends
        case .settings, .ramPolicyManager:
            return .settings
        case .battery:
            return .battery
        case .temperature, .ram:
            return .memory
        }
    }

    private func switchToSidebarTab(_ tab: SidebarTab) {
        switch tab {
        case .memory:
            viewModel.showRAM()
        case .battery:
            viewModel.showBattery()
        case .storage:
            viewModel.showStorage()
        case .trends:
            viewModel.showTrends()
        case .settings:
            viewModel.showSettings()
        }
    }

    private func normalizeLegacyScreenIfNeeded() {
        guard !hasNormalizedLegacyScreen else { return }
        hasNormalizedLegacyScreen = true

        switch viewModel.screen {
        case .temperature:
            viewModel.showRAM()
        case .storageManagement:
            viewModel.showStorage()
        case .battery, .ram, .storage, .trends, .settings, .ramPolicyManager:
            break
        }
    }

    private func synchronizeRAMDetailsRefresh(for screen: SystemSummaryViewModel.Screen) {
        let shouldRefresh = screen == .ram || screen == .temperature

        if shouldRefresh {
            ramDetailsViewModel.start()
            ramDetailsViewModel.setRefreshActive(true)
            return
        }

        ramDetailsViewModel.setRefreshActive(false)
    }


    private func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.appTheme = pairedTheme(for: settings.appTheme)
        }
    }

    private func pairedTheme(for theme: AppTheme) -> AppTheme {
        switch theme {
        case .lime:
            return .daylight
        case .midnight:
            return .arctic
        case .cyber:
            return .sand
        case .daylight:
            return .lime
        case .arctic:
            return .midnight
        case .sand:
            return .cyber
        }
    }

    private func thermalColor(for state: ThermalState) -> Color {
        switch state {
        case .nominal:
            return PopoverTheme.green
        case .fair:
            return PopoverTheme.yellow
        case .serious:
            return PopoverTheme.orange
        case .critical:
            return PopoverTheme.red
        case .unknown:
            return PopoverTheme.textMuted
        }
    }
}
// MARK: - Theme Palette

struct ThemePalette {
    let bgDeep: Color
    let bgPanel: Color
    let bgCard: Color
    let bgCardHover: Color
    let bgElevated: Color

    let borderSubtle: Color
    let borderMedium: Color
    let borderActive: Color

    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    let accent: Color
    let accentDim: Color

    let blue: Color
    let blueDim: Color
    let blueGlow: Color

    let green: Color
    let greenDim: Color

    let yellow: Color
    let yellowDim: Color

    let orange: Color
    let orangeDim: Color

    let red: Color
    let redDim: Color

    let mint: Color
    let mintDim: Color

    let purple: Color
    let purpleDim: Color

    /// Toggle knob and accent-on-accent text color
    let accentContrastText: Color

    /// Toggle track off state
    let toggleOffTrack: Color
    let toggleOffKnob: Color
}

// MARK: - PopoverTheme (dynamic)

enum PopoverTheme {
    nonisolated(unsafe) private(set) static var current: ThemePalette = palette(for: .lime)

    @MainActor
    static func applyTheme(_ theme: AppTheme) {
        current = palette(for: theme)
    }

    // ── Convenience accessors (keeps every call site unchanged) ──

    static var bgDeep: Color { current.bgDeep }
    static var bgPanel: Color { current.bgPanel }
    static var bgCard: Color { current.bgCard }
    static var bgCardHover: Color { current.bgCardHover }
    static var bgElevated: Color { current.bgElevated }

    static var borderSubtle: Color { current.borderSubtle }
    static var borderMedium: Color { current.borderMedium }
    static var borderActive: Color { current.borderActive }

    static var textPrimary: Color { current.textPrimary }
    static var textSecondary: Color { current.textSecondary }
    static var textMuted: Color { current.textMuted }

    static var accent: Color { current.accent }
    static var accentDim: Color { current.accentDim }

    static var blue: Color { current.blue }
    static var blueDim: Color { current.blueDim }
    static var blueGlow: Color { current.blueGlow }

    static var green: Color { current.green }
    static var greenDim: Color { current.greenDim }

    static var yellow: Color { current.yellow }
    static var yellowDim: Color { current.yellowDim }

    static var orange: Color { current.orange }
    static var orangeDim: Color { current.orangeDim }

    static var red: Color { current.red }
    static var redDim: Color { current.redDim }

    static var mint: Color { current.mint }
    static var mintDim: Color { current.mintDim }

    static var purple: Color { current.purple }
    static var purpleDim: Color { current.purpleDim }

    static var accentContrastText: Color { current.accentContrastText }
    static var toggleOffTrack: Color { current.toggleOffTrack }
    static var toggleOffKnob: Color { current.toggleOffKnob }

    // ── Palette factory ──

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .lime:     return limePalette
        case .midnight: return midnightPalette
        case .cyber:    return cyberPalette
        case .daylight: return daylightPalette
        case .arctic:   return arcticPalette
        case .sand:     return sandPalette
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // DARK THEMES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let limePalette = ThemePalette(
        bgDeep:          Color(hex: 0x17171B),
        bgPanel:         Color(hex: 0x1D1D21),
        bgCard:          Color(hex: 0x232329),
        bgCardHover:     Color(hex: 0x2A2A30),
        bgElevated:      Color(hex: 0x202026),
        borderSubtle:    Color.white.opacity(0.09),
        borderMedium:    Color.white.opacity(0.14),
        borderActive:    Color(hex: 0x5E5CE6, opacity: 0.36),
        textPrimary:     Color(hex: 0xF5F5F7),
        textSecondary:   Color(hex: 0xC1C1C8),
        textMuted:       Color(hex: 0xA1A1A6),
        accent:          Color(hex: 0x5E5CE6),
        accentDim:       Color(hex: 0x5E5CE6, opacity: 0.12),
        blue:            Color(hex: 0x0A84FF),
        blueDim:         Color(hex: 0x0A84FF, opacity: 0.12),
        blueGlow:        Color(hex: 0x0A84FF, opacity: 0.18),
        green:           Color(hex: 0x32D74B),
        greenDim:        Color(hex: 0x32D74B, opacity: 0.12),
        yellow:          Color(hex: 0xFFD60A),
        yellowDim:       Color(hex: 0xFFD60A, opacity: 0.12),
        orange:          Color(hex: 0xFF9F0A),
        orangeDim:       Color(hex: 0xFF9F0A, opacity: 0.12),
        red:             Color(hex: 0xFF453A),
        redDim:          Color(hex: 0xFF453A, opacity: 0.12),
        mint:            Color(hex: 0x64D2FF),
        mintDim:         Color(hex: 0x64D2FF, opacity: 0.12),
        purple:          Color(hex: 0xBF5AF2),
        purpleDim:       Color(hex: 0xBF5AF2, opacity: 0.12),
        accentContrastText: .white,
        toggleOffTrack:  Color(hex: 0x787880, opacity: 0.35),
        toggleOffKnob:   .white
    )

    private static let midnightPalette = ThemePalette(
        bgDeep:          Color(hex: 0x000000),
        bgPanel:         Color(hex: 0x0a0a0a),
        bgCard:          Color(hex: 0x111111),
        bgCardHover:     Color(hex: 0x1a1a1a),
        bgElevated:      Color(hex: 0x0d0d0d),
        borderSubtle:    Color.white.opacity(0.06),
        borderMedium:    Color.white.opacity(0.10),
        borderActive:    Color(hex: 0x3b82f6, opacity: 0.40),
        textPrimary:     Color(hex: 0xf0f0f0),
        textSecondary:   Color(hex: 0x7a7a7a),
        textMuted:       Color(hex: 0x444444),
        accent:          Color(hex: 0x3b82f6),
        accentDim:       Color(hex: 0x3b82f6, opacity: 0.12),
        blue:            Color(hex: 0x3b82f6),
        blueDim:         Color(hex: 0x3b82f6, opacity: 0.12),
        blueGlow:        Color(hex: 0x3b82f6, opacity: 0.15),
        green:           Color(hex: 0x22c55e),
        greenDim:        Color(hex: 0x22c55e, opacity: 0.12),
        yellow:          Color(hex: 0xeab308),
        yellowDim:       Color(hex: 0xeab308, opacity: 0.12),
        orange:          Color(hex: 0xf97316),
        orangeDim:       Color(hex: 0xf97316, opacity: 0.12),
        red:             Color(hex: 0xef4444),
        redDim:          Color(hex: 0xef4444, opacity: 0.12),
        mint:            Color(hex: 0x06b6d4),
        mintDim:         Color(hex: 0x06b6d4, opacity: 0.12),
        purple:          Color(hex: 0x8b5cf6),
        purpleDim:       Color(hex: 0x8b5cf6, opacity: 0.12),
        accentContrastText: .white,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    private static let cyberPalette = ThemePalette(
        bgDeep:          Color(hex: 0x0a0a0f),
        bgPanel:         Color(hex: 0x0f0f18),
        bgCard:          Color(hex: 0x141420),
        bgCardHover:     Color(hex: 0x1a1a2e),
        bgElevated:      Color(hex: 0x121220),
        borderSubtle:    Color(hex: 0x00ffff, opacity: 0.10),
        borderMedium:    Color(hex: 0x00ffff, opacity: 0.16),
        borderActive:    Color(hex: 0x00ffcc, opacity: 0.40),
        textPrimary:     Color(hex: 0xe0ffe0),
        textSecondary:   Color(hex: 0x66cc99),
        textMuted:       Color(hex: 0x336655),
        accent:          Color(hex: 0x00ffcc),
        accentDim:       Color(hex: 0x00ffcc, opacity: 0.10),
        blue:            Color(hex: 0x00ccff),
        blueDim:         Color(hex: 0x00ccff, opacity: 0.12),
        blueGlow:        Color(hex: 0x00ccff, opacity: 0.15),
        green:           Color(hex: 0x00ff66),
        greenDim:        Color(hex: 0x00ff66, opacity: 0.12),
        yellow:          Color(hex: 0xffff00),
        yellowDim:       Color(hex: 0xffff00, opacity: 0.12),
        orange:          Color(hex: 0xff6600),
        orangeDim:       Color(hex: 0xff6600, opacity: 0.12),
        red:             Color(hex: 0xff0066),
        redDim:          Color(hex: 0xff0066, opacity: 0.12),
        mint:            Color(hex: 0x00ffff),
        mintDim:         Color(hex: 0x00ffff, opacity: 0.12),
        purple:          Color(hex: 0xcc00ff),
        purpleDim:       Color(hex: 0xcc00ff, opacity: 0.12),
        accentContrastText: .black,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // LIGHT THEMES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let daylightPalette = ThemePalette(
        bgDeep:          Color(hex: 0xF5F5F7),
        bgPanel:         Color.white,
        bgCard:          Color.white.opacity(0.62),
        bgCardHover:     Color.white.opacity(0.76),
        bgElevated:      Color.white.opacity(0.70),
        borderSubtle:    Color.black.opacity(0.05),
        borderMedium:    Color.black.opacity(0.10),
        borderActive:    Color(hex: 0x5E5CE6, opacity: 0.34),
        textPrimary:     Color(hex: 0x1D1D1F),
        textSecondary:   Color(hex: 0x4A4A50),
        textMuted:       Color(hex: 0x86868B),
        accent:          Color(hex: 0x5E5CE6),
        accentDim:       Color(hex: 0x5E5CE6, opacity: 0.10),
        blue:            Color(hex: 0x0A84FF),
        blueDim:         Color(hex: 0x0A84FF, opacity: 0.08),
        blueGlow:        Color(hex: 0x0A84FF, opacity: 0.12),
        green:           Color(hex: 0x32D74B),
        greenDim:        Color(hex: 0x32D74B, opacity: 0.08),
        yellow:          Color(hex: 0xFFD60A),
        yellowDim:       Color(hex: 0xFFD60A, opacity: 0.08),
        orange:          Color(hex: 0xFF9F0A),
        orangeDim:       Color(hex: 0xFF9F0A, opacity: 0.08),
        red:             Color(hex: 0xFF453A),
        redDim:          Color(hex: 0xFF453A, opacity: 0.08),
        mint:            Color(hex: 0x64D2FF),
        mintDim:         Color(hex: 0x64D2FF, opacity: 0.08),
        purple:          Color(hex: 0xBF5AF2),
        purpleDim:       Color(hex: 0xBF5AF2, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color(hex: 0x787880, opacity: 0.32),
        toggleOffKnob:   .white
    )

    private static let arcticPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf0f4f8),
        bgPanel:         Color(hex: 0xe2e8f0),
        bgCard:          Color(hex: 0xffffff),
        bgCardHover:     Color(hex: 0xf1f5f9),
        bgElevated:      Color(hex: 0xf8fafc),
        borderSubtle:    Color(hex: 0x0f172a, opacity: 0.08),
        borderMedium:    Color(hex: 0x0f172a, opacity: 0.13),
        borderActive:    Color(hex: 0x2563eb, opacity: 0.35),
        textPrimary:     Color(hex: 0x0f172a),
        textSecondary:   Color(hex: 0x475569),
        textMuted:       Color(hex: 0x94a3b8),
        accent:          Color(hex: 0x2563eb),
        accentDim:       Color(hex: 0x2563eb, opacity: 0.08),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x059669),
        greenDim:        Color(hex: 0x059669, opacity: 0.08),
        yellow:          Color(hex: 0xca8a04),
        yellowDim:       Color(hex: 0xca8a04, opacity: 0.08),
        orange:          Color(hex: 0xea580c),
        orangeDim:       Color(hex: 0xea580c, opacity: 0.08),
        red:             Color(hex: 0xdc2626),
        redDim:          Color(hex: 0xdc2626, opacity: 0.08),
        mint:            Color(hex: 0x0891b2),
        mintDim:         Color(hex: 0x0891b2, opacity: 0.08),
        purple:          Color(hex: 0x7c3aed),
        purpleDim:       Color(hex: 0x7c3aed, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )

    private static let sandPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf5f0eb),
        bgPanel:         Color(hex: 0xe8e0d8),
        bgCard:          Color(hex: 0xfffefa),
        bgCardHover:     Color(hex: 0xf7f2ed),
        bgElevated:      Color(hex: 0xfaf7f4),
        borderSubtle:    Color(hex: 0x3c2814, opacity: 0.08),
        borderMedium:    Color(hex: 0x3c2814, opacity: 0.12),
        borderActive:    Color(hex: 0x0d9488, opacity: 0.35),
        textPrimary:     Color(hex: 0x1c1512),
        textSecondary:   Color(hex: 0x6b5c50),
        textMuted:       Color(hex: 0xa89888),
        accent:          Color(hex: 0x0d9488),
        accentDim:       Color(hex: 0x0d9488, opacity: 0.10),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x15803d),
        greenDim:        Color(hex: 0x15803d, opacity: 0.08),
        yellow:          Color(hex: 0xa16207),
        yellowDim:       Color(hex: 0xa16207, opacity: 0.08),
        orange:          Color(hex: 0xc2410c),
        orangeDim:       Color(hex: 0xc2410c, opacity: 0.08),
        red:             Color(hex: 0xb91c1c),
        redDim:          Color(hex: 0xb91c1c, opacity: 0.08),
        mint:            Color(hex: 0x0d9488),
        mintDim:         Color(hex: 0x0d9488, opacity: 0.08),
        purple:          Color(hex: 0x6d28d9),
        purpleDim:       Color(hex: 0x6d28d9, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )
}

struct PopoverToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isOn ? PopoverTheme.accent : PopoverTheme.toggleOffTrack)
                .frame(width: 36, height: 20)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(isOn ? PopoverTheme.accentContrastText : PopoverTheme.toggleOffKnob)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn ? 18 : 2)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
