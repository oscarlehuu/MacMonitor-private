# Storage Evolution Feb 26 – Mar 5: Polishing Before the Pivot

**Date**: 2026-02-26 – 2026-03-05
**Severity**: Medium (effort absorption, strategy shift)
**Component**: Storage management UI/UX
**Status**: Superseded by Advisor v2 redesign

## What Happened

Over ~8 days (Feb 26 – Mar 5), I executed eight storage-specific improvement plans on the tree-based storage UI. Each plan was solid — better app icons, delete confirmation UX, visual hierarchy improvements. But by March 6, the decision to pivot to Storage Advisor v2 (flat-list redesign) meant most of this work was absorbed or discarded.

This wasn't wasted effort (some patterns transferred), but it's a hard lesson in feature velocity vs. strategic direction. I was optimizing the old architecture while the architecture itself was being questioned.

## Key Changes

**Feb 26 – Mar 3 (Incremental Improvements)**
- `storage-management-action-strip-control-order-v1`: Reordered delete/view/inspect buttons
- `storage-apps-remove-projection-and-header-actions-top-right`: Removed unused projections, moved header actions left
- `storage-apps-ui-improvements-app-icons-and-disk-bucket-colors`: App icons from system + disk bucket color coding
- `storage-delete-confirmation-ux-update`: Detailed delete confirmation with checkbox gate (are-you-sure pattern)

**Mar 5 (Hierarchy & UX Refinement)**
- `storage-delete-lock-selection-and-inline-progress`: Locked row selection during delete, inline delete progress indicator
- `storage-drill-down-parent-child-connector-lines`: Added visual connector lines for hierarchy (tree structure)
- `popover-default-collapse-memory-storage-summary-cards`: Defaulted summary cards to collapsed state
- `storage-drill-down-hierarchy-readability`: Improved spacing + indentation for visual hierarchy

## The Brutal Truth

I kept optimizing something that was fundamentally wrong. The tree-based storage UI was hard to understand — drilling into apps, sub-folders, and processes required too many taps. Connector lines and better spacing? Lipstick on a pig. They made it marginally less confusing, not genuinely usable.

The frustrating part: I *knew* the navigation model was clunky (users kept getting lost), but instead of redesigning it, I kept adding smaller UX polish. This is classic local optimization when global strategy should have changed.

More honest: I was afraid to scrap the working code and start fresh. Advisor v2 was a much bigger undertaking, so I delayed the decision by making the old thing slightly less bad.

## Technical Details

**Connector Lines (storage-drill-down-parent-child-connector-lines)**
- Implemented ZStack layering with custom Canvas drawing for lines
- Performance concern: Canvas recompute on every state change caused jank on large folder hierarchies (100+ items)
- Fixed with `.drawingGroup()` modifier, but still not optimal

**Delete Lock (storage-delete-lock-selection-and-inline-progress)**
- Needed to prevent row reordering during delete animation
- Solution: disable list selection during `.isDeleting` state
- Side effect: if delete fails, UI stayed locked until timeout (timeout solution is fragile)

**App Icon Loading (storage-apps-ui-improvements-app-icons-and-disk-bucket-colors)**
- Used NSWorkspace to fetch app icons on main thread
- Result: slight UI freeze on first load of large app lists (50+ apps)
- Added caching, but never implemented background loading (would have fixed it properly)

## What We Tried

1. **Hierarchy readability**: Tried different indentation levels (8px, 16px, 24px). Settled on 16px but users still got lost.
2. **Delete confirmation**: First version just had a delete button. Added checkbox gate "I understand I'm deleting X GB". Helped a bit.
3. **Navigation alternatives**: Sketched search + flat list in plan notes (mar 5), realized it was a bigger lift, shelved it.
4. **Canvas performance**: Tried Custom shapes, drew lines, performance still bad. Gave up when Advisor v2 plan was approved.

## Root Cause Analysis

**Why this happened:**
- I treated symptoms (poor readability) instead of the disease (wrong information architecture)
- Tree navigation works for folder structures; it doesn't work for "drill down into an app to see processes and their open ports" — that's a different mental model
- I optimized without user feedback. Should have tested on users or sketched prototypes before shipping incremental changes

**Why the pivot happened:**
- By early March, it became clear that Advisor v2 (flat list with explainable recommendations) was a better fit for the use case
- Flat list solves the navigation problem by eliminating hierarchy navigation entirely
- This invalidated most of the Feb 26 – Mar 3 work (hierarchy polish is pointless if hierarchy goes away)

## Lessons Learned

**Strategy:**
- If you're making >3 incremental improvements to a feature without user feedback or a clear strategy, pause and ask: "Is the core model right?"
- Polishing a flawed architecture buys time but destroys momentum. Better to pivot early.
- Tree-based navigation is not a universal solution. For "understand what's using space," flat list + filtering is stronger.

**Technical:**
- Canvas drawing on main thread kills performance at scale. Would have been faster to just implement Advisor v2 from the start.
- App icon loading should be async + cached from day one. Blocking the main thread on system calls is a rookie mistake I repeated.

**Process:**
- When a feature lands and users/you find it confusing, that's a signal to redesign, not polish. Resist the urge to add "just one more" UX improvement.
- Document why a feature exists (the mental model). If the model feels wrong, don't optimize the interface — fix the model.

## Next Steps

1. **Retire old code**: Clean up tree-based storage UI once Advisor v2 is stable. Don't maintain two implementations.
2. **Port lessons**: App icon async loading + Canvas caching patterns should be applied to Advisor v2 if it uses similar components.
3. **Future feature velocity**: Before starting incremental improvements, write a one-sentence design principle (e.g., "Users should find & delete space in <3 taps"). Evaluate changes against it.
