---
title: "Patch: Guaranteed Popover Drag-Resize via Explicit Handle"
description: "Short bugfix plan to make popover width drag-resize reliable while preserving explicit save-default behavior."
status: completed
priority: P1
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, appkit, popover, bugfix]
created: 2026-03-03
---

# Overview
User still cannot reliably resize popover by edge/corner. Implement a robust fallback path with an explicit in-popover resize handle while retaining current AppKit window-resize support.

# Scope (YAGNI/KISS/DRY)
- In scope:
  - Explicit drag handle in existing popover UI for width resize.
  - Keep existing `Save Current Width as Default` behavior unchanged.
  - Minor hardening of popover width sync loop if needed.
- Out of scope:
  - Height resize persistence.
  - Automatic save on drag.
  - Detached/pinnable window mode.

# Phase
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Add explicit handle + harden width sync/save-default behavior | Completed | 100% | 2h | [phase-01-add-explicit-handle-and-harden-width-sync.md](./phase-01-add-explicit-handle-and-harden-width-sync.md) |

# Expected Source Files to Change
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift` (only if a tiny helper is necessary)
- `MacMonitor/Tests/SettingsStoreTests.swift` (only if behavior contract changes)

# Validation
- Build: `xcodegen generate`
- Tests: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual:
  - Drag explicit handle left/right: width updates immediately every time.
  - Save default still requires explicit button tap.
  - Close/reopen without save returns to stored default.
  - Save + relaunch opens at saved width.

# Unresolved Questions
- None.
