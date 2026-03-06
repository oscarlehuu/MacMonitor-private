# Context Links
- Plan: [plan.md](./plan.md)
- Related source: `MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`, `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`

# Overview
- Priority: P1
- Status: Done
- Description: prevent expensive RAM refresh work on tab re-entry and while Memory tab is inactive.

# Key Insights
- `ramDetailsViewModel.start()` is invoked from popover lifecycle, and Memory tab `onAppear` triggers extra refresh.
- Heavy process/port collection (`collectTopProcesses(limit: 10_000, ...)`) can fire unnecessarily on quick tab switches.

# Requirements
- Functional: Memory tab still updates quickly when actively viewed.
- Non-functional: reduce jank when switching tabs.

# Architecture
- Add explicit tab-visibility refresh control in `RAMDetailsViewModel` (`setActive(isActive:)`).
- Active tab: existing fast cadence; inactive tab: paused or throttled cadence.
- Gate immediate refresh on re-entry with freshness check (skip if recently refreshed).

# Related Code Files
- Files to modify:
  - `MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
  - `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
  - `MacMonitor/Tests/RAMDetailsViewModelTests.swift`
- Files to create: none
- Files to delete: none

# Implementation Steps
1. Add tab-active API + cadence state in `RAMDetailsViewModel`.
2. Move timer management behind the new API (single owner path).
3. Replace unconditional tab-entry refresh with `refreshIfStale` logic.
4. Wire `PopoverRootView` tab changes to this API using `activeTab` transitions.
5. Add tests for re-entry throttling and inactive-tab cadence behavior.

# Todo List
- [x] Add `setActive(isActive:)` + freshness guard in `RAMDetailsViewModel`.
- [x] Remove duplicate/unnecessary `start()/refresh()` calls tied to tab entry.
- [x] Add `onChange` tab wiring in `PopoverRootView` to toggle active refresh cadence.
- [ ] Add tests proving quick tab switches do not trigger extra heavy refresh.

# Success Criteria
- Tab switch to Memory feels immediate (no visible stutter from forced heavy refresh).
- Background tabs do not run unnecessary high-frequency RAM collection.

# Risk Assessment
- Risk: RAM data appears too stale after long inactive period.
- Mitigation: force one refresh when tab becomes active and data exceeds staleness threshold.

# Security Considerations
- No privilege or data-scope changes.

# Next Steps
- Proceed to Phase 3 for delete-flow preflight actor-path refactor.
