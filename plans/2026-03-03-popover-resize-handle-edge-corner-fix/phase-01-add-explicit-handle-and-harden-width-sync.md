# Phase 01: Add Explicit Handle and Harden Width Sync

## Context Links
- Plan: [plan.md](./plan.md)
- Existing resize wiring: [MenuBarController.swift](../../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)
- Popover UI: [PopoverRootView.swift](../../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- Width persistence: [SettingsStore.swift](../../../MacMonitor/Sources/Features/Settings/SettingsStore.swift)

## Overview
- Priority: P1
- Status: Pending
- Goal: Guarantee width drag-resize works by adding a dedicated resize handle in popover content, independent of native edge hit-testing reliability.

## Key Insights
- `NSPopover` window edge/corner drag affordance is inconsistent across macOS and visual configurations.
- Current save-default contract is correct: user resizes, then explicitly saves.
- Existing width persistence and clamp logic in `SettingsStore` can be reused without redesign.

## Requirements
- Functional:
  1. Add explicit resize-handle UI inside popover (bottom-right) with drag gesture.
  2. Handle drag updates `mainPopoverCurrentWidth` in real time using existing bounds.
  3. Keep fixed popover height and existing edge-resize support as secondary path.
  4. Preserve explicit `Save Current Width as Default` semantics.
- Non-functional:
  1. Keep implementation in existing files only.
  2. Keep code path minimal (YAGNI/KISS/DRY), avoid new view models/services.
  3. Avoid resize feedback loops/jitter in AppKit sync path.

## Architecture
- `PopoverRootView`:
  - Add a small, visible handle overlay aligned `.bottomTrailing`.
  - Use drag gesture with captured baseline width + translation width.
  - Update width through `settings.updateMainPopoverCurrentWidth(...)`.
- `MenuBarController`:
  - Keep current `popoverDidShow` window configuration (`.resizable`, min/max width, fixed height).
  - If needed, add threshold/equality guards in resize observer to prevent redundant looped updates.
- `SettingsStore`:
  - Reuse current clamp and save-default behavior; avoid schema/key changes unless strictly needed.

## Related Code Files
- Modify:
  - [PopoverRootView.swift](../../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
  - [MenuBarController.swift](../../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)
  - [SettingsStore.swift](../../../MacMonitor/Sources/Features/Settings/SettingsStore.swift) (optional/minimal)
  - [SettingsStoreTests.swift](../../../MacMonitor/Tests/SettingsStoreTests.swift) (optional/minimal)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. Add a `resizeHandle` view in `PopoverRootView` (bottom-right overlay, adequate hit target).
2. Track drag baseline width on gesture start and update width during drag with clamped values.
3. Keep existing settings button flow; no implicit default save during drag.
4. Harden `MenuBarController` resize observer path with small guard(s) if drag feedback loops are observed.
5. Verify UI remains stable at min/max widths and across tabs.

## Todo List
- [ ] Add explicit resize handle overlay and drag gesture in `PopoverRootView`
- [ ] Wire drag updates to `settings.updateMainPopoverCurrentWidth`
- [ ] Keep save-default button and unsaved-state logic unchanged
- [ ] Add AppKit width-update guard only if needed for loop/jitter prevention
- [ ] Run build/tests and manual resize/save/reopen/relaunch checks

## Success Criteria
- Resize via explicit handle works reliably on every open.
- Save-default remains explicit and persists correctly.
- Unsaved resize is discarded on close/reopen (default reapplied).
- No compile/runtime regressions.

## Risk Assessment
- Risk: Gesture conflicts with scroll/tap regions near bottom-right.
- Mitigation: Keep handle area isolated and use a dedicated hit target with clear affordance.

## Security Considerations
- No new privileged operations, auth flows, or external data handling.
- Width updates stay in existing bounded local settings path.

## Next Steps
- Implement phase in listed files.
- Validate manually on target macOS build with menu bar popover open/close cycles.
