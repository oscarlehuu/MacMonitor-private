# Phase 01: Stabilize Drag Vector and Width Sync

## Context Links
- Plan: [plan.md](./plan.md)
- Popover UI + handle: [PopoverRootView.swift](../../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- Popover host/window control: [MenuBarController.swift](../../../MacMonitor/Sources/Features/MenuBar/MenuBarController.swift)

## Overview
- Priority: P1
- Status: Completed
- Brief: Fix custom handle drag math and remove width update jitter with minimal code-path changes.

## Key Insights
- Current drag uses `.global` `location/startLocation`; this can drift when the popover repositions while resizing.
- Width is updated in tight loops from both SwiftUI and AppKit sides, increasing feedback jitter risk.
- Regression can be fixed without touching persistence model or adding new architecture.

## Requirements
- Functional:
1. Vertical-only and diagonal drags from custom handle must reliably affect width.
2. Drag updates must be smooth (no visible oscillation/jitter).
3. Fixed height and min/max width bounds must remain unchanged.
4. Save-default remains explicit (no implicit save on drag).
- Non-functional:
1. Limit edits to two scoped files.
2. Keep code simple, no new services/view models.
3. Avoid introducing resize lag.

## Architecture
- `PopoverRootView.swift`:
1. Replace coordinate-sensitive delta math with translation-based drag vector.
2. Keep one baseline width at drag start.
3. Add tiny dedupe threshold for repeated equivalent width values.
- `MenuBarController.swift`:
1. Ensure one clear, deduped path applies current width to shown popover.
2. Reuse existing clamp/fixed-height behavior.

## Related Code Files
- Modify:
1. `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
2. `MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- Create: None
- Delete: None

## Implementation Steps
1. Update handle gesture math in `PopoverRootView`:
   - Use `value.translation` rather than `location - startLocation`.
   - Compute one deterministic `appliedDelta` that always considers vertical + horizontal intent.
2. Keep drag baseline stable:
   - Capture baseline width once at gesture start.
   - Reset baseline and any transient drag state on `onEnded`.
3. Add jitter guard in `PopoverRootView`:
   - Skip width writes when target differs by <= small epsilon.
4. Harden sync path in `MenuBarController`:
   - Apply deduped `mainPopoverCurrentWidth` updates only when popover is visible.
   - Keep fixed height and current min/max constraints.
5. Keep UX contract:
   - Do not alter save-default button behavior.

## Todo List
- [x] Replace handle drag delta math with translation-based vector logic
- [x] Keep stable baseline width per drag
- [x] Add epsilon guard for width writes during drag
- [x] Deduplicate popover width-apply path in controller
- [x] Run build/test/manual validation

## Success Criteria
- Vertical drag clearly resizes width.
- Diagonal drag resizes width smoothly.
- No visible jitter while dragging.
- Existing save-default behavior still works.

## Risk Assessment
- Risk: Wrong vertical sign mapping could invert expected drag direction.
- Mitigation: Validate both up/down and diagonal directions immediately; flip sign once if needed.

## Security Considerations
- No auth/network/system-permission changes.
- Changes remain local UI/window sizing logic only.

## Next Steps
1. Manual UX retest by Oscar for vertical/diagonal drag feel on real menu bar positioning.
2. Optional follow-up: tune drag sensitivity constants if needed after live feedback.
