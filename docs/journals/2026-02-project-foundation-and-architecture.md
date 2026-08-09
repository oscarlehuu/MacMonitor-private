# Project Foundation and Architecture Plans (v1 Era)

**Date**: 2026-02-07 to 2026-02-08
**Severity**: Medium
**Component**: Project Architecture, Foundation Planning
**Status**: Resolved (all shipped)

## What Happened

Laid the foundation for MacMonitor across four major architectural initiatives spanning Feb 7–8. These weren't incremental tweaks — they defined what MacMonitor would be: a comprehensive system monitor built for Apple Silicon with strong safety guarantees and honest design.

**Thermal State Menu Bar v1** kicked off the core: a minimal macOS menu bar app monitoring RAM, storage, and thermal state using official Apple APIs. **RAM Process Management v1** extended that into a real workflow — process ranking by memory footprint, multi-select termination with strict safety guards, 5-second refresh. **RAM Policy Customization v1** added the "governor" layer: per-app RAM policies with percentage and absolute GB thresholds, immediate+sustained triggers, 7-day event logs. **Battery Management Apple Silicon v1** was the wildcard — privileged helper + XPC, charge limiter, discharge schedules, heat protection, and the framework for building out the full battery control surface across two phases.

All four shipped and merged by end of February. The decisions made in those two days shaped every line of code that followed.

## The Brutal Truth

This was planning as architecture. Every decision we made on Feb 7–8 was a bet on what MacMonitor needed to be three months out. We got it mostly right, but not because we were brilliant — we were ruthlessly conservative about scope.

The most honest thing: we deferred hard problems. Battery Group 2 (stop charging on sleep, calibration, LED control) went to "later" because we didn't want to ship a half-baked privileged helper. Storage termination (graceful→force) was scoped into "Phase 5" because we knew the 10-second timeout would be the real battle. We made those calls because shipping incomplete is shipping broken, and a broken battery helper is a revoked App Sandbox forever.

## Technical Details

**Key Architectural Decisions**

- **Apple Silicon only**: No Intel support. Narrowed the surface for thermal state, GPU/CPU readiness, and battery APIs. Paid off immediately.
- **Non-App-Store distribution**: Sparkle updater, signed/notarized .app, SMJobBless for privileged helper. Self-owned distribution chain meant we could ship features App Store would reject (XPC, root helpers).
- **Thermal state**: NSProcessInfoThermalState with manual polling fallback. Official, stable, no private APIs.
- **Process ranking**: ri_phys_footprint (resident memory), not vm_footprint or rss. Activity Monitor aligned, clear semantics.
- **Termination policy**: SIGTERM only, never SIGKILL. Self-protection (don't kill MacMonitor, pid ≤ 1, system processes), owned-only (don't kill processes you don't own), denylist (Finder, loginwindow, kernel_task). Errors on SIGTERM? Log it, don't escalate to force-kill.
- **Battery privileged helper**: SMJobBless with root. Charge limits (50%–95%), discharge rate control, schedule-based automation. XPC for safe IPC. All operations queued, bounded, validated against 3-generation OS history.
- **RAM policy scope**: Total app memory (all processes under that bundle). No per-process granularity — too complex, wrong semantics.

**What Got Built**

- Thermal State Menu Bar: 5 phases, all shipped (bootstrap → metrics → UI → packaging → snapshot)
- RAM Process Management: 4 phases, all shipped (data pipeline → protection policy + batch terminator → details UX → hardening)
- RAM Policy Customization: 5 phases, all shipped (domain → attribution → notify-only enforcement → UX → hardening)
- Battery Management: 5 of 6 phases shipped; phase 6 (deferred Group 2) awaiting later re-entry

## Lessons Learned

1. **Deferred scope is a feature, not a failure**: Battery Group 2 deferral didn't slow us down. It let us ship a rock-solid privilege helper without the complexity tax. Scope is a design tool.

2. **Safety is non-negotiable, complexity is**: We spent a full phase on "protection policy" for process termination. Worth every line. We could've shipped a simpler, faster quitter — but the denylist and self-protection logic prevented a entire class of crashes and data loss scenarios.

3. **Official APIs > private APIs, always**: NSProcessInfoThermalState looked risky at first (thermal monitoring via private magic), but it's the official entry point. ri_phys_footprint is undocumented but stable across generations. When you can't avoid it, document the assumption heavily and test across OS versions.

4. **Privilege is a contract, not a tool**: SMJobBless needs to be boring. Every operation (charge limit, discharge, schedule) goes through a queue, gets validated, gets bounded. That overhead felt real at first; it felt essential by mid-March when edge cases started appearing.

## Next Steps

None — this era is done and shipped. The foundation held. But the next person who reads this: these four v1 plans are the DNA of MacMonitor. Every feature that came later was building on top of these decisions. If you're changing RAM termination policy or battery helper scope, re-read these plans and understand why each guard exists.

The architecture shipped in Feb 2026 was conservative. It was right to be.
