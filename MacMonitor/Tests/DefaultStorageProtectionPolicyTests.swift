import XCTest
@testable import MacMonitor

final class DefaultStorageProtectionPolicyTests: XCTestCase {
    func testProtectsCurrentApplicationPath() {
        let policy = DefaultStorageProtectionPolicy(currentApplicationPath: "/Applications/MacMonitor.app")

        let decision = policy.evaluate(url: URL(fileURLWithPath: "/Applications/MacMonitor.app/Contents/MacOS/MacMonitor"))

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .currentApplication)
    }

    func testProtectsSystemPathPrefix() {
        let policy = DefaultStorageProtectionPolicy(currentApplicationPath: "/Applications/MacMonitor.app")

        let decision = policy.evaluate(url: URL(fileURLWithPath: "/System/Applications/Utilities"))

        XCTAssertTrue(decision.isProtected)
        XCTAssertEqual(decision.reason, .systemPath)
    }

    func testAllowsUserCachePath() {
        let policy = DefaultStorageProtectionPolicy(currentApplicationPath: "/Applications/MacMonitor.app")

        let decision = policy.evaluate(url: URL(fileURLWithPath: "/Users/oscar/Library/Caches/com.apple.Safari"))

        XCTAssertFalse(decision.isProtected)
        XCTAssertNil(decision.reason)
    }
}
