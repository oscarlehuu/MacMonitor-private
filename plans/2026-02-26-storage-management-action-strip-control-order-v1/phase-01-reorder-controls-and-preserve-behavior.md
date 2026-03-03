# Phase 01: Reorder Controls and Preserve Behavior

## Context Links
- Plan: [plan.md](./plan.md)
- Target view: [StorageManagementView.swift](../../../MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
- Affected block: `selectionSummaryCard` (`~lines 277-443`)

## Overview
- Priority: P3
- Status: Pending
- Goal: Minimal UI-only reorder in action strip to Search -> Filter icon-only -> Delete icon-only.

## Key Insights
- Search behavior depends on `isSearchExpanded`, `isSearchFieldFocused`, and `.onChange`/`.onSubmit` collapse logic.
- Filter behavior is menu-driven via `StorageCleanupPreset` + `viewModel.applyPreset`.
- Delete behavior depends on `requestDeleteSelection`, `.disabled(!canDeleteSelection || isScanning)`, `.help(deleteInfoTooltip)`, and `isDeleting` progress indicator.

## Requirements
- Functional:
  1. Keep controls in the same action-strip area.
  2. Order controls left-to-right: Search, Filter, Delete.
  3. Render Filter as icon-only trigger.
  4. Render Delete as icon-only trigger.
  5. Preserve all existing behavior and state rules.
- Non-functional:
  1. Minimal diff, no unnecessary refactor (YAGNI/KISS/DRY).
  2. Keep styles and animations consistent with current component.

## Architecture
- Keep `selectionSummaryCard` as the single source of UI composition.
- Reorder existing control blocks within the same `HStack` rather than introducing new view models or new components.
- Preserve existing bindings/actions; only adjust layout sequence and visible labels/icons.

## Related Code Files
- Modify:
  - [StorageManagementView.swift](../../../MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. In `selectionSummaryCard`, keep the current summary text area and keep controls in the same container.
2. Move the existing search control block to be the first control in the control sequence.
3. Keep Filter as `Menu`, but change trigger to icon-only (`line.3.horizontal.decrease.circle`) while retaining preset menu items/checkmarks.
4. Change delete trigger to icon-only (trash icon) and keep action, disabled state, tooltip, and current color styling behavior intact.
5. Keep `ProgressView` behavior tied to `viewModel.isDeleting` and validate placement does not alter behavior expectations.
6. Build + tests:
   - `xcodegen generate`
   - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`

## Todo List
- [ ] Reorder controls to Search -> Filter -> Delete in `selectionSummaryCard`
- [ ] Convert filter trigger to icon-only without changing menu behavior
- [ ] Convert delete trigger to icon-only without changing delete behavior
- [ ] Verify search expand/collapse and focus behavior unchanged
- [ ] Verify delete disabled/tooltip/progress behavior unchanged
- [ ] Run build/tests successfully

## Success Criteria
- Control order visually reads left-to-right as Search, Filter icon, Delete icon.
- Search expand/collapse and query clear/collapse behavior still works.
- Filter menu presets still selectable and checkmark state remains correct.
- Delete action still opens confirmation flow; disabled state + tooltip + progress remain intact.
- No regressions from build/test run.

## Risk Assessment
- Risk: Reordering conditional search UI (`if isSearchExpanded`) may impact spacing/animation.
- Mitigation: Keep existing transitions/animations unchanged; only move block location.
- Risk: Icon-only controls can reduce clarity.
- Mitigation: Preserve existing `.help(...)` affordances and destructive color semantics.

## Security Considerations
- No auth/data-flow changes.
- Destructive operation safeguards remain unchanged (existing disabled logic + confirmation flow).

## Next Steps
- After implementation, perform quick manual UI check in Storage Management popover for normal + deleting + scanning states.
