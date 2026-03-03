---
title: "Fix Popover Resize Regressions (Drag Vector + Jitter)"
description: "Concise plan to restore vertical/diagonal custom-handle resize and remove drag jitter."
status: completed
priority: P1
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, appkit, popover, regression]
created: 2026-03-03
---

# Overview
Fix two regressions in popover custom resize behavior:
1. Drag feels horizontal-biased instead of reliably reacting to vertical/diagonal drags.
2. Drag jitter still occurs during width updates.

Scope locked to:
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`

# Expected Root Causes
- `DragGesture` delta uses `value.location - value.startLocation` in `.global` coordinate space while popover/window repositions during resize, so gesture deltas get polluted.
- Drag currently writes width through two fast paths per frame (SwiftUI state + direct AppKit window sizing) without a stable one-way sync boundary, causing oscillation/jitter.
- Gesture mapping logic over-weights horizontal behavior under coordinate drift, making vertical/diagonal intent unreliable.

# Phase
| # | Phase | Status | Effort | Link |
|---|---|---|---|---|
| 1 | Stabilize drag vector math + width sync | Completed | 2h | [phase-01-stabilize-drag-vector-and-width-sync.md](./phase-01-stabilize-drag-vector-and-width-sync.md) |

# Practical Steps
1. In `PopoverRootView`, switch drag delta math to translation-based values from gesture state (stable under window movement), then map horizontal + vertical movement deterministically to width.
2. Keep a single drag baseline width at gesture start and optional last-applied width threshold to ignore sub-pixel oscillation.
3. In `MenuBarController`, centralize width application path for `mainPopoverCurrentWidth` updates while popover is shown, with dedupe tolerance.
4. Keep fixed height behavior and existing min/max clamp unchanged.
5. Preserve existing “Save Current Width as Default” contract (no auto-save on drag).

# Validation Commands
- `xcodegen generate`
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' build`
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

# Manual Validation
- Open popover, drag custom handle vertically (up/down): width changes smoothly and predictably.
- Drag diagonally both directions: width tracks gesture without horizontal lock-in.
- Hold cursor mostly still during drag: no rapid back-and-forth width jitter.
- Close popover without saving and reopen: width resets to saved default.
- Save current width as default, relaunch app: popover opens at saved width.

# Unresolved Questions
- None.
