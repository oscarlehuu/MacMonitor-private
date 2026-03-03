# Phase 01: Remove Global Alert Banner and Add Inline Alert Rows in Trend Cards

## Context Links
- Plan: [plan.md](./plan.md)
- Trends UI: [TrendsView.swift](../../../MacMonitor/Sources/Features/Trends/TrendsView.swift)
- Alert source: [SystemSummaryViewModel.swift](../../../MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift)
- Alert model: [SystemAlertPolicyEngine.swift](../../../MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift)

## Overview
- Priority: P2
- Status: Completed
- Goal: Move alert presentation from a standalone Trends banner into the relevant trend card, above chart content.

## Key Insights
- The global Trends alert banner was removed from the screen root.
- Card-specific inline rendering now resolves by alert kind from the latest timestamp batch.
- This remained presentation-only; chart data and summary metrics were preserved.

## Requirements
- Functional:
  1. Remove the standalone alert card from Trends root layout.
  2. Show alert title/message inline only inside matching card, above chart area.
  3. Keep no inline alert row in normal/non-alert state.
  4. Preserve existing sparkline and `Avg/Peak/Points` outputs.
- Non-functional:
  1. Keep changes localized and minimal.
  2. No new subsystems or broad refactors.

## Architecture
- `TrendsView` remains composition owner.
- Add per-card optional `inlineAlert` input (or equivalent helper lookup by `SystemAlertKind`).
- Add a lightweight resolver (`TrendInlineAlertResolver`) to get the latest alert batch and map kinds to card slots.
- Reuse current alert style tokens (`PopoverTheme.orange`, `orangeDim`) for visual consistency.

## Related Code Files
- Modify:
  - [TrendsView.swift](../../../MacMonitor/Sources/Features/Trends/TrendsView.swift)
  - [SystemSummaryViewModelTests.swift](../../../MacMonitor/Tests/SystemSummaryViewModelTests.swift) (resolver behavior tests added)
- Create:
  - None
- Delete:
  - None

## Implementation Steps
1. Remove top-level standalone alert rendering block from `TrendsView.body`.
2. Add alert-kind mapping for each trend card (Memory->`ram`, Storage->`storage`, CPU->`thermal`, Battery->`batteryHealth`).
3. Extend `trendCard(...)` API with optional alert payload and render inline alert row directly above sparkline/collecting-state block.
4. Keep current chart branch and summary row logic unchanged.
5. If needed for readability/DRY, add a small helper to resolve latest alert by kind.
6. Build and run targeted tests, then full test command.

## Todo List
- [x] Remove separate Trends alert banner
- [x] Inject optional inline alert into card layout above chart area
- [x] Ensure no inline row in normal state
- [x] Preserve chart + summary stats behavior
- [x] Run `xcodegen generate`
- [x] Run focused `xcodebuild` tests
- [x] Run full `xcodebuild ... test`

## Completion Notes
- Inline per-card alert rows shipped and standalone Trends alert banner removed.
- Resolver utilities now target the exact latest alert batch and apply explicit kind-to-slot mapping.
- Tests updated to cover latest-batch resolver behavior and mapping outcomes.
- Full suite passed on `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`.

## Success Criteria
- No standalone alert card appears in Trends.
- Threshold alerts appear inline in relevant card only.
- Normal state has no inline alert row.
- Sparkline and summary metrics remain unchanged.
- Build/tests complete without new failures.

## Risk Assessment
- Risk: Incorrect mapping can place alert in wrong card or show none.
- Mitigation: Use explicit kind-to-card mapping and targeted manual checks.

## Security Considerations
- No auth, permissions, or data-persistence changes.
- Alert content remains existing app-generated strings.

## Next Steps
- None.
