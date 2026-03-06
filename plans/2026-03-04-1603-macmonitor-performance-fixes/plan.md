---
title: "MacMonitor Performance Fix Plan"
description: "Quick-win-first plan to remove delete-flow UI stalls, reduce tab-switch jank, and lower delete-confirmation render cost with minimal behavior risk."
status: in_progress
priority: P1
effort: 6h
branch: codex/performance-optimization-brainstorm
tags: [performance, swiftui, macos, storage, ram]
created: 2026-03-04
---

# Overview
Apply 3 focused performance fixes with behavior parity: cache delete-confirmation preview rendering, scope RAM refresh work to active Memory tab, then move running-app preflight waits off main-actor paths where safe.

# Scope (YAGNI / KISS / DRY)
- In scope: only targeted performance paths in storage delete flow + RAM tab behavior.
- Out of scope: redesigning storage model, changing delete semantics, changing process safety rules.

# Quick-Win-First Phases
| # | Phase | Goal | Effort | Link |
|---|---|---|---|---|
| 1 | Cache delete-confirmation preview rows | Remove repeated expensive recomputation during overlay render | 1.5h | [phase-01-cache-storage-delete-confirmation-preview-rows.md](./phase-01-cache-storage-delete-confirmation-preview-rows.md) (Done) |
| 2 | Scope RAM refresh cadence to active tab | Avoid heavy refresh on every tab entry and while tab inactive | 1.5h | [phase-02-scope-ram-refresh-cadence-on-memory-tab.md](./phase-02-scope-ram-refresh-cadence-on-memory-tab.md) (Done) |
| 3 | Move running-app preflight waits off main actor | Eliminate delete-flow UI freeze risk while preserving force/skip behavior | 2h | [phase-03-move-running-app-preflight-waits-off-main-actor.md](./phase-03-move-running-app-preflight-waits-off-main-actor.md) (Done) |
| 4 | Validation + regression lock | Verify responsiveness and ensure no behavior drift | 1h | [phase-04-validate-performance-and-regression.md](./phase-04-validate-performance-and-regression.md) (In Progress) |

# File-Level TODO Summary
- [x] `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`: add memoized delete-preview model and explicit invalidation points.
- [x] `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`: consume cached preview rows/sections; stop recomputing large filters each render pass.
- [x] `MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`: add tab-active refresh gating (`active/inactive` cadence) and avoid unconditional heavy refresh on quick re-entry.
- [x] `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`: wire tab visibility changes to RAM refresh gating.
- [x] `MacMonitor/Sources/Core/Storage/RunningAppPreflightCoordinator.swift`: keep AppKit calls safe, move polling/wait logic to non-main path using PID liveness checks.
- [x] `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`: keep delete-flow state transitions cancellation-safe during async preflight.
- [ ] `MacMonitor/Tests/StorageManagementViewModelTests.swift`: add memoization invalidation + delete-flow parity tests.
- [ ] `MacMonitor/Tests/RAMDetailsViewModelTests.swift`: add cadence/tab-switch regression tests.
- [x] `MacMonitor/Tests/RunningAppPreflightCoordinatorTests.swift`: add wait-path and timeout behavior tests after actor-path refactor.

# Success Criteria
- Delete-confirmation overlay remains smooth when selecting large trees.
- Switching to non-memory tabs no longer triggers unnecessary heavy RAM refresh work.
- Deleting app bundles no longer risks UI freeze while waiting for app termination.
- Existing force-quit/skip/cancel outcomes and messages remain unchanged.

# Unresolved Questions
- None.
