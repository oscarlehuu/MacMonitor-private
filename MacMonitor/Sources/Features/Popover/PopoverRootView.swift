import AppKit
import SwiftUI

private enum MainPopoverTab: CaseIterable, Hashable {
    case memory
    case storageApps
    case trends
    case settings

    var title: String {
        switch self {
        case .memory:
            return "Memory"
        case .storageApps:
            return "Storage & Apps"
        case .trends:
            return "Trends"
        case .settings:
            return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .memory:
            return "cpu"
        case .storageApps:
            return "internaldrive"
        case .trends:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape"
        }
    }
}

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

private struct StorageDeletePreviewGroupSection: Identifiable {
    let group: StorageAppGroup
    let rows: [StorageListRow]

    var id: String { group.id }
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

@MainActor
private final class PopoverColorPanelController: NSObject, ObservableObject {
    private static weak var activeController: PopoverColorPanelController?
    private var onChange: ((Color) -> Void)?

    func present(color: Color, onChange: @escaping (Color) -> Void) {
        self.onChange = onChange

        let panel = NSColorPanel.shared
        Self.activeController = self
        panel.setTarget(self)
        panel.setAction(#selector(handleColorChange(_:)))
        panel.isContinuous = true
        panel.showsAlpha = false
        panel.color = NSColor(color)
        // Defer to the next run loop so the popover button click can finish
        // before we ask AppKit to surface the shared color panel above it.
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }

    func disconnectIfActive() {
        guard Self.activeController === self else { return }

        let panel = NSColorPanel.shared
        Self.activeController = nil
        panel.setTarget(nil)
        panel.setAction(nil)
        onChange = nil
    }

    @objc private func handleColorChange(_ sender: NSColorPanel) {
        onChange?(Color(nsColor: sender.color))
    }
}

private extension Color {
    var popoverAccessibilityValue: String {
        guard let sRGBColor = NSColor(self).usingColorSpace(.sRGB) else {
            return "Selected color"
        }

        let red = Int((sRGBColor.redComponent * 255.0).rounded())
        let green = Int((sRGBColor.greenComponent * 255.0).rounded())
        let blue = Int((sRGBColor.blueComponent * 255.0).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

private struct PopoverColorSwatchButton<Swatch: View>: View {
    @Binding var selection: Color
    let accessibilityLabel: String
    let helpText: String?
    @ViewBuilder let swatch: (Color) -> Swatch

    @StateObject private var colorPanelController = PopoverColorPanelController()

    var body: some View {
        Button {
            colorPanelController.present(color: selection) { selection = $0 }
        } label: {
            swatch(selection)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selection.popoverAccessibilityValue)
        .help(helpText ?? accessibilityLabel)
        .onDisappear {
            colorPanelController.disconnectIfActive()
        }
    }
}

struct PopoverRootView: View {
    private static let modalAppIconCache = NSCache<NSString, NSImage>()

    @ObservedObject var viewModel: SystemSummaryViewModel
    @ObservedObject var ramDetailsViewModel: RAMDetailsViewModel
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    @ObservedObject var storageManagementViewModel: StorageManagementViewModel
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    @ObservedObject var batteryScheduleViewModel: BatteryScheduleViewModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController
    let popoverWindowProvider: (() -> NSWindow?)?
    let diagnosticsExporter: DiagnosticsExporter

    @State private var hasNormalizedLegacyScreen = false
    @State private var diagnosticsStatusMessage: String?
    @State private var popoverResizeDragStartWidth: CGFloat?
    @State private var popoverResizePreviewWidth: CGFloat?
    @State private var deleteConfirmationAcknowledged = false
    @State private var deleteConfirmationSnapshot: StorageSelectionSnapshot?
    @State private var deleteConfirmationRootItemIDs: Set<String> = []
    @State private var didConfirmStorageDeletion = false
    @State private var hoveredStorageSegmentID: String?
    @State private var isMemorySummaryExpanded = false
    @State private var isStorageSummaryExpanded = false
    @State private var cachedDeletePreviewGroupSections: [StorageDeletePreviewGroupSection] = []
    @State private var cachedDeletePreviewLooseRows: [StorageListRow] = []
    @State private var isMenuBarComposerPresented = false
    @State private var menuBarComposerDraftConfiguration: MenuBarComposerConfiguration = .default

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            footer
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
                storageDeleteConfirmationOverlay
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
            updateRAMRefreshActivity(for: viewModel.screen)
            ramDetailsViewModel.start()
            storageManagementViewModel.loadIfNeeded()
        }
        .onDisappear {
            ramDetailsViewModel.stop()
            resetPopoverResizeDragState()
        }
        .onChange(of: viewModel.screen) { _, screen in
            updateRAMRefreshActivity(for: screen)
        }
        .onChange(of: storageManagementViewModel.showingDeleteConfirmation) { _, isPresented in
            if isPresented {
                didConfirmStorageDeletion = false
                deleteConfirmationAcknowledged = false
                deleteConfirmationSnapshot = storageManagementViewModel.makeSelectionSnapshot()
                deleteConfirmationRootItemIDs = storageManagementViewModel.deletionPreviewRootItemIDs
                refreshDeletePreviewCache()
                return
            }

            if !didConfirmStorageDeletion, let snapshot = deleteConfirmationSnapshot {
                storageManagementViewModel.restoreSelectionSnapshot(snapshot)
            }
            didConfirmStorageDeletion = false
            deleteConfirmationAcknowledged = false
            deleteConfirmationRootItemIDs = []
            deleteConfirmationSnapshot = nil
            clearDeletePreviewCache()
        }
        .onChange(of: storageManagementViewModel.selectedItemIDs) { _, _ in
            if storageManagementViewModel.showingDeleteConfirmation {
                deleteConfirmationAcknowledged = false
                refreshDeletePreviewCache()
            }
        }
        .onChange(of: storageManagementViewModel.expandedItemIDs) { _, _ in
            if storageManagementViewModel.showingDeleteConfirmation {
                refreshDeletePreviewCache()
            }
        }
        .onChange(of: storageManagementViewModel.drilledItemsByParentID) { _, _ in
            if storageManagementViewModel.showingDeleteConfirmation {
                refreshDeletePreviewCache()
            }
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

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Label {
                    Text("MacMonitor")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                } icon: {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PopoverTheme.accent)
                }
                .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                thermalStatusBadge

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

            HStack(spacing: 6) {
                ForEach(MainPopoverTab.allCases, id: \.self) { tab in
                    mainTabButton(tab)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
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

    private func mainTabButton(_ tab: MainPopoverTab) -> some View {
        let isActive = activeTab == tab

        return Button {
            switchToTab(tab)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(isActive ? PopoverTheme.textPrimary : PopoverTheme.textMuted)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? PopoverTheme.bgCard : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isActive ? PopoverTheme.borderMedium : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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

    private var storageDeleteConfirmationOverlay: some View {
        let previewGroupSections = cachedDeletePreviewGroupSections
        let previewLooseRows = cachedDeletePreviewLooseRows
        let hasPreviewRows = !previewGroupSections.isEmpty || !previewLooseRows.isEmpty

        return ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    cancelStorageDeleteConfirmation()
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Move selected items to Trash?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text(
                    "Selected: \(storageManagementViewModel.selectedAllowedCount) • " +
                    MetricFormatter.bytes(storageManagementViewModel.selectedAllowedBytes)
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PopoverTheme.textSecondary)

                if !hasPreviewRows {
                    Text("No selected items.")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(previewGroupSections.enumerated()), id: \.element.id) { index, section in
                                storageDeletePreviewGroupRow(section)

                                if storageManagementViewModel.expandedGroupIDs.contains(section.group.id) {
                                    ForEach(section.rows) { row in
                                        storageDeletePreviewRow(row, depthOffset: 1)
                                    }
                                }

                                if index < previewGroupSections.count - 1 || !previewLooseRows.isEmpty {
                                    storageDeletePreviewDivider
                                }
                            }

                            if !previewLooseRows.isEmpty {
                                storageDeletePreviewLooseHeader

                                ForEach(Array(previewLooseRows.enumerated()), id: \.element.id) { index, row in
                                    if index > 0 {
                                        storageDeletePreviewDivider
                                    }
                                    storageDeletePreviewRow(row, depthOffset: 0)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 212)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PopoverTheme.bgElevated.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                    )
                }

                Button {
                    deleteConfirmationAcknowledged.toggle()
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(PopoverTheme.borderMedium, lineWidth: 1.2)
                                .frame(width: 16, height: 16)

                            if deleteConfirmationAcknowledged {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(PopoverTheme.accent)
                                    .frame(width: 16, height: 16)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PopoverTheme.accentContrastText)
                            }
                        }

                        Text("I reviewed these items and still want to move them to Trash.")
                            .font(.system(size: 10))
                            .foregroundStyle(PopoverTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)

                HStack(spacing: 8) {
                    Button("Cancel") {
                        cancelStorageDeleteConfirmation()
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PopoverTheme.bgElevated)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                    )

                    Spacer(minLength: 0)

                    Button("Move to Trash") {
                        didConfirmStorageDeletion = true
                        Task { await storageManagementViewModel.deleteSelected() }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .foregroundStyle(
                        deleteConfirmationAcknowledged
                            ? PopoverTheme.accentContrastText
                            : PopoverTheme.textMuted
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                deleteConfirmationAcknowledged
                                    ? PopoverTheme.red
                                    : PopoverTheme.bgElevated
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                    )
                    .disabled(
                        !deleteConfirmationAcknowledged ||
                            storageManagementViewModel.selectedAllowedCount == 0 ||
                            storageManagementViewModel.isDeleteFlowInteractionLocked
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: 382)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.36), radius: 20, y: 10)
            .padding(.horizontal, 12)
        }
        .zIndex(200)
    }

    private func cancelStorageDeleteConfirmation() {
        storageManagementViewModel.showingDeleteConfirmation = false
    }

    private var storageDeletePreviewLooseHeader: some View {
        HStack(spacing: 8) {
            Spacer()
                .frame(width: 12)

            Image(systemName: "tray.full")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PopoverTheme.mint)
                .frame(width: 12)

            Text("Other Targets")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var storageDeletePreviewDivider: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.leading, 8)
    }

    private func storageDeletePreviewGroupRow(_ section: StorageDeletePreviewGroupSection) -> some View {
        let group = section.group
        let selectionState = storageManagementViewModel.groupSelectionState(group)
        let isExpanded = storageManagementViewModel.expandedGroupIDs.contains(group.id)

        return HStack(spacing: 8) {
            Button {
                storageManagementViewModel.toggleGroupExpansion(group.id)
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .frame(width: 10)
            }
            .buttonStyle(.plain)
            .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)

            Button {
                storageManagementViewModel.toggleGroupSelection(group.id)
            } label: {
                Image(systemName: modalGroupSelectionSymbol(selectionState))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(modalGroupSelectionColor(selectionState))
            }
            .buttonStyle(.plain)
            .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)

            if let appIcon = modalAppIconImage(for: group) {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PopoverTheme.blue)
                    .frame(width: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let bundleIdentifier = group.bundleIdentifier {
                    Text(bundleIdentifier)
                        .font(.system(size: 9))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            Text(MetricFormatter.bytes(group.totalBytes))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(PopoverTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    selectionState == .none
                        ? Color.clear
                        : PopoverTheme.bgCardHover.opacity(selectionState == .all ? 0.9 : 0.6)
                )
        )
    }

    private func storageDeletePreviewRow(_ row: StorageListRow, depthOffset: Int) -> some View {
        let item = row.item
        let isDirectlySelected = storageManagementViewModel.selectedItemIDs.contains(item.id)
        let isInDeletionScope = storageManagementViewModel.isItemInDeletionScope(item.id)
        let isIncludedByAncestor = isInDeletionScope && !isDirectlySelected
        let isExpanded = storageManagementViewModel.isItemExpanded(item.id)
        let isLoading = storageManagementViewModel.isLoadingChildren(for: item.id)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Spacer()
                    .frame(width: CGFloat(row.depth + depthOffset) * 12)

                if item.isExpandable {
                    Button {
                        storageManagementViewModel.toggleItemExpansion(item.id)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)
                } else {
                    Spacer()
                        .frame(width: 10)
                }

                Button {
                    storageManagementViewModel.toggleSelection(for: item.id)
                } label: {
                    Image(systemName: modalSelectionSymbol(
                        isDirectlySelected: isDirectlySelected,
                        isIncludedByAncestor: isIncludedByAncestor,
                        item: item
                    ))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(modalSelectionColor(
                            isDirectlySelected: isDirectlySelected,
                            isIncludedByAncestor: isIncludedByAncestor,
                            item: item
                        ))
                }
                .buttonStyle(.plain)
                .disabled(
                    item.isProtected ||
                        storageManagementViewModel.isDeleteFlowInteractionLocked
                )

                if let appIcon = modalAppIconImage(for: item) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                } else {
                    Image(systemName: storageItemIcon(for: item))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(storageItemColor(for: item.category))
                        .frame(width: 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.url.path)
                        .font(.system(size: 9))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if isIncludedByAncestor {
                        Text("Included via parent selection")
                            .font(.system(size: 8))
                            .foregroundStyle(PopoverTheme.orange)
                    }
                }

                Spacer(minLength: 8)

                Text(MetricFormatter.bytes(item.sizeBytes))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }

            if isExpanded && isLoading {
                HStack(spacing: 4) {
                    Spacer()
                        .frame(width: CGFloat(row.depth + depthOffset + 1) * 12 + 16)
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading children...")
                        .font(.system(size: 8))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    isInDeletionScope
                        ? PopoverTheme.bgCardHover.opacity(isDirectlySelected ? 1 : 0.62)
                        : Color.clear
                )
        )
    }

    private func refreshDeletePreviewCache() {
        let previewRootIDs = activeDeletePreviewRootItemIDs
        guard !previewRootIDs.isEmpty else {
            clearDeletePreviewCache()
            return
        }

        cachedDeletePreviewGroupSections = storageManagementViewModel.appGroups.compactMap { group in
            let filteredRows = storageManagementViewModel.rows(for: group).filter { row in
                isPreviewRowVisible(itemID: row.item.id, previewRootIDs: previewRootIDs)
            }
            guard !filteredRows.isEmpty else { return nil }
            return StorageDeletePreviewGroupSection(group: group, rows: filteredRows)
        }

        cachedDeletePreviewLooseRows = storageManagementViewModel.allLooseRows().filter { row in
            isPreviewRowVisible(itemID: row.item.id, previewRootIDs: previewRootIDs)
        }
    }

    private func clearDeletePreviewCache() {
        cachedDeletePreviewGroupSections = []
        cachedDeletePreviewLooseRows = []
    }

    private func isPreviewRowVisible(itemID: String, previewRootIDs: Set<String>) -> Bool {
        guard !previewRootIDs.isEmpty else { return false }

        if previewRootIDs.contains(itemID) {
            return true
        }
        if previewRootIDs.contains(where: { rootID in
            isAncestorPath(ancestor: rootID, descendant: itemID)
        }) {
            return true
        }
        return previewRootIDs.contains(where: { rootID in
            isAncestorPath(ancestor: itemID, descendant: rootID)
        })
    }

    private var activeDeletePreviewRootItemIDs: Set<String> {
        deleteConfirmationRootItemIDs.union(storageManagementViewModel.deletionPreviewRootItemIDs)
    }

    private func isAncestorPath(ancestor: String, descendant: String) -> Bool {
        if ancestor == descendant {
            return true
        }
        return descendant.hasPrefix(ancestor + "/")
    }

    private func modalGroupSelectionSymbol(_ state: StorageSelectionState) -> String {
        switch state {
        case .none:
            return "circle"
        case .partial:
            return "minus.circle.fill"
        case .all:
            return "checkmark.circle.fill"
        }
    }

    private func modalGroupSelectionColor(_ state: StorageSelectionState) -> Color {
        switch state {
        case .none:
            return PopoverTheme.textMuted
        case .partial:
            return PopoverTheme.orange
        case .all:
            return PopoverTheme.accent
        }
    }

    private func modalAppIconImage(for group: StorageAppGroup) -> NSImage? {
        let cacheKey = "group:\(group.id)" as NSString
        if let cachedIcon = Self.modalAppIconCache.object(forKey: cacheKey) {
            return cachedIcon
        }

        guard let appBundle = group.items.first(where: { $0.kind == .appBundle }),
              appBundle.url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: appBundle.url.path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appBundle.url.path)
        Self.modalAppIconCache.setObject(icon, forKey: cacheKey)
        return icon
    }

    private func modalAppIconImage(for item: StorageManagedItem) -> NSImage? {
        guard item.kind == .appBundle else { return nil }

        let cacheKey = "item:\(item.id)" as NSString
        if let cachedIcon = Self.modalAppIconCache.object(forKey: cacheKey) {
            return cachedIcon
        }

        guard item.url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: item.url.path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: item.url.path)
        Self.modalAppIconCache.setObject(icon, forKey: cacheKey)
        return icon
    }

    private func modalSelectionSymbol(
        isDirectlySelected: Bool,
        isIncludedByAncestor: Bool,
        item: StorageManagedItem
    ) -> String {
        if item.isProtected {
            return "lock.square.fill"
        }
        if isDirectlySelected {
            return "checkmark.square.fill"
        }
        if isIncludedByAncestor {
            return "checkmark.square"
        }
        return "square"
    }

    private func modalSelectionColor(
        isDirectlySelected: Bool,
        isIncludedByAncestor: Bool,
        item: StorageManagedItem
    ) -> Color {
        if item.isProtected {
            return PopoverTheme.orange
        }
        if isDirectlySelected {
            return PopoverTheme.accent
        }
        if isIncludedByAncestor {
            return PopoverTheme.orange
        }
        return PopoverTheme.textSecondary
    }

    private func storageItemIcon(for item: StorageManagedItem) -> String {
        switch item.kind {
        case .appBundle:
            return "app.dashed"
        case .appCache, .looseCache, .npmCache, .pnpmStore, .yarnCache:
            return "externaldrive.badge.timemachine"
        case .derivedData:
            return "hammer"
        case .xcodeArchives:
            return "archivebox"
        case .simulatorData:
            return "iphone.rear.camera"
        case .nodeModules:
            return "shippingbox"
        case .appSupport, .appContainer, .customFolder, .looseFolder, .drillDown:
            return item.category.symbolName
        case .appLogs:
            return "doc.text"
        case .appPreferences:
            return "slider.horizontal.3"
        }
    }

    private func storageItemColor(for category: StorageManagedItemCategory) -> Color {
        switch category {
        case .application:
            return PopoverTheme.blue
        case .cache:
            return PopoverTheme.mint
        case .folder:
            return PopoverTheme.purple
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
        VStack(alignment: .leading, spacing: 14) {
            settingsMenuBarCard
            settingsAlertsCard
            settingsAdvancedBatteryCard
            settingsGeneralDiagnosticsCard
            settingsAboutCard

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit MacMonitor", systemImage: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(settingsTextMain)
            .background(settingsInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(settingsCardBorder, lineWidth: 1)
            )
        }
        .onAppear {
            if viewModel.screen != .settings {
                viewModel.showSettings()
            }
            ramPolicyViewModel.refresh()
        }
    }

    private var settingsMenuBarCard: some View {
        settingsCard {
            settingsSectionHeader("Menu Bar Display", symbol: "rectangle.topthird.inset.filled")

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(settingsTextMain)

                    Text(
                        menuBarComposerPreviewAttributedString(
                            configuration: settings.menuBarComposerConfiguration,
                            baseColor: settingsTextMuted
                        )
                    )
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    menuBarComposerDraftConfiguration = settings.menuBarComposerConfiguration
                    isMenuBarComposerPresented = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(settingsTextMain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settingsInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(settingsCardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isMenuBarComposerPresented) {
            menuBarComposerSheet
        }
    }

    private var settingsGeneralDiagnosticsCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 0) {
                settingsCompactLaunchAtLoginRow
                settingsDivider
                settingsCompactPopoverWidthRow
                settingsDivider
                settingsCompactUpdatesRow
                settingsDivider
                settingsCompactDiagnosticsRow
            }
        }
    }

    private var settingsCompactLaunchAtLoginRow: some View {
        HStack(spacing: 10) {
            settingsCompactRowLabel("Launch at Login", symbol: "power")

            Spacer(minLength: 8)

            if let launchAtLoginError = settings.launchAtLoginError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.red)
                    .help(launchAtLoginError)
            }

            Toggle("", isOn: $settings.launchAtLoginEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settingsToggleTint)
        }
        .padding(.vertical, 7)
    }

    private var settingsCompactPopoverWidthRow: some View {
        HStack(spacing: 10) {
            settingsCompactRowLabel("Popover Width", symbol: "arrow.left.and.right")

            Spacer(minLength: 8)

            Text(formattedMainPopoverWidth(settings.mainPopoverCurrentWidth))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(settingsTextMuted)

            settingsCompactActionButton(
                "Save",
                tint: settings.hasUnsavedMainPopoverWidth ? PopoverTheme.accent : settingsTextMuted,
                isEnabled: settings.hasUnsavedMainPopoverWidth
            ) {
                settings.saveCurrentPopoverWidthAsDefault()
            }
            .help(
                "Current \(formattedMainPopoverWidth(settings.mainPopoverCurrentWidth)) • " +
                    "Default \(formattedMainPopoverWidth(settings.mainPopoverDefaultWidth))"
            )
        }
        .padding(.vertical, 7)
    }

    private var settingsCompactUpdatesRow: some View {
        let state = settingsCompactUpdateState

        return HStack(spacing: 10) {
            settingsCompactRowLabel("Updates", symbol: "arrow.triangle.2.circlepath")

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(state.color)
                    .frame(width: 7, height: 7)

                Text(state.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsTextMuted)
            }

            settingsCompactActionButton(
                settingsCompactUpdateActionTitle,
                tint: state == .failed ? PopoverTheme.red : PopoverTheme.accent,
                isEnabled: settingsCompactUpdateActionEnabled
            ) {
                if appUpdateController.canRestartToInstallUpdate {
                    appUpdateController.restartToInstallUpdate()
                } else {
                    appUpdateController.checkForUpdates()
                }
            }
        }
        .padding(.vertical, 7)
        .help(appUpdateController.detailMessage ?? appUpdateController.statusMessage)
    }

    private var settingsCompactDiagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                settingsCompactRowLabel("Diagnostics", symbol: "square.and.arrow.up")

                Spacer(minLength: 8)

                settingsCompactActionButton("Export") {
                    exportDiagnostics()
                }
                .help(diagnosticsStatusMessage ?? "Export diagnostics bundle")
            }

            if let diagnosticsStatusMessage {
                Text(diagnosticsStatusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(settingsTextMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 7)
    }

    private func settingsCompactRowLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(settingsTextMuted)
                .frame(width: 14)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(settingsTextMain)
        }
    }

    private func settingsCompactActionButton(
        _ title: String,
        tint: Color = PopoverTheme.accent,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isEnabled ? PopoverTheme.accentContrastText : settingsTextMain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isEnabled ? tint : settingsInputBackground)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.65)
    }

    private enum SettingsCompactUpdateState: Equatable {
        case ready
        case disabled
        case checking
        case available
        case upToDate
        case failed

        var label: String {
            switch self {
            case .ready:
                return "Ready"
            case .disabled:
                return "Off"
            case .checking:
                return "Checking"
            case .available:
                return "Available"
            case .upToDate:
                return "Up to date"
            case .failed:
                return "Failed"
            }
        }

        var color: Color {
            switch self {
            case .ready:
                return PopoverTheme.textMuted
            case .disabled:
                return PopoverTheme.textMuted
            case .checking:
                return PopoverTheme.orange
            case .available:
                return PopoverTheme.blue
            case .upToDate:
                return PopoverTheme.green
            case .failed:
                return PopoverTheme.red
            }
        }
    }

    private var settingsCompactUpdateState: SettingsCompactUpdateState {
        let statusMessage = appUpdateController.statusMessage.lowercased()

        if statusMessage.contains("disabled") || statusMessage.contains("unavailable") {
            return .disabled
        }
        if statusMessage.contains("failed") || statusMessage.contains("error") {
            return .failed
        }
        if statusMessage.contains("checking") || statusMessage.contains("downloading") {
            return .checking
        }
        if statusMessage.contains("ready to check") {
            return .ready
        }
        if statusMessage.contains("available") || statusMessage.contains("ready") || statusMessage.contains("downloaded") {
            return .available
        }
        if statusMessage.contains("up to date") {
            return .upToDate
        }
        return .ready
    }

    private var settingsCompactUpdateActionTitle: String {
        if appUpdateController.canRestartToInstallUpdate {
            return "Restart"
        }
        if !appUpdateController.canCheckForUpdates {
            return "Off"
        }
        if settingsCompactUpdateState == .failed {
            return "Retry"
        }
        return "Check"
    }

    private var settingsCompactUpdateActionEnabled: Bool {
        appUpdateController.canRestartToInstallUpdate || appUpdateController.canCheckForUpdates
    }

    private var settingsAlertsCard: some View {
        settingsCard {
            HStack(spacing: 8) {
                settingsSectionHeader("Alerts", symbol: "bell.badge")
                Spacer(minLength: 6)
                settingsAlertsHeaderHighlightColorPicker
            }

            settingsAlertPickerToggleRow(
                title: "Thermal Pressure Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.thermalThreshold },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.thermalThreshold = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                options: [.fair, .serious, .critical],
                isOn: Binding(
                    get: { settings.systemAlertSettings.thermalAlertEnabled },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.thermalAlertEnabled = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                )
            ) { option in
                option.title
            }

            settingsDivider

            settingsAlertPercentToggleRow(
                title: "RAM Alert Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.ramUsagePercentThreshold },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.ramUsagePercentThreshold = min(max(newValue, 60), 99)
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                isOn: Binding(
                    get: { settings.systemAlertSettings.ramAlertEnabled },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.ramAlertEnabled = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                )
            )

            settingsAlertPercentToggleRow(
                title: "Storage Alert Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.storageUsagePercentThreshold },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.storageUsagePercentThreshold = min(max(newValue, 60), 99)
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                isOn: Binding(
                    get: { settings.systemAlertSettings.storageAlertEnabled },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.storageAlertEnabled = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                )
            )

            settingsDivider

            settingsAlertPickerToggleRow(
                title: "Battery Health Drop Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.batteryHealthDropPercentThreshold },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.batteryHealthDropPercentThreshold = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                options: [5, 10, 15, 20, 25, 30, 35, 40],
                isOn: Binding(
                    get: { settings.systemAlertSettings.batteryHealthDropAlertEnabled },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.batteryHealthDropAlertEnabled = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                )
            ) { value in
                "\(value)%"
            }

            settingsDivider

            settingsPickerRow(
                title: "Alert Cooldown (All)",
                selection: Binding(
                    get: { settings.systemAlertSettings.cooldownMinutes },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.cooldownMinutes = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                options: [5, 10, 15, 30]
            ) { value in
                "\(value)m"
            }
        }
    }

    private var settingsAdvancedBatteryCard: some View {
        let helperAvailability = batteryPolicyCoordinator.helperAvailability
        let helperAvailable: Bool
        switch helperAvailability {
        case .available:
            helperAvailable = true
        case .unavailable:
            helperAvailable = false
        }

        return settingsCard {
            settingsSectionHeader("Advanced Battery (Gated)", symbol: "shield.lefthalf.filled")

            Text("These controls only apply on lifecycle events (sleep/wake) or fallback battery parsing paths.")
                .font(.system(size: 11))
                .foregroundStyle(settingsTextMuted)

            if case .unavailable(let reason) = helperAvailability {
                infoBanner(
                    text: "Helper unavailable: \(reason)",
                    tint: PopoverTheme.orange,
                    background: PopoverTheme.orangeDim
                )

                if batteryPolicyCoordinator.isInstallingHelper {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Installing helper...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(settingsTextMuted)
                    }
                }

                Button {
                    Task {
                        await batteryPolicyCoordinator.installHelperIfNeededAsync()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Install Helper")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PopoverTheme.accentContrastText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(PopoverTheme.blue)
                    )
                }
                .buttonStyle(.plain)
                .disabled(batteryPolicyCoordinator.isInstallingHelper)
                .opacity(batteryPolicyCoordinator.isInstallingHelper ? 0.6 : 1.0)
                .help("Install or update the privileged helper used for battery control.")
            }

            settingsToggleRow(
                title: "Sleep-aware Stop Charging",
                subtitle: "Pause charging before system sleep transitions.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.sleepAwareStopChargingEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.sleepAwareStopChargingEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                ),
                isEnabled: helperAvailable
            )

            settingsDivider

            settingsToggleRow(
                title: "Block Sleep Until Limit",
                subtitle: "Attempt limit recovery before sleep when below charge target.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.blockSleepUntilLimitEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.blockSleepUntilLimitEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                ),
                isEnabled: helperAvailable
            )

            settingsDivider

            settingsToggleRow(
                title: "Hardware Percentage Refinement",
                subtitle: "Use fallback percentage parsing only when standard percentage is unavailable.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.hardwarePercentageRefinementEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.hardwarePercentageRefinementEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                ),
                isEnabled: helperAvailable
            )
        }
    }

    private var settingsAboutCard: some View {
        settingsCard {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(settingsCardBorder, lineWidth: 1)
                    )

                Text("MacMonitor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(settingsTextMain)

                Spacer(minLength: 8)

                Text(appVersionLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settingsTextMuted)

                Button {
                    openPublicReleasePage()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(settingsTextMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open latest release notes")
                .help("Open latest public release notes")
            }
            .padding(.vertical, 3)
        }
    }

    private func settingsToggleRow(
        title: String,
        subtitle: String,
        subtitleColor: Color = PopoverTheme.textMuted,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(settingsTextMain)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settingsToggleTint)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.6)
        }
    }

    private func settingsAlertPercentToggleRow(
        title: String,
        selection: Binding<Int>,
        isOn: Binding<Bool>
    ) -> some View {
        let thresholdEnabled = isOn.wrappedValue

        return HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsTextMain)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                TextField("", value: selection, formatter: Self.settingsIntegerFormatter)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .frame(width: 44)

                Text("%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsTextMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(settingsInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(settingsCardBorder, lineWidth: 1)
            )
            .frame(width: settingsPickerWidth, alignment: .trailing)
            .disabled(!thresholdEnabled)
            .opacity(thresholdEnabled ? 1.0 : 0.6)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settingsToggleTint)
        }
    }

    private func settingsAlertPickerToggleRow<Option: Hashable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        isOn: Binding<Bool>,
        optionTitle: @escaping (Option) -> String
    ) -> some View {
        let thresholdEnabled = isOn.wrappedValue

        return HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsTextMain)

            Spacer(minLength: 8)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(optionTitle(option))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(optionTitle(selection.wrappedValue))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(thresholdEnabled ? settingsTextMain : settingsTextMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: settingsPickerWidth, alignment: .trailing)
                .background(settingsInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(settingsCardBorder, lineWidth: 1)
                )
                .opacity(thresholdEnabled ? 1.0 : 0.6)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .disabled(!thresholdEnabled)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settingsToggleTint)
        }
    }

    private func settingsPercentInputRow(
        title: String,
        selection: Binding<Int>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsTextMain)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                TextField("", value: selection, formatter: Self.settingsIntegerFormatter)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .frame(width: 44)

                Text("%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsTextMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(settingsInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(settingsCardBorder, lineWidth: 1)
            )
            .frame(width: settingsPickerWidth, alignment: .trailing)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
    }

    private func settingsPickerRow<Option: Hashable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        isEnabled: Bool = true,
        optionTitle: @escaping (Option) -> String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsTextMain)

            Spacer(minLength: 8)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(optionTitle(option))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(optionTitle(selection.wrappedValue))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(settingsTextMain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: settingsPickerWidth, alignment: .leading)
                .background(settingsInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(settingsCardBorder, lineWidth: 1)
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.6)
            .frame(width: settingsPickerWidth, alignment: .trailing)
        }
    }

    private var menuBarComposerSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu Bar Composer")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(settingsTextMain)

                Spacer(minLength: 8)

                Button("Cancel") {
                    isMenuBarComposerPresented = false
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    settings.menuBarComposerConfiguration = menuBarComposerDraftConfiguration
                    isMenuBarComposerPresented = false
                }
                .buttonStyle(.borderedProminent)
            }

            settingsDivider

            VStack(alignment: .leading, spacing: 6) {
                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settingsTextMain)
                Text(
                    menuBarComposerPreviewAttributedString(
                        configuration: menuBarComposerDraftConfiguration,
                        baseColor: settingsTextMuted
                    )
                )
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }

            Text("Compose freely with metric and text blocks. Use text blocks for separators, emoji, or any wording.")
                .font(.system(size: 11))
                .foregroundStyle(settingsTextMuted)
                .lineLimit(2)

            HStack(spacing: 6) {
                menuBarComposerAddMetricButton(kind: .memory, symbol: "memorychip.fill")
                menuBarComposerAddMetricButton(kind: .storage, symbol: "internaldrive.fill")
                menuBarComposerAddMetricButton(kind: .cpu, symbol: "cpu.fill")
                menuBarComposerAddMetricButton(kind: .network, symbol: "network")
                Button {
                    addMenuBarComposerTextBlock()
                } label: {
                    Label("Text", systemImage: "textformat")
                }
                .buttonStyle(.bordered)
            }

            settingsDivider

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(menuBarComposerDraftConfiguration.blocks.enumerated()), id: \.element.id) { index, block in
                        menuBarComposerBlockRow(index: index, block: block)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .frame(width: 700, height: 520, alignment: .topLeading)
        .background(PopoverTheme.bgPanel)
        .onAppear {
            menuBarComposerDraftConfiguration = settings.menuBarComposerConfiguration
        }
    }

    private func menuBarComposerAddMetricButton(kind: MenuBarComposerBlockKind, symbol: String) -> some View {
        Button {
            addMenuBarComposerMetricBlock(kind)
        } label: {
            Label(kind.title, systemImage: symbol)
        }
        .buttonStyle(.bordered)
    }

    private func menuBarComposerBlockRow(index: Int, block: MenuBarComposerBlock) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { menuBarComposerBlock(at: index)?.isEnabled ?? false },
                        set: { isEnabled in
                            updateMenuBarComposerConfiguration { config in
                                guard config.blocks.indices.contains(index) else { return }
                                config.blocks[index].isEnabled = isEnabled
                            }
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settingsToggleTint)

                Text(block.kind.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settingsTextMain)

                Spacer(minLength: 8)

                Button {
                    moveMenuBarComposerBlock(at: index, direction: -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    moveMenuBarComposerBlock(at: index, direction: 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(index == menuBarComposerDraftConfiguration.blocks.count - 1)

                Button(role: .destructive) {
                    removeMenuBarComposerBlock(at: index)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            if block.kind == .text {
                TextField(
                    "Text or emoji",
                    text: Binding(
                        get: { menuBarComposerBlock(at: index)?.text ?? "" },
                        set: { value in
                            updateMenuBarComposerConfiguration { config in
                                guard config.blocks.indices.contains(index) else { return }
                                config.blocks[index].text = value
                            }
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
            } else {
                HStack(spacing: 8) {
                    TextField(
                        "Label",
                        text: Binding(
                            get: { menuBarComposerBlock(at: index)?.label ?? "" },
                            set: { value in
                                updateMenuBarComposerConfiguration { config in
                                    guard config.blocks.indices.contains(index) else { return }
                                    config.blocks[index].label = value
                                }
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                    Menu {
                        ForEach(block.kind.supportedFormats, id: \.self) { format in
                            Button {
                                updateMenuBarComposerConfiguration { config in
                                    guard config.blocks.indices.contains(index) else { return }
                                    config.blocks[index].format = format
                                }
                            } label: {
                                Text(format.title)
                            }
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
                        .background(settingsInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(settingsCardBorder, lineWidth: 1)
                        )
                    }
                    .menuIndicator(.hidden)
                    .buttonStyle(.plain)
                    .disabled(block.kind.supportedFormats.count <= 1)
                    .opacity(block.kind.supportedFormats.count <= 1 ? 0.6 : 1)

                    PopoverColorSwatchButton(
                        selection: Binding(
                            get: {
                                Color(hex: menuBarComposerBlock(at: index)?.colorHex ?? block.kind.defaultColorHex)
                            },
                            set: { selectedColor in
                                guard let hex = colorHexValue(from: selectedColor) else { return }
                                updateMenuBarComposerConfiguration { config in
                                    guard config.blocks.indices.contains(index) else { return }
                                    config.blocks[index].colorHex = hex
                                }
                            }
                        ),
                        accessibilityLabel: "Block color",
                        helpText: "Color"
                    ) { color in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(settingsCardBorder, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(10)
        .background(settingsInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settingsCardBorder, lineWidth: 1)
        )
        .opacity(block.isEnabled ? 1 : 0.68)
    }

    private func menuBarComposerBlock(at index: Int) -> MenuBarComposerBlock? {
        guard menuBarComposerDraftConfiguration.blocks.indices.contains(index) else {
            return nil
        }
        return menuBarComposerDraftConfiguration.blocks[index]
    }

    private func addMenuBarComposerMetricBlock(_ kind: MenuBarComposerBlockKind) {
        guard kind.isMetric else { return }
        updateMenuBarComposerConfiguration { config in
            config.blocks.append(.metric(kind))
        }
    }

    private func addMenuBarComposerTextBlock() {
        updateMenuBarComposerConfiguration { config in
            config.blocks.append(.text("•"))
        }
    }

    private func moveMenuBarComposerBlock(at index: Int, direction: Int) {
        updateMenuBarComposerConfiguration { config in
            guard config.blocks.indices.contains(index) else { return }
            let destination = index + direction
            guard config.blocks.indices.contains(destination) else { return }
            config.blocks.swapAt(index, destination)
        }
    }

    private func removeMenuBarComposerBlock(at index: Int) {
        updateMenuBarComposerConfiguration { config in
            guard config.blocks.indices.contains(index) else { return }
            config.blocks.remove(at: index)
        }
    }

    private func updateMenuBarComposerConfiguration(_ mutation: (inout MenuBarComposerConfiguration) -> Void) {
        var configuration = menuBarComposerDraftConfiguration
        mutation(&configuration)
        menuBarComposerDraftConfiguration = configuration.normalized()
    }

    private func menuBarComposerPreviewAttributedString(
        configuration: MenuBarComposerConfiguration,
        baseColor: Color
    ) -> AttributedString {
        let output = MenuBarDisplayFormatter.composedValue(
            for: viewModel.snapshot,
            configuration: configuration
        )
        let renderedText = output.text.isEmpty ? "--" : output.text
        var attributed = AttributedString(renderedText)
        if !attributed.characters.isEmpty {
            attributed[attributed.startIndex..<attributed.endIndex].foregroundColor = baseColor
        }

        guard !output.text.isEmpty else {
            return attributed
        }

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

    private var settingsDivider: some View {
        Rectangle()
            .fill(settingsCardBorder)
            .frame(height: 1)
    }

    private var settingsTextMain: Color {
        settings.appTheme.isDark ? Color(hex: 0xF5F5F7) : Color(hex: 0x1D1D1F)
    }

    private var settingsTextMuted: Color {
        settings.appTheme.isDark ? Color(hex: 0xA1A1A6) : Color(hex: 0x86868B)
    }

    private var settingsCardFill: Color {
        settings.appTheme.isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.62)
    }

    private var settingsCardBorder: Color {
        settings.appTheme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var settingsInputBackground: Color {
        settings.appTheme.isDark ? Color.black.opacity(0.26) : Color.black.opacity(0.04)
    }

    private var settingsToggleTint: Color {
        Color(hex: 0x32D74B)
    }

    private var settingsAlertsHeaderHighlightColorPicker: some View {
        let selection = Binding<Color>(
            get: { Color(hex: settings.systemAlertSettings.exceededThresholdHighlightColor) },
            set: { selectedColor in
                guard let hex = colorHexValue(from: selectedColor) else { return }
                var alertSettings = settings.systemAlertSettings
                alertSettings.exceededThresholdHighlightColor = hex
                settings.systemAlertSettings = alertSettings
            }
        )

        return PopoverColorSwatchButton(
            selection: selection,
            accessibilityLabel: "Exceeded threshold color",
            helpText: "Exceeded threshold color"
        ) { color in
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(settingsCardBorder, lineWidth: 1)
                )
        }
    }

    private func colorHexValue(from color: Color) -> UInt32? {
        guard let sRGBColor = NSColor(color).usingColorSpace(.sRGB) else {
            return nil
        }

        let red = UInt32((sRGBColor.redComponent * 255.0).rounded())
        let green = UInt32((sRGBColor.greenComponent * 255.0).rounded())
        let blue = UInt32((sRGBColor.blueComponent * 255.0).rounded())
        return (red << 16) | (green << 8) | blue
    }

    private func settingsSectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.45)
        }
        .foregroundStyle(settingsTextMuted)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(settingsCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(settingsCardBorder, lineWidth: 1)
        )
    }

    private var settingsPickerWidth: CGFloat {
        96
    }

    private static let settingsIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = 0
        return formatter
    }()

    private func formattedMainPopoverWidth(_ width: CGFloat) -> String {
        "\(Int(width.rounded())) pt"
    }

    private func infoBanner(text: String, tint: Color, background: Color) -> some View {
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

    private var activeTab: MainPopoverTab {
        switch viewModel.screen {
        case .storage, .storageManagement:
            return .storageApps
        case .trends:
            return .trends
        case .settings, .ramPolicyManager:
            return .settings
        case .temperature, .battery, .ram:
            return .memory
        }
    }

    private func switchToTab(_ tab: MainPopoverTab) {
        switch tab {
        case .memory:
            viewModel.showRAM()
        case .storageApps:
            viewModel.showStorage()
        case .trends:
            viewModel.showTrends()
        case .settings:
            viewModel.showSettings()
        }
    }

    private func updateRAMRefreshActivity(for screen: SystemSummaryViewModel.Screen) {
        switch screen {
        case .temperature, .ram:
            ramDetailsViewModel.setRefreshActive(true)
        case .battery, .storage, .trends, .storageManagement, .settings, .ramPolicyManager:
            ramDetailsViewModel.setRefreshActive(false)
        }
    }

    private func normalizeLegacyScreenIfNeeded() {
        guard !hasNormalizedLegacyScreen else { return }
        hasNormalizedLegacyScreen = true

        switch viewModel.screen {
        case .temperature, .battery:
            viewModel.showRAM()
        case .storageManagement:
            viewModel.showStorage()
        case .ram, .storage, .trends, .settings, .ramPolicyManager:
            break
        }
    }

    private func exportDiagnostics() {
        do {
            let bundleURL = try diagnosticsExporter.exportDiagnosticsBundle(
                settings: settings,
                snapshot: viewModel.snapshot,
                history: viewModel.history,
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
        guard let releaseURL = URL(string: "https://github.com/oscarlehuu/macmonitor-open/releases/latest") else {
            return
        }
        NSWorkspace.shared.open(releaseURL)
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
