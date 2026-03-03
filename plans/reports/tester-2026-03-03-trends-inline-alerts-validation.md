# Trends Inline Alerts Validation (2026-03-03)

## Test Results Overview
- Command: `xcodegen generate`
- Result: pass
- Command: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Result: pass
- Tests: 143 run, 143 passed, 0 failed, 0 skipped (per xcodebuild summary)

## Coverage Metrics
- Source: `xcrun xccov view --report --json <xcresult>`
- Line coverage (overall): 31.51% (9144/29022)
- Function coverage (overall, executionCount>0 heuristic): 49.44% (1640/3317)
- Branch coverage: N/A (Xcode xccov report does not expose branch metric directly)

## Failed Tests
- None

## Performance Metrics
- Test execution (suite body): 2.635s
- End-to-end xcodebuild test elapsed: 3.933s
- Slowest observed individual tests in log: ~0.10-0.11s range (no acute perf issue)

## Build Status
- Build + test status: success
- Non-blocking warnings noticed:
  - Destination selection warning: multiple matching macOS destinations, first selected
  - Sparkle runtime warning about gentle reminders in background app
  - Test-time environment logs from storage tests (`DetachedSignatures`, scoped bookmarks) but tests still pass

## Critical Issues
- No compile/test blocker found.
- Regression risk in Trends inline alert presentation logic:
  - `TrendsView` only checks `recentSystemAlerts.first` and only shows inline when that single alert matches the card kind ([TrendsView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Trends/TrendsView.swift:55), [TrendsView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Trends/TrendsView.swift:167)).
  - Alert engine can emit multiple alert kinds in one evaluation in fixed order thermal->storage->ram->battery ([SystemAlertPolicyEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift:42), [SystemAlertPolicyEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift:55), [SystemAlertPolicyEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift:69), [SystemAlertPolicyEngine.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Alerts/SystemAlertPolicyEngine.swift:83)).
  - ViewModel prepends full alert batch to `recentSystemAlerts` ([SystemSummaryViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift:274)).
  - Net effect: when multiple kinds trigger same cycle, only first kind can render inline; matching alerts for other cards can be suppressed.

## Recommendations
1. In `TrendsView`, resolve per-card alert via first match in `recentSystemAlerts` (not only `first`).
2. Add tests for trend alert routing behavior (single alert, multi-alert same tick, stale older alert fallback).
3. Keep new `SystemAlertPolicyEngineTests` and add ordering/combination assertion to lock alert precedence intentionally.

## Next Steps
1. Decide intended UX: one-inline-alert-only vs one-per-card when multiple active alerts.
2. If one-per-card intended, patch `TrendsView` lookup and add tests before merge.
3. If one-only intended, document precedence in code comments/tests to avoid future confusion.

## Unresolved Questions
- Should Trends show only latest alert globally, or latest relevant alert per card?
