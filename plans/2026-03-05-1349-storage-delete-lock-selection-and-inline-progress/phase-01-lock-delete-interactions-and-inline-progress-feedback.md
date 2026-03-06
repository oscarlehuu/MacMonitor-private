## Context Links
- [plan.md](./plan.md)
- [StorageManagementViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift)
- [StorageManagementView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
- [PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- [StorageManagementViewModelTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/StorageManagementViewModelTests.swift)

## Overview
- Priority: P1
- Current status: in_progress
- Brief description: unify delete interaction lock + inline progress feedback to remove confusing post-delete selection behavior.

## Key Insights
- Delete scope exists (`deletingItemIDs`, `deletingGroupIDs`) but view disable logic is not consistently tied to one canonical lock state.
- Progress visibility during delete is fragmented; user feedback needs one obvious inline state in Storage UI.
- Minimal fix should reuse existing state and avoid new files or flow redesign.

## Requirements
- Functional requirements:
  - Once delete starts, items/groups in deletion scope are non-interactive until flow completes/cancels.
  - During active delete, UI shows clear inline progress (spinner + short status text) in Storage screen.
  - Keep existing force-quit/delete pipeline behavior intact.
- Non-functional requirements:
  - Update existing files only.
  - Keep logic centralized to avoid duplicate condition checks.
  - Preserve current look/feel except necessary disable/progress cues.

## Architecture
- Add a single view-model derived state for delete-flow interactivity lock (example: `isDeleteFlowInteractionLocked`).
- Use this state in both:
  - Storage main list (`StorageManagementView`) controls.
  - Delete-preview overlay controls in `PopoverRootView`.
- Add one inline progress message source in view model (derived from `isDeleting` + pending context) and render it in existing UI containers.

## Related Code Files
- List of files to modify:
  - [StorageManagementViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift)
  - [StorageManagementView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
  - [PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
  - [StorageManagementViewModelTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/StorageManagementViewModelTests.swift)
- List of files to create:
  - none
- List of files to delete:
  - none

## Implementation Steps
1. In `StorageManagementViewModel`, add canonical derived properties for:
   - delete-flow lock state.
   - short inline delete status text.
2. Replace scattered disable conditions in `StorageManagementView` with the canonical lock state for:
   - row selection toggles, expand/collapse buttons, group toggles, and relevant top actions.
3. Update `PopoverRootView` delete-preview controls to use the same lock state so delete-target rows cannot be reselected during active/pending delete flow.
4. Add inline progress UI in existing storage section (small spinner + status text), visible only during delete flow.
5. Keep existing cancel/force-quit actions unchanged except state gating.
6. Add regression tests in `StorageManagementViewModelTests` for:
   - lock state true during delete and pending force-quit context.
   - lock state reset after completion/cancel.
   - delete scope still reflects selected root+descendants while locked.
7. Run targeted and full test commands.

## Todo List
- [x] Add canonical delete interaction lock + inline status derived state in view model.
- [x] Apply lock state across storage row/group/preview controls.
- [x] Add inline delete progress feedback in storage UI.
- [x] Add regression tests for lock-state transitions.
- [x] Run targeted `StorageManagementViewModelTests`.
- [ ] Run full `MacMonitor` test suite.

## Success Criteria
- Delete-target items/groups cannot be selected or expanded while delete flow is active.
- User sees clear inline progress during deletion inside Storage UI.
- No disruptive progress window behavior is introduced.
- Existing delete/force-quit outcomes stay behaviorally unchanged.
- All tests pass.

## Risk Assessment
- Potential issue: over-locking may block harmless navigation during pending states.
- Mitigation: apply lock narrowly to delete-affecting controls and verify with manual UX checks.

## Security Considerations
- No new privileged operations.
- Existing force-quit and file-deletion safety rules remain unchanged.

## Next Steps
- Run full `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test` before merge.

## Unresolved Questions
- None.
