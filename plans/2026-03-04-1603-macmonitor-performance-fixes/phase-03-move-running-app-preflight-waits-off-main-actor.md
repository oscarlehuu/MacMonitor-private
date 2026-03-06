# Context Links
- Plan: [plan.md](./plan.md)
- Related source: `MacMonitor/Sources/Core/Storage/RunningAppPreflightCoordinator.swift`, `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`

# Overview
- Priority: P1
- Status: Done
- Description: remove UI freeze risk in delete flow by moving preflight wait/poll work off main actor where safe.

# Key Insights
- Preflight coordinator is main-actor isolated end-to-end; wait loop currently runs on main-actor path.
- AppKit APIs (`NSWorkspace` / `NSRunningApplication`) should stay on main actor; polling process liveness can run off-main.

# Requirements
- Functional: preserve outcomes (`notRunning`, `terminatedGracefully`, `forceTerminated`, `stillRunning`) and force/skip flow.
- Non-functional: UI remains responsive during long quit waits.

# Architecture
- Keep running-app resolution + terminate/force calls on main actor.
- Shift timeout polling to non-main path using PID liveness checks (`kill(pid, 0)` style) + async sleep.
- Preserve existing timeout/poll-interval behavior and item ordering.

# Related Code Files
- Files to modify:
  - `MacMonitor/Sources/Core/Storage/RunningAppPreflightCoordinator.swift`
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
  - `MacMonitor/Tests/RunningAppPreflightCoordinatorTests.swift`
  - `MacMonitor/Tests/StorageManagementViewModelTests.swift`
- Files to create: none
- Files to delete: none

# Implementation Steps
1. Refactor coordinator internals to separate AppKit-bound operations from wait/poll operations.
2. Introduce liveness-check abstraction for deterministic tests (default: PID probe).
3. Keep `StorageManagementViewModel` delete-state transitions unchanged; ensure cancellation safety.
4. Add tests validating timeout/termination outcomes and unchanged delete-flow decisions.

# Todo List
- [x] Separate main-actor AppKit calls from off-main waiting loop.
- [x] Use PID-based liveness polling during wait windows.
- [x] Verify graceful/force/skip outcomes still map exactly to existing user messages.
- [x] Add regression tests for timeout and force-quit branches.

# Success Criteria
- Delete flow no longer stalls UI during app quit waits.
- Force-quit confirmation logic and deletion result messaging remain unchanged.

# Risk Assessment
- Risk: PID liveness edge cases (permission/state race) alter outcomes.
- Mitigation: keep conservative mapping and backstop with existing + new unit tests.

# Security Considerations
- No expanded permissions.
- Keep process operations constrained to already-selected app items only.

# Next Steps
- Run full validation in Phase 4.
