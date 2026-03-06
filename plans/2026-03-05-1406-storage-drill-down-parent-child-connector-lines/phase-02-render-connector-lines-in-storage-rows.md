# Phase 02 - Render Connector Lines in Storage Rows

## Context Links
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`

## Overview
- Priority: P1
- Status: pending
- Goal: draw clear parent-child connector lines in the row indent gutter with no interaction regressions.

## Key Insights
- Current indent is plain `Spacer`; replacing it with a lightweight connector gutter can stay behavior-neutral.
- Main storage row and delete preview row use similar indentation; shared rendering approach avoids drift.

## Requirements
- Functional: nested rows show vertical continuity + branch elbow.
- Functional: root rows remain unconnected (no visual clutter).
- Non-functional: preserve chevron, checkbox, loading text alignment and existing disabled states.

## Architecture
- In each view, replace fixed-depth spacer with a connector gutter view built from row metadata.
- Use constant column width (same as current indent unit, `12`) to preserve layout.
- Render subtle lines with existing theme colors; no new theming system.

## Related Code Files
- Modify: `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- Modify: `MacMonitor/Sources/Features/Popover/PopoverRootView.swift` (if parity desired)
- Create: none
- Delete: none

## Implementation Steps
1. Add a small private connector-gutter builder in `StorageManagementView`.
2. Replace row indent spacer in `itemRow(_:)` with connector gutter.
3. If parity approved, apply same gutter logic to `storageDeletePreviewRow` in `PopoverRootView`.
4. Verify no hit-testing regressions: connector area stays passive/non-interactive.

## Todo List
- [ ] Implement connector gutter in main storage rows.
- [ ] Keep spacing and alignment equivalent to current UI.
- [ ] Optionally mirror connector gutter in delete preview rows (based on decision).

## Success Criteria
- Connectors visibly track parent-child structure for expanded nested rows.
- Row controls (expand/select/reveal) remain aligned and clickable.

## Risk Assessment
- Risk: subtle row alignment shifts.
- Mitigation: reuse existing indent constants and compare before/after UI behavior.

## Security Considerations
- No security impact (presentation-only changes).

## Next Steps
- Run build/tests and manual regression checklist (Phase 03).
