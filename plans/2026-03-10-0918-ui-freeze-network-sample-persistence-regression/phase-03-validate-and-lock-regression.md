# Context Links
- [plan.md](./plan.md)
- [AppDelegate.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/App/AppDelegate.swift)
- [MetricsEngineTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/MetricsEngineTests.swift)
- [SystemSummaryViewModelTests.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Tests/SystemSummaryViewModelTests.swift)

# Overview
- Priority: P1
- Status: Done
- Brief: Lock the regression with focused tests, shared-summary coverage, and stable XCTest execution.

# Key Insights
- Existing tests now cover both summary/history suppression and shared-summary non-rewrite on `networkSample`.
- XCTest host app had to stay inert to remove production startup work from targeted unit-test execution.

# Requirements
- Keep regression coverage focused on the network-sample path.
- Keep the XCTest host lightweight enough that targeted unit tests finish deterministically.

# Related Code Files
- Modify: `MacMonitor/Sources/App/AppDelegate.swift`
- Modify: `MacMonitor/Tests/MetricsEngineTests.swift`
- Modify: `MacMonitor/Tests/SystemSummaryViewModelTests.swift`

# Implementation Steps
1. Keep the host app inert when `XCTestConfigurationFilePath` is present.
2. Use focused expectations that do not block `@MainActor` delivery for network-sample tests.
3. Run targeted test suites and confirm they complete on a clean derived-data path.

# Todo List
- [x] Add regression test.
- [x] Run focused tests.
- [x] Run project build/test.

# Success Criteria
- Tests prove `networkSample` does not rewrite shared snapshot payload.
- Targeted verification completes without new failures.

# Risk Assessment
- Low: changes are test-only plus a guard that only activates under XCTest.

# Security Considerations
- Temp files only; no sensitive material.

# Next Steps
- If lag persists after this fix, profile remaining main-thread collectors separately.
- Consider pinning Debug signing explicitly later if stale local signing state reappears.

# Unresolved Questions
- None.
