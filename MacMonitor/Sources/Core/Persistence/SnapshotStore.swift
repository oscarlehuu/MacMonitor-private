import Foundation

final class SnapshotStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let maxHistoryCount: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        maxHistoryCount: Int = 200
    ) {
        self.fileManager = fileManager
        self.maxHistoryCount = maxHistoryCount

        let directory: URL
        if let baseDirectoryURL {
            directory = baseDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directory = appSupport.appendingPathComponent("MacMonitor", isDirectory: true)
        }

        self.fileURL = directory.appendingPathComponent("snapshots.json")

        encoder.outputFormatting = [.sortedKeys]
        decoder.dateDecodingStrategy = .deferredToDate

        ensureStorageDirectoryExists()
    }

    func loadHistory() -> [SystemSnapshot] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let snapshots = try? decoder.decode([SystemSnapshot].self, from: data) else {
            return []
        }
        return snapshots
    }

    func append(_ snapshot: SystemSnapshot) {
        var history = loadHistory()
        history.append(snapshot)
        if history.count > maxHistoryCount {
            history = Array(history.suffix(maxHistoryCount))
        }
        save(history)
    }

    func save(_ history: [SystemSnapshot]) {
        ensureStorageDirectoryExists()
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func ensureStorageDirectoryExists() {
        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
