## 1) Context Links
- `./plan.md`
- `./phase-01-reproduce-and-pinpoint-root-causes.md`
- `./phase-02-minimal-fix-design-and-implementation-plan.md`
- `./README.md`
- `./MacMonitor/Tests/SettingsStoreTests.swift`
- `./MacMonitor/Tests/BatteryPolicyCoordinatorTests.swift`
- `./MacMonitor/Tests/BatteryPolicyEngineTests.swift`

## 2) Overview
- Priority: P1
- Current status: in progress
- Description: verify fixes with automated and manual checks before merge.

## 3) Key Insights
- Alert behavior can appear broken if notification permission/cooldown context is uncontrolled.
- Advanced battery behavior depends on lifecycle and helper state, so manual verification is required.

## 4) Requirements
- Functional requirements:
  - Build succeeds.
  - Relevant unit tests pass.
  - Alerts and Advanced Battery controls behave as documented in Settings.
- Non-functional requirements:
  - No regression in existing battery policy and Settings persistence tests.
  - Validation steps are repeatable by another developer.

## 5) Architecture
- Validation layers:
  - Unit: settings persistence, alert policy/notifier, battery policy/flags.
  - Integration-manual: popover settings actions + observed runtime effects.

## 6) Related Code Files
- Modify:
  - test files affected by Phase 02 changes.
- Create:
  - test files introduced in Phase 02.
- Delete:
  - none

## 7) Implementation Steps
1. Run project generation and full tests.
2. Run targeted tests for changed alert/advanced battery logic while iterating.
3. Perform manual checklists for each fixed control.
4. Capture concise verification notes in PR description.

## 8) Todo List
- [x] `xcodegen generate`
- [x] `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- [ ] Manual Alerts verification (threshold + cooldown + notification visible).
- [ ] Manual Advanced Battery verification (lifecycle and policy reactions).
- [x] Regression sweep of existing Settings and battery tests.

## 9) Success Criteria
- All required tests pass.
- Reproduced failures from Phase 01 are closed.
- No new critical warnings/errors in runtime logs for these feature paths.

## 10) Risk Assessment
- Risk: flaky manual lifecycle testing around sleep/wake.
- Mitigation: run repeated deterministic scenarios and document exact test setup.

## 11) Security Considerations
- Ensure no new privileged path bypasses helper availability checks.
- Keep notification permissions scoped to macOS local alerts.

## 12) Next Steps
- Merge after validation evidence is complete and unresolved questions are answered.
