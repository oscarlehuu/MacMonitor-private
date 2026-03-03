# Context Links
- [Plan overview](./plan.md)
- [Phase 1](./phase-01-remove-icon-only-user-options-and-default-to-both-percent-usage.md)
- `MacMonitor/Tests/SettingsStoreTests.swift`
- `README.md` (test command)

# Overview
- Priority: P2
- Status: Pending
- Description: Add regression tests to prove defaults and persisted `icon` compatibility work as intended.

# Key Insights
- Existing tests cover persistence and one legacy migration path, but not default mode/format expectations for this new requirement.
- Existing formatter tests include `.icon`; these can remain if `.icon` is retained for compatibility.

# Requirements
- Functional requirements:
  - Test fresh defaults: `menuBarDisplayMode == .both`, `menuBarMemoryFormat == .percentUsage`, `menuBarStorageFormat == .percentUsage`.
  - Test persisted current-key `"icon"` migrates to `.both`.
  - Test legacy format migration behavior remains unchanged.
- Non-functional requirements:
  - Fast deterministic tests under `SettingsStoreTests`.
  - No flaky runtime dependencies.

# Architecture
- Extend `SettingsStoreTests` with focused cases for new defaults and `icon` migration.
- Keep migration tests using isolated `UserDefaults(suiteName:)` instances.
- Execute targeted tests first, then full suite if needed.

# Related Code Files
- Files to modify:
  - `MacMonitor/Tests/SettingsStoreTests.swift`
  - `MacMonitor/Tests/MenuBarDisplayFormatterTests.swift` (only if migration strategy changes icon-path expectation)
- Files to create:
  - None
- Files to delete:
  - None

# Implementation Steps
1. Add `testDefaultMenuBarSettingsPreferBothAndPercentUsageFormats`.
2. Add `testHydratesPersistedIconDisplayModeAsBothForCompatibility`.
3. Keep/adjust legacy migration expectations where required.
4. Run targeted tests:
   - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/SettingsStoreTests test`
5. Run full test command from README if targeted tests pass.

# Todo List
- [ ] Add defaults regression test.
- [ ] Add persisted icon migration test.
- [ ] Execute targeted tests and capture result.
- [ ] Execute full suite/build verification.

# Success Criteria
- New tests pass and clearly encode expected migration/default behavior.
- No regression in existing settings migration coverage.

# Risk Assessment
- Risk: Test expectations mismatch existing migration semantics.
- Mitigation: Align tests directly to required user-facing behavior; keep legacy coverage explicit.

# Security Considerations
- No direct security impact.
- Preserve deterministic test isolation to avoid cross-test leakage.

# Next Steps
- After implementation, mark phase statuses and sync plan progress.
