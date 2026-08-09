import AppKit
import SwiftUI

// MARK: - Color Panel Controller

/// Manages the shared NSColorPanel for settings color pickers.
/// Only one controller may hold the color panel at a time.
@MainActor
final class PopoverColorPanelController: NSObject, ObservableObject {
    private static weak var activeController: PopoverColorPanelController?
    private var closeObserver: NSObjectProtocol?
    private var onChange: ((Color) -> Void)?
    private var onPresentationChange: ((Bool) -> Void)?
    private var isPresenting = false

    func present(
        color: Color,
        onChange: @escaping (Color) -> Void,
        onPresentationChange: ((Bool) -> Void)? = nil
    ) {
        if let previousController = Self.activeController,
           previousController !== self {
            previousController.releaseOwnershipForHandoff()
        }

        self.onChange = onChange
        self.onPresentationChange = onPresentationChange

        let panel = NSColorPanel.shared
        Self.activeController = self
        installCloseObserver(for: panel)
        panel.setTarget(self)
        panel.setAction(#selector(handleColorChange(_:)))
        panel.isContinuous = true
        panel.showsAlpha = false
        panel.color = NSColor(color)
        if !isPresenting {
            isPresenting = true
            onPresentationChange?(true)
        }
        // Defer to next run loop so the popover button click can finish
        // before we ask AppKit to surface the shared color panel above it.
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }

    func disconnectIfActive() {
        guard Self.activeController === self || isPresenting else { return }

        let panel = NSColorPanel.shared
        if Self.activeController === self {
            Self.activeController = nil
            panel.setTarget(nil)
            panel.setAction(nil)
        }
        tearDownPresentation()
        onChange = nil
    }

    @objc private func handleColorChange(_ sender: NSColorPanel) {
        onChange?(Color(nsColor: sender.color))
    }

    private func installCloseObserver(for panel: NSColorPanel) {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.disconnectIfActive()
            }
        }
    }

    private func tearDownPresentation() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
        if isPresenting {
            onPresentationChange?(false)
            isPresenting = false
        }
        onPresentationChange = nil
    }

    private func releaseOwnershipForHandoff() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
        onChange = nil
        onPresentationChange = nil
        isPresenting = false
    }
}

// MARK: - Color Accessibility Extension

extension Color {
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

// MARK: - Color Swatch Button

/// A button that opens the shared NSColorPanel. Accepts a custom swatch view builder.
struct PopoverColorSwatchButton<Swatch: View>: View {
    @Binding var selection: Color
    let accessibilityLabel: String
    let helpText: String?
    let onPresentationChange: ((Bool) -> Void)?
    @ViewBuilder let swatch: (Color) -> Swatch

    @StateObject private var colorPanelController = PopoverColorPanelController()

    var body: some View {
        Button {
            colorPanelController.present(
                color: selection,
                onChange: { selection = $0 },
                onPresentationChange: onPresentationChange
            )
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

// MARK: - Hex Color Helper

/// Converts a SwiftUI Color to a packed UInt32 hex value (RRGGBB).
func colorHexValue(from color: Color) -> UInt32? {
    guard let sRGBColor = NSColor(color).usingColorSpace(.sRGB) else {
        return nil
    }
    let red = UInt32((sRGBColor.redComponent * 255.0).rounded())
    let green = UInt32((sRGBColor.greenComponent * 255.0).rounded())
    let blue = UInt32((sRGBColor.blueComponent * 255.0).rounded())
    return (red << 16) | (green << 8) | blue
}
