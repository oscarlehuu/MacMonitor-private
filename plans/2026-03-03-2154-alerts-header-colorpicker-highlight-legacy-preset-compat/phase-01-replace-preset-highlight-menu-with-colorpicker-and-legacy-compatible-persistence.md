# Phase 01: Replace Preset Highlight Menu with ColorPicker + Legacy-Compatible Persistence

## Context Links
- Plan: [plan.md](./plan.md)
- Settings model: [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift)
- Alerts header UI: [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- Trends highlight usage: [TrendsView.swift](../../MacMonitor/Sources/Features/Trends/TrendsView.swift)
- Menu bar highlight usage: [MenuBarController.swift](../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)
- Persistence tests: [SettingsStoreTests.swift](../../MacMonitor/Tests/SettingsStoreTests.swift)

## Overview
- Priority: P2
- Status: Completed
- Brief: Migrate from fixed preset strings to free-picked color value while keeping existing persisted preset-string payloads valid.

## Key Insights
- `SystemAlertSettings` already uses custom `init(from:)`; this is the safe migration point.
- Current persistence stores color as string under `exceededThresholdHighlightColor`.
- Trends and menu bar consume color via `paletteHex`, so a single normalized color source keeps DRY.

## Requirements
- Functional requirements:
  1. Alerts header uses `ColorPicker` for free color selection.
  2. `Highlight` text label is removed from UI.
  3. Picked color persists across restart.
  4. Trends and menu bar highlights use persisted picked color.
  5. Legacy persisted preset string values (`yellow`, `orange`, etc.) still decode correctly.
- Non-functional requirements:
  1. Keep persistence key stable (`exceededThresholdHighlightColor`).
  2. Keep migration logic localized to settings decoding/encoding.
  3. No new feature flags or extra storage keys.

## Architecture
- Replace preset enum-only storage with a small codable color value abstraction that can:
  - Encode current value as a stable color string format (hex).
  - Decode either hex string or legacy preset name.
  - Fallback to existing default color on invalid input.
- Keep UI/consumers reading the same settings property so no threshold logic changes.

## Related Code Files
- Files to modify:
  - [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift)
  - [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
  - [TrendsView.swift](../../MacMonitor/Sources/Features/Trends/TrendsView.swift)
  - [MenuBarController.swift](../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)
  - [SettingsStoreTests.swift](../../MacMonitor/Tests/SettingsStoreTests.swift)
- Files to create:
  - None
- Files to delete:
  - None

## Implementation Steps
1. In `SettingsStore.swift`, introduce a minimal highlight-color value type backed by hex and legacy preset-name decode support.
2. Keep `SystemAlertSettings.CodingKeys.exceededThresholdHighlightColor` unchanged; decode legacy names and hex, encode normalized hex.
3. In `PopoverRootView.swift`, replace `settingsAlertsHeaderHighlightColorPicker` menu content with a compact unlabeled `ColorPicker`.
4. Remove `Text("Highlight")` from the Alerts header control.
5. Update Trends and menu bar color reads to use the migrated color value type (no hardcoded presets).
6. Update `SettingsStoreTests.swift`:
   1. Persist/hydrate custom color.
   2. Hydrate legacy preset string payload.
   3. Hydrate invalid string fallback without resetting other fields.
7. Run project generation + tests.

## Todo List
- [x] Add migrated color value model and legacy decode map.
- [x] Swap Alerts header UI to unlabeled `ColorPicker`.
- [x] Remove `Highlight` label text.
- [x] Apply migrated color to Trends and menu bar highlight code paths.
- [x] Update compatibility/persistence tests.
- [x] Run focused test command and verify pass.

## Success Criteria
- User can pick any color in Alerts header.
- UI shows no `Highlight` text label.
- Selected color survives app restart.
- Trends and menu bar highlighted exceed-threshold text use selected color.
- Existing users with old preset-string payloads keep expected color after upgrade.

## Risk Assessment
- Risk: decode ambiguity between legacy names and malformed custom strings.
- Mitigation: deterministic decode order (hex first or explicit map), strict fallback to default.
- Risk: color conversion mismatch between SwiftUI and AppKit rendering.
- Mitigation: centralize conversion from one normalized persisted value.

## Security Considerations
- Local settings-only change, no network/auth surface impact.
- Validate decoded values to avoid invalid color state propagation.

## Next Steps
- Execute this phase directly (single-phase plan).
- If completed, mark `plan.md` status to `completed`.

## Unresolved Questions
- None.
