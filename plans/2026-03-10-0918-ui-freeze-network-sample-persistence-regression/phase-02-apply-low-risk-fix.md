# Context Links
- [plan.md](./plan.md)
- [SystemSummaryViewModel.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift)

# Overview
- Priority: P1
- Status: In Progress
- Brief: Remove the blocking persistence side effect from the `networkSample` branch.

# Key Insights
- The shared snapshot store is for cross-process/widget consumption, not immediate in-popover rendering.
- Writing it once per full refresh preserves expected summary history behavior without per-second UI stalls.

# Requirements
- Do not change `MetricsEngine` refresh reasons in this phase.
- Do not change history append semantics.

# Architecture
- `MetricsEngine` still emits `.networkSample`.
- `SystemSummaryViewModel` still updates `snapshot`.
- Only non-network refresh reasons persist to shared storage.

# Related Code Files
- Modify: `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift`

# Implementation Steps
1. Keep merged snapshot assignment.
2. Return early on `.networkSample` before shared snapshot persistence.
3. Leave full refresh persistence path intact.

# Todo List
- [ ] Patch `SystemSummaryViewModel`.
- [ ] Re-read for unintended behavior drift.

# Success Criteria
- Live network sample still updates current snapshot.
- Per-second shared snapshot writes stop.

# Risk Assessment
- Low: widget/app-intent network freshness becomes interval-based instead of per-second.

# Security Considerations
- No new persistence surface.

# Next Steps
- Add test coverage for shared snapshot persistence behavior.

# Unresolved Questions
- None.
