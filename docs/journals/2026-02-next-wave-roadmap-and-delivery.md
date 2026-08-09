# Next-Wave Roadmap and Delivery Expansion (Feb 19–28)

**Date**: 2026-02-16 to 2026-02-28
**Severity**: Low
**Component**: Roadmap, Feature Planning, Architecture Expansion
**Status**: Resolved (all phases implemented locally)

## What Happened

After the foundation plans shipped in early February, we took stock and realized MacMonitor wasn't done being shaped. Over Feb 16–28, we planned the next major expansion across two separate initiatives.

**Storage Safety and Port Termination v1** (Feb 16) focused on a gap in the storage deletion workflow: graceful-then-force app termination. You can't delete app data if the app is still holding file handles or listening on network ports. The plan: 10-second graceful shutdown, 250ms polling intervals, fallback to force quit if the app doesn't cooperate. One dialog for all forced quits. Skip-only for declined terminations (don't delete the whole app just because one process refused to quit).

**Next-Wave Roadmap** (Feb 19) was bigger: six phases of features that transformed MacMonitor from a minimal thermal monitor into a comprehensive system monitor. Battery schedule UX and task lifecycle. Trends, alerts, and history architecture. CPU/network/GPU telemetry readiness. Battery Group 2 features (conditional charging, calibration). Widget and automation surfaces. Diagnostics export. All planned, all implemented locally during February, ready to ship.

This was the moment we went from "thermal state monitor with RAM details" to "full system monitor."

## The Brutal Truth

This was ambition hitting reality. The Feb 7–8 foundation was conservative and smart. But by mid-February, we could see the shape of the thing we wanted to build, and it was bigger than a thermal monitor.

The honest part: planning six phases of expansion in one week while simultaneously shipping the foundation felt reckless. We weren't sure battery schedule UX would work. We didn't know if trends architecture could scale. We were betting that CPU/network/GPU telemetry would be reliable. We planned them all anyway.

Why? Because deferring everything meant shipping an incomplete product. And we knew — from the Feb 7–8 foundation work — that deferred doesn't mean abandoned. It means planned, scoped, bounded. Group 2 battery features could be gated by feature flags. Trends and alerts could start minimal. The widget surface could ship read-only first. We were building a roadmap that could be shipped in pieces, not an all-or-nothing bet.

## Technical Details

**Storage Safety and Port Termination v1**

- **Graceful shutdown**: SIGTERM with 10s timeout
- **Polling interval**: 250ms check if process exited
- **Fallback**: Force quit via SIGKILL after timeout
- **Batch termination**: Single dialog for all processes needing force quit
- **Safety**: Skip-only mode (if user declines, skip that process, continue deletion)
- **Scope**: TCP LISTEN ports mode (RAM Ports) + app file handle detection
- Status: Planned (later superseded by storage redesign in March)

**Next-Wave Roadmap (6 Phases, All Implemented Locally)**

1. **Battery Schedule UX and Task Lifecycle** (100%)
   - Schedule builder: time ranges, repeat patterns, target state (charge/discharge/limit)
   - Task execution via privileged helper, state feedback, error handling
   - Sleep/wake synchronization

2. **Trends, Alerts, and History Architecture** (100%)
   - Time-series storage for RAM, storage, thermal, battery, network
   - Per-metric alert rules (threshold, sustained duration, cooldown)
   - 30-day history window with daily aggregation

3. **Expand Telemetry — CPU, Network, GPU Readiness** (100%)
   - CPU core usage and throttle detection
   - Network interfaces (active/inactive), bandwidth measurement
   - GPU core count, memory, utilization (readiness phase — no heavy tracking yet)

4. **Battery Group 2 Re-Entry** (100%, gated)
   - Stop charging on sleep (disable charger when system sleeps)
   - Disable sleep until charge limit reached
   - Calibration mode (full discharge + recharge for battery health)
   - LED control and state feedback
   - Feature-flagged, conditional on 3-generation validation

5. **Widget and Read-Only Automation Surface** (100%)
   - SwiftUI widgets for menu bar (summary, thermal, RAM, battery)
   - Automation intent handlers (query system state, query battery state)
   - No write operations (read-only by design)
   - Shortcuts integration ready

6. **Diagnostics Export and Release Hardening** (100%)
   - System state snapshot (JSON): thermal, battery, RAM, storage, network, CPU
   - Trends export (CSV): time-series data for analysis
   - Performance profiling instrumentation
   - Crash reporting and telemetry

## Lessons Learned

1. **Planning in waves prevents death march**: Week one (Feb 7–8) was conservative and focused. Week three (Feb 16–28) was ambitious but scoped across six achievable phases. We weren't trying to ship everything at once; we were mapping the terrain.

2. **Local implementation validates plans**: All six phases were implemented locally in February. That caught design problems before shipping. Battery schedule UX revealed that task lifecycle was complex. Trends architecture showed that 30-day history needed daily aggregation to avoid memory bloat. Widget surface forced us to think about read-only semantics.

3. **Feature gates are a design tool, not a hack**: Battery Group 2 is feature-flagged and gated by OS validation. That's not a compromise; it's responsible shipping. We could ship the infrastructure without the features, validate on real systems, then unlock the features when confident.

4. **Roadmap drives architecture**: The next-wave expansion forced us to realize we needed a trends engine, a task scheduler, an automation surface. Those aren't afterthoughts; they're foundational. The Feb 7–8 foundation couldn't have predicted them perfectly, but it was general enough to support them.

## Next Steps

All six phases implemented locally by end of February. From March onward: integration, hardening, release. The battery helper needed stabilization work (phase 5 was only 55% complete). Storage redesign was coming (Feb 16 plan got superseded by a UI rethink in March). Trends engine needed production-level testing. But the architecture was solid enough to build on.

MacMonitor went from "thermal state monitor" to "system monitor" because we planned conservatively in week one and ambitiously in week three. The combination worked.
