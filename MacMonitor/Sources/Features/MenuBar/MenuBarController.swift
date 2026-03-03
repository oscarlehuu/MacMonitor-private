import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private struct MenuBarHighlightState {
        let ramExceeded: Bool
        let storageExceeded: Bool
    }

    private let viewModel: SystemSummaryViewModel
    private let ramDetailsViewModel: RAMDetailsViewModel
    private let ramPolicyViewModel: RAMPolicySettingsViewModel
    private let storageManagementViewModel: StorageManagementViewModel
    private let batteryPolicyCoordinator: BatteryPolicyCoordinator
    private let batteryScheduleViewModel: BatteryScheduleViewModel
    private let appUpdateController: AppUpdateController
    private let diagnosticsExporter: DiagnosticsExporter
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObserver: NSObjectProtocol?

    init(
        viewModel: SystemSummaryViewModel,
        ramDetailsViewModel: RAMDetailsViewModel,
        ramPolicyViewModel: RAMPolicySettingsViewModel,
        storageManagementViewModel: StorageManagementViewModel,
        batteryPolicyCoordinator: BatteryPolicyCoordinator,
        batteryScheduleViewModel: BatteryScheduleViewModel,
        appUpdateController: AppUpdateController,
        diagnosticsExporter: DiagnosticsExporter
    ) {
        self.viewModel = viewModel
        self.ramDetailsViewModel = ramDetailsViewModel
        self.ramPolicyViewModel = ramPolicyViewModel
        self.storageManagementViewModel = storageManagementViewModel
        self.batteryPolicyCoordinator = batteryPolicyCoordinator
        self.batteryScheduleViewModel = batteryScheduleViewModel
        self.appUpdateController = appUpdateController
        self.diagnosticsExporter = diagnosticsExporter
        super.init()
    }

    func install() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                viewModel: viewModel,
                ramDetailsViewModel: ramDetailsViewModel,
                ramPolicyViewModel: ramPolicyViewModel,
                storageManagementViewModel: storageManagementViewModel,
                batteryPolicyCoordinator: batteryPolicyCoordinator,
                batteryScheduleViewModel: batteryScheduleViewModel,
                settings: viewModel.settings,
                appUpdateController: appUpdateController,
                diagnosticsExporter: diagnosticsExporter
            )
        )
        applyMainPopoverDefaultSize()

        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseDown])

        installAppearanceObserver()
        bindViewModel()
        renderStatusItem()
    }

    func uninstall() {
        cancellables.removeAll()
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            applyMainPopoverDefaultSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        renderStatusItem()
    }

    private func bindViewModel() {
        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                statusItem.button?.toolTip = viewModel.statusTooltip
                renderStatusItem()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            viewModel.settings.$menuBarDisplayMode,
            viewModel.settings.$menuBarMemoryFormat,
            viewModel.settings.$menuBarStorageFormat
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
            self?.renderStatusItem()
        }
        .store(in: &cancellables)

        viewModel.settings.$systemAlertSettings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.renderStatusItem()
            }
            .store(in: &cancellables)
    }

    private func renderStatusItem() {
        guard let button = statusItem.button else { return }
        let settings = viewModel.settings

        switch settings.menuBarDisplayMode {
        case .icon:
            statusItem.length = NSStatusItem.squareLength
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image = iconOnlySymbol()
        case .memory, .storage, .cpu, .network, .both:
            statusItem.length = NSStatusItem.variableLength
            button.imagePosition = .noImage
            button.imageScaling = .scaleProportionallyDown
            button.image = nil
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize(for: .small),
                weight: .semibold
            )
            let titleText = MenuBarDisplayFormatter.valueText(
                for: viewModel.snapshot,
                mode: settings.menuBarDisplayMode,
                memoryFormat: settings.menuBarMemoryFormat,
                storageFormat: settings.menuBarStorageFormat
            ) ?? ""
            button.title = titleText
            button.attributedTitle = attributedMenuBarTitle(
                text: titleText,
                mode: settings.menuBarDisplayMode,
                font: button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
            )
        }

        applyBackgroundStyle(to: button, mode: settings.menuBarDisplayMode)
        button.contentTintColor = nil
    }

    private func attributedMenuBarTitle(
        text: String,
        mode: MenuBarDisplayMode,
        font: NSFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )

        let highlightState = menuBarHighlightState()
        let highlightRanges = MenuBarDisplayFormatter.highlightedRanges(
            in: text,
            mode: mode,
            highlightRAM: highlightState.ramExceeded,
            highlightStorage: highlightState.storageExceeded
        )
        let highlightColor = menuBarExceededThresholdHighlightColor

        for range in highlightRanges {
            result.addAttribute(.foregroundColor, value: highlightColor, range: range)
        }

        return result
    }

    private func menuBarHighlightState() -> MenuBarHighlightState {
        guard let snapshot = viewModel.snapshot else {
            return MenuBarHighlightState(ramExceeded: false, storageExceeded: false)
        }

        let alertSettings = viewModel.settings.systemAlertSettings
        let ramPercent = snapshot.memory.usageRatio * 100
        let storagePercent = snapshot.storage.usageRatio * 100

        let ramExceeded = alertSettings.ramAlertEnabled
            && ramPercent >= Double(alertSettings.ramUsagePercentThreshold)
        let storageExceeded = alertSettings.storageAlertEnabled
            && storagePercent >= Double(alertSettings.storageUsagePercentThreshold)

        return MenuBarHighlightState(ramExceeded: ramExceeded, storageExceeded: storageExceeded)
    }

    private var menuBarExceededThresholdHighlightColor: NSColor {
        let hex = viewModel.settings.systemAlertSettings.exceededThresholdHighlightColor
        return nsColor(hex: hex)
    }

    private func nsColor(hex: UInt32) -> NSColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }

    private func iconOnlySymbol() -> NSImage? {
        guard let symbolImage = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
            return nil
        }

        let configured = symbolImage.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: 10,
                weight: .medium,
                scale: .small
            )
        )
        let image = configured ?? symbolImage
        image.isTemplate = true
        return image
    }

    private func applyBackgroundStyle(to button: NSStatusBarButton, mode: MenuBarDisplayMode) {
        switch mode {
        case .icon:
            button.wantsLayer = true
            guard let layer = button.layer else { return }

            let bestAppearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            if bestAppearance == .darkAqua {
                layer.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
                layer.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
            } else {
                layer.backgroundColor = NSColor.black.withAlphaComponent(0.06).cgColor
                layer.borderColor = NSColor.black.withAlphaComponent(0.10).cgColor
            }
            layer.borderWidth = 0.5
            layer.cornerRadius = 6
            layer.masksToBounds = true
        case .memory, .storage, .cpu, .network, .both:
            button.wantsLayer = true
            guard let layer = button.layer else { return }

            let bestAppearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            let fillColor: NSColor
            let borderColor: NSColor
            if bestAppearance == .darkAqua {
                fillColor = NSColor.white.withAlphaComponent(0.14)
                borderColor = NSColor.white.withAlphaComponent(0.24)
            } else {
                fillColor = NSColor.black.withAlphaComponent(0.10)
                borderColor = NSColor.black.withAlphaComponent(0.16)
            }

            layer.backgroundColor = fillColor.cgColor
            layer.borderColor = borderColor.cgColor
            layer.borderWidth = 0.5
            layer.cornerRadius = 6
            layer.masksToBounds = true
        }
    }

    private func installAppearanceObserver() {
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }

        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.renderStatusItem()
            }
        }
    }

    private func applyMainPopoverDefaultSize() {
        viewModel.settings.resetMainPopoverCurrentWidthToDefault()
        applyPopoverSize(width: viewModel.settings.mainPopoverCurrentWidth)
    }

    private func applyPopoverSize(width: CGFloat) {
        popover.contentSize = NSSize(
            width: SettingsStore.normalizedMainPopoverWidth(width),
            height: SettingsStore.mainPopoverFixedHeight
        )
    }

    private func configureResizablePopoverWindow() {
        guard let window = popover.contentViewController?.view.window else { return }
        window.styleMask.insert(.resizable)
        let minSize = NSSize(
            width: SettingsStore.mainPopoverMinWidth,
            height: SettingsStore.mainPopoverFixedHeight
        )
        let maxSize = NSSize(
            width: SettingsStore.mainPopoverMaxWidth,
            height: SettingsStore.mainPopoverFixedHeight
        )
        window.contentMinSize = minSize
        window.contentMaxSize = maxSize

        let normalizedWidth = SettingsStore.normalizedMainPopoverWidth(window.contentLayoutRect.width)
        window.setContentSize(
            NSSize(width: normalizedWidth, height: SettingsStore.mainPopoverFixedHeight)
        )
        viewModel.settings.updateMainPopoverCurrentWidth(normalizedWidth)
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        configureResizablePopoverWindow()
        renderStatusItem()
    }

    func popoverDidClose(_ notification: Notification) {
        renderStatusItem()
    }
}
