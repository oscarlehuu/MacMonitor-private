import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let viewModel: SystemSummaryViewModel
    private let ramDetailsViewModel: RAMDetailsViewModel
    private let ramPolicyViewModel: RAMPolicySettingsViewModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(
        viewModel: SystemSummaryViewModel,
        ramDetailsViewModel: RAMDetailsViewModel,
        ramPolicyViewModel: RAMPolicySettingsViewModel
    ) {
        self.viewModel = viewModel
        self.ramDetailsViewModel = ramDetailsViewModel
        self.ramPolicyViewModel = ramPolicyViewModel
        super.init()
    }

    func install() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                viewModel: viewModel,
                ramDetailsViewModel: ramDetailsViewModel,
                ramPolicyViewModel: ramPolicyViewModel
            )
        )

        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.imagePosition = .imageOnly
        button.sendAction(on: [.leftMouseDown])

        bindViewModel()
        applyStatus(for: viewModel.thermalState)
    }

    func uninstall() {
        cancellables.removeAll()
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
    }

    private func bindViewModel() {
        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                applyStatus(for: snapshot?.thermal.state ?? .unknown)
                statusItem.button?.toolTip = viewModel.statusTooltip
            }
            .store(in: &cancellables)
    }

    private func applyStatus(for state: ThermalState) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.title)
        button.contentTintColor = state.nsColor
    }
}

private extension ThermalState {
    var symbolName: String {
        switch self {
        case .nominal:
            return "thermometer.low"
        case .fair:
            return "thermometer.medium"
        case .serious:
            return "thermometer.high"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .nominal:
            return .systemGreen
        case .fair:
            return .systemYellow
        case .serious:
            return .systemOrange
        case .critical:
            return .systemRed
        case .unknown:
            return .secondaryLabelColor
        }
    }
}
