import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?
    private let livenessChecker = POSIXProcessLivenessChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared

        guard !handleDuplicateLaunchIfNeeded() else {
            application.terminate(nil)
            return
        }

        application.setActivationPolicy(.accessory)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopenAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )

        let container = AppContainer()
        self.container = container
        DispatchQueue.main.async { [weak self] in
            self?.container?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )
        container?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        container?.revealMenuBarPopover()
        return false
    }

    @objc private func handleReopenAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        container?.revealMenuBarPopover()
    }

    private func handleDuplicateLaunchIfNeeded() -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let runningWithSameBundle = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { app in
                app.processIdentifier != currentPID &&
                !app.isTerminated &&
                livenessChecker.isAlive(processID: app.processIdentifier)
            }

        if !runningWithSameBundle.isEmpty,
           AppUpdateController.consumePendingRelaunchVersion(matching: currentBundleVersion) {
            return false
        }

        if runningWithSameBundle.isEmpty {
            _ = AppUpdateController.consumePendingRelaunchVersion(matching: nil)
            return false
        }

        runningWithSameBundle.forEach { app in
            _ = app.activate(options: [])
        }
        DistributedNotificationCenter.default().postNotificationName(
            .macMonitorRevealPopover,
            object: bundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        return true
    }
}
