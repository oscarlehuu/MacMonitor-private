import XCTest
@testable import MacMonitor

final class SnapshotStoreTests: XCTestCase {
    func testAppendAndLoadHistory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapshotStoreTests-\(UUID().uuidString)", isDirectory: true)

        let store = SnapshotStore(baseDirectoryURL: tempDirectory, maxHistoryCount: 2)

        let first = makeSnapshot(minutesAgo: 10)
        let second = makeSnapshot(minutesAgo: 5)
        let third = makeSnapshot(minutesAgo: 1)

        store.append(first)
        store.append(second)
        store.append(third)

        let loaded = store.loadHistory()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.id, second.id)
        XCTAssertEqual(loaded.last?.id, third.id)
    }

    private func makeSnapshot(minutesAgo: Int) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            memory: MemorySnapshot(usedBytes: 1, totalBytes: 2, pressure: .normal),
            storage: StorageSnapshot(usedBytes: 10, totalBytes: 20),
            thermal: ThermalSnapshot(state: .nominal),
            refreshReason: .interval
        )
    }
}
