import XCTest
@testable import MacMonitor

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testPersistsRefreshInterval() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.refreshInterval = .fiveMinutes

        XCTAssertEqual(defaults.integer(forKey: "settings.refreshIntervalMinutes"), 5)
    }

    func testLaunchAtLoginFailureRevertsToggleAndStoresError() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager(enabled: false, throwOnSet: true)
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.launchAtLoginEnabled = true

        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertNotNil(store.launchAtLoginError)
    }

    func testPersistsMenuBarDisplaySettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.menuBarDisplayMode = .both
        store.menuBarMemoryFormat = .numberUsage
        store.menuBarStorageFormat = .numberLeft

        XCTAssertEqual(defaults.string(forKey: "settings.menuBarDisplayMode"), "both")
        XCTAssertEqual(defaults.string(forKey: "settings.menuBarMemoryFormat"), "numberUsage")
        XCTAssertEqual(defaults.string(forKey: "settings.menuBarStorageFormat"), "numberLeft")
    }

    func testHydratesPersistedMenuBarDisplaySettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set("storage", forKey: "settings.menuBarDisplayMode")
        defaults.set("numberUsage", forKey: "settings.menuBarMemoryFormat")
        defaults.set("percentUsage", forKey: "settings.menuBarStorageFormat")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.menuBarDisplayMode, .storage)
        XCTAssertEqual(store.menuBarMemoryFormat, .numberUsage)
        XCTAssertEqual(store.menuBarStorageFormat, .percentUsage)
    }

    func testDefaultsMenuBarDisplaySettingsToBothAndPercentUsage() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.menuBarDisplayMode, .both)
        XCTAssertEqual(store.menuBarMemoryFormat, .percentUsage)
        XCTAssertEqual(store.menuBarStorageFormat, .percentUsage)
    }

    func testHydratesPersistedIconMenuBarDisplayModeAsBoth() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set("icon", forKey: "settings.menuBarDisplayMode")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.menuBarDisplayMode, .both)
        XCTAssertEqual(defaults.string(forKey: "settings.menuBarDisplayMode"), "both")
    }

    func testMigratesLegacyMenuBarFormatSettings() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set("ram", forKey: "settings.menuBarDisplayMode")
        defaults.set("free", forKey: "settings.menuBarMetricValueMode")
        defaults.set("number", forKey: "settings.menuBarMetricFormat")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.menuBarDisplayMode, .memory)
        XCTAssertEqual(store.menuBarMemoryFormat, .numberLeft)
        XCTAssertEqual(store.menuBarStorageFormat, .numberLeft)
    }

    func testSettingIconMenuBarDisplayModeNormalizesToBoth() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.menuBarDisplayMode = .icon

        XCTAssertEqual(store.menuBarDisplayMode, .both)
        XCTAssertEqual(defaults.string(forKey: "settings.menuBarDisplayMode"), "both")
    }

    func testPersistsBatteryPolicyConfiguration() throws {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 83
        config.automaticDischargeEnabled = true
        store.batteryPolicyConfiguration = config

        let persistedData = try XCTUnwrap(defaults.data(forKey: "settings.batteryPolicyConfiguration"))
        let persistedConfig = try JSONDecoder().decode(BatteryPolicyConfiguration.self, from: persistedData)

        XCTAssertEqual(persistedConfig.chargeLimitPercent, 83)
        XCTAssertTrue(persistedConfig.automaticDischargeEnabled)
    }

    func testPersistsSystemAlertSettings() throws {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var alerts = store.systemAlertSettings
        alerts.thermalAlertEnabled = false
        alerts.ramAlertEnabled = false
        alerts.ramUsagePercentThreshold = 88
        alerts.storageAlertEnabled = false
        alerts.storageUsagePercentThreshold = 85
        alerts.batteryHealthDropAlertEnabled = false
        alerts.batteryHealthDropPercentThreshold = 20
        alerts.cooldownMinutes = 30
        alerts.exceededThresholdHighlightColor = 0xBF5AF2
        store.systemAlertSettings = alerts

        let persistedData = try XCTUnwrap(defaults.data(forKey: "settings.systemAlertSettings"))
        let persistedSettings = try JSONDecoder().decode(SystemAlertSettings.self, from: persistedData)

        XCTAssertFalse(persistedSettings.thermalAlertEnabled)
        XCTAssertFalse(persistedSettings.ramAlertEnabled)
        XCTAssertEqual(persistedSettings.ramUsagePercentThreshold, 88)
        XCTAssertFalse(persistedSettings.storageAlertEnabled)
        XCTAssertEqual(persistedSettings.storageUsagePercentThreshold, 85)
        XCTAssertFalse(persistedSettings.batteryHealthDropAlertEnabled)
        XCTAssertEqual(persistedSettings.batteryHealthDropPercentThreshold, 20)
        XCTAssertEqual(persistedSettings.cooldownMinutes, 30)
        XCTAssertEqual(persistedSettings.exceededThresholdHighlightColor, 0xBF5AF2)
    }

    func testHydratesLegacySystemAlertSettingsWithoutRAMFields() throws {
        struct LegacySystemAlertSettings: Codable {
            let thermalAlertEnabled: Bool
            let thermalThreshold: ThermalState
            let storageAlertEnabled: Bool
            let storageUsagePercentThreshold: Int
            let batteryHealthDropAlertEnabled: Bool
            let batteryHealthDropPercentThreshold: Int
            let cooldownMinutes: Int
        }

        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let legacy = LegacySystemAlertSettings(
            thermalAlertEnabled: false,
            thermalThreshold: .critical,
            storageAlertEnabled: true,
            storageUsagePercentThreshold: 86,
            batteryHealthDropAlertEnabled: false,
            batteryHealthDropPercentThreshold: 25,
            cooldownMinutes: 120
        )
        let legacyData = try JSONEncoder().encode(legacy)
        defaults.set(legacyData, forKey: "settings.systemAlertSettings")

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertFalse(store.systemAlertSettings.thermalAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.thermalThreshold, .critical)
        XCTAssertTrue(store.systemAlertSettings.storageAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.storageUsagePercentThreshold, 86)
        XCTAssertFalse(store.systemAlertSettings.batteryHealthDropAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.batteryHealthDropPercentThreshold, 25)
        XCTAssertEqual(store.systemAlertSettings.cooldownMinutes, 30)
        XCTAssertEqual(store.systemAlertSettings.ramAlertEnabled, SystemAlertSettings.default.ramAlertEnabled)
        XCTAssertEqual(
            store.systemAlertSettings.ramUsagePercentThreshold,
            SystemAlertSettings.default.ramUsagePercentThreshold
        )
        XCTAssertEqual(
            store.systemAlertSettings.exceededThresholdHighlightColor,
            SystemAlertSettings.default.exceededThresholdHighlightColor
        )
    }

    func testHydratesPersistedSystemAlertHighlightColor() throws {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        var alerts = SystemAlertSettings.default
        alerts.exceededThresholdHighlightColor = 0xFF453A
        defaults.set(try JSONEncoder().encode(alerts), forKey: "settings.systemAlertSettings")

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.systemAlertSettings.exceededThresholdHighlightColor, 0xFF453A)
    }

    func testHydratesLegacyPresetStringSystemAlertHighlightColor() throws {
        struct LegacyPresetColorSystemAlertSettings: Codable {
            let thermalAlertEnabled: Bool
            let thermalThreshold: ThermalState
            let ramAlertEnabled: Bool
            let ramUsagePercentThreshold: Int
            let storageAlertEnabled: Bool
            let storageUsagePercentThreshold: Int
            let batteryHealthDropAlertEnabled: Bool
            let batteryHealthDropPercentThreshold: Int
            let cooldownMinutes: Int
            let exceededThresholdHighlightColor: String
        }

        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let payload = LegacyPresetColorSystemAlertSettings(
            thermalAlertEnabled: true,
            thermalThreshold: .serious,
            ramAlertEnabled: true,
            ramUsagePercentThreshold: 90,
            storageAlertEnabled: true,
            storageUsagePercentThreshold: 90,
            batteryHealthDropAlertEnabled: true,
            batteryHealthDropPercentThreshold: 15,
            cooldownMinutes: 15,
            exceededThresholdHighlightColor: "purple"
        )
        defaults.set(try JSONEncoder().encode(payload), forKey: "settings.systemAlertSettings")

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.systemAlertSettings.exceededThresholdHighlightColor, 0xBF5AF2)
    }

    func testHydratesInvalidPersistedSystemAlertHighlightColorUsingDefaultWithoutResettingOtherFields() throws {
        struct InvalidColorSystemAlertSettings: Codable {
            let thermalAlertEnabled: Bool
            let thermalThreshold: ThermalState
            let ramAlertEnabled: Bool
            let ramUsagePercentThreshold: Int
            let storageAlertEnabled: Bool
            let storageUsagePercentThreshold: Int
            let batteryHealthDropAlertEnabled: Bool
            let batteryHealthDropPercentThreshold: Int
            let cooldownMinutes: Int
            let exceededThresholdHighlightColor: String
        }

        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let payload = InvalidColorSystemAlertSettings(
            thermalAlertEnabled: false,
            thermalThreshold: .critical,
            ramAlertEnabled: false,
            ramUsagePercentThreshold: 93,
            storageAlertEnabled: false,
            storageUsagePercentThreshold: 94,
            batteryHealthDropAlertEnabled: false,
            batteryHealthDropPercentThreshold: 20,
            cooldownMinutes: 25,
            exceededThresholdHighlightColor: "unknown-color"
        )
        defaults.set(try JSONEncoder().encode(payload), forKey: "settings.systemAlertSettings")

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertFalse(store.systemAlertSettings.thermalAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.thermalThreshold, .critical)
        XCTAssertFalse(store.systemAlertSettings.ramAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.ramUsagePercentThreshold, 93)
        XCTAssertFalse(store.systemAlertSettings.storageAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.storageUsagePercentThreshold, 94)
        XCTAssertFalse(store.systemAlertSettings.batteryHealthDropAlertEnabled)
        XCTAssertEqual(store.systemAlertSettings.batteryHealthDropPercentThreshold, 20)
        XCTAssertEqual(store.systemAlertSettings.cooldownMinutes, 25)
        XCTAssertEqual(
            store.systemAlertSettings.exceededThresholdHighlightColor,
            SystemAlertSettings.default.exceededThresholdHighlightColor
        )
    }

    func testHydratesOversizedPersistedSystemAlertHighlightColorUsingDefault() throws {
        struct OversizedColorSystemAlertSettings: Codable {
            let thermalAlertEnabled: Bool
            let thermalThreshold: ThermalState
            let ramAlertEnabled: Bool
            let ramUsagePercentThreshold: Int
            let storageAlertEnabled: Bool
            let storageUsagePercentThreshold: Int
            let batteryHealthDropAlertEnabled: Bool
            let batteryHealthDropPercentThreshold: Int
            let cooldownMinutes: Int
            let exceededThresholdHighlightColor: Int
        }

        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let payload = OversizedColorSystemAlertSettings(
            thermalAlertEnabled: true,
            thermalThreshold: .serious,
            ramAlertEnabled: true,
            ramUsagePercentThreshold: 90,
            storageAlertEnabled: true,
            storageUsagePercentThreshold: 90,
            batteryHealthDropAlertEnabled: true,
            batteryHealthDropPercentThreshold: 15,
            cooldownMinutes: 15,
            exceededThresholdHighlightColor: 5_000_000_000
        )
        defaults.set(try JSONEncoder().encode(payload), forKey: "settings.systemAlertSettings")

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(
            store.systemAlertSettings.exceededThresholdHighlightColor,
            SystemAlertSettings.default.exceededThresholdHighlightColor
        )
    }

    func testNormalizesSystemAlertThresholdAndCooldownBounds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var alerts = store.systemAlertSettings
        alerts.ramUsagePercentThreshold = 20
        alerts.storageUsagePercentThreshold = 120
        alerts.batteryHealthDropPercentThreshold = 2
        alerts.cooldownMinutes = 120
        store.systemAlertSettings = alerts

        XCTAssertEqual(store.systemAlertSettings.ramUsagePercentThreshold, 60)
        XCTAssertEqual(store.systemAlertSettings.storageUsagePercentThreshold, 99)
        XCTAssertEqual(store.systemAlertSettings.batteryHealthDropPercentThreshold, 5)
        XCTAssertEqual(store.systemAlertSettings.cooldownMinutes, 30)
    }

    func testPersistsBatteryAdvancedControlFeatureFlags() throws {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var flags = store.batteryAdvancedControlFeatureFlags
        flags.sleepAwareStopChargingEnabled = true
        flags.blockSleepUntilLimitEnabled = true
        flags.calibrationWorkflowEnabled = true
        flags.hardwarePercentageRefinementEnabled = true
        flags.magsafeLEDControlEnabled = true
        store.batteryAdvancedControlFeatureFlags = flags

        let persistedData = try XCTUnwrap(defaults.data(forKey: "settings.batteryAdvancedControlFeatureFlags"))
        let persistedFlags = try JSONDecoder().decode(BatteryAdvancedControlFeatureFlags.self, from: persistedData)

        XCTAssertTrue(persistedFlags.sleepAwareStopChargingEnabled)
        XCTAssertTrue(persistedFlags.blockSleepUntilLimitEnabled)
        XCTAssertFalse(persistedFlags.calibrationWorkflowEnabled)
        XCTAssertTrue(persistedFlags.hardwarePercentageRefinementEnabled)
        XCTAssertFalse(persistedFlags.magsafeLEDControlEnabled)
    }

    func testNormalizesBatteryPolicyConfigurationBounds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var config = BatteryPolicyConfiguration.default
        config.chargeLimitPercent = 20
        config.sailingLowerPercent = 99
        config.sailingUpperPercent = 40
        config.heatProtectionThresholdCelsius = 90

        store.batteryPolicyConfiguration = config

        XCTAssertEqual(store.batteryPolicyConfiguration.chargeLimitPercent, 50)
        XCTAssertEqual(store.batteryPolicyConfiguration.sailingLowerPercent, 50)
        XCTAssertEqual(store.batteryPolicyConfiguration.sailingUpperPercent, 95)
        XCTAssertEqual(store.batteryPolicyConfiguration.heatProtectionThresholdCelsius, 55)
    }

    func testNormalizesBatteryPolicyConfigurationDischargeMutualExclusion() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        var config = BatteryPolicyConfiguration.default
        config.manualDischargeEnabled = true
        config.automaticDischargeEnabled = true

        store.batteryPolicyConfiguration = config

        XCTAssertTrue(store.batteryPolicyConfiguration.manualDischargeEnabled)
        XCTAssertFalse(store.batteryPolicyConfiguration.automaticDischargeEnabled)
    }

    func testHydratesMainPopoverWidthFromPersistedDefault() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set(612.0, forKey: "settings.mainPopoverDefaultWidth")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.mainPopoverDefaultWidth, 612, accuracy: 0.001)
        XCTAssertEqual(store.mainPopoverCurrentWidth, 612, accuracy: 0.001)
    }

    func testMainPopoverWidthUpdateIsClampedToSafeBounds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.updateMainPopoverCurrentWidth(SettingsStore.mainPopoverMaxWidth + 200)
        XCTAssertEqual(store.mainPopoverCurrentWidth, SettingsStore.mainPopoverMaxWidth, accuracy: 0.001)

        store.updateMainPopoverCurrentWidth(SettingsStore.mainPopoverMinWidth - 200)
        XCTAssertEqual(store.mainPopoverCurrentWidth, SettingsStore.mainPopoverMinWidth, accuracy: 0.001)
    }

    func testSaveCurrentPopoverWidthAsDefaultPersistsValue() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        store.updateMainPopoverCurrentWidth(598)
        store.saveCurrentPopoverWidthAsDefault()

        XCTAssertEqual(store.mainPopoverDefaultWidth, 598, accuracy: 0.001)
        XCTAssertEqual(defaults.double(forKey: "settings.mainPopoverDefaultWidth"), 598, accuracy: 0.001)
    }

    func testMainPopoverWidthFallsBackWhenNoPersistedValue() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.mainPopoverDefaultWidth, SettingsStore.mainPopoverFallbackWidth, accuracy: 0.001)
        XCTAssertEqual(store.mainPopoverCurrentWidth, SettingsStore.mainPopoverFallbackWidth, accuracy: 0.001)
    }

    func testMainPopoverWidthFallsBackWhenPersistedValueIsNaN() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set(Double.nan, forKey: "settings.mainPopoverDefaultWidth")
        let manager = MutableLaunchManager()

        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertEqual(store.mainPopoverDefaultWidth, SettingsStore.mainPopoverFallbackWidth, accuracy: 0.001)
        XCTAssertEqual(store.mainPopoverCurrentWidth, SettingsStore.mainPopoverFallbackWidth, accuracy: 0.001)
    }

    func testMainPopoverUnsavedWidthFlagTracksCurrentVsDefault() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let manager = MutableLaunchManager()
        let store = SettingsStore(defaults: defaults, launchAtLoginManager: manager)

        XCTAssertFalse(store.hasUnsavedMainPopoverWidth)

        store.updateMainPopoverCurrentWidth(store.mainPopoverDefaultWidth + 0.4)
        XCTAssertFalse(store.hasUnsavedMainPopoverWidth)

        store.updateMainPopoverCurrentWidth(store.mainPopoverDefaultWidth + 1)
        XCTAssertTrue(store.hasUnsavedMainPopoverWidth)
    }
}

private final class MutableLaunchManager: LaunchAtLoginManaging {
    private(set) var enabled: Bool
    private let throwOnSet: Bool

    init(enabled: Bool = false, throwOnSet: Bool = false) {
        self.enabled = enabled
        self.throwOnSet = throwOnSet
    }

    func isEnabled() -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if throwOnSet {
            throw TestError.toggleFailed
        }
        self.enabled = enabled
    }
}

private enum TestError: Error {
    case toggleFailed
}
