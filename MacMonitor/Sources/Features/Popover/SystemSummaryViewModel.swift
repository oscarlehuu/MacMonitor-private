import Combine
import Foundation

@MainActor
final class SystemSummaryViewModel: ObservableObject {
    enum Screen {
        case temperature
        case battery
        case ram
        case storage
        case settings
        case ramPolicyManager
    }

    @Published private(set) var snapshot: SystemSnapshot?
    @Published private(set) var history: [SystemSnapshot] = []
    @Published private(set) var screen: Screen = .temperature

    let settings: SettingsStore

    private let engine: MetricsEngine
    private let snapshotStore: SnapshotStore
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    init(engine: MetricsEngine, snapshotStore: SnapshotStore, settings: SettingsStore) {
        self.engine = engine
        self.snapshotStore = snapshotStore
        self.settings = settings
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        history = snapshotStore.loadHistory()
        snapshot = history.last

        engine.$latestSnapshot
            .compactMap { $0 }
            .sink { [weak self] newSnapshot in
                guard let self else { return }
                snapshot = newSnapshot
                history.append(newSnapshot)
                if history.count > 200 {
                    history = Array(history.suffix(200))
                }
                snapshotStore.append(newSnapshot)
            }
            .store(in: &cancellables)

        engine.start()
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        engine.stop()
        cancellables.removeAll()
    }

    func refreshNow() {
        engine.refreshNow()
    }

    func showSettings() {
        screen = .settings
    }

    func showSummary() {
        showTemperature()
    }

    func showRAMDetails() {
        showRAM()
    }

    func showBattery() {
        screen = .battery
    }

    func showTemperature() {
        screen = .temperature
    }

    func showRAM() {
        screen = .ram
    }

    func showStorage() {
        screen = .storage
    }

    func showRAMPolicyManager() {
        screen = .ramPolicyManager
    }

    var isStale: Bool {
        guard let snapshot else { return true }
        let maxAge = settings.refreshInterval.seconds * 2.0
        return snapshot.age() > maxAge
    }

    var thermalState: ThermalState {
        snapshot?.thermal.state ?? .unknown
    }

    var statusTooltip: String {
        guard let snapshot else {
            return "MacMonitor: waiting for data"
        }

        let memoryUsage = MetricFormatter.percent(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes)
        let storageUsage = MetricFormatter.percent(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes)
        let batteryText: String
        if let percentage = snapshot.battery.percentage {
            batteryText = "\(percentage)% \(snapshot.battery.chargeState.title)"
        } else {
            batteryText = "Unavailable"
        }
        return "Thermal: \(snapshot.thermal.state.title) | RAM: \(memoryUsage) | Storage: \(storageUsage) | Battery: \(batteryText)"
    }
}
