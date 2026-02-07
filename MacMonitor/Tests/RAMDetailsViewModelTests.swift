import XCTest
@testable import MacMonitor

@MainActor
final class RAMDetailsViewModelTests: XCTestCase {
    func testStartLoadsProcesses() {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [makeProcess(pid: 100, name: "Safari", userID: 501, protected: false)]
        collector.allItems = collector.mineItems

        viewModel.start()

        XCTAssertEqual(viewModel.processes.count, 1)
        XCTAssertEqual(collector.callCount, 2)
        viewModel.stop()
    }

    func testChangingScopeClearsSelectionAndRefreshes() {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [makeProcess(pid: 101, name: "Xcode", userID: 501, protected: false)]
        collector.allItems = [
            makeProcess(pid: 101, name: "Xcode", userID: 501, protected: false),
            makeProcess(pid: 55, name: "launchd", userID: 0, protected: true)
        ]

        viewModel.start()
        viewModel.selectedProcessIDs = [101]

        viewModel.setScopeMode(.allDiscoverable)

        XCTAssertTrue(viewModel.selectedProcessIDs.isEmpty)
        XCTAssertEqual(viewModel.scopeMode, .allDiscoverable)
        XCTAssertEqual(collector.callCount, 4)
        viewModel.stop()
    }

    func testTerminateSelectedUsesAllowedProcessesOnly() {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        terminator.summary = ProcessTerminationSummary(
            results: [
                ProcessTerminationResult(pid: 200, processName: "Allowed", outcome: .terminated)
            ]
        )

        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [
            makeProcess(pid: 200, name: "Allowed", userID: 501, protected: false),
            makeProcess(pid: 201, name: "Protected", userID: 501, protected: true)
        ]
        collector.allItems = collector.mineItems

        viewModel.start()
        viewModel.selectedProcessIDs = [200, 201]

        viewModel.terminateSelected()

        XCTAssertEqual(terminator.lastSelectedProcessIDs, [200])
        XCTAssertTrue(viewModel.selectedProcessIDs.isEmpty)
        XCTAssertEqual(viewModel.resultMessage, "Terminated 1, skipped 0, failed 0.")
        viewModel.stop()
    }

    func testRequestTerminateSelectedIgnoresProtectedOnlySelection() {
        let collector = FakeProcessCollector()
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        collector.mineItems = [makeProcess(pid: 300, name: "Protected", userID: 501, protected: true)]
        collector.allItems = collector.mineItems

        viewModel.start()
        viewModel.selectedProcessIDs = [300]

        viewModel.requestTerminateSelected()

        XCTAssertFalse(viewModel.showingTerminateConfirmation)
        viewModel.stop()
    }

    func testComputesMineAndAllProcessBytesFromAllScopeData() {
        let collector = FakeProcessCollector()
        collector.mineItems = [makeProcess(pid: 401, name: "Mine", userID: 501, protected: false, rankingBytes: 120)]
        collector.allItems = [
            makeProcess(pid: 401, name: "Mine", userID: 501, protected: false, rankingBytes: 120),
            makeProcess(pid: 402, name: "Root", userID: 0, protected: true, rankingBytes: 300)
        ]
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 20,
            refreshInterval: 3600,
            currentUserID: 501
        )

        viewModel.start()

        XCTAssertEqual(viewModel.myProcessBytes, 120)
        XCTAssertEqual(viewModel.allProcessBytes, 420)
        viewModel.stop()
    }

    func testSetShowAllMineLoadsAllMineRows() {
        let collector = FakeProcessCollector()
        collector.mineItems = [
            makeProcess(pid: 501, name: "A", userID: 501, protected: false, rankingBytes: 300),
            makeProcess(pid: 502, name: "B", userID: 501, protected: false, rankingBytes: 200),
            makeProcess(pid: 503, name: "C", userID: 501, protected: false, rankingBytes: 100)
        ]
        collector.allItems = collector.mineItems
        let terminator = FakeProcessTerminator()
        let viewModel = RAMDetailsViewModel(
            processCollector: collector,
            processTerminator: terminator,
            maxRows: 2,
            refreshInterval: 3600,
            currentUserID: 501
        )

        viewModel.start()
        XCTAssertEqual(viewModel.processes.count, 2)
        XCTAssertFalse(viewModel.showAllMine)

        viewModel.setShowAllMine(true)

        XCTAssertTrue(viewModel.showAllMine)
        XCTAssertEqual(viewModel.processes.count, 3)
        XCTAssertEqual(collector.callCount, 4)
        viewModel.stop()
    }

    private func makeProcess(pid: Int32, name: String, userID: uid_t, protected: Bool, rankingBytes: UInt64 = 120) -> ProcessMemoryItem {
        ProcessMemoryItem(
            pid: pid,
            name: name,
            userID: userID,
            userName: "oscar",
            residentBytes: rankingBytes,
            footprintBytes: rankingBytes,
            bsdFlags: 0,
            protectionReason: protected ? .systemProcess : nil
        )
    }
}

private final class FakeProcessCollector: ProcessListCollecting {
    var mineItems: [ProcessMemoryItem] = []
    var allItems: [ProcessMemoryItem] = []
    var error: Error?
    private(set) var callCount = 0

    func collectTopProcesses(limit: Int, scope: ProcessScopeMode) throws -> [ProcessMemoryItem] {
        callCount += 1
        if let error {
            throw error
        }
        switch scope {
        case .sameUserOnly:
            return Array(mineItems.prefix(limit))
        case .allDiscoverable:
            return Array(allItems.prefix(limit))
        }
    }
}

private final class FakeProcessTerminator: ProcessTerminating {
    var summary = ProcessTerminationSummary(results: [])
    private(set) var lastSelectedProcessIDs: Set<Int32> = []

    func terminate(processes: [ProcessMemoryItem], selectedProcessIDs: Set<Int32>) -> ProcessTerminationSummary {
        lastSelectedProcessIDs = selectedProcessIDs
        return summary
    }
}
