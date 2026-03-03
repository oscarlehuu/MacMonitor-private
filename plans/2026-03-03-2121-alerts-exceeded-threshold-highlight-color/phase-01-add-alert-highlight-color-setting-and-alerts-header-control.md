# Phase 01: Add Persisted Alert Highlight Color + Alerts-Header Inline Control

## Context Links
- Plan: [plan.md](./plan.md)
- Settings model: [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift)
- Settings Alerts UI: [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)

## Overview
- Priority: P2
- Status: Completed
- Goal: Introduce a persisted, backward-compatible alert highlight color setting and surface selector inline with the Alerts header.

## Key Insights
- `SystemAlertSettings` already uses custom `init(from:)` with `decodeIfPresent`, ideal for additive field migration.
- Alerts header currently rendered by `settingsSectionHeader(...)`; inline control can be added without new layout containers/cards.

## Requirements
- Functional:
  1. Add a user-selectable alert highlight color option to persisted alert settings.
  2. Render selector inline with `Alerts` header (same row).
  3. Keep default behavior for existing users with old persisted settings.
- Non-functional:
  1. No new persistence keys; reuse `settings.systemAlertSettings` payload.
  2. Keep implementation minimal and local.

## Architecture
- Add compact enum in settings domain (raw-value codable, case iterable).
- Add new field on `SystemAlertSettings` and include in `CodingKeys` + custom decoder fallback.
- Extend `normalized()` to preserve selected color (no unnecessary transforms).
- In `settingsAlertsCard`, replace plain header with header row: title + right-aligned color menu/chip.

## Related Code Files
- Modify:
  - [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift)
  - [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. Add `ExceededThresholdHighlightColor` enum in `SettingsStore.swift` with stable raw values and display titles.
2. Add `exceededThresholdHighlightColor` field to `SystemAlertSettings`.
3. Update `CodingKeys`, `init(...)`, `init(from:)`, `default`, and `normalized()` for backward-compatible fallback.
4. Update `settingsAlertsCard` to render header row with inline color selection bound to `settings.systemAlertSettings.exceededThresholdHighlightColor`.
5. Keep control compact (menu/chip), no additional settings rows.

## Todo List
- [x] Add enum + display metadata.
- [x] Add new persisted field with decode fallback.
- [x] Add inline Alerts-header selector bound to settings.
- [x] Verify no structural UI regressions in Settings screen.

## Success Criteria
- Existing installs with old alert settings decode without crash/reset.
- Alerts header shows selectable color control inline on same row.
- Setting updates in-memory + persists via existing `systemAlertSettings` data key.

## Risk Assessment
- Risk: enum raw-value typo can break decode/compatibility.
- Mitigation: stable raw values + explicit default fallback.

## Security Considerations
- No new privileged APIs, secrets, or network/data-exposure changes.

## Next Steps
- Phase 02 completed; no remaining implementation work in this plan.

## Unresolved Questions
- None.
