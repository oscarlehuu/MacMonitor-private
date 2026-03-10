import Foundation

final class NetworkSamplingCoordinator {
    typealias SampleHandler = @Sendable (_ snapshot: NetworkSnapshot) -> Void

    private let collector: NetworkCollecting
    private let interval: TimeInterval
    private let samplingQueue = DispatchQueue(
        label: "com.oscar.macmonitor.network-sampling",
        qos: .utility
    )
    private let stateLock = NSLock()

    private var latestSnapshot: NetworkSnapshot = .unavailable
    private var generation: UInt64 = 0
    private var samplingTimer: DispatchSourceTimer?
    private var bootstrapWorkItem: DispatchWorkItem?

    init(
        collector: NetworkCollecting,
        interval: TimeInterval
    ) {
        self.collector = collector
        self.interval = interval
    }

    func start(onSample: @escaping SampleHandler) {
        stop()
        let activeGeneration = currentGeneration()

        let timer = DispatchSource.makeTimerSource(queue: samplingQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.collectAndEmitIfChanged(expectedGeneration: activeGeneration, onSample: onSample)
        }

        samplingTimer = timer
        timer.resume()
        scheduleBootstrapIfNeeded(expectedGeneration: activeGeneration, onSample: onSample)
    }

    func stop() {
        samplingTimer?.setEventHandler {}
        samplingTimer?.cancel()
        samplingTimer = nil
        bootstrapWorkItem?.cancel()
        bootstrapWorkItem = nil

        stateLock.lock()
        latestSnapshot = .unavailable
        generation &+= 1
        stateLock.unlock()
    }

    func cachedSnapshot() -> NetworkSnapshot {
        stateLock.lock()
        defer { stateLock.unlock() }
        return latestSnapshot
    }

    private func currentGeneration() -> UInt64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return generation
    }

    private func scheduleBootstrapIfNeeded(
        expectedGeneration: UInt64,
        onSample: @escaping SampleHandler
    ) {
        bootstrapWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let cachedSnapshot = self.cachedSnapshot()
            guard cachedSnapshot.downloadBytesPerSecond == nil ||
                    cachedSnapshot.uploadBytesPerSecond == nil else {
                return
            }

            self.collectAndEmitIfChanged(expectedGeneration: expectedGeneration, onSample: onSample)
        }

        bootstrapWorkItem = workItem
        let bootstrapDelay = interval * 0.5
        samplingQueue.asyncAfter(deadline: .now() + bootstrapDelay, execute: workItem)
    }

    private func collectAndEmitIfChanged(
        expectedGeneration: UInt64,
        onSample: @escaping SampleHandler
    ) {
        let snapshot = collector.collect()
        guard store(snapshot, expectedGeneration: expectedGeneration) else { return }
        onSample(snapshot)
    }

    private func store(_ snapshot: NetworkSnapshot, expectedGeneration: UInt64) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard generation == expectedGeneration else { return false }
        guard snapshot != latestSnapshot else { return false }
        latestSnapshot = snapshot
        return true
    }
}
