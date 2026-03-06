import XCTest
@testable import MacMonitor

@MainActor
final class AppUpdateControllerTests: XCTestCase {
    func testConsumePendingRelaunchVersionMatchesDownloadedBuild() {
        let defaults = makeDefaults()

        AppUpdateController.markPendingRelaunch(version: "42", defaults: defaults)

        XCTAssertTrue(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: "42",
                defaults: defaults
            )
        )
        XCTAssertFalse(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: "42",
                defaults: defaults
            )
        )
    }

    func testConsumePendingRelaunchVersionRejectsDifferentBuild() {
        let defaults = makeDefaults()

        AppUpdateController.markPendingRelaunch(version: "42", defaults: defaults)

        XCTAssertFalse(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: "41",
                defaults: defaults
            )
        )
        XCTAssertFalse(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: "42",
                defaults: defaults
            )
        )
    }

    func testMarkPendingRelaunchIgnoresEmptyVersion() {
        let defaults = makeDefaults()

        AppUpdateController.markPendingRelaunch(version: "", defaults: defaults)
        AppUpdateController.markPendingRelaunch(version: nil, defaults: defaults)

        XCTAssertFalse(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: "42",
                defaults: defaults
            )
        )
    }

    func testConsumePendingRelaunchVersionClearsMarkerWhenBundleVersionMissing() {
        let defaults = makeDefaults()

        AppUpdateController.markPendingRelaunch(version: "42", defaults: defaults)

        XCTAssertFalse(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: nil,
                defaults: defaults
            )
        )
        XCTAssertFalse(
            AppUpdateController.consumePendingRelaunchVersion(
                matching: "42",
                defaults: defaults
            )
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppUpdateControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
