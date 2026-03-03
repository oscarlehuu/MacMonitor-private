---
title: "Storage & Apps: Remove Projection and Pin Header Actions"
description: "Concise plan to remove Projection card and keep Refresh/Add Folder at top-right header in Storage & Apps."
status: pending
priority: P2
effort: 1.5h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, storage-management, ui]
created: 2026-03-03
---

# Overview
Apply a minimal UI-only update in Storage & Apps:
- Remove the Projection card/frame.
- Move/keep `Refresh` and `Add Folder` as the trailing controls in the top header row (top-right placement).

# Scope (YAGNI/KISS/DRY)
- In scope:
  - `StorageManagementView` layout composition only.
  - Header control placement and spacing/alignment.
- Out of scope:
  - Storage scanning/deletion logic.
  - View model data/state behavior.
  - Any new source files/components.

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Remove projection and align header actions top-right | Pending | 0% | 1.5h | [phase-01-remove-projection-and-align-header-actions-top-right.md](./phase-01-remove-projection-and-align-header-actions-top-right.md) |

# Expected Source Files to Change
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`

# Validation
- Build: `xcodegen generate`
- Verify: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual check: Storage & Apps UI shows no Projection card and action buttons appear in header top-right.

# Unresolved Questions
- None.
