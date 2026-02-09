import Foundation

enum BatteryPowerSource: String, Codable, Equatable {
    case ac
    case battery
    case ups
    case unknown

    var title: String {
        switch self {
        case .ac:
            return "AC"
        case .battery:
            return "Battery"
        case .ups:
            return "UPS"
        case .unknown:
            return "Unknown"
        }
    }
}

enum BatteryChargeState: String, Codable, Equatable {
    case charging
    case discharging
    case charged
    case notCharging
    case unknown

    var title: String {
        switch self {
        case .charging:
            return "Charging"
        case .discharging:
            return "Discharging"
        case .charged:
            return "Charged"
        case .notCharging:
            return "Not Charging"
        case .unknown:
            return "Unknown"
        }
    }
}

struct BatterySnapshot: Codable, Equatable {
    let currentCapacity: Int?
    let maxCapacity: Int?
    let isPresent: Bool
    let isCharging: Bool
    let isCharged: Bool
    let powerSource: BatteryPowerSource
    let timeToEmptyMinutes: Int?
    let timeToFullChargeMinutes: Int?
    let amperageMilliAmps: Int?
    let voltageMilliVolts: Int?
    let temperatureCelsius: Int?
    let cycleCount: Int?
    let health: String?
    let healthCondition: String?
    let lowPowerModeEnabled: Bool

    var percentage: Int? {
        guard let currentCapacity, let maxCapacity, maxCapacity > 0 else { return nil }
        return Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
    }

    var chargeState: BatteryChargeState {
        if isCharging {
            return .charging
        }
        if isCharged {
            return .charged
        }
        switch powerSource {
        case .battery:
            return .discharging
        case .ac, .ups:
            return .notCharging
        case .unknown:
            return .unknown
        }
    }

    static let unavailable = BatterySnapshot(
        currentCapacity: nil,
        maxCapacity: nil,
        isPresent: false,
        isCharging: false,
        isCharged: false,
        powerSource: .unknown,
        timeToEmptyMinutes: nil,
        timeToFullChargeMinutes: nil,
        amperageMilliAmps: nil,
        voltageMilliVolts: nil,
        temperatureCelsius: nil,
        cycleCount: nil,
        health: nil,
        healthCondition: nil,
        lowPowerModeEnabled: false
    )
}

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
    case batteryNotification
    case thermalNotification
    case manual
}

struct SystemSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let memory: MemorySnapshot
    let storage: StorageSnapshot
    let battery: BatterySnapshot
    let thermal: ThermalSnapshot
    let refreshReason: RefreshReason

    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case memory
        case storage
        case battery
        case thermal
        case refreshReason
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        memory: MemorySnapshot,
        storage: StorageSnapshot,
        battery: BatterySnapshot = .unavailable,
        thermal: ThermalSnapshot,
        refreshReason: RefreshReason
    ) {
        self.id = id
        self.timestamp = timestamp
        self.memory = memory
        self.storage = storage
        self.battery = battery
        self.thermal = thermal
        self.refreshReason = refreshReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        memory = try container.decode(MemorySnapshot.self, forKey: .memory)
        storage = try container.decode(StorageSnapshot.self, forKey: .storage)
        battery = try container.decodeIfPresent(BatterySnapshot.self, forKey: .battery) ?? .unavailable
        thermal = try container.decode(ThermalSnapshot.self, forKey: .thermal)
        refreshReason = try container.decode(RefreshReason.self, forKey: .refreshReason)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(memory, forKey: .memory)
        try container.encode(storage, forKey: .storage)
        try container.encode(battery, forKey: .battery)
        try container.encode(thermal, forKey: .thermal)
        try container.encode(refreshReason, forKey: .refreshReason)
    }

    func age(referenceDate: Date = Date()) -> TimeInterval {
        referenceDate.timeIntervalSince(timestamp)
    }
}
