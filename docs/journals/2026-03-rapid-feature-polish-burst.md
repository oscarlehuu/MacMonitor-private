# March 2-3 Rapid Feature Polish Burst: Making It Real

**Date**: 2026-03-02 – 2026-03-03
**Severity**: Medium (scope creep + intense sprint)
**Component**: UI/UX across memory, alerts, settings, popover
**Status**: Completed

## What Happened

In a two-day sprint (March 2-3), I executed 15 feature plans back-to-back. This wasn't planned upfront — it emerged from realizing the app had functional features but looked unpolished and felt broken. Settings didn't work. Alerts had no thresholds. The popover was fixed-width. RAM metrics didn't match Activity Monitor. Over 48 hours, I went full feature-completion mode, treating each rough edge as a blocker.

The exhausting part: constantly switching contexts between memory formatting, alert configuration, settings wiring, and popover resizing. No feature was complex on its own, but the sheer volume + context switching meant sleep deprivation and a lot of "wait, did I test this everywhere?" moments.

## Key Changes

**Memory & Performance:**
- Aligned RAM metrics exactly to Activity Monitor (physical vs. theoretical)
- Added compact RAM details view with search + port inspection
- Memory free alignment + launch screen routing fixes

**Alerts & Thresholds:**
- Fixed dead alert settings paths (traced unwired/hidden controls, rewired or deprecated them)
- Added thermal pressure threshold input to alerts
- Added RAM threshold input to alerts
- Custom highlight color for exceeded thresholds (color picker UI)

**Settings & Configuration:**
- Unified adaptive diagnostics card in general settings
- Gated advanced battery settings behind helper availability check
- Legacy preset color compatibility maintained in color picker

**Popover & UI:**
- Removed icon-only menu bar option, defaulted to both percent + usage display
- Implemented drag-resizable popover width (3 separate plans to get jitter/edge-detection right)
- Inline alert indicators in trend cards

## The Brutal Truth

I had no sprint plan for this. I just kept finding things that looked half-broken and fixed them. That's not scalable. By hour 20, I was making decisions on muscle memory ("does this look right?") instead of careful thought. The popover resize took 3 plans to stabilize — jitter on the first attempt, edge detection off on the second — because I was rushing.

The worst part: I shipped changes to alert thresholds without fully documenting what "exceeded" means for thermal pressure. Is it per-core? System average? I wired the UI but didn't nail down the semantics. That's going to bite me when someone reports a confusing threshold.

## Technical Details

**RAM Alignment (activity-monitor-ram-metrics-ui-alignment)**
- Changed from theoretical used RAM (allocated) to physical resident memory
- Calculation: `(total - inactive - cached) = active + wired`
- Activity Monitor shows this same value; users expect consistency

**Dead Settings Paths (settings-alerts-advanced-battery-fix-investigation)**
- `@ObservedObject var batteryHelper` was initialized but never wired to state updates
- Advanced battery section was hidden by default but not gated to availability
- Either: fix the binding (hard, requires async context propagation) or hide it when helper unavailable (done)

**Popover Resize Issues**
- First plan: simple drag tracking worked but had 2-3 frame jitter at start
- Second plan: added velocity damping, introduced lag on release
- Third plan: fixed by deferring width update to next frame + gesture cancellation on edge-tap

## What We Tried

1. **Settings wiring**: Attempted to propagate battery helper state through ObservedObject — gave up, gated UI instead
2. **Popover width caching**: NSUserDefaults initially, switched to AppStorage for cleaner binding
3. **Alert color matching**: Started with preset system colors, realized users want custom colors, built color picker
4. **Thermal threshold semantics**: Looked at system frameworks, none exposed thermal pressure per-core — punted on clarification

## Root Cause Analysis

The core issue: I maintained a mental queue of "rough edges" without prioritizing. The moment I had sprint velocity (features flowing), I kept going. No one said "stop, wait for feedback" because I'm the only dev. That meant scope crept silently until I'd committed to 15 plans in two days.

Second: I didn't separate "finish implementation" from "polish UX" phases. They got tangled. I should have declared "phase 1: make it work, phase 2: make it feel right" with testing checkpoints between.

## Lessons Learned

**Process:**
- Sprint velocity without direction is dangerous. Create explicit phase gates.
- Context switching > 5 features per day tanks quality. I made dumb mistakes in hours 30+ of continuous work.
- Unfinished semantic decisions (like "what is thermal pressure threshold?") should block UI wiring, not follow it.

**Technical:**
- Small UI problems (color picker, resize handle edge detection) take longer than feature implementation. Budget for it.
- Setting controls that aren't wired should fail fast or be hidden. Don't let "looks working" mask non-functional code.

**People (solo dev):**
- I need external checkpoint discipline. Next time, ship a build, let it sit 2 hours, review with fresh eyes before continuing.
- "Making it feel real" is code for "I'm compensating for lack of direction with velocity." Dangerous pattern.

## Next Steps

1. **Document alert semantics**: Write what "thermal pressure threshold" means in settings help text. Is it instantaneous or averaged?
2. **Test matrix for settings**: Verify every alert threshold works (not just UI). Exercise with manual CPU/memory/thermal load.
3. **Review popover resize on real hardware**: Current fix works on simulator; need to test on actual M1/M2 machines for jitter regression.
4. **Retro on sprint planning**: Before next feature wave, write a one-page plan listing all planned features + estimated time. Enforce it.
