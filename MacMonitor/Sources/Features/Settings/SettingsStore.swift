import Combine
import Foundation

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

protocol LaunchAtLoginManaging {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var refreshInterval: RefreshInterval {
        didSet {
            guard !isHydrating else { return }
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
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
        static let refreshInterval = "settings.refreshIntervalMinutes"
        static let launchAtLogin = "settings.launchAtLogin"
    }

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginManager: LaunchAtLoginManaging
    ) {
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager

        let persistedInterval = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = RefreshInterval(rawValue: persistedInterval) ?? .threeMinutes

        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            self.launchAtLoginEnabled = launchAtLoginManager.isEnabled()
        } else {
            self.launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLogin)
        }

        isHydrating = false
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
