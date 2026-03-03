---
title: "Trends UI: Inline Alerts Inside Trend Cards"
description: "Concise implementation plan to remove the standalone Trends alert card and render contextual inline alerts per trend card."
status: completed
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, trends, alerts, ui]
created: 2026-03-03
---

# Overview
Apply a minimal UI composition change in Trends:
- remove the separate alert card below the trend grid
- render alert messaging inline inside the matching trend card, above the chart area (for example, Storage)
- keep normal behavior: no inline alert row when no alert applies
- preserve existing chart rendering and summary stats (`Avg`, `Peak`, `Points`)

# Scope (YAGNI/KISS/DRY)
- In scope:
  - Trends card layout/composition only
  - Alert-to-card mapping for existing alert kinds used in Trends
- Out of scope:
  - Alert generation thresholds and policy logic
  - Trend sampling/history calculations
  - Any redesign outside Trends card internals

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Remove global alert banner and add card-inline alert rows | Completed | 100% | 2h | [phase-01-inline-alerts-inside-trend-cards.md](./phase-01-inline-alerts-inside-trend-cards.md) |

# Source Files Changed
- `MacMonitor/Sources/Features/Trends/TrendsView.swift` (inline alert resolver + kind-to-slot mapping)
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift` (exact latest-batch + slot-mapping resolver coverage)

# Validation
- Build metadata refresh: `xcodegen generate`
- Compile + tests: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Optional focused run during iteration:
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/SystemSummaryViewModelTests -only-testing:MacMonitorTests/SystemAlertPolicyEngineTests test`
- Manual UI validation:
  - Trigger Storage threshold exceedance, verify inline alert row appears in Storage card above sparkline
  - Verify no separate alert card is rendered below the grid
  - Verify when no active threshold alert exists, no inline alert row is shown
  - Verify sparkline and summary stats remain unchanged in all cards

# Completion Notes
- Standalone Trends alert banner removed from root layout.
- Inline alert rows now resolve per card from the exact latest alert batch timestamp.
- Resolver behavior tests added for exact latest-batch selection + kind-to-slot mapping.
- Full test suite passing after change.

# Unresolved Questions
- None.
