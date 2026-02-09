import Combine
import Foundation

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case lime
    case midnight
    case cyber
    case daylight
    case arctic
    case sand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lime: return "Lime"
        case .midnight: return "Midnight"
        case .cyber: return "Cyberpunk"
        case .daylight: return "Daylight"
        case .arctic: return "Arctic"
        case .sand: return "Sand"
        }
    }

    var isDark: Bool {
        switch self {
        case .lime, .midnight, .cyber: return true
        case .daylight, .arctic, .sand: return false
        }
    }

    var symbol: String {
        isDark ? "moon.fill" : "sun.max.fill"
    }
}

// MARK: - Settings Enums

enum RefreshInterval: Int, CaseIterable, Codable, Identifiable {
    case oneMinute = 1
    case threeMinutes = 3
    case fiveMinutes = 5
    case tenMinutes = 10

    var id: Int { rawValue }

    var title: String {
        "Every \(rawValue) min"
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Codable, Identifiable {
    case icon
    case battery
    case ram
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icon:
            return "Icon"
        case .battery:
            return "Battery"
        case .ram:
            return "RAM"
        case .storage:
            return "Storage"
        }
    }
}

enum MenuBarMetricValueMode: String, CaseIterable, Codable, Identifiable {
    case used
    case free

    var id: String { rawValue }

    var title: String {
        switch self {
        case .used:
            return "Used"
        case .free:
            return "Free"
        }
    }
}

enum MenuBarMetricFormat: String, CaseIterable, Codable, Identifiable {
    case percent
    case number

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percent:
            return "Percent"
        case .number:
            return "Number"
        }
    }
}

protocol LaunchAtLoginManaging {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var appTheme: AppTheme {
        didSet {
            guard !isHydrating else { return }
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
            PopoverTheme.applyTheme(appTheme)
        }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet {
            guard !isHydrating else { return }
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
        }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
        }
    }

    @Published var menuBarMetricValueMode: MenuBarMetricValueMode {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarMetricValueMode.rawValue, forKey: Keys.menuBarMetricValueMode)
        }
    }

    @Published var menuBarMetricFormat: MenuBarMetricFormat {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarMetricFormat.rawValue, forKey: Keys.menuBarMetricFormat)
        }
    }

    @Published var batteryPolicyConfiguration: BatteryPolicyConfiguration {
        didSet {
            guard !isHydrating else { return }
            let normalized = batteryPolicyConfiguration.normalized()
            if normalized != batteryPolicyConfiguration {
                batteryPolicyConfiguration = normalized
                return
            }
            persistBatteryPolicyConfiguration(normalized)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            guard !isHydrating, !isSyncingLaunchToggle else { return }
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLogin)
            applyLaunchAtLoginToggle()
        }
    }

    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults
    private let launchAtLoginManager: LaunchAtLoginManaging
    private var isHydrating = true
    private var isSyncingLaunchToggle = false

    private enum Keys {
        static let appTheme = "settings.appTheme"
        static let refreshInterval = "settings.refreshIntervalMinutes"
        static let menuBarDisplayMode = "settings.menuBarDisplayMode"
        static let menuBarMetricValueMode = "settings.menuBarMetricValueMode"
        static let menuBarMetricFormat = "settings.menuBarMetricFormat"
        static let batteryPolicyConfiguration = "settings.batteryPolicyConfiguration"
        static let launchAtLogin = "settings.launchAtLogin"
    }

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginManager: LaunchAtLoginManaging
    ) {
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager

        self.appTheme = AppTheme(
            rawValue: defaults.string(forKey: Keys.appTheme) ?? ""
        ) ?? .lime

        let persistedInterval = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = RefreshInterval(rawValue: persistedInterval) ?? .threeMinutes

        self.menuBarDisplayMode = MenuBarDisplayMode(
            rawValue: defaults.string(forKey: Keys.menuBarDisplayMode) ?? ""
        ) ?? .icon
        self.menuBarMetricValueMode = MenuBarMetricValueMode(
            rawValue: defaults.string(forKey: Keys.menuBarMetricValueMode) ?? ""
        ) ?? .used
        self.menuBarMetricFormat = MenuBarMetricFormat(
            rawValue: defaults.string(forKey: Keys.menuBarMetricFormat) ?? ""
        ) ?? .percent

        self.batteryPolicyConfiguration = Self.loadBatteryPolicyConfiguration(defaults: defaults)

        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            self.launchAtLoginEnabled = launchAtLoginManager.isEnabled()
        } else {
            self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLogin)
        }

        isHydrating = false
        PopoverTheme.applyTheme(appTheme)
    }

    private static func loadBatteryPolicyConfiguration(defaults: UserDefaults) -> BatteryPolicyConfiguration {
        guard let data = defaults.data(forKey: Keys.batteryPolicyConfiguration) else {
            return .default
        }
        guard let decoded = try? JSONDecoder().decode(BatteryPolicyConfiguration.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    private func persistBatteryPolicyConfiguration(_ configuration: BatteryPolicyConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.batteryPolicyConfiguration)
    }

    private func applyLaunchAtLoginToggle() {
        do {
            try launchAtLoginManager.setEnabled(launchAtLoginEnabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            isSyncingLaunchToggle = true
            launchAtLoginEnabled = launchAtLoginManager.isEnabled()
            isSyncingLaunchToggle = false
        }
    }
}
