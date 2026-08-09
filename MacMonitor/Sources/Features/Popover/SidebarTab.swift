import Foundation

/// Represents each top-level section in the sidebar navigation.
enum SidebarTab: CaseIterable, Hashable {
    case memory
    case battery
    case storage
    case trends
    case settings

    var symbol: String {
        switch self {
        case .memory: return "memorychip"
        case .battery: return "battery.100"
        case .storage: return "internaldrive"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }

    var tooltip: String {
        switch self {
        case .memory: return "Memory"
        case .battery: return "Battery"
        case .storage: return "Storage"
        case .trends: return "Trends"
        case .settings: return "Settings"
        }
    }

    /// Primary nav items displayed above the separator (excludes settings).
    static var primaryItems: [SidebarTab] {
        [.memory, .storage, .trends]
    }
}
