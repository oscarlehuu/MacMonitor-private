## Executive Summary

- `xcodebuild ... test` does launch the host app and does start targeted tests. The run looks hung because network-sampling tests time out, Xcode restarts the host app, and the cycle repeats.
- Primary local root cause: network sample delivery now reaches observers via `Task { @MainActor ... }` in [MetricsEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/MetricsEngine.swift#L106), while the affected tests are themselves `@MainActor` async tests waiting with `await fulfillment(...)` in [MetricsEngineTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/MetricsEngineTests.swift#L93) and [SystemSummaryViewModelTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/SystemSummaryViewModelTests.swift#L183). That combination prevents the enqueued main-actor work from being observed before timeout.
- Secondary repo-local amplifier: the host app still boots full production services under XCTest. Sample evidence shows [AppContainer.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/DI/AppContainer.swift#L181) driving battery reconciliation into [BatteryControlService.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/BatteryControl/BatteryControlService.swift#L48) and [BatteryEventStore.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/BatteryControl/BatteryEventStore.swift#L63), which reparses and rewrites a large `battery-events.jsonl` on startup.

## Repro + Evidence

- Minimal host-app test passes:
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/MetricsEngineTests/testStartPublishesStartupSnapshot test`
  - Result: `** TEST SUCCEEDED **`
- Focused repro of the problematic area:
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/MetricsEngineTests -only-testing:MacMonitorTests/SystemSummaryViewModelTests -only-testing:MacMonitorTests/RAMDetailsViewModelTests test`
- Observed failures during that run:
  - `MetricsEngineTests.testNetworkSamplingPublishesNetworkSampleSnapshot` timed out after only seeing `.startup`
  - `SystemSummaryViewModelTests.testNetworkSampleDoesNotRewriteSharedSnapshotSummary` timed out waiting for `.networkSample`
  - Xcode then logged `Restarting after unexpected exit, crash, or test timeout`
- Process evidence during the "hang" window:
  - `ps` showed host-app test processes plus Sparkle helper/updater children:
    - `MacMonitor` pids `7171`, `7253`
    - `Autoupdate` pid `7327`
    - `Updater` pid `7328`
- `sample 7253 5 1` evidence:
  - Hot path was not XCTest deadlock.
  - Heavy CPU was in `closure #1 in closure #3 in AppContainer.start()` -> `BatteryPolicyCoordinator.handle(snapshot:)` -> `BatteryControlService.execute` -> `FileBatteryEventStore.append/loadEvents`
  - Local data size at repro time: `~/Library/Application Support/com.oscar.macmonitor/battery-events.jsonl` was `18M`

## Technical Analysis

- The new network path is:
  - [NetworkSamplingCoordinator.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/NetworkSamplingCoordinator.swift#L24) collects on a background dispatch queue
  - [MetricsEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/MetricsEngine.swift#L106) hops delivery back with `Task { @MainActor ... }`
  - `latestSnapshot` mutation then happens in `applyNetworkSample`
- The failing tests are `@MainActor` async tests that wait with `await fulfillment(...)`:
  - [MetricsEngineTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/MetricsEngineTests.swift#L93)
  - [SystemSummaryViewModelTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/SystemSummaryViewModelTests.swift#L183)
- Result:
  - startup snapshot publishes synchronously
  - network sample callback is queued to the main actor
  - the test is suspended waiting for an expectation on that same actor
  - `.networkSample` never becomes visible before timeout, so Xcode reports timeout and restarts the host app
- Separate but relevant startup noise:
  - [AppDelegate.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/App/AppDelegate.swift#L21) always builds a real [AppContainer.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/DI/AppContainer.swift#L21) even under XCTest
  - [AppContainer.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/DI/AppContainer.swift#L181) starts menu bar, battery policy, storage loading, RAM policy monitor, lifecycle coordinator
  - sample shows that this startup noise is expensive enough to worsen the perception of a hung harness

## Recommendations

- Fix the failing tests first:
  - avoid `await fulfillment(...)` for these `@MainActor` network-sample tests
  - use run-loop polling / `assertEventually` or make the observation path not require a queued main-actor hop
- Then harden host-app test startup:
  - skip `AppContainer.start()` heavy production services under `XCTestConfigurationFilePath`
  - at minimum disable Sparkle updater launch and battery/storage policy startup in tests
- Performance cleanup worth doing anyway:
  - [BatteryEventStore.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/BatteryControl/BatteryEventStore.swift#L63) currently loads the whole JSONL file and rewrites it on every append
  - this makes repeated host-app launches much noisier when the event file has grown

## Unresolved Questions

- Whether you want the final fix to be test-only (`assertEventually`) or runtime-side (`MetricsEngine` delivery semantics).
- Whether to add an XCTest-specific startup guard in app bootstrap now, or handle that as a separate cleanup after unblocking tests.
