import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let duplicateLaunchGracePeriod: TimeInterval = 1.0
    private static let duplicateLaunchPollInterval: TimeInterval = 0.05

    private var container: AppContainer?
    private let livenessChecker = POSIXProcessLivenessChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared

        // Keep the XCTest host app as inert as possible so unit tests do not boot
        // background services, Sparkle, or menu bar UI.
        if isRunningTests {
            return
        }

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

    @objc private func handleReopenAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        container?.revealMenuBarPopover()
    }

    private func handleDuplicateLaunchIfNeeded() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        var runningWithSameBundle = runningSiblingApplications(
            bundleIdentifier: bundleIdentifier,
            currentPID: currentPID
        )

        if !runningWithSameBundle.isEmpty,
           AppUpdateController.consumePendingRelaunchVersion(matching: currentBundleVersion) {
            let graceDeadline = Date().addingTimeInterval(Self.duplicateLaunchGracePeriod)
            while Date() < graceDeadline {
                if runningSiblingApplications(bundleIdentifier: bundleIdentifier, currentPID: currentPID).isEmpty {
                    return false
                }
                RunLoop.current.run(
                    mode: .default,
                    before: Date().addingTimeInterval(Self.duplicateLaunchPollInterval)
                )
            }

            runningWithSameBundle = runningSiblingApplications(
                bundleIdentifier: bundleIdentifier,
                currentPID: currentPID
            )
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

    private func runningSiblingApplications(
        bundleIdentifier: String,
        currentPID: pid_t
    ) -> [NSRunningApplication] {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { app in
                app.processIdentifier != currentPID &&
                !app.isTerminated &&
                livenessChecker.isAlive(processID: app.processIdentifier)
            }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
