## 1) Context Links
- `./plans/2026-03-03-popover-width-resize-save-default/plan.md`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `./MacMonitor/Tests/SettingsStoreTests.swift`

## 2) Overview
- date: 2026-03-03
- priority: P2
- implementation status: pending
- description: Add normalized popover width state in `SettingsStore` for persisted default width and runtime current width.

## 3) Key Insights
- `PopoverRootView` is currently hard-coded to width `440` and cannot express user default width.
- `SettingsStore` already persists UI-level preferences and is the right single source for this value.
- Width must be clamped to a safe range to avoid broken layouts.

## 4) Requirements
### Functional requirements
- Persist `mainPopoverDefaultWidth` in `UserDefaults`.
- Hydrate persisted width on app start with fallback to `440`.
- Track `mainPopoverCurrentWidth` as runtime value (not persisted).
- Expose `saveCurrentPopoverWidthAsDefault()` to copy runtime width into persisted default.
- Clamp all widths to one shared range (ex: `360...760`).

### Non-functional requirements
- Keep API minimal and intuitive for UI/AppKit callers.
- Keep behavior deterministic for tests.
- Maintain backward compatibility for existing settings keys.

## 5) Architecture
- Extend `SettingsStore.Keys` with one new key for default width.
- Add two published properties:
  - persisted default width (`mainPopoverDefaultWidth`)
  - runtime current width (`mainPopoverCurrentWidth`)
- Add one normalization helper used by both hydration and setters.
- Add one convenience command for UI button (`saveCurrentPopoverWidthAsDefault`).

## 6) Related Code Files
- modify: `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- modify: `./MacMonitor/Tests/SettingsStoreTests.swift`
- create: none
- delete: none

## 7) Implementation Steps
1. Add width constants in `SettingsStore` (default/min/max/fixedHeight) to keep DRY across files.
2. Hydrate persisted default width from defaults with clamp normalization.
3. Persist default width whenever it changes (guarded by existing hydration logic).
4. Add runtime updater (`updateMainPopoverCurrentWidth(_:)`) for AppKit resize callbacks.
5. Add `saveCurrentPopoverWidthAsDefault()` to support explicit Settings action.
6. Add tests for hydration fallback, clamp, and save-current persistence.

## 8) Todo List
- [ ] Define `mainPopoverDefaultWidth` settings key.
- [ ] Add normalized width helpers/constants.
- [ ] Add runtime `mainPopoverCurrentWidth` update API.
- [ ] Add save-current-as-default API.
- [ ] Cover new behavior in `SettingsStoreTests`.

## 9) Success Criteria
- Persisted width survives relaunch.
- Out-of-range persisted values are clamped safely.
- Save-current action writes expected width to defaults.

## 10) Risk Assessment
- Risk: invalid defaults data can produce bad initial width.
- Mitigation: clamp + fallback logic in a single helper tested in unit tests.

## 11) Security Considerations
- Only local preference persistence in `UserDefaults`; no sensitive data path.
- Ensure no external input path can bypass clamp bounds.

## 12) Next Steps
- Feed `SettingsStore` width values into AppKit popover configuration (Phase 2).
