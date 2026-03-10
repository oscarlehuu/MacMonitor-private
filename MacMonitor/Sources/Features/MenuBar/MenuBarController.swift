import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let macMonitorRevealPopover = Notification.Name("com.oscar.macmonitor.reveal-popover")
}

@MainActor
final class MenuBarController: NSObject {
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
    private var revealPopoverObserver: NSObjectProtocol?
    private var isAuxiliaryPanelPresented = false
    private var hasInstalledStatusButton = false
    private var retainedStatusItemLength: CGFloat = 0
    private var latestMenuBarSnapshot: SystemSnapshot?

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
        popover.behavior = .applicationDefined
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
                popoverWindowProvider: { [weak self] in
                    self?.popover.contentViewController?.view.window
                },
                auxiliaryPanelPresentationHandler: { [weak self] isPresented in
                    self?.setAuxiliaryPanelPresentation(isPresented)
                },
                diagnosticsExporter: diagnosticsExporter
            )
        )
        applyMainPopoverDefaultSize()

        installAppearanceObserver()
        installRevealPopoverObserver()
        bindViewModel()
        installStatusButtonWhenReady()
    }

    func uninstall() {
        cancellables.removeAll()
        setAuxiliaryPanelPresentation(false)
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }
        if let revealPopoverObserver {
            DistributedNotificationCenter.default().removeObserver(revealPopoverObserver)
            self.revealPopoverObserver = nil
        }
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func revealPopover() {
        installStatusButtonWhenReady()
        showPopoverWhenReady(activateApp: true)
        renderStatusItem()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(activateApp: true)
        }

        renderStatusItem()
    }

    private func setAuxiliaryPanelPresentation(_ isPresented: Bool) {
        guard isAuxiliaryPanelPresented != isPresented else { return }

        isAuxiliaryPanelPresented = isPresented
        popover.behavior = .applicationDefined
    }

    private func bindViewModel() {
        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                latestMenuBarSnapshot = snapshot
                statusItem.button?.toolTip = viewModel.statusTooltip(for: latestMenuBarSnapshot)
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
            self?.resetRetainedStatusItemLength()
            self?.renderStatusItem()
        }
        .store(in: &cancellables)

        viewModel.settings.$systemAlertSettings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.renderStatusItem()
            }
            .store(in: &cancellables)

        viewModel.settings.$menuBarComposerConfiguration
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resetRetainedStatusItemLength()
                self?.renderStatusItem()
            }
            .store(in: &cancellables)
    }

    private func renderStatusItem() {
        guard let button = statusItem.button else { return }
        let settings = viewModel.settings
        let snapshot = latestMenuBarSnapshot ?? viewModel.snapshot

        button.imagePosition = .noImage
        button.imageScaling = .scaleProportionallyDown
        button.image = nil
        button.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize(for: .small),
            weight: .semibold
        )

        let composedOutput = MenuBarDisplayFormatter.composedValue(
            for: snapshot,
            configuration: settings.menuBarComposerConfiguration
        )
        let titleFont = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        if composedOutput.text.isEmpty {
            button.title = "--"
            button.attributedTitle = NSAttributedString(
                string: "--",
                attributes: [
                    .font: titleFont,
                    .foregroundColor: NSColor.labelColor
                ]
            )
        } else {
            button.title = composedOutput.text
            button.attributedTitle = attributedMenuBarTitle(
                composedOutput: composedOutput,
                font: titleFont
            )
        }

        retainStatusItemLength(for: button)
        applyBackgroundStyle(to: button, mode: .both)
        button.contentTintColor = nil
    }
    private func resetRetainedStatusItemLength() {
        retainedStatusItemLength = 0
        statusItem.length = NSStatusItem.variableLength
    }

    private func retainStatusItemLength(for button: NSStatusBarButton) {
        let textWidth = ceil(button.attributedTitle.size().width)
        let targetLength = max(NSStatusItem.squareLength, textWidth + 10)
        retainedStatusItemLength = max(retainedStatusItemLength, targetLength)
        statusItem.length = retainedStatusItemLength
    }

    private func attributedMenuBarTitle(
        composedOutput: MenuBarComposedOutput,
        font: NSFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: composedOutput.text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )

        for span in composedOutput.metricSpans {
            result.addAttribute(
                .foregroundColor,
                value: nsColor(hex: span.colorHex),
                range: span.valueRange
            )
        }

        return result
    }

    private func nsColor(hex: UInt32) -> NSColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }

    private func metricPrefixIcon() -> NSImage? {
        guard let symbolImage = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
            return nil
        }

        let configured = symbolImage.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: 11,
                weight: .medium,
                scale: .small
            )
        )
        let image = configured ?? symbolImage
        image.isTemplate = true
        return image
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

    private func installRevealPopoverObserver() {
        if let revealPopoverObserver {
            DistributedNotificationCenter.default().removeObserver(revealPopoverObserver)
            self.revealPopoverObserver = nil
        }

        revealPopoverObserver = DistributedNotificationCenter.default().addObserver(
            forName: .macMonitorRevealPopover,
            object: Bundle.main.bundleIdentifier,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showPopoverWhenReady(activateApp: true)
            }
        }
    }

    private func installStatusButtonWhenReady(retriesRemaining: Int = 10) {
        guard !hasInstalledStatusButton else { return }

        guard let button = statusItem.button else {
            guard retriesRemaining > 0 else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.installStatusButtonWhenReady(retriesRemaining: retriesRemaining - 1)
            }
            return
        }

        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp])
        hasInstalledStatusButton = true
        renderStatusItem()
    }

    private func showPopover(activateApp: Bool) {
        guard let button = statusItem.button else { return }

        if activateApp {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        if popover.isShown {
            bringPopoverWindowToFront()
            return
        }

        applyMainPopoverDefaultSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if activateApp {
            bringPopoverWindowToFront(retriesRemaining: 3)
        }
    }

    private func showPopoverWhenReady(activateApp: Bool, retriesRemaining: Int = 20) {
        guard let button = statusItem.button else {
            guard retriesRemaining > 0 else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showPopoverWhenReady(
                    activateApp: activateApp,
                    retriesRemaining: retriesRemaining - 1
                )
            }
            return
        }

        guard button.window != nil, !button.bounds.isEmpty else {
            guard retriesRemaining > 0 else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showPopoverWhenReady(
                    activateApp: activateApp,
                    retriesRemaining: retriesRemaining - 1
                )
            }
            return
        }

        showPopover(activateApp: activateApp)
    }

    private func bringPopoverWindowToFront(retriesRemaining: Int = 0) {
        guard let window = popover.contentViewController?.view.window else {
            guard retriesRemaining > 0 else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.bringPopoverWindowToFront(retriesRemaining: retriesRemaining - 1)
            }
            return
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
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
        setAuxiliaryPanelPresentation(false)
        renderStatusItem()
    }
}
