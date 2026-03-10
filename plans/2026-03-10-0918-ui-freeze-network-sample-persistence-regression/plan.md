---
title: "UI Freeze Network Sample Persistence Regression"
description: "Remove the latest-version responsiveness regression caused by startup main-thread blocking in network snapshot persistence and battery event loading."
status: completed
priority: P1
effort: 2h
branch: codex/performance-optimization-brainstorm
tags: [performance, regression, metrics, popover]
created: 2026-03-10
---

# Overview
Stabilize popover open time and tab switching by removing the low-value per-second shared snapshot write introduced for live network reporting, then eliminate remaining startup main-thread blocking from battery event loading and lock the behavior with regression tests and XCTest-host stabilization.

# Phases
| # | Phase | Goal | Status | Link |
|---|---|---|---|---|
| 1 | Confirm regression path | Verify which latest-version path blocks responsiveness | Done | [phase-01-confirm-regression-path.md](./phase-01-confirm-regression-path.md) |
| 2 | Apply low-risk fix | Keep live network UI updates, stop blocking persistence work on `networkSample`, and move shared snapshot disk writes off the launch path | Done | [phase-02-apply-low-risk-fix.md](./phase-02-apply-low-risk-fix.md) |
| 3 | Validate and lock | Add regression coverage, remove battery startup contention, and run verification | Done | [phase-03-validate-and-lock-regression.md](./phase-03-validate-and-lock-regression.md) |

# File-Level TODO Summary
- [x] Inspect `MacMonitor/Sources/Core/Metrics/MetricsEngine.swift` recent network sampling changes.
- [x] Inspect `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift` network-sample persistence behavior.
- [x] Update `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift` to avoid blocking shared snapshot writes on `networkSample`.
- [x] Add regression coverage in `MacMonitor/Tests/SystemSummaryViewModelTests.swift`.
- [x] Keep shared widget snapshot cache readable immediately while persisting to disk asynchronously.
- [x] Move battery recent-event refresh off the main path and order async refresh publishing.
- [x] Add battery-service regression coverage for stale refresh ordering and periodic pruning.
- [x] Keep XCTest host app inert so unit tests do not boot full production services.
- [x] Stabilize network-sample expectations so `@MainActor` tests do not stall waiting on async fulfillment.
- [x] Run focused tests, full suite validation, and live launch sampling after reinstall.

# Success Criteria
- Popover and tab switching no longer degrade because of per-second network sample persistence.
- Live network values still update in current UI snapshot.
- History append semantics stay unchanged for `networkSample`.
- Battery diagnostics loading no longer blocks menu bar startup or popover reveal.
- Shared snapshot disk writes no longer block the main thread during startup.
- Regression coverage fails if shared snapshot persistence is reintroduced on `networkSample`.
- Build compiles cleanly except for the pre-existing `SMJobBless` deprecation warning.
- Targeted and full unit tests complete without host-app startup noise or network-sample timeout regressions.

# Unresolved Questions
- Docs impact: none.
- Follow-up: migrate deprecated `SMJobBless` helper install path separately from this responsiveness fix.
