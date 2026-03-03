# Phase 02: Apply Selected Highlight Color in Trends and Menu Bar

## Context Links
- Plan: [plan.md](./plan.md)
- Trends UI: [TrendsView.swift](../../MacMonitor/Sources/Features/Trends/TrendsView.swift)
- Menu Bar rendering: [MenuBarController.swift](../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)
- Persistence tests: [SettingsStoreTests.swift](../../MacMonitor/Tests/SettingsStoreTests.swift)

## Overview
- Priority: P2
- Status: Completed
- Goal: Use the configured alert highlight color consistently wherever exceeded-threshold values are highlighted.

## Key Insights
- Trends highlight currently hardcoded to `PopoverTheme.orange` for top-right value and info icon.
- Menu Bar highlight currently hardcoded to `NSColor.systemYellow` for attributed ranges.

## Requirements
- Functional:
  1. Trends top-right highlighted percentage and icon use selected alert highlight color.
  2. Menu Bar highlighted exceeded ranges use selected alert highlight color.
  3. Persist/reload still works across app restarts.
- Non-functional:
  1. Keep rendering code paths unchanged except color source.
  2. Maintain readability in dark and light mode.

## Architecture
- Add color mapping helpers on enum:
  - `swiftUIColor` (for `TrendsView`)
  - `nsColor` (for `MenuBarController`)
- Resolve color from `viewModel.settings.systemAlertSettings.exceededThresholdHighlightColor` at render time.
- Keep `MenuBarDisplayFormatter` unchanged; only replace attributed color constant.

## Related Code Files
- Modify:
  - [TrendsView.swift](../../MacMonitor/Sources/Features/Trends/TrendsView.swift)
  - [MenuBarController.swift](../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)
  - [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift) (color mapping helpers)
  - [SettingsStoreTests.swift](../../MacMonitor/Tests/SettingsStoreTests.swift)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. Add enum-to-`Color`/`NSColor` mapping helpers in settings domain.
2. In `TrendsView.trendCard`, replace hardcoded orange with resolved selected highlight color for active inline alert.
3. In `MenuBarController.attributedMenuBarTitle`, replace `NSColor.systemYellow` with selected highlight color.
4. Extend `SettingsStoreTests`:
   - persistence/hydration includes new field
   - legacy decode without field still defaults correctly
5. Run build/test commands and manual verification for both surfaces.

## Todo List
- [x] Replace hardcoded Trends alert highlight color with settings-driven color.
- [x] Replace hardcoded Menu Bar highlight color with settings-driven color.
- [x] Add/adjust persistence + backward-compat tests.
- [x] Run full test suite and manual smoke checks.

## Success Criteria
- Switching alert highlight color updates Trends and Menu Bar highlights consistently.
- Existing persisted settings payloads without new field still load with default color.
- No regressions to threshold logic, alert generation, or menu bar formatting.

## Risk Assessment
- Risk: color mismatch between SwiftUI and AppKit mappings.
- Mitigation: centralize both mappings in one enum and avoid duplicated hex constants.

## Security Considerations
- No auth/authz impact; purely local UI/settings change.

## Next Steps
- Optional follow-up only: add focused UI/snapshot tests for highlight color regression if UI test harness expands.

## Unresolved Questions
- None.
