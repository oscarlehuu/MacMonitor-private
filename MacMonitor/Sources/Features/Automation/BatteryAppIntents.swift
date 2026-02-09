import AppIntents
import Foundation

struct SetBatteryChargeLimitIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Battery Charge Limit"
    static let description = IntentDescription("Set MacMonitor battery charge limit between 50% and 95%.")

    @Parameter(title: "Charge Limit (%)")
    var chargeLimit: Int

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard (50...95).contains(chargeLimit) else {
            return .result(value: "Charge limit must be between 50 and 95 percent.")
        }

        let response = await BatteryIntentBridge.shared.perform(.setChargeLimit(chargeLimit))
        return .result(value: response.message)
    }
}

struct PauseBatteryChargingIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Battery Charging"
    static let description = IntentDescription("Pause charging immediately.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await BatteryIntentBridge.shared.perform(.pauseCharging)
        return .result(value: response.message)
    }
}

struct StartBatteryTopUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Battery Top Up"
    static let description = IntentDescription("Temporarily charge battery to full.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await BatteryIntentBridge.shared.perform(.startTopUp)
        return .result(value: response.message)
    }
}

struct StartBatteryDischargeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Battery Discharge"
    static let description = IntentDescription("Discharge battery down to a target between 50% and 95%.")

    @Parameter(title: "Target (%)")
    var targetPercent: Int

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard (50...95).contains(targetPercent) else {
            return .result(value: "Target must be between 50 and 95 percent.")
        }

        let response = await BatteryIntentBridge.shared.perform(.startDischarge(targetPercent))
        return .result(value: response.message)
    }
}

struct GetBatteryControlStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Battery Control State"
    static let description = IntentDescription("Return current battery control state and diagnostics.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = await BatteryIntentBridge.shared.perform(.getState)
        return .result(value: response.message)
    }
}

struct BatteryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetBatteryChargeLimitIntent(),
            phrases: [
                "Set \(.applicationName) battery limit",
                "Adjust battery limit in \(.applicationName)"
            ],
            shortTitle: "Set Limit",
            systemImageName: "battery.75"
        )

        AppShortcut(
            intent: PauseBatteryChargingIntent(),
            phrases: [
                "Pause charging with \(.applicationName)",
                "Pause battery charging in \(.applicationName)"
            ],
            shortTitle: "Pause Charging",
            systemImageName: "pause.circle"
        )

        AppShortcut(
            intent: StartBatteryTopUpIntent(),
            phrases: [
                "Top up battery with \(.applicationName)",
                "Start battery top up in \(.applicationName)"
            ],
            shortTitle: "Top Up",
            systemImageName: "arrow.up.circle"
        )

        AppShortcut(
            intent: StartBatteryDischargeIntent(),
            phrases: [
                "Start battery discharge with \(.applicationName)",
                "Discharge battery in \(.applicationName)"
            ],
            shortTitle: "Discharge",
            systemImageName: "arrow.down.circle"
        )

        AppShortcut(
            intent: GetBatteryControlStateIntent(),
            phrases: [
                "Get battery state from \(.applicationName)",
                "Check battery state in \(.applicationName)"
            ],
            shortTitle: "Battery State",
            systemImageName: "battery.100"
        )
    }
}
