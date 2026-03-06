# Phase 03 - Validation and Regression Checks

## Context Links
- `MacMonitor/Tests/StorageManagementViewModelTests.swift`
- `README.md`

## Overview
- Priority: P1
- Status: pending
- Goal: confirm connector feature ships without regressions in core storage workflows.

## Key Insights
- Highest-risk areas are selection propagation and async child loading while rows are expanded.
- Existing `StorageManagementViewModelTests` already cover many regressions; extend minimally where needed.

## Requirements
- Functional: connectors present where expected.
- Regression: expand, selection propagation, and loading indicators still correct.
- Quality: project builds and relevant tests pass.

## Architecture
- Automated checks first, then short manual UI checklist.
- Keep test scope focused to maintain speed and confidence.

## Related Code Files
- Modify: `MacMonitor/Tests/StorageManagementViewModelTests.swift` (if new metadata assertions added)
- Create: none
- Delete: none

## Implementation Steps
1. Build app target.
2. Run storage-focused tests.
3. Run full test suite (or document why skipped).
4. Manual UI pass on storage drill-down interactions.

## Todo List
- [ ] Run: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' build`
- [ ] Run: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test -only-testing:MacMonitorTests/StorageManagementViewModelTests`
- [ ] Run: `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- [ ] Manual check: expand/collapse nested rows still works.
- [ ] Manual check: parent/child selection behavior unchanged.
- [ ] Manual check: "Loading children..." state still appears and aligns correctly.

## Success Criteria
- Build succeeds.
- Targeted tests pass.
- Full tests pass (or explicitly documented blocker).
- Manual checks confirm no UX regression.

## Risk Assessment
- Risk: false confidence if only manual checks done.
- Mitigation: keep at least targeted automated tests mandatory.

## Security Considerations
- No security impact.

## Next Steps
- Mark phases complete in `plan.md` as implementation progresses.

## Unresolved Questions
- none
