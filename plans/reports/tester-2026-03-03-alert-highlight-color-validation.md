# QA Validation Report - Alerts Highlight Color (2026-03-03)

## Test Results Overview
- Scope: recent feature "user-selectable exceeded-threshold highlight color" in Alerts header, applied to Trends + Menu Bar.
- Targeted run: `SettingsStoreTests`.
  - Result: pass
  - Executed: 19
  - Passed: 19
  - Failed: 0
  - Skipped: 0 (none reported)
- Full suite run: `MacMonitor` scheme tests.
  - Result: pass
  - Executed: 152
  - Passed: 152
  - Failed: 0
  - Skipped: 0 (none reported)
- Combined executions in this validation session: 171 test executions, 0 failures.

## Coverage Metrics
- Coverage source: `xccov` from full-suite `.xcresult`.
- Line coverage (targets):
  - `MacMonitor.app`: 19.96% (4823/24163)
  - `MacMonitorTests.xctest`: 98.94% (4571/4620)
  - `MacMonitorWidget.appex`: 0.00% (0/233)
  - `com.oscar.macmonitor.battery-helper`: 0.00% (0/593)
- Line coverage (feature-relevant files in app target):
  - `SettingsStore.swift`: 71.46% (288/403)
  - `TrendsView.swift`: 5.07% (22/434)
  - `MenuBarController.swift`: 0.00% (0/344)
  - `PopoverRootView.swift`: 0.35% (19/5419)
- Branch coverage: N/A (not emitted by current `xccov` report format).
- Function coverage: N/A (not emitted as aggregate metric by current `xccov` report format).

## Failed Tests
- None.

## Performance Metrics
- Targeted run (`SettingsStoreTests`):
  - Test execution: 0.040s
  - Total elapsed: 1.171s
- Full suite (`MacMonitor`):
  - Test execution: 1.810s
  - Total elapsed: 3.082s
- Slowest tests observed (>=0.100s):
  - `BatteryScheduleCoordinatorTests.testStartupExecutesDueTasksAndPersistsFutureTasks` 0.109s
  - `BatteryPolicyCoordinatorTests.testPauseChargingClearsTopUpAndManualDischarge` 0.108s
  - `BatteryScheduleViewModelTests.testScheduleDraftTaskRejectsTimeTooSoon` 0.106s
  - `BatteryScheduleViewModelTests.testLastFailureReasonTracksMostRecentFailedEvent` 0.106s
  - `RunningAppPreflightCoordinatorTests.testGracefulPreflightReturnsNotRunningWhenAppAlreadyClosed` 0.105s

## Build Status
- `xcodebuild ... test` status: success.
- Warnings/log notes seen during run:
  - Destination warning (multiple matching macOS destinations arm64/x86_64).
  - Sparkle runtime warning: background update checks without gentle reminders.
  - Storage tests emitted environment log noise around `/private/var/db/DetachedSignatures` and scoped bookmark creation for missing paths.
- No compile or link failures.

## Feature Wiring Validation (Static Check)
- `SettingsStore.swift`: added persisted `exceededThresholdHighlightColor` with decode fallback to default; legacy compatibility path present.
- `PopoverRootView.swift`: Alerts header shows inline Highlight selector and updates `settings.systemAlertSettings.exceededThresholdHighlightColor`.
- `TrendsView.swift`: inline alert value/icon use selected highlight color mapping.
- `MenuBarController.swift`: highlighted exceeded ranges use selected highlight color mapping.
- `SettingsStoreTests.swift`: includes persistence + hydration + legacy default behavior checks for highlight color.

## Critical Issues
- None blocking release for this feature.

## Recommendations
1. Add focused unit test for Menu Bar highlight-color mapping path in `MenuBarController` (currently uncovered at line level).
2. Add focused UI/view test or snapshot for Trends inline alert color + Alerts header selector behavior.
3. Consider enabling coverage gates per target/module, not only test target.

## Next Steps
1. Keep this feature green by adding one regression test for Menu Bar color mapping.
2. Add one UI regression test for Trends highlight color propagation from settings.
3. Re-run full suite after those tests to raise relevant app-target coverage.

## Unresolved Questions
- None.
