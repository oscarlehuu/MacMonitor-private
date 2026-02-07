import XCTest
@testable import MacMonitor

final class SignalProcessTerminatorTests: XCTestCase {
    func testSkipsProtectedProcessesAndContinuesAllowed() {
        let allowed = makeProcess(pid: 10, name: "Allowed", protectionReason: nil)
        let protected = makeProcess(pid: 11, name: "Protected", protectionReason: .systemProcess)

        let terminator = SignalProcessTerminator { _, _ in
            (0, 0)
        }

        let summary = terminator.terminate(processes: [allowed, protected], selectedProcessIDs: [10, 11])

        XCTAssertEqual(summary.terminatedCount, 1)
        XCTAssertEqual(summary.skippedCount, 1)
        XCTAssertEqual(summary.failedCount, 0)
    }

    func testMapsPermissionDeniedAndNotFound() {
        let permissionProcess = makeProcess(pid: 20, name: "Permission", protectionReason: nil)
        let missingProcess = makeProcess(pid: 21, name: "Missing", protectionReason: nil)

        let terminator = SignalProcessTerminator { pid, _ in
            if pid == 20 {
                return (-1, EPERM)
            }
            return (-1, ESRCH)
        }

        let summary = terminator.terminate(processes: [permissionProcess, missingProcess], selectedProcessIDs: [20, 21])

        XCTAssertEqual(summary.terminatedCount, 0)
        XCTAssertEqual(summary.skippedCount, 0)
        XCTAssertEqual(summary.failedCount, 2)
        XCTAssertTrue(summary.results.contains { $0.pid == 20 && $0.outcome == .permissionDenied })
        XCTAssertTrue(summary.results.contains { $0.pid == 21 && $0.outcome == .notFound })
    }

    func testOnlyProcessesSelectedIDs() {
        let first = makeProcess(pid: 30, name: "First", protectionReason: nil)
        let second = makeProcess(pid: 31, name: "Second", protectionReason: nil)

        var calledPIDs: [Int32] = []
        let terminator = SignalProcessTerminator { pid, _ in
            calledPIDs.append(pid)
            return (0, 0)
        }

        _ = terminator.terminate(processes: [first, second], selectedProcessIDs: [31])

        XCTAssertEqual(calledPIDs, [31])
    }

    private func makeProcess(pid: Int32, name: String, protectionReason: ProcessProtectionReason?) -> ProcessMemoryItem {
        ProcessMemoryItem(
            pid: pid,
            name: name,
            userID: 501,
            userName: "oscar",
            residentBytes: 1,
            footprintBytes: nil,
            bsdFlags: 0,
            protectionReason: protectionReason
        )
    }
}
