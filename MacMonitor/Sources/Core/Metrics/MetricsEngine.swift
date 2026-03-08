import Combine
import Foundation

@MainActor
final class MetricsEngine: ObservableObject {
    @Published private(set) var latestSnapshot: SystemSnapshot?

    private let memoryCollector: MemoryCollecting
    private let storageCollector: StorageCollecting
    private let batteryCollector: BatteryCollecting
    private let thermalCollector: ThermalCollecting
    private let cpuCollector: CPUCollecting
    private let networkCollector: NetworkCollecting
    private let gpuCollector: GPUCollecting
    private let settings: SettingsStore
    private let now: () -> Date
    private let networkSamplingInterval: TimeInterval

    private var timerCancellable: AnyCancellable?
    private var refreshIntervalCancellable: AnyCancellable?
    private var batteryChangeCancellable: AnyCancellable?
    private var thermalChangeCancellable: AnyCancellable?
    private var networkSamplingCancellable: AnyCancellable?
    private var networkBootstrapWorkItem: DispatchWorkItem?

    init(
        memoryCollector: MemoryCollecting,
        storageCollector: StorageCollecting,
        batteryCollector: BatteryCollecting,
        thermalCollector: ThermalCollecting,
        cpuCollector: CPUCollecting,
        networkCollector: NetworkCollecting,
        gpuCollector: GPUCollecting = DefaultGPUCollector(),
        settings: SettingsStore,
        now: @escaping () -> Date = Date.init,
        networkSamplingInterval: TimeInterval = 1.0
    ) {
        self.memoryCollector = memoryCollector
        self.storageCollector = storageCollector
        self.batteryCollector = batteryCollector
        self.thermalCollector = thermalCollector
        self.cpuCollector = cpuCollector
        self.networkCollector = networkCollector
        self.gpuCollector = gpuCollector
        self.settings = settings
        self.now = now
        self.networkSamplingInterval = networkSamplingInterval
    }

    func start() {
        bindSettings()
        bindBatteryChanges()
        bindThermalChanges()
        scheduleTimer(using: settings.refreshInterval)
        scheduleNetworkSampling()
        refresh(reason: .startup)
        scheduleNetworkBootstrapRefreshIfNeeded()
    }

    func stop() {
        timerCancellable?.cancel()
        refreshIntervalCancellable?.cancel()
        batteryChangeCancellable?.cancel()
        thermalChangeCancellable?.cancel()
        networkSamplingCancellable?.cancel()
        networkSamplingCancellable = nil
        networkBootstrapWorkItem?.cancel()
        networkBootstrapWorkItem = nil
    }

    func refreshNow() {
        refresh(reason: .manual)
    }

    private func bindSettings() {
        refreshIntervalCancellable = settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] interval in
                self?.scheduleTimer(using: interval)
            }
    }

    private func bindBatteryChanges() {
        batteryChangeCancellable = batteryCollector.stateDidChangePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refresh(reason: .batteryNotification)
            }
    }

    private func bindThermalChanges() {
        thermalChangeCancellable = thermalCollector.stateDidChangePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh(reason: .thermalNotification)
            }
    }

    private func scheduleTimer(using interval: RefreshInterval) {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: interval.seconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh(reason: .interval)
            }
    }

    private func scheduleNetworkSampling() {
        networkSamplingCancellable?.cancel()
        networkSamplingCancellable = Timer.publish(every: networkSamplingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNetworkSample()
            }
    }

    private func refresh(reason: RefreshReason) {
        let memory = memoryCollector.collect() ?? .empty(totalBytes: ProcessInfo.processInfo.physicalMemory)
        let storage = storageCollector.collect() ?? .empty()
        let battery = batteryCollector.collect() ?? .unavailable
        let thermal = thermalCollector.collect()
        let cpu = cpuCollector.collect()
        let network = networkCollector.collect()
        let gpu = gpuCollector.collect()

        latestSnapshot = SystemSnapshot(
            timestamp: now(),
            memory: memory,
            storage: storage,
            battery: battery,
            thermal: thermal,
            cpu: cpu,
            network: network,
            gpu: gpu,
            refreshReason: reason
        )
    }

    private func refreshNetworkSample() {
        guard let latestSnapshot else { return }

        let network = networkCollector.collect()
        guard network != latestSnapshot.network else { return }

        self.latestSnapshot = SystemSnapshot(
            id: latestSnapshot.id,
            schemaVersion: latestSnapshot.schemaVersion,
            timestamp: now(),
            memory: latestSnapshot.memory,
            storage: latestSnapshot.storage,
            battery: latestSnapshot.battery,
            thermal: latestSnapshot.thermal,
            cpu: latestSnapshot.cpu,
            network: network,
            gpu: latestSnapshot.gpu,
            refreshReason: .networkSample
        )
    }

    private func scheduleNetworkBootstrapRefreshIfNeeded() {
        networkBootstrapWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard latestSnapshot?.network.downloadBytesPerSecond == nil ||
                latestSnapshot?.network.uploadBytesPerSecond == nil else {
                return
            }
            refreshNetworkSample()
        }

        networkBootstrapWorkItem = workItem
        let bootstrapDelay = min(max(networkSamplingInterval, 0.05), 0.25)
        DispatchQueue.main.asyncAfter(deadline: .now() + bootstrapDelay, execute: workItem)
    }
}
