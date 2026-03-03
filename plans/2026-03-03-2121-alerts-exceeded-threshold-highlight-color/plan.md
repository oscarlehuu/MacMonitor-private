---
title: "User-Selectable Exceeded-Threshold Highlight Color"
description: "Concise implementation plan to add a configurable highlight color for exceeded-threshold values across Alerts settings, Trends, and Menu Bar." 
status: completed
priority: P2
effort: 3h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, settings, alerts, trends, menu-bar]
created: 2026-03-03
---

# Overview
Add one alert-style setting for exceeded-threshold highlight color, expose it inline with the Alerts header, and apply it consistently to:
- Trends top-right highlighted percentage + icon when an inline alert is active
- Menu Bar highlighted exceeded ranges (RAM/SSD)

# Scope (YAGNI/KISS/DRY)
- In scope:
  - Persisted setting for alert highlight color with safe default.
  - Inline Alerts-header control in Settings UI (no new card/section).
  - Reuse same setting in Trends and Menu Bar rendering.
  - Backward-compatible decode for existing persisted alert settings.
- Out of scope:
  - Alert policy/threshold logic changes.
  - Theme system redesign.
  - New cross-platform/shared color system.

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Add persisted alert highlight color + Alerts-header inline selector | Completed | 100% | 1.5h | [phase-01-add-alert-highlight-color-setting-and-alerts-header-control.md](./phase-01-add-alert-highlight-color-setting-and-alerts-header-control.md) |
| 2 | Apply selected color in Trends and Menu Bar + regression tests | Completed | 100% | 1.5h | [phase-02-apply-selected-highlight-color-to-trends-and-menu-bar.md](./phase-02-apply-selected-highlight-color-to-trends-and-menu-bar.md) |

# Exact Files Likely To Modify
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/Trends/TrendsView.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- `MacMonitor/Tests/SettingsStoreTests.swift`

# TODO Checklist
- [x] Define codable alert highlight color option with default fallback in alert settings model.
- [x] Keep legacy persisted `settings.systemAlertSettings` payloads decoding successfully.
- [x] Add inline color selector beside `Alerts` section header in Settings card.
- [x] Use selected color for Trends top-right highlighted percentage + info icon.
- [x] Use selected color for Menu Bar exceeded-value attributed ranges.
- [x] Add/adjust settings persistence tests for new field + backward compatibility.
- [x] Run `xcodegen generate` and `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`.

# Validation
- Unit: `SettingsStoreTests` covers persist/hydrate + legacy decode path.
- Manual UI:
  - Change alert highlight color in Settings -> Alerts header control.
  - Trigger RAM/Storage threshold exceedance; verify Trends top-right value/icon color updates.
  - Verify Menu Bar exceeded values use the same selected color.
  - Restart app; verify color persists.

# Risks
- If enum decoding is not fallback-safe, old persisted payloads could reset/lose settings.
- Menu Bar color must remain legible in light/dark appearances.

# Docs Impact
- `Docs impact: none` for product/architecture docs.
- Tracking docs updated: this plan and both phase files.

# Unresolved Questions
- None.
