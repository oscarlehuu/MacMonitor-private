## Executive Summary

Current regression is most likely a compound issue, not one single slow syscall.

Highest-confidence cause:
- `fix: improve storage workflows and live network reporting` on 2026-03-06 introduced 1 Hz `networkSample` publishing in `MetricsEngine`, which updates `SystemSummaryViewModel.snapshot` every second and forces broad UI work even when user is not on a network-focused screen.

Secondary cause:
- Memory tab still does an immediate heavy RAM/process refresh on popover open and on re-entering Memory. That path runs both a full libproc scan and a full `/bin/ps` scan before trimming to visible rows.

Impact fit:
- Slow popover open: default screen is Memory, so open path immediately starts RAM refresh.
- Slow tab switching: every 1 second network sample republishes `snapshot`, invalidating popover/menu-bar state while user interacts.
- App becomes broadly sluggish: the popover root is large and `snapshot`-driven; frequent repaints plus periodic heavy Memory work compound.

## Evidence

### 1. 1 Hz network sample republishes the whole summary model

`MetricsEngine` is `@MainActor` and schedules a network sampling tick every second:
- [MacMonitor/Sources/Core/Metrics/MetricsEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/MetricsEngine.swift#L4)
- [MacMonitor/Sources/Core/Metrics/MetricsEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/MetricsEngine.swift#L108)
- [MacMonitor/Sources/Core/Metrics/MetricsEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/MetricsEngine.swift#L139)

That tick replaces `latestSnapshot`, even for network-only changes:
- [MacMonitor/Sources/Core/Metrics/MetricsEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/MetricsEngine.swift#L145)

`SystemSummaryViewModel` consumes that publish and always assigns `snapshot = mergedSnapshot`:
- [MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift#L97)
- [MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift#L105)

This means the whole popover’s observed model changes every second, even outside Memory/Storage/Trends use cases.

### 2. `getifaddrs` itself is cheap; the invalidation fan-out is the expensive part

Local micro-benchmark on this machine:
- `NetworkCollector`-equivalent `getifaddrs` loop x1000: avg `0.017ms`

So the likely regression is not raw network-counter collection time. It is the cost of publishing a new top-level snapshot every second into a large SwiftUI tree plus related observers.

Relevant read path:
- [MacMonitor/Sources/Core/Metrics/Collectors/NetworkCollector.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Metrics/Collectors/NetworkCollector.swift#L14)

### 3. Every snapshot update also re-renders menu bar state on main

`MenuBarController` subscribes to `viewModel.$snapshot` and re-renders the status item on every snapshot change:
- [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L118)
- [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L156)

This is not enough alone to explain “nearly unusable”, but it adds steady main-thread work on every 1 Hz sample.

### 4. Popover open always starts the RAM details engine

On popover appear:
- `ramDetailsViewModel.start()`
- `storageManagementViewModel.loadIfNeeded()`

References:
- [MacMonitor/Sources/Features/Popover/PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift#L349)
- [MacMonitor/Sources/Features/Popover/PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift#L355)
- [MacMonitor/Sources/Features/Popover/PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift#L356)

Default normalized screen is Memory:
- [MacMonitor/Sources/Features/Popover/PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift#L3039)

So first popover open tends to land on the heaviest tab.

### 5. Memory refresh is materially expensive

`RAMDetailsViewModel.start()` immediately calls `refresh()` when active:
- [MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift#L92)
- [MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift#L96)

`performProcessRefresh()` does two broad scans before trimming:
- same-user scan via libproc
- all-discoverable scan via `/bin/ps`

References:
- [MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift#L384)
- [MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift#L395)
- [MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift#L16)
- [MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift#L49)

Local micro-benchmarks on this machine:
- collector-like same-user libproc path: avg `3.405ms`
- collector-like `/bin/ps` all-discoverable path: avg `129.697ms`

That makes Memory re-entry visibly expensive even without any network issue.

### 6. The worst regression path was introduced on 2026-03-06

Commit history:
- `269e05b` / `8936177` on 2026-03-06 added live 1 Hz network sampling and network-only snapshot publishing.
- In those commits, `SystemSummaryViewModel` also wrote app-group snapshot data on every `networkSample`, which would have added disk I/O every second.

Evidence from commit diff:
- `git show 8936177 -- MacMonitor/Sources/Core/Metrics/MetricsEngine.swift MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`

Current working tree no longer writes app-group data for `networkSample`:
- [MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift#L106)

So if the installed app predates the Mar 8 follow-up fixes, the released binary may be worse than current source.

### 7. Popover-show retry code is not the primary cause

`showPopoverWhenReady()` has retry loops, but normal menu-bar click uses `showPopover()`, not the delayed reopen path:
- [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L101)
- [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L108)
- [MacMonitor/Sources/Features/MenuBar/MenuBarController.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/MenuBar/MenuBarController.swift#L367)

This path may affect reopen/relaunch behavior, but it does not explain slow tab switching across an already-open popover.

## Root Cause Assessment

Most likely root cause chain:
1. Mar 6 change added 1 Hz live network sampling.
2. Each network tick republishes the top-level `snapshot`.
3. `snapshot` drives both popover UI and menu-bar rendering.
4. The popover root is large, so constant invalidation adds interaction jank.
5. Opening or returning to Memory piles on a heavy RAM refresh that includes a `/bin/ps` pass.

Confidence:
- High: frequent top-level snapshot invalidation is contributing.
- High: Memory tab refresh path is expensive enough to make open/re-entry feel slow.
- Medium: severity depends on whether the user’s installed build still includes the per-second app-group file write from the Mar 6 commit series.

## Suggested Fix Direction

1. Decouple live network rate from the top-level `SystemSummaryViewModel.snapshot`.
2. Keep network sampling local to the menu bar / network-specific surfaces, or publish a smaller network-only observable that does not invalidate the whole popover.
3. Do not refresh Memory details on popover open unless Memory tab is actually visible and foregrounded.
4. In Memory refresh, avoid always computing both same-user and all-discoverable sets up front; compute only the active scope, and only compute all-discoverable on demand.
5. If any shipped build still includes `appGroupSnapshotStore?.write(...)` on `networkSample`, remove that first.

## Supporting Measurements

Executed locally during investigation:
- `network getifaddrs x1000: total 0.017s avg 0.017ms`
- `mine collector-like x5: lastCount 517 total 0.017s avg 3.405ms`
- `allDiscoverable collector-like x5: lastCount 846 total 0.648s avg 129.697ms`

## Unresolved Questions

- Exact installed build Oscar is running: unreleased local build vs binary that still contains the Mar 6 per-second app-group write path.
- Whether there is an additional runtime hotspot inside SwiftUI body recomposition not visible from static analysis alone.
