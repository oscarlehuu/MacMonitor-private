# Context Links
- Plan: [plan.md](./plan.md)
- Phases: [phase-01-cache-storage-delete-confirmation-preview-rows.md](./phase-01-cache-storage-delete-confirmation-preview-rows.md), [phase-02-scope-ram-refresh-cadence-on-memory-tab.md](./phase-02-scope-ram-refresh-cadence-on-memory-tab.md), [phase-03-move-running-app-preflight-waits-off-main-actor.md](./phase-03-move-running-app-preflight-waits-off-main-actor.md)

# Overview
- Priority: P1
- Status: In Progress
- Description: validate behavior parity and performance improvements before merge.

# Key Insights
- This work is performance-sensitive with subtle behavioral risk around deletion and tab refresh timing.
- Existing tests cover core delete/force flows and RAM operations; add targeted regressions only.

# Requirements
- Functional: no regressions in delete outcomes, selection behavior, RAM view interactions.
- Non-functional: measurable responsiveness improvement on tab switch and delete confirmation overlay.

# Architecture
- Keep validation lightweight: unit tests + build/test + focused manual profiling scenario.

# Related Code Files
- Files to modify:
  - `MacMonitor/Tests/StorageManagementViewModelTests.swift`
  - `MacMonitor/Tests/RAMDetailsViewModelTests.swift`
  - `MacMonitor/Tests/RunningAppPreflightCoordinatorTests.swift`
- Files to create: none
- Files to delete: none

# Implementation Steps
1. Add/update unit tests from phases 1-3.
2. Run compile/tests.
3. Manual smoke profile: large delete selection overlay + rapid tab switching + delete with running app.
4. Compare before/after behavior and confirm no UX drift.

# Todo List
- [ ] Run `xcodegen generate`.
- [ ] Run `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`.
- [ ] Manually verify: overlay responsiveness, tab-switch smoothness, delete-flow responsiveness.
- [x] Run focused regression suite: `StorageManagementViewModelTests`, `RunningAppPreflightCoordinatorTests`, `RAMDetailsViewModelTests`.
- [ ] Document any regressions and loop back to owning phase.

# Success Criteria
- All tests pass.
- No functional regressions observed in targeted flows.
- User-perceived jank/freeze reduced in the three target scenarios.

# Risk Assessment
- Risk: performance improves but behavior drift appears in edge cases.
- Mitigation: preserve contracts, expand only targeted tests, avoid broad refactors.

# Security Considerations
- Confirm no new process operations beyond existing allowed flows.

# Next Steps
- Mark plan phases in progress during implementation.
