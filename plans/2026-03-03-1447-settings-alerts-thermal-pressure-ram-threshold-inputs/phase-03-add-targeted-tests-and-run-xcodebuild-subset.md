## 1) Context Links
- `./plan.md`
- `./MacMonitor/Tests/SettingsStoreTests.swift`
- `./MacMonitor/Tests/SystemSummaryViewModelTests.swift`
- `./MacMonitor/Tests/SystemAlertPolicyEngineTests.swift` (new)

## 2) Overview
- Priority: P1
- Current status: pending
- Description: cover changed behavior with focused tests and run targeted suite only.

## 3) Key Insights
- Current coverage misses direct `SystemAlertPolicyEngine` unit tests.
- Adding policy-engine tests provides the highest-value regression shield for this change set.

## 4) Requirements
- Functional requirements:
  - Validate `SystemAlertSettings` persistence + normalization with RAM fields and new cooldown default.
  - Validate RAM alert policy behavior (trigger/no-trigger, disabled state).
  - Validate settings-change re-evaluation path still triggers notifier (`SystemSummaryViewModelTests`).
- Non-functional requirements:
  - Keep test scope targeted and deterministic.
  - Avoid brittle UI-level tests for this patch.

## 5) Architecture
- Test at unit level around settings model + policy engine + VM integration seam.

## 6) Related Code Files
- Modify:
  - `./MacMonitor/Tests/SettingsStoreTests.swift`
  - `./MacMonitor/Tests/SystemSummaryViewModelTests.swift`
- Create:
  - `./MacMonitor/Tests/SystemAlertPolicyEngineTests.swift`
- Delete:
  - none

## 7) Implementation Steps
1. Extend `SettingsStoreTests` for RAM fields + cooldown expectations + decode compatibility case.
2. Add `SystemAlertPolicyEngineTests` for thermal/storage/ram/battery and disabled paths.
3. Optionally add one `SystemSummaryViewModelTests` assertion for RAM settings change -> notifier invocation.
4. Run targeted tests:
   - `xcodegen generate`
   - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/SettingsStoreTests -only-testing:MacMonitorTests/SystemSummaryViewModelTests -only-testing:MacMonitorTests/SystemAlertPolicyEngineTests test`

## 8) Todo List
- [ ] Add/adjust `SettingsStoreTests`.
- [ ] Add `SystemAlertPolicyEngineTests`.
- [ ] Adjust `SystemSummaryViewModelTests` for RAM setting change trigger.
- [ ] Execute targeted `xcodebuild` test command.

## 9) Success Criteria
- Targeted test command passes.
- New behavior is covered without unrelated suite expansion.
- No regressions in existing alert settings paths.

## 10) Risk Assessment
- Risk: test flakes from async notifier timing.
- Mitigation: use existing `Task.yield()` pattern and deterministic collectors.

## 11) Security Considerations
- Tests only; no security surface change.

## 12) Next Steps
- If tests pass, proceed to implementation PR with a single focused commit sequence.
