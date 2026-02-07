import XCTest
@testable import MacMonitor

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testPersistsRefreshInterval() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.refreshInterval = .fiveMinutes

        XCTAssertEqual(defaults.integer(forKey: "settings.refreshIntervalMinutes"), 5)
    }

    func testLaunchAtLoginFailureRevertsToggleAndStoresError() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager(enabled: false, throwOnSet: true)
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.launchAtLoginEnabled = true

        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertNotNil(store.launchAtLoginError)
    }
}

private final class MutableLaunchManager: LaunchAtLoginManaging {
    private(set) var enabled: Bool
    private let throwOnSet: Bool

    init(enabled: Bool = false, throwOnSet: Bool = false) {
        self.enabled = enabled
        self.throwOnSet = throwOnSet
    }

    func isEnabled() -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if throwOnSet {
            throw TestError.toggleFailed
        }
        self.enabled = enabled
    }
}

private enum TestError: Error {
    case toggleFailed
}
