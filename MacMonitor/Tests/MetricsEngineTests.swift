import Combine
import Darwin
import XCTest
@testable import MacMonitor

@MainActor
final class MetricsEngineTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testStartPublishesStartupSnapshot() {
        let engine = makeEngine()

        engine.start()

        XCTAssertEqual(engine.latestSnapshot?.refreshReason, .startup)
    }

    func testRefreshNowPublishesManualSnapshot() {
        let engine = makeEngine()

        engine.start()
        engine.refreshNow()

        XCTAssertEqual(engine.latestSnapshot?.refreshReason, .manual)
    }

    func testThermalChangePublishesThermalNotificationSnapshot() {
        let thermalCollector = FakeThermalCollector(initial: .nominal)
        let engine = makeEngine(thermalCollector: thermalCollector)

        var refreshReasons: [RefreshReason] = []
        let expectation = expectation(description: "collect startup and thermal change snapshots")

        engine.$latestSnapshot
            .compactMap { $0?.refreshReason }
            .sink { reason in
                refreshReasons.append(reason)
                if refreshReasons.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        engine.start()
        thermalCollector.send(state: .serious)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(refreshReasons, [.startup, .thermalNotification])
    }

    private func makeEngine(
        thermalCollector: FakeThermalCollector = FakeThermalCollector(initial: .nominal)
    ) -> MetricsEngine {
        let defaults = UserDefaults(suiteName: "MetricsEngineTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults, launchAtLoginManager: FakeLaunchAtLoginManager())

        return MetricsEngine(
            memoryCollector: FakeMemoryCollector(),
            storageCollector: FakeStorageCollector(),
            thermalCollector: thermalCollector,
            settings: settings,
            now: { Date(timeIntervalSince1970: 1_234_567) }
        )
    }
}

final class MemoryCollectorTests: XCTestCase {
    func testUsedPageCountExcludesInactivePages() {
        var stats = vm_statistics64()
        stats.active_count = 120
        stats.inactive_count = 240
        stats.wire_count = 30
        stats.compressor_page_count = 10

        XCTAssertEqual(MemoryCollector.usedPageCount(from: stats), 150)
    }
}

private struct FakeMemoryCollector: MemoryCollecting {
    func collect() -> MemorySnapshot? {
        MemorySnapshot(usedBytes: 4, totalBytes: 8, pressure: .normal)
    }
}

private struct FakeStorageCollector: StorageCollecting {
    func collect() -> StorageSnapshot? {
        StorageSnapshot(usedBytes: 10, totalBytes: 20)
    }
}

private final class FakeThermalCollector: ThermalCollecting {
    private let subject = PassthroughSubject<ThermalState, Never>()
    private var current: ThermalState

    init(initial: ThermalState) {
        current = initial
    }

    var stateDidChangePublisher: AnyPublisher<ThermalState, Never> {
        subject.eraseToAnyPublisher()
    }

    func collect() -> ThermalSnapshot {
        ThermalSnapshot(state: current)
    }

    func send(state: ThermalState) {
        current = state
        subject.send(state)
    }
}

private struct FakeLaunchAtLoginManager: LaunchAtLoginManaging {
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}
