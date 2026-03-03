## 1) Context Links
- `./plan.md`
- `./phase-01-reproduce-and-pinpoint-root-causes.md`
- `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `./MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `./MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift`
- `./MacMonitor/Sources/Core/Alerts/SystemAlertNotifier.swift`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyCoordinator.swift`
- `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyEngine.swift`

## 2) Overview
- Priority: P1
- Current status: completed
- Description: define minimal code changes that make Settings controls truthful and functional.

## 3) Key Insights
- Fastest safe path is aligning UI controls with currently implemented behavior.
- If a feature remains deferred, UI must not present it as fully operational.
- Alerts reliability needs both wiring correctness and cooldown/notification clarity.

## 4) Requirements
- Functional requirements:
  - Alerts settings controls must map 1:1 to `SystemAlertSettings` fields that are intended in current scope.
  - Advanced Battery controls must only expose options that have real runtime effect, or explicitly mark unavailable.
  - Persistence and runtime behavior must remain backward compatible with existing defaults.
- Non-functional requirements:
  - Keep diffs small and localized.
  - Preserve existing settings card style and interaction patterns.

## 5) Architecture
- Keep current architecture; apply targeted updates:
  - UI binding fixes in `PopoverRootView`.
  - Optional lightweight notifier/policy adjustments if Phase 01 confirms gaps.
  - No new services, no cross-module redesign.

## 6) Related Code Files
- Modify (expected):
  - `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
  - `./MacMonitor/Sources/Core/Alerts/SystemAlertNotifier.swift` (only if root-cause confirms notifier issue)
  - `./MacMonitor/Sources/Core/BatteryControl/BatteryPolicyCoordinator.swift` (only if root-cause confirms unwired flag path)
- Create (expected):
  - `./MacMonitor/Tests/SystemAlertPolicyEngineTests.swift`
  - `./MacMonitor/Tests/SystemAlertNotifierTests.swift` (if notifier logic changes)
- Delete:
  - none

## 7) Implementation Steps
1. Convert Phase 01 matrix into a minimal fix list with issue IDs and acceptance criteria.
2. Patch Alerts Settings controls to match intended model fields and behavior.
3. Patch Advanced Battery Settings to avoid dead toggles (wire or explicitly unavailable).
4. Keep any deferred features out of active controls until implemented.
5. Update/add tests only for changed behaviors.

## 8) Todo List
- [x] Freeze fix scope to confirmed root causes.
- [x] Implement UI/logic alignment changes.
- [x] Add targeted unit tests for new/changed behavior.
- [x] Re-check persistence migration behavior.

## 9) Success Criteria
- No Settings control in these sections is misleading or non-functional.
- Runtime behavior matches what Settings presents.
- Existing battery control/alert behavior is not regressed.

## 10) Risk Assessment
- Risk: changing visibility of toggles may confuse existing users.
- Mitigation: use clear labels/help text and preserve persisted values where safe.

## 11) Security Considerations
- Notification flow remains local-only.
- Advanced battery actions continue to respect helper availability and safety monitor behavior.

## 12) Next Steps
- Execute full validation matrix in Phase 03.
