# Context Links
- [Plan overview](./plan.md)
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Features/Settings/SettingsView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`

# Overview
- Priority: P2
- Status: Pending
- Description: Remove `Icon Only` from user-facing menu bar mode options while keeping backward compatibility for persisted `icon` values, and move defaults to `both` + `% Usage` formats.

# Key Insights
- `MenuBarDisplayMode.allCases` currently feeds both user-facing pickers.
- `MenuBarDisplayMode` includes `.icon`; this is needed for decoding legacy/current persisted values.
- Current defaults are mixed (`display: .memory`, `memory: .percentUsage`, `storage: .numberLeft`).
- `loadMenuBarDisplayMode` currently returns `.icon` for persisted `"icon"`.

# Requirements
- Functional requirements:
  - User cannot choose `Icon Only` from menu bar options in Settings surfaces.
  - Fresh/default configuration resolves to `display=both`, `memoryFormat=percentUsage`, `storageFormat=percentUsage`.
  - Persisted/legacy `icon` values load safely as `both`.
- Non-functional requirements:
  - Keep settings key names unchanged.
  - Keep changes minimal and localized.
  - Avoid UI state mismatch where selected value is not present in options.

# Architecture
- Add a user-facing case list in `MenuBarDisplayMode` (example: `userFacingCases`) that excludes `.icon`.
- Use `userFacingCases` in both Settings option groups instead of `allCases`.
- In `loadMenuBarDisplayMode`, normalize `.icon` (or raw `"icon"`) to `.both`.
- Update default fallbacks in initializer/load path:
  - display fallback: `.both`
  - memory format fallback: `.percentUsage`
  - storage format fallback: `.percentUsage`

Component interaction/data flow:
- UserDefaults -> `SettingsStore` load normalization -> published values -> Settings/Popover pickers + MenuBar renderer.

# Related Code Files
- Files to modify:
  - `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
  - `MacMonitor/Sources/Features/Settings/SettingsView.swift`
  - `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Files to create:
  - None
- Files to delete:
  - None

# Implementation Steps
1. Define a non-icon user-facing display mode list in `MenuBarDisplayMode`.
2. Replace `MenuBarDisplayMode.allCases` in both settings UIs with the user-facing list.
3. Update `SettingsStore` defaults to `both` + `% Usage` for both metrics.
4. Update menu bar display mode load logic so persisted `icon` resolves to `.both`.
5. Keep enum `.icon` for decode/backward compatibility only.

# Todo List
- [ ] Add `userFacingCases` (or equivalent) on `MenuBarDisplayMode`.
- [ ] Wire user-facing pickers to this list in both settings views.
- [ ] Change default return/fallback paths in `SettingsStore`.
- [ ] Add explicit `icon -> both` normalization in load mapping.

# Success Criteria
- `Icon Only` does not appear in either user-facing menu bar display picker.
- New/fallback values produce `Both` + `% Usage` + `% Usage`.
- Existing users with persisted `icon` render as `Both` without crash/regression.

# Risk Assessment
- Risk: Hidden `.icon` value can still appear from persistence if not normalized.
- Mitigation: Normalize during load before value reaches UI bindings.

- Risk: Duplicate picker option lists drift over time.
- Mitigation: Centralize user-facing cases in enum/static helper.

# Security Considerations
- No auth/network changes.
- Persistence migration stays within same local UserDefaults keys; no new sensitive data introduced.

# Next Steps
- Implement phase 2 tests to lock migration/default behavior.
