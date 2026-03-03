---
title: "Alerts Highlight ColorPicker Migration"
description: "Minimal plan to replace preset highlight choices with ColorPicker, persist custom colors, and keep legacy preset-string compatibility."
status: completed
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, settings, alerts, compatibility]
created: 2026-03-03
---

# Overview
Replace preset highlight color choices in the Alerts header with free color selection via `ColorPicker`, remove `Highlight` label text, and keep the selected color persistent and shared across Trends + menu bar highlight rendering.

# Scope (YAGNI/KISS)
- In scope:
  - Swap Alerts header control from preset `Menu` to unlabeled `ColorPicker`.
  - Persist a user-picked color in `SystemAlertSettings`.
  - Apply persisted color to Trends and menu bar highlighted values.
  - Keep backward compatibility for already persisted preset string values.
- Out of scope:
  - Alert threshold/business-logic changes.
  - Theme/palette system redesign.
  - New settings screens or data store keys.

# Phase
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | ColorPicker migration + persistence compatibility + highlight consumers | Completed | 100% | 2h | [phase-01-replace-preset-highlight-menu-with-colorpicker-and-legacy-compatible-persistence.md](./phase-01-replace-preset-highlight-menu-with-colorpicker-and-legacy-compatible-persistence.md) |

# Exact Files Likely To Modify
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/Trends/TrendsView.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- `MacMonitor/Tests/SettingsStoreTests.swift`

# TODO Checklist
- [x] Replace preset enum-based highlight selection with custom color persistence model.
- [x] Add backward-compatible decode path for legacy persisted preset strings.
- [x] Replace Alerts header menu with unlabeled `ColorPicker` control.
- [x] Remove visible `Highlight` label text from Alerts header UI.
- [x] Verify Trends and menu bar use selected persisted color.
- [x] Add/adjust compatibility and persistence tests.
- [x] Run `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/SettingsStoreTests -only-testing:MacMonitorTests/SystemSummaryViewModelTests -only-testing:MacMonitorTests/MenuBarDisplayFormatterTests test`.

# Unresolved Questions
- None.
