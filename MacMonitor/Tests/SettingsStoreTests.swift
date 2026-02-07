import XCTest
@testable import MacMonitor

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testPersistsIntervalAndTemperatureUnit() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.refreshInterval = .fiveMinutes
        store.temperatureUnit = .fahrenheit

        XCTAssertEqual(defaults.integer(forKey: "settings.refreshIntervalMinutes"), 5)
        XCTAssertEqual(defaults.string(forKey: "settings.temperatureUnit"), TemperatureUnit.fahrenheit.rawValue)
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
