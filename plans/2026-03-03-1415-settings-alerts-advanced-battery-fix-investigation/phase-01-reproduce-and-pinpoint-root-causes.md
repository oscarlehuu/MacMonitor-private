## 1) Context Links
- `./plan.md`
- `./README.md`
- `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `./MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift`
- `./MacMonitor/Sources/Core/Alerts/SystemAlertNotifier.swift`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyCoordinator.swift`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyEngine.swift`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryControlSafetyMonitor.swift`

## 2) Overview
- Priority: P1
- Current status: completed
- Description: reproduce non-working behavior and produce a root-cause matrix before touching implementation.

## 3) Key Insights
- Settings model includes more alert options than current Settings UI exposes.
- Advanced Battery UI includes toggles that may be partially deferred by design.
- No dedicated alert unit tests exist yet, increasing regression risk.

## 4) Requirements
- Functional requirements:
  - Reproduce reported failures for Alerts and Advanced Battery toggles.
  - Confirm persistence and runtime impact for each setting.
  - Produce root-cause classification: regression, unwired UI, deferred placeholder, or environment constraint.
- Non-functional requirements:
  - Keep analysis evidence-based and reproducible.
  - Avoid speculative refactors.

## 5) Architecture
- Trace graph:
  - Alerts: `PopoverRootView` -> `SettingsStore.systemAlertSettings` -> `SystemSummaryViewModel.evaluateAndNotifyAlerts` -> `SystemAlertPolicyEngine` -> `SystemAlertNotifier`.
  - Advanced Battery: `PopoverRootView` -> `SettingsStore.batteryAdvancedControlFeatureFlags` -> `BatteryPolicyCoordinator` / `BatteryPolicyEngine` / lifecycle handlers.

## 6) Related Code Files
- Modify: none (investigation only).
- Create: temporary notes in this plan folder if needed.
- Delete: none.

## 7) Implementation Steps
1. Build a settings control matrix listing every Alerts + Advanced Battery control and expected effect.
2. Verify each control is persisted correctly via `SettingsStore`.
3. Verify each persisted setting is consumed by runtime logic.
4. Reproduce non-working cases with deterministic threshold scenarios.
5. Output root-cause matrix with severity and fix recommendation.

## 8) Todo List
- [x] Create control-to-consumer mapping table.
- [x] Reproduce and log each failing behavior.
- [x] Classify each issue as bug vs deferred feature mismatch.
- [x] Confirm no hidden dependency on notification permissions/helper availability.

## 9) Success Criteria
- Every control has a clear status: works, broken, or intentionally deferred.
- Root causes are concrete enough to implement fixes without guesswork.

## 10) Risk Assessment
- Risk: false negatives due cooldown/permission state.
- Mitigation: test with cooldown-minimized setup and explicit permission state checks.

## 11) Security Considerations
- No privileged or external operations in this phase.
- Keep diagnostics local and avoid exporting sensitive data.

## 12) Next Steps
- Hand off root-cause matrix to Phase 02 for minimal fix scope finalization.
