## Code Review Summary

### Scope
- Files: `MetricsEngine.swift`, `NetworkSamplingCoordinator.swift`, `SystemSummaryViewModel.swift`, `MenuBarController.swift`, `PopoverRootView.swift`, `RAMDetailsViewModel.swift`, related tests
- LOC: ~314 changed lines across tracked files
- Focus: current uncommitted responsiveness regression fix
- Scout findings:
  - `snapshot.network` consumers are effectively menu-bar formatting + tooltip, so skipping popover-wide `networkSample` propagation is aligned with current call sites
  - `RAMDetailsView` now owns `start()`/`stop()` through `onAppear`/`onDisappear`; root-level refresh ownership is gone, but no regression coverage proves tab/popover lifecycle still gates refresh work correctly

### Overall Assessment
Direction is right: the diff removes the obvious 1 Hz popover invalidation path and avoids the expensive all-scope RAM refresh on the default same-user path. Main remaining risk is lifecycle correctness around the new off-main network sampler and the lack of tests around the new direct menu-bar update path.

### High Priority

1. `NetworkSamplingCoordinator.stop()` is not a hard lifecycle barrier, so stop/start can reuse stale throughput and a queued sample can still publish after stop.  
   Evidence: [MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift:15](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift#L15), [MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift:43](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift#L43), [MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift:51](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift#L51), [MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift:57](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift#L57), [MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift:76](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift#L76).  
   Impact: after `stop()`, `latestSnapshot` stays cached, so the next `MetricsEngine.refresh(.startup/.manual/.interval)` can surface old network rates before a fresh sample lands. Separately, `bootstrapWorkItem` / timer work already in flight has no generation check, so it can still call back into `MetricsEngine.applyNetworkSample` after the engine has been stopped. That is both lifecycle drift and a concurrency hole.

2. The new live-network behavior has no regression test at the integration point that now matters: `MenuBarController <- MetricsEngine.$latestSnapshot`.  
   Evidence: [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift:122](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L122), [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift:133](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L133), [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift:176](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L176), [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift:216](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L216), [MacMonitor/Tests/SystemSummaryViewModelTests.swift:183](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/SystemSummaryViewModelTests.swift#L183), [MacMonitor/Tests/MetricsEngineTests.swift:93](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/MetricsEngineTests.swift#L93).  
   Impact: existing tests prove engine publication and prove `SystemSummaryViewModel` now suppresses `networkSample`, but they do not prove the menu bar title/tooltip still update live, nor that the local merge keeps non-network fields stable. This is now the primary user-visible behavior; it should be locked with at least one focused test.

### Medium Priority

1. The review cannot treat this change as verified because the test gate is still red from infrastructure, not from code.  
   Evidence: [plans/2026-03-10-0918-ui-freeze-network-sample-persistence-regression/plan.md:20](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/plans/2026-03-10-0918-ui-freeze-network-sample-persistence-regression/plan.md#L20), [plans/2026-03-10-0918-ui-freeze-network-sample-persistence-regression/plan.md:27](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/plans/2026-03-10-0918-ui-freeze-network-sample-persistence-regression/plan.md#L27), [plans/reports/tester-2026-03-10-responsiveness-regression-validation.md:5](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/plans/reports/tester-2026-03-10-responsiveness-regression-validation.md#L5), [plans/reports/tester-2026-03-10-responsiveness-regression-validation.md:46](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/plans/reports/tester-2026-03-10-responsiveness-regression-validation.md#L46).  
   Impact: build passes, but targeted `xcodebuild ... test` runs still hang after launching the host app. That leaves the new coordinator/lifecycle code without executable proof, and it also weakens confidence in the newly edited tests themselves.

### Edge Cases Found by Scout
- Stop/start lifecycle:
  - stale cached network sample reused on restart until next collector tick
  - queued bootstrap/timer callback can outlive `stop()`
- Menu-bar-only live updates:
  - direct engine subscription is now the only path for live network title/tooltip refresh
  - no test covers that path
- RAM lifecycle ownership:
  - `PopoverRootView` no longer controls `ramDetailsViewModel`
  - current tests exercise `RAMDetailsViewModel` directly, not view mount/unmount driven refresh gating

### Positive Observations
- Suppressing `networkSample` inside `SystemSummaryViewModel` avoids the high-cost popover/history/app-group fan-out while preserving regular summary refresh behavior.
- `RAMDetailsViewModel.performProcessRefresh()` now avoids the eager same-user + all-discoverable double scan, which directly addresses the measured `/bin/ps` cost.

### Recommended Actions
1. Make `NetworkSamplingCoordinator` lifecycle-safe: clear cached state on `stop()` and guard callbacks with a generation/cancellation token.
2. Add a focused test around the new menu-bar integration path, ideally asserting live network text/tooltip changes without changing `SystemSummaryViewModel.snapshot`.
3. Add one lifecycle regression test covering RAM refresh ownership after the `PopoverRootView` change, or fix the hanging host-app test harness first and then add that coverage.
4. Resolve the hanging `xcodebuild ... test` runner before claiming the fix is validated.

### Metrics
- Type Coverage: not measured
- Test Coverage: not generated
- Linting Issues: not checked in this review

### Unresolved Questions
- What is causing the host-app test runner to stall before `xctest` execution.
- Whether the app has any runtime stop/start path for `MetricsEngine` besides app shutdown and tests; that decides how user-visible the stale-sample bug is.
