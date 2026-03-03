---
title: "Menu Bar Mode Simplification Defaults Migration"
description: "Remove Icon Only from user-facing mode pickers, set default mode to Both, default metric formats to % Usage, and keep persisted legacy/icon compatibility."
status: pending
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, menu-bar, settings, migration, backward-compatibility]
created: 2026-03-03
---

# Overview
Remove `Icon Only` from user-facing menu bar display options, set default display mode to `Both`, set default memory/storage formats to `% Usage`, and preserve backward compatibility by mapping persisted legacy/current `icon` values to `both`.

# Scope (YAGNI/KISS)
- In scope:
  - Hide `Icon Only` from Settings and Popover menu bar mode option groups.
  - Keep persisted compatibility for existing `icon` values (legacy and current key usage).
  - Change default `menuBarDisplayMode` to `both`.
  - Change default `menuBarMemoryFormat` and `menuBarStorageFormat` to `percentUsage`.
  - Add/adjust tests for migration + defaults.
- Out of scope:
  - Removing `.icon` enum case from persisted schema.
  - UI redesign beyond option visibility/defaults.
  - Diagnostics schema changes.

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | UI options + defaults + icon compatibility mapping | Pending | 0% | 1.5h | [phase-01-remove-icon-only-user-options-and-default-to-both-percent-usage.md](./phase-01-remove-icon-only-user-options-and-default-to-both-percent-usage.md) |
| 2 | Tests and verification | Pending | 0% | 0.5h | [phase-02-add-backward-compatibility-and-default-regression-tests.md](./phase-02-add-backward-compatibility-and-default-regression-tests.md) |

# Exact Files Likely To Modify
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Features/Settings/SettingsView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Tests/SettingsStoreTests.swift`
- `MacMonitor/Tests/MenuBarDisplayFormatterTests.swift` (only if icon-path behavior assertions need alignment)

# TODO Checklist
- [ ] Replace `MenuBarDisplayMode.allCases` usage in user-facing pickers with non-icon selectable set.
- [ ] Update Settings defaults: display mode `both`, memory format `percentUsage`, storage format `percentUsage`.
- [ ] Map persisted `icon` (current and legacy representations) to `both` during load.
- [ ] Add tests for new defaults and `icon` migration behavior.
- [ ] Run targeted + full build tests for settings/menu bar surfaces.

# Unresolved Questions
- None.
