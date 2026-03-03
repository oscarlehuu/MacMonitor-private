# Focused QA Report: Alerts Header ColorPicker + Highlight Label Removal

Date: 2026-03-03
Scope (only validated):
- MacMonitor/Sources/Features/Settings/SettingsStore.swift
- MacMonitor/Sources/Features/Popover/PopoverRootView.swift
- MacMonitor/Sources/Features/Trends/TrendsView.swift
- MacMonitor/Sources/Features/MenuBar/MenuBarController.swift
- MacMonitor/Tests/SettingsStoreTests.swift
- MacMonitor/Tests/SystemSummaryViewModelTests.swift

## Test Results Overview
- Build check: passed (`xcodebuild ... build`)
- Focused tests: passed
  - `SettingsStoreTests`: 21 passed, 0 failed
  - `SystemSummaryViewModelTests`: 7 passed, 0 failed
- Adjacent focused tests: passed
  - `MenuBarDisplayFormatterTests`: 11 passed, 0 failed
- Aggregate executed in this validation run-set: 39 passed, 0 failed, 0 skipped
- Flake check: repeated focused run once (28 tests), all passed again

## Coverage Metrics
Source: `xcrun xccov view --report` on focused xcresult
- App line coverage (focused run): 6.31% (1516/24038)
- Changed-file line coverage:
  - `SettingsStore.swift`: 76.14% (316/415)
  - `SystemSummaryViewModel.swift`: 52.33% (146/279)
  - `TrendsView.swift`: 5.23% (22/421)
  - `MenuBarController.swift`: 0.00% (0/338)
  - `PopoverRootView.swift`: 0.36% (19/5267)
- Branch coverage: N/A from `xccov` report output in this run
- Function coverage: N/A from `xccov` report output in this run

## Failed Tests
- None

## Performance Metrics
- Focused suite runtime: 0.059s test execution (`xcodebuild` elapsed 1.392s)
- Adjacent suite runtime: 0.009s test execution (`xcodebuild` elapsed 1.149s)
- Flake rerun runtime: 0.060s test execution (`xcodebuild` elapsed 1.245s)
- Slow tests observed: none in focused scope

## Build Status
- Status: success
- Build warnings/errors: none from compile step
- Test-time warning observed (non-blocking): Sparkle "gentle reminders" warning logged during app launch in test runs

## Critical Issues
- None blocking found for requested change behavior.

## Behavioral Validation Notes
- Alerts header now uses icon + color control without separate `"Highlight"` text label in header row.
- Header color control uses free `ColorPicker` path and writes selected sRGB hex into `systemAlertSettings.exceededThresholdHighlightColor`.
- Highlight color is consumed by trends inline alert values and menu bar attributed title highlight rendering.
- Settings hydration tests cover legacy preset string, persisted numeric hex, invalid color fallback.

## Risks
- UI regression risk remains for label removal because no UI/snapshot assertion checks the Alerts header text content.
- `PopoverRootView.swift` and `MenuBarController.swift` runtime coverage is near-zero in focused tests; color picker interaction and menu-bar paint path are mostly untested by automation.
- `colorHexValue(from:)` silently ignores update if color space conversion fails (`nil` path); no direct unit test on this conversion helper.
- Same files contain broad concurrent edits outside this feature; focused tests do not guarantee no regression from unrelated hunks.

## Recommendations
1. Add a focused UI test/snapshot for Settings > Alerts header asserting no visible `"Highlight"` label and presence of color control.
2. Add unit/integration test for ColorPicker-to-hex persistence roundtrip (select arbitrary non-preset color, relaunch store, assert same hex).
3. Add test coverage for `MenuBarController` attributed highlight color application using a mocked snapshot/settings state.

## Next Steps
1. If this change is ready to merge, run one full `MacMonitor` test pass before merge due wide unrelated edits in same files.
2. If staying focused only, at minimum add one UI assertion test for the header label removal.

## Unresolved Questions
- Do we need strict UI-level guarantee (snapshot/UI test) for the removed `"Highlight"` label before merge?
- Is ignoring non-sRGB-convertible `Color` selections acceptable product behavior, or should we fallback to previous color with user feedback?
