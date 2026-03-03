## 1) Context Links
- `./plan.md`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `./MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift`
- `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`

## 2) Overview
- Priority: P1
- Current status: pending
- Description: add RAM alert config and evaluate RAM alerts in existing policy engine.

## 3) Key Insights
- `SystemAlertSettings` is persisted JSON; adding non-optional fields needs compatible decoding.
- Existing alert flow already supports additional kinds with minimal changes.

## 4) Requirements
- Functional requirements:
  - Add `ramAlertEnabled` + `ramUsagePercentThreshold` to `SystemAlertSettings`.
  - Add RAM alert rule in `SystemAlertPolicyEngine.evaluate(...)` using `snapshot.memory.usageRatio * 100`.
  - Include `.ram` in `SystemAlertKind`.
  - Keep cooldown and existing alert kinds working unchanged.
- Non-functional requirements:
  - Preserve existing users’ stored alert settings where possible.
  - Keep code localized; no new services.

## 5) Architecture
- Keep pipeline unchanged:
  - Settings persistence in `SettingsStore`
  - Rule evaluation in `SystemAlertPolicyEngine`
  - Trigger path in `SystemSummaryViewModel` (already reevaluates on settings change)

## 6) Related Code Files
- Modify:
  - `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
  - `./MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift`
- Create:
  - none in this phase
- Delete:
  - none

## 7) Implementation Steps
1. Extend `SystemAlertSettings` with RAM fields and defaults.
2. Update `normalized()` to clamp RAM threshold (`60...99`) and apply new cooldown default (`15`).
3. Add backward-compatible decoding path (decode missing RAM keys with defaults).
4. Add `SystemAlertKind.ram`.
5. Add RAM alert branch in policy engine with title/message aligned to existing style.
6. Confirm `SystemSummaryViewModel` needs no structural changes.

## 8) Todo List
- [ ] Add RAM fields/defaults/normalization.
- [ ] Add compatibility-safe decode behavior.
- [ ] Add RAM policy evaluation and alert kind.

## 9) Success Criteria
- RAM alert can be enabled/disabled via settings model.
- RAM alert triggers only when memory usage crosses configured threshold.
- Existing thermal/storage/battery alert behavior remains intact.

## 10) Risk Assessment
- Risk: decode regression resets stored alerts.
- Mitigation: explicit decode fallback per new key + tests.

## 11) Security Considerations
- No new permissions, network calls, or privileged actions.
- Alert messages remain local app notifications.

## 12) Next Steps
- Implement Settings UI controls in Phase 02.
