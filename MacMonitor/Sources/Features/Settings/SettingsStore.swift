import Combine
import CoreGraphics
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
        case .lime: return "Dark"
        case .midnight: return "Midnight"
        case .cyber: return "Cyberpunk"
        case .daylight: return "Light"
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
    case memory
    case storage
    case cpu
    case network
    case both
    case icon

    var id: String { rawValue }

    static let userSelectableCases: [MenuBarDisplayMode] = [
        .both,
        .memory,
        .storage,
        .cpu,
        .network
    ]

    var title: String {
        switch self {
        case .memory:
            return "Memory"
        case .storage:
            return "Storage"
        case .cpu:
            return "CPU"
        case .network:
            return "Network"
        case .both:
            return "Both"
        case .icon:
            return "Icon Only"
        }
    }
}

enum MenuBarMetricDisplayFormat: String, CaseIterable, Codable, Identifiable {
    case percentUsage
    case percentUsageLeft
    case numberUsage
    case numberLeft
    case numberUsageLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentUsage:
            return "% Usage"
        case .percentUsageLeft:
            return "% Usage / Left"
        case .numberUsage:
            return "Number (Usage)"
        case .numberLeft:
            return "Number (Left)"
        case .numberUsageLeft:
            return "# Usage / Left"
        }
    }
}

enum MenuBarComposerBlockKind: String, CaseIterable, Codable, Identifiable {
    case memory
    case storage
    case cpu
    case network
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory:
            return "RAM"
        case .storage:
            return "SSD"
        case .cpu:
            return "CPU"
        case .network:
            return "Network"
        case .text:
            return "Text"
        }
    }

    var defaultLabel: String {
        switch self {
        case .memory:
            return "RAM"
        case .storage:
            return "SSD"
        case .cpu:
            return "CPU"
        case .network:
            return "NET"
        case .text:
            return ""
        }
    }

    var defaultColorHex: UInt32 {
        switch self {
        case .memory:
            return 0x0A84FF
        case .storage:
            return 0x32D74B
        case .cpu:
            return 0xFF9F0A
        case .network:
            return 0xBF5AF2
        case .text:
            return 0xFFFFFF
        }
    }

    var supportedFormats: [MenuBarMetricDisplayFormat] {
        switch self {
        case .memory, .storage:
            return MenuBarMetricDisplayFormat.allCases
        case .cpu:
            return [.percentUsage]
        case .network:
            return [.numberUsage]
        case .text:
            return []
        }
    }

    func normalizedFormat(_ format: MenuBarMetricDisplayFormat) -> MenuBarMetricDisplayFormat {
        supportedFormats.contains(format) ? format : supportedFormats.first ?? .percentUsage
    }

    var isMetric: Bool {
        self != .text
    }
}

struct MenuBarComposerBlock: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: MenuBarComposerBlockKind
    var isEnabled: Bool
    var label: String
    var format: MenuBarMetricDisplayFormat
    var colorHex: UInt32
    var text: String

    static func metric(_ kind: MenuBarComposerBlockKind, format: MenuBarMetricDisplayFormat? = nil) -> MenuBarComposerBlock {
        MenuBarComposerBlock(
            id: UUID(),
            kind: kind,
            isEnabled: true,
            label: kind.defaultLabel,
            format: kind.normalizedFormat(format ?? .percentUsage),
            colorHex: kind.defaultColorHex,
            text: ""
        )
    }

    static func text(_ value: String = "•") -> MenuBarComposerBlock {
        MenuBarComposerBlock(
            id: UUID(),
            kind: .text,
            isEnabled: true,
            label: "",
            format: .numberUsage,
            colorHex: MenuBarComposerBlockKind.text.defaultColorHex,
            text: value
        )
    }

    func normalized() -> MenuBarComposerBlock {
        var normalized = self
        normalized.colorHex = colorHex & 0x00FF_FFFF
        if kind.isMetric {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.label = trimmed.isEmpty ? kind.defaultLabel : trimmed
            normalized.format = kind.normalizedFormat(format)
            normalized.text = ""
        } else {
            normalized.label = ""
            normalized.format = .numberUsage
            if normalized.text.isEmpty {
                normalized.text = "•"
            }
        }
        return normalized
    }
}

struct MenuBarComposerConfiguration: Codable, Equatable {
    var separator: String
    var blocks: [MenuBarComposerBlock]

    static let `default` = MenuBarComposerConfiguration(
        separator: " | ",
        blocks: [
            .metric(.memory, format: .percentUsage),
            .text(" | "),
            .metric(.storage, format: .percentUsage)
        ]
    )

    func normalized() -> MenuBarComposerConfiguration {
        let normalizedBlocks = blocks.map { $0.normalized() }

        let normalizedSeparator = separator.count > 16 ? String(separator.prefix(16)) : separator
        let fallbackSeparator = normalizedSeparator.isEmpty ? " " : normalizedSeparator

        return MenuBarComposerConfiguration(
            separator: fallbackSeparator,
            blocks: normalizedBlocks.isEmpty ? Self.default.blocks : normalizedBlocks
        )
    }
}

private enum LegacyExceededThresholdHighlightColorPreset: String {
    case yellow
    case orange
    case red
    case green
    case blue
    case purple

    var paletteHex: UInt32 {
        switch self {
        case .yellow:
            return 0xFFD60A
        case .orange:
            return 0xFF9F0A
        case .red:
            return 0xFF453A
        case .green:
            return 0x32D74B
        case .blue:
            return 0x0A84FF
        case .purple:
            return 0xBF5AF2
        }
    }
}

struct SystemAlertSettings: Codable, Equatable {
    var thermalAlertEnabled: Bool
    var thermalThreshold: ThermalState
    var ramAlertEnabled: Bool
    var ramUsagePercentThreshold: Int
    var storageAlertEnabled: Bool
    var storageUsagePercentThreshold: Int
    var batteryHealthDropAlertEnabled: Bool
    var batteryHealthDropPercentThreshold: Int
    var cooldownMinutes: Int
    var exceededThresholdHighlightColor: UInt32

    private enum CodingKeys: String, CodingKey {
        case thermalAlertEnabled
        case thermalThreshold
        case ramAlertEnabled
        case ramUsagePercentThreshold
        case storageAlertEnabled
        case storageUsagePercentThreshold
        case batteryHealthDropAlertEnabled
        case batteryHealthDropPercentThreshold
        case cooldownMinutes
        case exceededThresholdHighlightColor
    }

    init(
        thermalAlertEnabled: Bool,
        thermalThreshold: ThermalState,
        ramAlertEnabled: Bool,
        ramUsagePercentThreshold: Int,
        storageAlertEnabled: Bool,
        storageUsagePercentThreshold: Int,
        batteryHealthDropAlertEnabled: Bool,
        batteryHealthDropPercentThreshold: Int,
        cooldownMinutes: Int,
        exceededThresholdHighlightColor: UInt32
    ) {
        self.thermalAlertEnabled = thermalAlertEnabled
        self.thermalThreshold = thermalThreshold
        self.ramAlertEnabled = ramAlertEnabled
        self.ramUsagePercentThreshold = ramUsagePercentThreshold
        self.storageAlertEnabled = storageAlertEnabled
        self.storageUsagePercentThreshold = storageUsagePercentThreshold
        self.batteryHealthDropAlertEnabled = batteryHealthDropAlertEnabled
        self.batteryHealthDropPercentThreshold = batteryHealthDropPercentThreshold
        self.cooldownMinutes = cooldownMinutes
        self.exceededThresholdHighlightColor = exceededThresholdHighlightColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thermalAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .thermalAlertEnabled)
            ?? SystemAlertSettings.default.thermalAlertEnabled
        thermalThreshold = try container.decodeIfPresent(ThermalState.self, forKey: .thermalThreshold)
            ?? SystemAlertSettings.default.thermalThreshold
        ramAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .ramAlertEnabled)
            ?? SystemAlertSettings.default.ramAlertEnabled
        ramUsagePercentThreshold = try container.decodeIfPresent(Int.self, forKey: .ramUsagePercentThreshold)
            ?? SystemAlertSettings.default.ramUsagePercentThreshold
        storageAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .storageAlertEnabled)
            ?? SystemAlertSettings.default.storageAlertEnabled
        storageUsagePercentThreshold = try container.decodeIfPresent(Int.self, forKey: .storageUsagePercentThreshold)
            ?? SystemAlertSettings.default.storageUsagePercentThreshold
        batteryHealthDropAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .batteryHealthDropAlertEnabled)
            ?? SystemAlertSettings.default.batteryHealthDropAlertEnabled
        batteryHealthDropPercentThreshold = try container.decodeIfPresent(Int.self, forKey: .batteryHealthDropPercentThreshold)
            ?? SystemAlertSettings.default.batteryHealthDropPercentThreshold
        cooldownMinutes = try container.decodeIfPresent(Int.self, forKey: .cooldownMinutes)
            ?? SystemAlertSettings.default.cooldownMinutes
        exceededThresholdHighlightColor = Self.decodeHighlightColor(
            from: container,
            key: .exceededThresholdHighlightColor
        ) ?? SystemAlertSettings.default.exceededThresholdHighlightColor
    }

    static let `default` = SystemAlertSettings(
        thermalAlertEnabled: true,
        thermalThreshold: .serious,
        ramAlertEnabled: true,
        ramUsagePercentThreshold: 90,
        storageAlertEnabled: true,
        storageUsagePercentThreshold: 90,
        batteryHealthDropAlertEnabled: true,
        batteryHealthDropPercentThreshold: 15,
        cooldownMinutes: 15,
        exceededThresholdHighlightColor: 0xFFD60A
    )

    func normalized() -> SystemAlertSettings {
        let normalizedThreshold: ThermalState
        switch thermalThreshold {
        case .nominal, .fair, .serious, .critical:
            normalizedThreshold = thermalThreshold
        case .unknown:
            normalizedThreshold = .serious
        }

        return SystemAlertSettings(
            thermalAlertEnabled: thermalAlertEnabled,
            thermalThreshold: normalizedThreshold,
            ramAlertEnabled: ramAlertEnabled,
            ramUsagePercentThreshold: min(max(ramUsagePercentThreshold, 60), 99),
            storageAlertEnabled: storageAlertEnabled,
            storageUsagePercentThreshold: min(max(storageUsagePercentThreshold, 60), 99),
            batteryHealthDropAlertEnabled: batteryHealthDropAlertEnabled,
            batteryHealthDropPercentThreshold: min(max(batteryHealthDropPercentThreshold, 5), 40),
            cooldownMinutes: min(max(cooldownMinutes, 5), 30),
            exceededThresholdHighlightColor: Self.normalizedHighlightColorHex(exceededThresholdHighlightColor)
        )
    }

    private static func decodeHighlightColor(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> UInt32? {
        if let value = try? container.decode(UInt32.self, forKey: key) {
            return normalizedHighlightColorHex(value)
        }

        if let value = try? container.decode(Int.self, forKey: key),
           let safeValue = UInt32(exactly: value) {
            return normalizedHighlightColorHex(safeValue)
        }

        if let rawValue = try? container.decode(String.self, forKey: key) {
            if let legacyPreset = LegacyExceededThresholdHighlightColorPreset(rawValue: rawValue) {
                return legacyPreset.paletteHex
            }

            let normalizedHexString = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "0x", with: "")
            if let value = UInt32(normalizedHexString, radix: 16) {
                return normalizedHighlightColorHex(value)
            }
        }

        return nil
    }

    private static func normalizedHighlightColorHex(_ value: UInt32) -> UInt32 {
        value & 0x00FF_FFFF
    }
}

struct BatteryAdvancedControlFeatureFlags: Codable, Equatable {
    var sleepAwareStopChargingEnabled: Bool
    var blockSleepUntilLimitEnabled: Bool
    var calibrationWorkflowEnabled: Bool
    var hardwarePercentageRefinementEnabled: Bool
    var magsafeLEDControlEnabled: Bool

    static let `default` = BatteryAdvancedControlFeatureFlags(
        sleepAwareStopChargingEnabled: false,
        blockSleepUntilLimitEnabled: false,
        calibrationWorkflowEnabled: false,
        hardwarePercentageRefinementEnabled: false,
        magsafeLEDControlEnabled: false
    )

    var anyEnabled: Bool {
        sleepAwareStopChargingEnabled
            || blockSleepUntilLimitEnabled
            || calibrationWorkflowEnabled
            || hardwarePercentageRefinementEnabled
            || magsafeLEDControlEnabled
    }

    func normalized() -> BatteryAdvancedControlFeatureFlags {
        BatteryAdvancedControlFeatureFlags(
            sleepAwareStopChargingEnabled: sleepAwareStopChargingEnabled,
            blockSleepUntilLimitEnabled: blockSleepUntilLimitEnabled,
            calibrationWorkflowEnabled: false,
            hardwarePercentageRefinementEnabled: hardwarePercentageRefinementEnabled,
            magsafeLEDControlEnabled: false
        )
    }
}

protocol LaunchAtLoginManaging {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class SettingsStore: ObservableObject {
    static let mainPopoverFixedHeight: CGFloat = 620
    static let mainPopoverFallbackWidth: CGFloat = 440
    static let mainPopoverMinWidth: CGFloat = 404
    static let mainPopoverMaxWidth: CGFloat = 760

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
            if menuBarDisplayMode == .icon {
                menuBarDisplayMode = .both
                return
            }
            defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
            guard !isSyncingMenuBarLegacySettings else { return }
            synchronizeComposerFromLegacySettings()
        }
    }

    @Published var menuBarMemoryFormat: MenuBarMetricDisplayFormat {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarMemoryFormat.rawValue, forKey: Keys.menuBarMemoryFormat)
            guard !isSyncingMenuBarLegacySettings else { return }
            synchronizeComposerFromLegacySettings()
        }
    }

    @Published var menuBarStorageFormat: MenuBarMetricDisplayFormat {
        didSet {
            guard !isHydrating else { return }
            defaults.set(menuBarStorageFormat.rawValue, forKey: Keys.menuBarStorageFormat)
            guard !isSyncingMenuBarLegacySettings else { return }
            synchronizeComposerFromLegacySettings()
        }
    }

    @Published var menuBarComposerConfiguration: MenuBarComposerConfiguration {
        didSet {
            guard !isHydrating else { return }
            let normalized = menuBarComposerConfiguration.normalized()
            if normalized != menuBarComposerConfiguration {
                menuBarComposerConfiguration = normalized
                return
            }
            persistMenuBarComposerConfiguration(normalized)
            guard !isSyncingMenuBarLegacySettings else { return }
            synchronizeLegacyMenuBarSettings(from: normalized)
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

    @Published var systemAlertSettings: SystemAlertSettings {
        didSet {
            guard !isHydrating else { return }
            let normalized = systemAlertSettings.normalized()
            if normalized != systemAlertSettings {
                systemAlertSettings = normalized
                return
            }
            persistSystemAlertSettings(normalized)
        }
    }

    @Published var batteryAdvancedControlFeatureFlags: BatteryAdvancedControlFeatureFlags {
        didSet {
            guard !isHydrating else { return }
            let normalized = batteryAdvancedControlFeatureFlags.normalized()
            if normalized != batteryAdvancedControlFeatureFlags {
                batteryAdvancedControlFeatureFlags = normalized
                return
            }
            persistBatteryAdvancedControlFeatureFlags(normalized)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            guard !isHydrating, !isSyncingLaunchToggle else { return }
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLogin)
            applyLaunchAtLoginToggle()
        }
    }

    @Published private(set) var mainPopoverDefaultWidth: CGFloat {
        didSet {
            guard !isHydrating else { return }
            let normalized = Self.normalizedMainPopoverWidth(mainPopoverDefaultWidth)
            if normalized != mainPopoverDefaultWidth {
                mainPopoverDefaultWidth = normalized
                return
            }
            defaults.set(Double(normalized), forKey: Keys.mainPopoverDefaultWidth)
        }
    }

    @Published private(set) var mainPopoverCurrentWidth: CGFloat

    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults
    private let launchAtLoginManager: LaunchAtLoginManaging
    private var isHydrating = true
    private var isSyncingLaunchToggle = false
    private var isSyncingMenuBarLegacySettings = false

    private enum Keys {
        static let appTheme = "settings.appTheme"
        static let refreshInterval = "settings.refreshIntervalMinutes"
        static let menuBarDisplayMode = "settings.menuBarDisplayMode"
        static let menuBarMemoryFormat = "settings.menuBarMemoryFormat"
        static let menuBarStorageFormat = "settings.menuBarStorageFormat"
        static let menuBarComposerConfiguration = "settings.menuBarComposerConfiguration"

        // Legacy keys kept for migration.
        static let legacyMenuBarDisplayMode = "settings.menuBarDisplayMode"
        static let legacyMenuBarMetricValueMode = "settings.menuBarMetricValueMode"
        static let legacyMenuBarMetricFormat = "settings.menuBarMetricFormat"
        static let batteryPolicyConfiguration = "settings.batteryPolicyConfiguration"
        static let systemAlertSettings = "settings.systemAlertSettings"
        static let batteryAdvancedControlFeatureFlags = "settings.batteryAdvancedControlFeatureFlags"
        static let launchAtLogin = "settings.launchAtLogin"
        static let mainPopoverDefaultWidth = "settings.mainPopoverDefaultWidth"
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

        let hydratedMenuBarDisplayMode = Self.loadMenuBarDisplayMode(defaults: defaults)
        let hydratedMenuBarMemoryFormat = Self.loadMenuBarMetricFormat(
            defaults: defaults,
            key: Keys.menuBarMemoryFormat,
            defaultFormat: .percentUsage
        )
        let hydratedMenuBarStorageFormat = Self.loadMenuBarMetricFormat(
            defaults: defaults,
            key: Keys.menuBarStorageFormat,
            defaultFormat: .percentUsage
        )
        self.menuBarDisplayMode = hydratedMenuBarDisplayMode
        self.menuBarMemoryFormat = hydratedMenuBarMemoryFormat
        self.menuBarStorageFormat = hydratedMenuBarStorageFormat
        self.menuBarComposerConfiguration = Self.loadMenuBarComposerConfiguration(
            defaults: defaults,
            mode: hydratedMenuBarDisplayMode,
            memoryFormat: hydratedMenuBarMemoryFormat,
            storageFormat: hydratedMenuBarStorageFormat
        )
        let hydratedMainPopoverDefaultWidth = Self.loadMainPopoverDefaultWidth(defaults: defaults)
        self.mainPopoverDefaultWidth = hydratedMainPopoverDefaultWidth
        self.mainPopoverCurrentWidth = hydratedMainPopoverDefaultWidth

        self.batteryPolicyConfiguration = Self.loadBatteryPolicyConfiguration(defaults: defaults)
        self.systemAlertSettings = Self.loadSystemAlertSettings(defaults: defaults)
        self.batteryAdvancedControlFeatureFlags = Self.loadBatteryAdvancedControlFeatureFlags(defaults: defaults)

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

    private static func loadSystemAlertSettings(defaults: UserDefaults) -> SystemAlertSettings {
        guard let data = defaults.data(forKey: Keys.systemAlertSettings),
              let decoded = try? JSONDecoder().decode(SystemAlertSettings.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    private static func loadBatteryAdvancedControlFeatureFlags(defaults: UserDefaults) -> BatteryAdvancedControlFeatureFlags {
        guard let data = defaults.data(forKey: Keys.batteryAdvancedControlFeatureFlags),
              let decoded = try? JSONDecoder().decode(BatteryAdvancedControlFeatureFlags.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    private static func loadMainPopoverDefaultWidth(defaults: UserDefaults) -> CGFloat {
        guard let value = defaults.object(forKey: Keys.mainPopoverDefaultWidth) as? Double else {
            return mainPopoverFallbackWidth
        }
        return normalizedMainPopoverWidth(CGFloat(value))
    }

    private static func loadMenuBarDisplayMode(defaults: UserDefaults) -> MenuBarDisplayMode {
        if let persisted = defaults.string(forKey: Keys.menuBarDisplayMode),
           let mode = MenuBarDisplayMode(rawValue: persisted) {
            if mode == .icon {
                defaults.set(MenuBarDisplayMode.both.rawValue, forKey: Keys.menuBarDisplayMode)
                return .both
            }
            return mode
        }

        if let legacyMode = defaults.string(forKey: Keys.legacyMenuBarDisplayMode) {
            switch legacyMode {
            case "ram":
                return .memory
            case "storage":
                return .storage
            case "icon":
                defaults.set(MenuBarDisplayMode.both.rawValue, forKey: Keys.menuBarDisplayMode)
                return .both
            case "battery":
                return .memory
            case "both":
                return .both
            default:
                break
            }
        }

        return .both
    }

    private static func loadMenuBarMetricFormat(
        defaults: UserDefaults,
        key: String,
        defaultFormat: MenuBarMetricDisplayFormat
    ) -> MenuBarMetricDisplayFormat {
        if let persisted = defaults.string(forKey: key),
           let format = MenuBarMetricDisplayFormat(rawValue: persisted) {
            return format
        }

        let legacyValueMode = defaults.string(forKey: Keys.legacyMenuBarMetricValueMode)
        let legacyFormat = defaults.string(forKey: Keys.legacyMenuBarMetricFormat)
        switch (legacyValueMode, legacyFormat) {
        case ("free", "number"):
            return .numberLeft
        case ("used", "number"):
            return .numberUsage
        case (_, "percent"):
            return .percentUsage
        default:
            return defaultFormat
        }
    }

    private static func loadMenuBarComposerConfiguration(
        defaults: UserDefaults,
        mode: MenuBarDisplayMode,
        memoryFormat: MenuBarMetricDisplayFormat,
        storageFormat: MenuBarMetricDisplayFormat
    ) -> MenuBarComposerConfiguration {
        if let data = defaults.data(forKey: Keys.menuBarComposerConfiguration),
           let decoded = try? JSONDecoder().decode(MenuBarComposerConfiguration.self, from: data) {
            return decoded.normalized()
        }

        return withExplicitSeparatorsIfNeeded(
            makeComposerConfigurationFromLegacySettings(
                mode: mode,
                memoryFormat: memoryFormat,
                storageFormat: storageFormat
            )
        )
    }

    private static func withExplicitSeparatorsIfNeeded(
        _ configuration: MenuBarComposerConfiguration
    ) -> MenuBarComposerConfiguration {
        let normalized = configuration.normalized()
        guard normalized.blocks.count > 1 else {
            return normalized
        }
        guard !normalized.blocks.contains(where: { $0.kind == .text }) else {
            return normalized
        }

        var expandedBlocks: [MenuBarComposerBlock] = []
        for (index, block) in normalized.blocks.enumerated() {
            if index > 0 {
                expandedBlocks.append(.text(normalized.separator))
            }
            expandedBlocks.append(block)
        }

        return MenuBarComposerConfiguration(
            separator: normalized.separator,
            blocks: expandedBlocks
        ).normalized()
    }

    private static func makeComposerConfigurationFromLegacySettings(
        mode: MenuBarDisplayMode,
        memoryFormat: MenuBarMetricDisplayFormat,
        storageFormat: MenuBarMetricDisplayFormat
    ) -> MenuBarComposerConfiguration {
        switch mode {
        case .memory:
            return MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [.metric(.memory, format: memoryFormat)]
            )
        case .storage:
            return MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [.metric(.storage, format: storageFormat)]
            )
        case .cpu:
            return MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [.metric(.cpu, format: .percentUsage)]
            )
        case .network:
            return MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [.metric(.network, format: .numberUsage)]
            )
        case .both, .icon:
            return MenuBarComposerConfiguration(
                separator: " | ",
                blocks: [
                    .metric(.memory, format: memoryFormat),
                    .text(" | "),
                    .metric(.storage, format: storageFormat)
                ]
            )
        }
    }

    static func normalizedMainPopoverWidth(_ width: CGFloat) -> CGFloat {
        guard width.isFinite else {
            return mainPopoverFallbackWidth
        }
        return min(max(width, mainPopoverMinWidth), mainPopoverMaxWidth)
    }

    func updateMainPopoverCurrentWidth(_ width: CGFloat) {
        mainPopoverCurrentWidth = Self.normalizedMainPopoverWidth(width)
    }

    func resetMainPopoverCurrentWidthToDefault() {
        mainPopoverCurrentWidth = mainPopoverDefaultWidth
    }

    func saveCurrentPopoverWidthAsDefault() {
        mainPopoverDefaultWidth = mainPopoverCurrentWidth
    }

    var hasUnsavedMainPopoverWidth: Bool {
        abs(mainPopoverCurrentWidth - mainPopoverDefaultWidth) > 0.5
    }

    private func synchronizeComposerFromLegacySettings() {
        isSyncingMenuBarLegacySettings = true
        menuBarComposerConfiguration = Self.makeComposerConfigurationFromLegacySettings(
            mode: menuBarDisplayMode,
            memoryFormat: menuBarMemoryFormat,
            storageFormat: menuBarStorageFormat
        )
        isSyncingMenuBarLegacySettings = false
    }

    private func synchronizeLegacyMenuBarSettings(from configuration: MenuBarComposerConfiguration) {
        isSyncingMenuBarLegacySettings = true
        defer { isSyncingMenuBarLegacySettings = false }

        let metricBlocks = configuration.blocks.filter { $0.isEnabled && $0.kind.isMetric }
        let nextDisplayMode = Self.derivedLegacyDisplayMode(from: metricBlocks)
        if menuBarDisplayMode != nextDisplayMode {
            menuBarDisplayMode = nextDisplayMode
        }

        if let memoryBlock = metricBlocks.first(where: { $0.kind == .memory }),
           menuBarMemoryFormat != memoryBlock.format {
            menuBarMemoryFormat = memoryBlock.format
        }

        if let storageBlock = metricBlocks.first(where: { $0.kind == .storage }),
           menuBarStorageFormat != storageBlock.format {
            menuBarStorageFormat = storageBlock.format
        }
    }

    private static func derivedLegacyDisplayMode(from metricBlocks: [MenuBarComposerBlock]) -> MenuBarDisplayMode {
        let uniqueKinds = Array(Set(metricBlocks.map(\.kind)))
        guard !uniqueKinds.isEmpty else { return .both }
        if uniqueKinds.count == 1 {
            switch uniqueKinds[0] {
            case .memory:
                return .memory
            case .storage:
                return .storage
            case .cpu:
                return .cpu
            case .network:
                return .network
            case .text:
                return .both
            }
        }
        return .both
    }

    private func persistMenuBarComposerConfiguration(_ configuration: MenuBarComposerConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.menuBarComposerConfiguration)
    }

    private func persistBatteryPolicyConfiguration(_ configuration: BatteryPolicyConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.batteryPolicyConfiguration)
    }

    private func persistSystemAlertSettings(_ configuration: SystemAlertSettings) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.systemAlertSettings)
    }

    private func persistBatteryAdvancedControlFeatureFlags(_ configuration: BatteryAdvancedControlFeatureFlags) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }
        defaults.set(data, forKey: Keys.batteryAdvancedControlFeatureFlags)
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
