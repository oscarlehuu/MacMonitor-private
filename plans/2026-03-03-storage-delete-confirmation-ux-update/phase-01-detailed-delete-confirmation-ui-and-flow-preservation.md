# Phase 01: Detailed Delete Confirmation UI and Flow Preservation

## Context Links
- Plan: [plan.md](./plan.md)
- Related files:
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
  - `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
  - `MacMonitor/Tests/StorageManagementViewModelTests.swift`

## Overview
- Priority: P2
- Status: Pending
- Goal: Upgrade delete confirmation UX to be explicit and safer while keeping current delete + force-quit logic unchanged.

## Key Insights
- Current delete confirmation is a simple `confirmationDialog` with only aggregate count/bytes.
- `deleteSelected()` already contains the full safe flow: normalize selection -> graceful quit preflight -> optional force-quit prompt -> delete.
- `PopoverRootView` also binds `showingDeleteConfirmation`; leaving old dialog there would bypass the new detailed confirmation UX.

## Requirements
- Functional:
  - Show selected deletion targets in confirmation UI (name + per-item size).
  - Show total selected size in same UI.
  - Require explicit checkbox acknowledgment before enabling destructive action.
  - Keep `deleteSelected()`, `confirmForceQuitAndDelete()`, and `skipForceQuitAndDelete()` behavior unchanged.
- Non-functional:
  - Keep UI responsive for larger selections (scrollable list, bounded height).
  - Keep code changes localized; no new architecture layers.
  - Avoid duplicate confirmation presenters for delete action.

## Architecture
- ViewModel data exposure:
  - Add a read-only deletion-target summary surface derived from existing normalized selection (stable order, protected items excluded).
  - Reuse existing normalization path to avoid duplicate logic.
- View presentation:
  - Replace delete `confirmationDialog` in `StorageManagementView` with a detailed custom confirmation surface (sheet/dialog content view) containing:
    - Target list
    - Per-target size text
    - Total size row
    - Acknowledgment checkbox
    - Cancel + destructive action buttons
  - Keep force-quit confirmation flow unchanged.
- Presenter ownership:
  - Remove/disable old simple delete confirmation binding in `PopoverRootView` so Storage screen owns delete confirmation UX.

## Related Code Files
- Files to modify:
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
  - `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
  - `MacMonitor/Tests/StorageManagementViewModelTests.swift`
- Files to create:
  - None
- Files to delete:
  - None

## Implementation Steps
1. Add read-only delete-target summary accessors in `StorageManagementViewModel` backed by existing normalized selected items.
2. In `StorageManagementView`, replace delete `confirmationDialog` with a detailed confirmation UI that reads the new summary accessors.
3. Add local view state for acknowledgment checkbox; disable destructive action until checked.
4. Reset checkbox state when confirmation opens/closes to avoid stale acknowledgment.
5. Keep destructive action wired to existing `Task { await viewModel.deleteSelected() }` (no logic change).
6. Remove the duplicate simple delete confirmation dialog from `PopoverRootView` to prevent interception/conflict.
7. Keep force-quit confirmation UI and calls unchanged.
8. Add/adjust tests in `StorageManagementViewModelTests` for deletion-target summary ordering and total bytes (flow tests remain green).

## Todo List
- [ ] Expose deletion-target summaries from view model.
- [ ] Implement detailed confirmation UI with target list + total bytes.
- [ ] Add checkbox-gated destructive action.
- [ ] Remove duplicate simple delete confirmation presenter in popover root.
- [ ] Add/update tests for summary data surface.
- [ ] Run full build and test commands.

## Success Criteria
- Delete confirmation shows selected targets and per-item sizes.
- Total size is accurate and visible in confirmation UI.
- Delete action is disabled until user checks acknowledgment.
- Existing delete/force-quit behavior and outcomes remain unchanged.
- Build and tests pass.

## Risk Assessment
- Risk: Duplicate confirmation bindings cause wrong dialog to appear.
  - Mitigation: make `StorageManagementView` the single delete-confirmation presenter.
- Risk: Selection changes while confirmation is open can desync list vs action.
  - Mitigation: rely on view model normalized selection at action time (existing guard logic already handles empty/invalid state).
- Risk: Large selections reduce dialog usability.
  - Mitigation: constrain list height and use scrollable container.

## Security Considerations
- No auth/network/permissions changes.
- Destructive action remains user-confirmed and still routes through existing guardrails (protected-item filtering + running-app preflight).

## Next Steps
1. Implement phase in listed files.
2. Execute build + tests.
3. Manual UX verification in Storage tab.

## Unresolved Questions
- None.
