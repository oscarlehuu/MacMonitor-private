---
title: "Fix Memory Free Alignment and Launch Screen Routing"
description: "Minimal plan to align memory summary segments and prevent default fallback to legacy battery screen."
status: pending
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, popover, ui, routing]
created: 2026-03-03
---

# Overview
Fix 2 popover UX bugs with smallest safe surface:
1. Memory summary `Free` item alignment looks off.
2. Launch/reinstall can open legacy battery screen until user switches tabs.

## Scope
- Keep battery feature code intact; only adjust default/popover routing.
- Keep memory metrics math unchanged; only adjust summary layout rendering.
- Update only directly affected tests.

## Root Causes
- Memory summary uses a 2-column grid for 3 segments (`Memory Used`, `Cached Files`, `Free`), leaving `Free` isolated on a new row.
- `SystemSummaryViewModel.screen` defaults to `.battery`, while header tabs no longer expose battery as a primary tab.

## Phase 1: Memory Summary Layout
- File: `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Replace the segment presentation with a stable 3-up layout (or equivalent fixed alignment) so `Free` aligns with peer items.
- Keep existing segment order/colors/values.

## Phase 2: Launch Screen Routing
- File: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- Set default screen to `.ram` and make `showSummary()` route to RAM.
- Keep `showBattery()` available for legacy/manual paths.
- File: `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Expand `normalizeLegacyScreenIfNeeded()` to remap `.battery` -> `.ram` (same as `.temperature`), preventing stale route fallback.

## Tests (Minimal)
- File: `MacMonitor/Tests/SystemSummaryViewModelTests.swift`
- Update default-screen test: expect `.ram`.
- Update summary-route expectation: `showSummary()` -> `.ram`.
- Keep existing battery transition assertion to ensure legacy route still works if explicitly called.

## Validation
- Open popover after clean launch/reinstall: first visible content is memory overview, not battery screen.
- Memory summary row shows `Free` aligned with other segment items (no isolated/misaligned placement).
- Run: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Risks
- Low: visual spacing change may need minor tuning at small widths.
- Low: route default change may affect hidden flows that assumed battery-first; compatibility preserved via `showBattery()`.

## Affected Files
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift`

## Unresolved Questions
- None.
