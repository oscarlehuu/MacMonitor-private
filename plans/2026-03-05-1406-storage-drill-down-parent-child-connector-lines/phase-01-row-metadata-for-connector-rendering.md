# Phase 01 - Row Metadata for Connector Rendering

## Context Links
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- `MacMonitor/Sources/Core/Storage/StorageManagementModels.swift`
- `MacMonitor/Tests/StorageManagementViewModelTests.swift`

## Overview
- Priority: P1
- Status: pending
- Goal: expose minimal tree-structure metadata per `StorageListRow` so UI can draw connectors deterministically.

## Key Insights
- Current rows only carry `depth`, so connector continuity cannot be drawn reliably.
- `appendRows` already has sibling context; best place to compute connector metadata with near-zero behavior risk.

## Requirements
- Functional: each row provides enough info to render ancestor vertical lines + current elbow line.
- Non-functional: no change to selection, expansion, ordering, loading, or row identity.

## Architecture
- Extend `StorageListRow` with connector fields (example: `ancestorHasNextSibling: [Bool]`, `isLastSibling: Bool`).
- Compute fields in `appendRows` using sibling index and recursive ancestor state.
- Keep existing `id` and `depth` behavior unchanged.

## Related Code Files
- Modify: `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- Modify: `MacMonitor/Tests/StorageManagementViewModelTests.swift`
- Create: none
- Delete: none

## Implementation Steps
1. Add connector metadata fields to `StorageListRow`.
2. Update `flattenRows/appendRows` to propagate ancestor sibling continuity flags.
3. Keep recursion order and depth increments unchanged.
4. Add tests for nested rows validating connector metadata values.

## Todo List
- [ ] Add row connector metadata properties.
- [ ] Refactor `appendRows` recursion to compute metadata.
- [ ] Add/adjust tests for nested row metadata.

## Success Criteria
- Row metadata correctly represents tree continuity for at least 3-level nesting in tests.
- Existing tests around selection/expand behavior still pass.

## Risk Assessment
- Risk: accidental row-order/depth change.
- Mitigation: keep flatten algorithm shape identical; test row order and depth unchanged.

## Security Considerations
- No security impact (UI metadata only).

## Next Steps
- Feed metadata into row gutter rendering in SwiftUI (Phase 02).
