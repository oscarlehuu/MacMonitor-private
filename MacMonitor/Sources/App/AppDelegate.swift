import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let container = AppContainer()
        self.container = container
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.stop()
    }
}
