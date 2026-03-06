---
title: "Storage Delete Interaction Lock + Inline Progress"
description: "Minimal bug-fix plan to lock delete-target interactions and surface clear in-UI deletion progress in Storage Management."
status: in_progress
priority: P1
effort: 2.5h
branch: codex/performance-optimization-brainstorm
tags: [storage-management, bugfix, swiftui, ux]
created: 2026-03-05
---

# Overview
Fix Storage Management delete UX regression with minimal code churn:
- Delete-target items/groups become truly non-interactive once delete starts.
- Deletion progress is shown inline in the existing UI (no disruptive progress window behavior).

# Scope (YAGNI / KISS / DRY)
- In scope:
  - Interaction gating for delete flow in existing storage views.
  - Inline progress feedback using existing cards/rows.
  - Targeted regression tests in existing test suite.
- Out of scope:
  - Redesigning delete pipeline or storage data model.
  - New screens/components/files.
  - Broad visual restyling.

# Phase
| # | Phase | Goal | Effort | Link |
|---|---|---|---|---|
| 1 | Lock deletion interactions + inline progress + tests | Prevent confusing re-selection during delete and provide clear in-place progress state | 2.5h | [phase-01-lock-delete-interactions-and-inline-progress-feedback.md](./phase-01-lock-delete-interactions-and-inline-progress-feedback.md) (In Progress) |

# File-Level TODO Summary
- [x] `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`: add one canonical delete-flow interaction lock state derived from existing delete/pending scope state.
- [x] `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`: wire row/group control disabling + concise inline status text/spinner to lock/progress states.
- [x] `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`: align delete confirmation preview controls with same lock state; keep progress feedback in popover UI.
- [x] `MacMonitor/Tests/StorageManagementViewModelTests.swift`: add regression tests for lock-state transitions and delete-scope behavior.

# Validation
- Build/tests:
  - `xcodegen generate`
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/StorageManagementViewModelTests test`
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Current execution:
  - ✅ 2026-03-05: targeted `StorageManagementViewModelTests` passed (33/33).
  - ⏳ Full `MacMonitor` suite still pending for this phase.
- Manual UX checks:
  - Start delete -> target rows/groups cannot be toggled/expanded/selected.
  - While delete runs, inline progress text/spinner is visible in Storage UI.
  - No extra disruptive progress window behavior appears.

# Unresolved Questions
- None.
