import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let viewModel: SystemSummaryViewModel
    private let ramDetailsViewModel: RAMDetailsViewModel
    private let ramPolicyViewModel: RAMPolicySettingsViewModel
    private let storageManagementViewModel: StorageManagementViewModel
    private let batteryPolicyCoordinator: BatteryPolicyCoordinator
    private let appUpdateController: AppUpdateController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let statusIconRenderer = MenuBarStatusIconRenderer.shared
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObserver: NSObjectProtocol?

    init(
        viewModel: SystemSummaryViewModel,
        ramDetailsViewModel: RAMDetailsViewModel,
        ramPolicyViewModel: RAMPolicySettingsViewModel,
        storageManagementViewModel: StorageManagementViewModel,
        batteryPolicyCoordinator: BatteryPolicyCoordinator,
        appUpdateController: AppUpdateController
    ) {
        self.viewModel = viewModel
        self.ramDetailsViewModel = ramDetailsViewModel
        self.ramPolicyViewModel = ramPolicyViewModel
        self.storageManagementViewModel = storageManagementViewModel
        self.batteryPolicyCoordinator = batteryPolicyCoordinator
        self.appUpdateController = appUpdateController
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
                settings: viewModel.settings,
                appUpdateController: appUpdateController
            )
        )

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
            viewModel.settings.$menuBarMetricValueMode,
            viewModel.settings.$menuBarMetricFormat
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
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
            button.imagePosition = .imageOnly
            button.image = statusIconRenderer.icon(
                for: statusIconVariant(for: button, thermalState: viewModel.thermalState),
                pointSize: iconPointSize(for: button)
            )
        case .battery, .ram, .storage:
            statusItem.length = NSStatusItem.variableLength
            button.imagePosition = .imageLeft
            button.image = metricIcon(for: settings.menuBarDisplayMode, in: button)
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize(for: .small),
                weight: .semibold
            )
            button.title = MenuBarDisplayFormatter.valueText(
                for: viewModel.snapshot,
                mode: settings.menuBarDisplayMode,
                valueMode: settings.menuBarMetricValueMode,
                format: settings.menuBarMetricFormat
            ) ?? ""
        }

        button.contentTintColor = nil
    }

    private func metricIcon(for mode: MenuBarDisplayMode, in button: NSStatusBarButton) -> NSImage? {
        let symbolName: String
        switch mode {
        case .icon:
            return nil
        case .battery:
            symbolName = batterySymbolName(for: viewModel.snapshot?.battery)
        case .ram:
            symbolName = "memorychip.fill"
        case .storage:
            symbolName = "internaldrive.fill"
        }

        guard let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }

        let configured = symbolImage.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: max(10, iconPointSize(for: button) - 4),
                weight: .medium
            )
        )
        guard let configured else {
            symbolImage.isTemplate = true
            return symbolImage
        }
        configured.isTemplate = true
        return configured
    }

    private func batterySymbolName(for battery: BatterySnapshot?) -> String {
        guard let battery else {
            return "battery.0"
        }

        if battery.isCharging {
            return "battery.100.bolt"
        }

        guard let percent = battery.percentage else {
            return "battery.0"
        }

        switch percent {
        case ..<13:
            return "battery.0"
        case ..<38:
            return "battery.25"
        case ..<63:
            return "battery.50"
        case ..<88:
            return "battery.75"
        default:
            return "battery.100"
        }
    }

    private func statusIconVariant(for button: NSStatusBarButton, thermalState: ThermalState) -> MenuBarIconVariant {
        if popover.isShown {
            return .premiumGlass(thermalState)
        }

        let bestAppearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        if bestAppearance == .darkAqua {
            return .white
        }
        return .black
    }

    private func iconPointSize(for button: NSStatusBarButton) -> CGFloat {
        let side = min(button.bounds.width, button.bounds.height)
        guard side > 8 else { return 18 }
        return max(side - 4, 14)
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
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        renderStatusItem()
    }

    func popoverDidClose(_ notification: Notification) {
        renderStatusItem()
    }
}
