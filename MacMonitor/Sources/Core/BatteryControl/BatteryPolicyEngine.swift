import Foundation

struct BatteryPolicyEngine {
    func evaluate(snapshot: BatterySnapshot, configuration: BatteryPolicyConfiguration) -> BatteryPolicyDecision {
        let config = configuration.normalized()

        guard snapshot.isPresent else {
            return BatteryPolicyDecision(
                state: .unavailable,
                command: nil,
                reason: "No internal battery detected."
            )
        }

        guard let currentPercent = snapshot.percentage else {
            return BatteryPolicyDecision(
                state: .unavailable,
                command: nil,
                reason: "Battery percentage unavailable."
            )
        }

        // Priority 1: heat safety has top precedence.
        if config.heatProtectionEnabled,
           snapshot.isCharging,
           let temperature = snapshot.temperatureCelsius,
           temperature >= config.heatProtectionThresholdCelsius {
            return BatteryPolicyDecision(
                state: .heatProtection,
                command: .setChargingPaused(true),
                reason: "Heat protection threshold reached."
            )
        }

        // Priority 2: top up temporarily overrides all normal limits.
        if config.topUpEnabled {
            if currentPercent < 100 {
                return BatteryPolicyDecision(
                    state: .topUp,
                    command: .startTopUp,
                    reason: "Top Up enabled and battery below 100%."
                )
            }
            return BatteryPolicyDecision(
                state: .topUp,
                command: nil,
                reason: "Top Up already fulfilled at 100%."
            )
        }

        // Priority 3: manual discharge request.
        if config.manualDischargeEnabled {
            if currentPercent > config.chargeLimitPercent {
                return BatteryPolicyDecision(
                    state: .dischargingToLimit,
                    command: .startDischarge(targetPercent: config.chargeLimitPercent),
                    reason: "Manual discharge requested above charge limit."
                )
            }
            return BatteryPolicyDecision(
                state: .pausedAtLimit,
                command: .setChargingPaused(true),
                reason: "Manual discharge completed at or below charge limit."
            )
        }

        // Priority 4: automatic discharge.
        if config.automaticDischargeEnabled, currentPercent > config.chargeLimitPercent {
            return BatteryPolicyDecision(
                state: .dischargingToLimit,
                command: .startDischarge(targetPercent: config.chargeLimitPercent),
                reason: "Automatic discharge enabled above charge limit."
            )
        }

        // Priority 5: sailing mode keeps battery in configured range.
        if config.sailingModeEnabled {
            if currentPercent >= config.sailingUpperPercent {
                return BatteryPolicyDecision(
                    state: .sailing,
                    command: .startDischarge(targetPercent: config.sailingLowerPercent),
                    reason: "Sailing mode discharging from upper bound to lower bound."
                )
            }
            if currentPercent <= config.sailingLowerPercent {
                return BatteryPolicyDecision(
                    state: .chargingToLimit,
                    command: .setChargeLimit(config.sailingUpperPercent),
                    reason: "Sailing mode charging from lower bound to upper bound."
                )
            }
            return BatteryPolicyDecision(
                state: .sailing,
                command: nil,
                reason: "Sailing mode in stable range."
            )
        }

        // Priority 6: steady-state charge limiter.
        if currentPercent < config.chargeLimitPercent {
            return BatteryPolicyDecision(
                state: .chargingToLimit,
                command: .setChargeLimit(config.chargeLimitPercent),
                reason: "Charging up to configured charge limit."
            )
        }

        if currentPercent > config.chargeLimitPercent {
            return BatteryPolicyDecision(
                state: .pausedAtLimit,
                command: .setChargingPaused(true),
                reason: "Above charge limit; pause charging."
            )
        }

        return BatteryPolicyDecision(
            state: .pausedAtLimit,
            command: nil,
            reason: "Exactly at charge limit."
        )
    }
}
