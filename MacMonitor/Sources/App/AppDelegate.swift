import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicateLaunch else {
            NSApp.terminate(nil)
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)

        let container = AppContainer()
        self.container = container
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.stop()
    }

    private var isDuplicateLaunch: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningWithSameBundle = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }

        return !runningWithSameBundle.isEmpty
    }
}
