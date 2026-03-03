---
title: "Resizable Main Popover Width with Saved Default"
description: "Enable drag-resizing the main popover width and let user save current width as default from Settings."
status: completed
priority: P2
effort: 5h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, appkit, popover, settings]
created: 2026-03-03
---

# Overview
Allow user to drag-resize main popover width, then save current width as default from Settings. Next launches must open at saved default width.

## Scope (KISS/YAGNI/DRY)
- Keep current fixed height (`620`) behavior.
- Add width persistence only (no height persistence, no per-tab sizes, no autosave-on-resize).
- Reuse existing `SettingsStore` and popover architecture; avoid new service layers.

## Out of Scope
- Detached/pinnable window mode.
- Multiple size presets.
- Synchronizing size across devices.

## Files to Modify
- `MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Tests/SettingsStoreTests.swift`

## Phase Breakdown
1. [Phase 1: Add Popover Width State + Persistence](./phase-01-add-popover-width-state-and-persistence.md)
2. [Phase 2: Enable Drag Resize in AppKit + Apply Default Width](./phase-02-enable-popover-width-drag-resize-appkit.md)
3. [Phase 3: Add Settings Save Action + Validate End-to-End](./phase-03-add-settings-save-default-action-and-verification.md)

## Implementation Checklist
- [x] Add persisted `mainPopoverDefaultWidth` with clamp/range normalization in `SettingsStore`.
- [x] Track non-persisted `mainPopoverCurrentWidth` from active popover window.
- [x] Make popover window horizontally resizable while keeping fixed height.
- [x] Remove hard fixed width in SwiftUI root and allow width to follow AppKit container.
- [x] Add Settings action: `Save Current Width as Default`.
- [x] Ensure next show/next launch uses saved default width.
- [x] Add/update tests for width persistence and save action behavior.

## Test Plan
- Automated (`xcodebuild ... test`):
  - `SettingsStoreTests` for width hydration, clamping, and save-current-as-default persistence.
- Manual:
  - Drag popover width wider/narrower from window edge; verify live layout remains stable.
  - In Settings, save current width as default.
  - Quit app, relaunch, open popover; verify width matches saved value.
  - Resize without saving, close/reopen popover; verify it reopens at saved default.

## Risks
- AppKit popover window style-mask changes may vary across macOS versions.
- Existing fixed-width SwiftUI assumptions could cause clipping at smaller widths.

## Unresolved Questions
- None.
