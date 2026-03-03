# Phase 01: Remove Projection and Align Header Actions Top-Right

## Context Links
- Plan: [plan.md](./plan.md)
- Target UI: [StorageManagementView.swift](../../../MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
- Key blocks: `body`, `actionHeader`, `projectionCard`

## Overview
- Priority: P2
- Status: Pending
- Goal: Remove Projection card and ensure `Refresh` + `Add Folder` render in the top-right header area.

## Key Insights
- `projectionCard` is a standalone card in `body`; removing it is low-risk if no dependent references remain.
- `Refresh` and `Add Folder` are already in `actionHeader`; top-right placement can be enforced by a dedicated trailing controls group.
- No business-logic changes are needed; this is a layout/composition task only.

## Requirements
- Functional:
  1. Remove the Projection card/frame from Storage & Apps screen.
  2. Place `Refresh` and `Add Folder` controls in header trailing position (top-right).
  3. Preserve existing actions and disabled states.
- Non-functional:
  1. Keep change minimal and localized (YAGNI/KISS/DRY).
  2. Modify existing files only.
  3. Avoid visual regressions in scanning/deleting states.

## Architecture
- Keep `StorageManagementView` as single composition owner.
- Remove `projectionCard` call from `body`.
- Keep actions inside `actionHeader` and group them in trailing cluster for stable alignment.

## Related Code Files
- Modify:
  - [StorageManagementView.swift](../../../MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. Remove `projectionCard` from `body` composition in `StorageManagementView`.
2. Delete now-unused `projectionCard` and `projectionRow` view builders.
3. Refine `actionHeader` layout so `Refresh` + `Add Folder` are in a trailing controls group pinned to top-right.
4. Keep current control actions:
   - `viewModel.refresh()`
   - `addFoldersFromPanel()`
5. Keep current button disabled states and styles for scan/delete safety.
6. Build and run tests to confirm no compile/runtime regressions.

## Todo List
- [ ] Remove Projection card call from `body`
- [ ] Remove unused `projectionCard`/`projectionRow` code
- [ ] Confirm header trailing alignment for `Refresh` + `Add Folder`
- [ ] Verify disabled-state behavior remains unchanged
- [ ] Run `xcodegen generate`
- [ ] Run `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Success Criteria
- Projection card/frame no longer appears in Storage & Apps.
- Refresh and Add Folder are visually in header top-right area.
- Button actions still work as before.
- Build/tests pass without new failures.

## Risk Assessment
- Risk: Header spacing can shift when last-updated label changes length.
- Mitigation: Keep trailing controls grouped and preserve `Spacer` behavior.

## Security Considerations
- No auth/data-flow changes.
- Existing destructive-action safeguards remain unchanged.

## Next Steps
- Implement phase changes in `StorageManagementView.swift`.
- Perform quick manual visual check in Storage & Apps screen.
