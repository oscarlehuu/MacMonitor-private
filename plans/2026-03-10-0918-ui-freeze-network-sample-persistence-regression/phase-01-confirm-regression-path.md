# Context Links
- [plan.md](./plan.md)
- [SystemSummaryViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift)
- [AppGroupSnapshotStore.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/Persistence/AppGroupSnapshotStore.swift)

# Overview
- Priority: P1
- Status: Done
- Brief: Confirm the latest regression source before touching runtime behavior.

# Key Insights
- `networkSample` started writing to `AppGroupSnapshotStore` in commit `269e05b`.
- `AppGroupSnapshotStore.write(...)` uses `queue.sync`, builds projected history arrays, encodes JSON, then writes to disk.
- The call site is on `SystemSummaryViewModel`, which is `@MainActor`, so every per-second network sample can block the UI thread.

# Requirements
- Preserve live network snapshot updates for menu bar and popover.
- Avoid speculative refactors in unrelated collectors or tab code.

# Related Code Files
- Modify: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`
- Modify: `MacMonitor/Tests/SystemSummaryViewModelTests.swift`

# Implementation Steps
1. Keep the current `snapshot` update path for `networkSample`.
2. Remove shared snapshot persistence from the `networkSample` fast path.
3. Keep history append behavior unchanged for non-network refresh reasons only.

# Todo List
- [x] Trace commit introducing the regression.
- [x] Confirm blocking persistence behavior and affected files.

# Success Criteria
- Root cause is explicit and file-scoped.

# Risk Assessment
- Low: change is scoped to one branch in one view model.

# Security Considerations
- No auth or data-access scope changes.

# Next Steps
- Implement the narrow fix and add regression coverage.

# Unresolved Questions
- None.
