# Phase 01: Implement Card Collapse Toggles and Validate

## Context Links
- Plan: [plan.md](./plan.md)
- Target UI: [PopoverRootView.swift](../../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- Focus blocks: `memorySummaryCard`, `storageSummaryCard`, storage hover state

## Overview
- Priority: P2
- Status: Pending
- Goal: Default-collapse Memory and Storage summary cards, keep top rows visible, preserve current expanded behavior.

## Requirements
- Functional:
  1. Memory summary card is collapsed by default.
  2. Storage summary card is collapsed by default.
  3. Memory collapsed row still shows title/pressure + used/total context.
  4. Storage collapsed row still shows used/total and existing top actions.
  5. Expanding each card reveals current full detail view.
- Non-functional:
  1. Minimal change in one file.
  2. No behavior regression for existing actions/state when expanded.

## Related Code Files
- Modify:
  - [PopoverRootView.swift](../../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. Add local `@State` flags in `PopoverRootView`:
   - `isMemorySummaryExpanded = false`
   - `isStorageSummaryExpanded = false`
2. Update `memorySummaryCard` layout:
   - Keep a persistent top row (title + pressure + used/total context + expand/collapse control).
   - Gate existing detailed content (usage track, segment cards, stats grid) behind `isMemorySummaryExpanded`.
3. Update `storageSummaryCard` layout:
   - Keep current top row always visible (`used/total`, hovered text if applicable, `storageTopActions`, toggle control).
   - Gate existing detail content (`compactStorageUsageTrack`, `storageScanSourcesStrip`) behind `isStorageSummaryExpanded`.
4. Preserve existing expanded behavior by reusing current detailed blocks unchanged where possible.
5. When storage card collapses, clear `hoveredStorageSegmentID` to avoid stale hovered label context.
6. Keep loading/fallback memory state readable and functional.

## Todo List
- [ ] Add two local expand/collapse state flags (default `false`)
- [ ] Add memory card expand/collapse control and keep top row visible
- [ ] Add storage card expand/collapse control and keep top row visible
- [ ] Move existing detail sections behind expanded-state guards
- [ ] Clear stale storage hover state on collapse
- [ ] Run build + tests
- [ ] Run manual UI regression checks

## Success Criteria
- Both cards are collapsed by default on first open.
- Collapsed memory card still shows title/pressure and used/total context.
- Collapsed storage card still shows used/total and action buttons.
- Expanded cards match current full detail behavior.
- No regressions in storage actions, RAM details view embedding, or card styling.

## Risk Assessment
- Risk: Toggle button placement can squeeze top-row content on narrow widths.
- Mitigation: Keep compact control styling and preserve current spacing priorities.
- Risk: Hover text persistence can show stale segment details after collapse.
- Mitigation: Reset `hoveredStorageSegmentID` when storage card collapses.

## Security Considerations
- UI-only change; no auth/data/security surface changes.

## Validation Steps
1. `xcodegen generate`
2. `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
3. Manual checks:
   - Open RAM screen: memory summary collapsed by default.
   - Expand memory card: usage track, segments, and stat rows match current behavior.
   - Open Storage screen: storage summary collapsed by default with top actions visible.
   - Expand storage card: usage track + scan-source strip render as before.
   - Confirm `Refresh` and `Add Folder` actions still work in collapsed and expanded states.

## Next Steps
- Implement directly in `PopoverRootView.swift` per TODO checklist.
