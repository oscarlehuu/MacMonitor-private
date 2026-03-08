import AppKit

@main
enum MacMonitorApp {
    @MainActor
    private static var retainedDelegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
