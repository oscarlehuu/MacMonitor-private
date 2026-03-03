---
title: "Storage Delete Confirmation UX Upgrade"
description: "Concise plan to replace simple delete confirmation with a detailed, checkbox-gated confirmation while preserving existing delete/force-quit behavior."
status: pending
priority: P2
effort: 3h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, storage-management, ux]
created: 2026-03-03
---

# Overview
Replace the current one-line delete `confirmationDialog` with a detailed confirmation UI in `StorageManagementView` that shows selected deletion targets (name + size), total size, and a mandatory acknowledgment checkbox before delete is enabled.

# Scope (YAGNI/KISS/DRY)
- In scope:
  - Detailed delete confirmation UI in Storage screen.
  - Per-target size list + total size summary.
  - Checkbox gate for destructive action.
  - Preserve current `deleteSelected()` flow and force-quit branching.
- Out of scope:
  - Changes to deletion engine, preflight rules, or force-quit decision logic.
  - New storage scanning or selection rules.
  - New feature files/modules.

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Detailed delete confirmation UI + flow-preservation hardening | Pending | 0% | 3h | [phase-01-detailed-delete-confirmation-ui-and-flow-preservation.md](./phase-01-detailed-delete-confirmation-ui-and-flow-preservation.md) |

# Expected Source Files to Change
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Tests/StorageManagementViewModelTests.swift`

# Validation
- Build: `xcodegen generate`
- Tests: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual:
  - Delete confirmation opens with selected target list and per-item sizes.
  - Total size matches selected targets.
  - Delete button stays disabled until checkbox is ticked.
  - Confirmed delete still triggers existing force-quit prompt when needed.
  - Skip/confirm/cancel force-quit behavior remains unchanged.

# Unresolved Questions
- None.
