# Context Links
- Plan: [plan.md](./plan.md)
- Related source: `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`, `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`

# Overview
- Priority: P1
- Status: Done
- Description: Cache/memoize delete-preview rows/sections to remove repeated recomputation in confirmation overlay rendering.

# Key Insights
- Preview rendering currently rebuilds filtered rows/sections repeatedly via `rows(for:)`, `allLooseRows()`, and root-ID checks.
- Selection normalization/sorting is recomputed from scratch across multiple computed properties.

# Requirements
- Functional: keep preview ordering, selection toggles, and scope highlighting identical.
- Non-functional: reduce CPU spikes during confirmation overlay updates.

# Architecture
- Add a lightweight memoized preview snapshot in `StorageManagementViewModel` keyed by selection + expansion + drill-down state.
- `PopoverRootView` reads cached snapshot rather than recomputing group/loose previews in body helpers.

# Related Code Files
- Files to modify:
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
  - `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
  - `MacMonitor/Tests/StorageManagementViewModelTests.swift`
- Files to create: none
- Files to delete: none

# Implementation Steps
1. Introduce cached delete-preview data model in `StorageManagementViewModel` (root IDs + grouped rows + loose rows).
2. Add deterministic cache invalidation hooks where selection/expansion/drilled-items/item-index changes.
3. Replace overlay helper recomputation in `PopoverRootView` with cached snapshot reads.
4. Keep existing selection-interaction handlers unchanged to preserve behavior.
5. Add tests for ordering parity and invalidation correctness.

# Todo List
- [x] Add memoized preview snapshot API in `StorageManagementViewModel`.
- [x] Invalidate cache on refresh, selection changes, expansion changes, and drill-down completion.
- [x] Update delete confirmation overlay render path to consume memoized data.
- [ ] Add regression tests for preview order and parent/child visibility behavior.

# Success Criteria
- Overlay UI remains responsive for large selections.
- Preview content matches pre-refactor behavior exactly.

# Risk Assessment
- Risk: stale preview cache after deep selection mutation.
- Mitigation: centralize cache invalidation in one helper and assert with tests.

# Security Considerations
- No auth/data-sensitivity changes.
- Ensure no extra file paths are exposed beyond current UI behavior.

# Next Steps
- Feed this phase output into Phase 2 for tab-switch cadence reductions.
