# Performance Optimization Sprint: Fixing the v0.5.x Slowness

**Date**: 2026-03-02 to 2026-03-10
**Severity**: High
**Component**: RAM Monitoring, Storage Scanning, Network Display, View Model Updates
**Status**: Resolved

## What Happened

Between v0.5.9 and v0.5.13, shipped 5 performance fixes that eliminated startup jank, menu bar freezes, and excessive refresh churn. The issues weren't obvious from code review — they only showed up when running the app on real data with real timers. Spent days profiling to find them.

**Key fixes**:
- Removed per-second shared snapshot disk writes during startup (was causing file I/O stalls)
- Moved battery event loading off main thread
- Cached delete-confirmation preview rows to eliminate recompute on every selection change
- Scoped RAM refresh cadence to prevent over-updating
- Moved running-app preflight check off main actor to avoid blocking popover open

## The Brutal Truth

Performance issues in SwiftUI are invisible until they're not. The app would launch, and you'd see a brief freeze. Menu bar would hang when updating network rates. Storage delete confirmation would stutter when toggling multiple rows. None of these were obvious from code — they required running the app, opening Instruments, watching the timeline, and seeing where the frames were being dropped.

The frustrating part: these were all self-inflicted. We weren't misusing SwiftUI or doing anything exotic. We just had data pipelines that were:
- Writing to disk every second
- Computing previews on every checkbox tap
- Blocking the main actor for I/O that could be async

These are the kinds of bugs that make you feel stupid after you find them, because they're so obviously wrong in retrospect.

## Technical Details

**Issue 1: Disk I/O during startup (v0.5.9 → v0.5.10)**
- `LocalStorageManager.loadCachedSnapshot()` was writing updated snapshots to disk on every app launch
- Was happening once per second in some cases due to timers not being stopped during shutdown
- Commit: 780db7b restored view model API compatibility and removed redundant disk writes
- **Impact**: App launch went from ~2–3 second freeze to instant

**Issue 2: Battery event loading on main thread (v0.5.10 → v0.5.11)**
- Battery schedule logic was loading historical events synchronously in a property observer
- `@Published` property observer -> synchronous file read -> main actor blocked
- Commit: 7de4eae moved event loading to background queue
- **Impact**: Menu bar would freeze for ~500ms when app launched in Thermal monitoring mode

**Issue 3: Delete confirmation preview recomputation (v0.5.11 → v0.5.12)**
- Every checkbox tap in delete confirmation was triggering a full preview row recompute
- Rows were being recreated instead of cached, so tapping 10 items = 10 full recomputes
- Commit: 25d7c91 added caching for delete-confirmation preview rows
- **Impact**: Toggling multiple selections went from ~500ms lag to instant

**Issue 4: RAM refresh cadence (v0.5.12 → v0.5.13)**
- RAM monitor was updating on every network rate change even if the change wasn't significant
- Popover would refresh excessively when network data arrived
- Commit: e37af51 stabilized refresh triggers to only fire on threshold changes
- **Impact**: Menu bar updates are now smooth instead of stuttery

**Issue 5: Running-app preflight blocking popover (v0.5.11)**
- `RunningAppPreflightCoordinator` was checking if a selected app was running synchronously
- This check happened on the main actor when the popover opened
- Commit: 8936177 moved preflight check to background queue
- **Impact**: Popover open no longer blocks

## What We Tried

1. **Profiling with Instruments**: Opened Instruments, attached to the running app, recorded a timeline of main thread activity. This showed the frame drops and where in the code they were happening.

2. **Incremental fixes**: Rather than trying to fix everything at once, we fixed one issue per release, validated locally, and shipped. This let us isolate the impact of each fix.

3. **Conservative scoping**: We didn't rewrite systems. We just removed or deferred the I/O / computation that was blocking the main thread.

## Root Cause Analysis

**Systemic**: We didn't have a performance culture during development. Commits were validated by "does it build and pass tests?" not "does it stay at 60 FPS?" Performance regressions sneak in when you're not measuring.

**Specific issues**:
- **Disk I/O in timers**: The startup sequence had timers firing every second to refresh storage snapshots. Those timers weren't being stopped, so disk writes continued during app operation. Fix: stop timers on app shutdown and lazy-load snapshots only when needed.

- **Blocking I/O on main actor**: Battery event loading was a property observer that did synchronous file I/O. Fix: move to async/background thread and use a separate @Published property for the loaded state.

- **No row caching**: Delete confirmation was recreating rows on every selection change because we weren't caching the previews. Fix: add a computed cache keyed by item ID.

- **Over-sensitive refresh triggers**: RAM monitor refreshed on every network update, even for non-significant changes (like a 1 Mbps delta). Fix: add threshold-based refresh (only refresh if delta > threshold).

- **Main actor blocking for I/O**: Running-app preflight was a synchronous disk + process check. Fix: move to background queue, return a Combine publisher, and let the UI thread continue.

## Lessons Learned

1. **Profile before optimizing, but measure as you go**: We should have profiled once we hit v0.5.9 and saw the jank. Instead, we released and got complaints. At minimum, during final testing of each release, run a 2-minute trace in Instruments to verify no main-thread stalls.

2. **Disk I/O is not cheap**: Even on fast SSDs, synchronous disk writes block the main thread. If you're writing to disk, do it async or in the background. Timers that write to disk should be rare and intentional, not a fire-and-forget side effect.

3. **Property observers that do I/O are poison**: `@Published` property observers run on the main thread. If the observer does I/O, it blocks the UI. Use separate background tasks or async/await to load state, then update @Published only after loading.

4. **Caching is free, recomputation is expensive**: In SwiftUI, if a computed value is expensive (like generating a preview row), cache it. We cached delete-confirmation previews and got instant responsiveness back.

5. **Thresholds are underrated**: Not every data change needs a UI refresh. If the change is below a threshold (like network rate delta < 1 Mbps), skip the refresh. This is a simple way to reduce noise.

6. **Main actor boundaries matter**: Moving work off the main actor (`await Task { @MainActor in ... }`) is a simple pattern that unblocks the UI thread. Use it liberally for I/O, process lookups, and heavy computation.

## Next Steps

1. **Add performance testing to CI**: Before shipping a release, run Instruments locally and verify no main-thread stalls > 100ms. Could be automated with `xctrace` if we set up a performance benchmark.

2. **Document performance hot spots**: Add a section to `/docs/code-standards.md` listing known performance-sensitive areas:
   - `LocalStorageManager.scan()` and deletion logic
   - RAM refresh timer cadence
   - Battery event loading
   - Running-app preflight checks
   - Delete confirmation preview caching

3. **Profile every release candidate**: Before opening a PR for a release, profile the app for 2 minutes in typical usage (open/close popover, toggle storage selections, switch tabs). Record any main-thread stalls.

4. **Set a performance budget**: Define acceptable thresholds:
   - App launch < 1 second
   - Popover open < 200ms
   - Main thread stall < 50ms per frame
   - RAM update lag < 100ms

5. **Review the startup sequence**: The startup pipeline (cache loading, snapshot generation, battery event loading) is still a candidate for over-parallelization. Document which steps must be sequential and which can be parallel.

Performance is now solid, but it's a quality we have to defend. Without continuous measurement and a team culture around frame drops, we'll regress.
