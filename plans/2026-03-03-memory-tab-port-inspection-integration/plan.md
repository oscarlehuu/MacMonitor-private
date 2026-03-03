---
title: "Integrate Port Inspection Into Memory Tab"
description: "Minimal plan to reuse RAMDetailsView in Memory tab and avoid duplicate termination alerts."
status: in_progress
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, memory, ports, popover]
created: 2026-03-03
---

# Overview
Add existing port-inspection UI to the Memory tab by reusing `RAMDetailsView` (processes + ports) inside `PopoverRootView`.

# Scope (YAGNI/KISS/DRY)
- Reuse existing `RAMDetailsView`; no new view model or collectors.
- Integrate inside current Memory screen path in `PopoverRootView`.
- Keep a single owner for terminate/force-kill alerts to prevent conflicts.
- Avoid unrelated tab/layout refactors.

# Exact Files Likely Touched
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Tests/PopoverRootView*` (only if an existing popover UI test file exists; otherwise skip)

# Implementation TODOs
- [x] Replace `memoryProcessesCard` usage in `memoryOverviewScreen` with embedded `RAMDetailsView` configured for inline use (`showsBackButton: false`).
- [x] Keep existing memory summary card as-is; pass `memorySnapshot: nil` to `RAMDetailsView` to avoid duplicated summary blocks.
- [x] Remove parent-level RAM terminate alert in `PopoverRootView` so `RAMDetailsView` is sole owner of RAM termination alerts (process + port owner + force-kill).
- [x] Remove now-unused helper UI code in `PopoverRootView` that belonged only to old process list card (keep deletions minimal and compile-safe).
- [x] Verify memory tab default still opens in `.processes` mode and user can switch to `.ports` mode.

# Validation Checklist
- [x] Memory tab shows processes mode by default.
- [ ] Mode switch to `Ports` shows listening port rows and owner selection.
- [ ] Trigger terminate from processes mode: exactly one confirmation alert appears.
- [ ] Trigger terminate from ports mode (including force-kill flow): exactly one dialog/alert path appears.
- [x] Build/tests pass: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`.
- [x] Installed local signed build to `/Applications/MacMonitor.app` for live verification.

# Risks + Mitigations
- Risk: Nested scrolling (parent `ScrollView` + `RAMDetailsView` internal list scroll) can feel awkward.
  Mitigation: Keep change minimal first; tune only if UX regression is observed.
- Risk: Alert presentation conflicts if parent alert remains.
  Mitigation: enforce single-alert ownership in child view path.

# Unresolved Questions
- None.
