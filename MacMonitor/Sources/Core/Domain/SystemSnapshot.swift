import Foundation

enum ThermalState: String, Codable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical
    case unknown

    var title: String {
        switch self {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        case .unknown:
            return "Unknown"
        }
    }

    var severity: Int {
        switch self {
        case .nominal:
            return 0
        case .fair:
            return 1
        case .serious:
            return 2
        case .critical:
            return 3
        case .unknown:
            return 4
        }
    }
}

enum MemoryPressureLevel: String, Codable {
    case normal
    case warning
    case critical
    case unknown
}

struct MemorySnapshot: Codable, Equatable {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let pressure: MemoryPressureLevel
    let activeBytes: UInt64?
    let inactiveBytes: UInt64?
    let wiredBytes: UInt64?
    let compressedBytes: UInt64?
    let freeBytes: UInt64?

    init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        pressure: MemoryPressureLevel,
        activeBytes: UInt64? = nil,
        inactiveBytes: UInt64? = nil,
        wiredBytes: UInt64? = nil,
        compressedBytes: UInt64? = nil,
        freeBytes: UInt64? = nil
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.freeBytes = freeBytes
    }

    var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    var usedIncludingCompressedBytes: UInt64 {
        min(totalBytes, usedBytes + (compressedBytes ?? 0))
    }

    static func empty(totalBytes: UInt64) -> MemorySnapshot {
        MemorySnapshot(usedBytes: 0, totalBytes: totalBytes, pressure: .unknown)
    }
}

struct StorageSnapshot: Codable, Equatable {
    let usedBytes: UInt64
    let totalBytes: UInt64

    var usageRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    static func empty(totalBytes: UInt64 = 0) -> StorageSnapshot {
        StorageSnapshot(usedBytes: 0, totalBytes: totalBytes)
    }
}

struct ThermalSnapshot: Codable, Equatable {
    let state: ThermalState
}

enum RefreshReason: String, Codable {
    case startup
    case interval
    case thermalNotification
    case manual
}

struct SystemSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let memory: MemorySnapshot
    let storage: StorageSnapshot
    let thermal: ThermalSnapshot
    let refreshReason: RefreshReason

    init(
        id: UUID = UUID(),
        timestamp: Date,
        memory: MemorySnapshot,
        storage: StorageSnapshot,
        thermal: ThermalSnapshot,
        refreshReason: RefreshReason
    ) {
        self.id = id
        self.timestamp = timestamp
        self.memory = memory
        self.storage = storage
        self.thermal = thermal
        self.refreshReason = refreshReason
    }

    func age(referenceDate: Date = Date()) -> TimeInterval {
        referenceDate.timeIntervalSince(timestamp)
    }
}
