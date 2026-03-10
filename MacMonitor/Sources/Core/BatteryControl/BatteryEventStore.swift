import Foundation

enum BatteryControlEventSource: String, Codable {
    case policy
    case manual
    case lifecycle
    case schedule
    case shortcut
    case system
}

struct BatteryControlEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let source: BatteryControlEventSource
    let state: BatteryControlState
    let command: BatteryControlCommand?
    let accepted: Bool
    let message: String
    let batteryPercent: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        source: BatteryControlEventSource,
        state: BatteryControlState,
        command: BatteryControlCommand?,
        accepted: Bool,
        message: String,
        batteryPercent: Int?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.state = state
        self.command = command
        self.accepted = accepted
        self.message = message
        self.batteryPercent = batteryPercent
    }
}

protocol BatteryEventStoring {
    func append(_ event: BatteryControlEvent) throws
    func recentEvents(limit: Int) -> [BatteryControlEvent]
    func pruneExpiredEvents(referenceDate: Date)
}

final class FileBatteryEventStore: BatteryEventStoring {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.oscar.macmonitor.battery-event-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retentionInterval: TimeInterval

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        retentionDays: Int = 14
    ) {
        self.fileManager = fileManager
        let resolvedDirectory = FileRAMPolicyStore.resolveDirectoryURL(directoryURL: directoryURL, fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("battery-events.jsonl", isDirectory: false)
        self.retentionInterval = TimeInterval(max(1, retentionDays) * 24 * 60 * 60)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func append(_ event: BatteryControlEvent) throws {
        try syncThrowing {
            try appendLine(for: event)
        }
    }

    func recentEvents(limit: Int) -> [BatteryControlEvent] {
        queue.sync {
            guard limit > 0 else { return [] }
            let pruned = prune(events: loadRecentEvents(limit: max(limit * 3, limit)), referenceDate: Date())
            return Array(
                pruned
                    .sorted(by: { $0.timestamp > $1.timestamp })
                    .prefix(limit)
            )
        }
    }

    func pruneExpiredEvents(referenceDate: Date = Date()) {
        queue.sync {
            let events = prune(events: loadEvents(), referenceDate: referenceDate)
            try? write(events: events)
        }
    }

    private func loadEvents() -> [BatteryControlEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        guard let data = try? Data(contentsOf: fileURL),
              let payload = String(data: data, encoding: .utf8) else {
            return []
        }

        return payload
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let lineData = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(BatteryControlEvent.self, from: lineData)
            }
    }

    private func loadRecentEvents(limit: Int) -> [BatteryControlEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return loadEvents()
        }

        defer {
            try? handle.close()
        }

        do {
            let fileSize = try handle.seekToEnd()
            if fileSize == 0 {
                return []
            }

            let chunkSize: UInt64 = 64 * 1024
            var cursor = fileSize
            var buffer = Data()
            var newlineCount = 0
            let targetLineCount = max(limit + 1, 8)

            while cursor > 0, newlineCount < targetLineCount {
                let readSize = min(chunkSize, cursor)
                cursor -= readSize
                try handle.seek(toOffset: cursor)

                guard let chunk = try handle.read(upToCount: Int(readSize)), !chunk.isEmpty else {
                    break
                }

                buffer.insert(contentsOf: chunk, at: 0)
                newlineCount += chunk.reduce(into: 0) { count, byte in
                    if byte == 0x0A {
                        count += 1
                    }
                }
            }

            let candidateLines = buffer
                .split(separator: 0x0A)
                .suffix(max(limit * 2, limit))

            return candidateLines.compactMap { line in
                try? decoder.decode(BatteryControlEvent.self, from: Data(line))
            }
        } catch {
            return loadEvents()
        }
    }

    private func prune(events: [BatteryControlEvent], referenceDate: Date) -> [BatteryControlEvent] {
        events.filter { referenceDate.timeIntervalSince($0.timestamp) <= retentionInterval }
    }

    private func write(events: [BatteryControlEvent]) throws {
        if events.isEmpty {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }

        let lines = try events.map { event -> String in
            let data = try encoder.encode(event)
            return String(decoding: data, as: UTF8.self)
        }

        let content = lines.joined(separator: "\n") + "\n"
        guard let data = content.data(using: .utf8) else {
            return
        }

        try data.write(to: fileURL, options: [.atomic])
    }

    private func appendLine(for event: BatteryControlEvent) throws {
        let lineData = try encoder.encode(event) + Data([0x0A])

        if !fileManager.fileExists(atPath: fileURL.path) {
            try lineData.write(to: fileURL, options: [.atomic])
            return
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        try handle.write(contentsOf: lineData)
    }

    private func syncThrowing<T>(_ work: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        queue.sync {
            result = Result { try work() }
        }
        return try result.get()
    }
}
