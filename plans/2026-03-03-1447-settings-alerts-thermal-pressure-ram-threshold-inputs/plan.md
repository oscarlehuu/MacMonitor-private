---
title: "Settings Alerts: Thermal Rename, RAM Alert, Numeric Threshold Inputs"
description: "Minimal implementation plan for requested Settings alert updates and targeted test coverage."
status: pending
priority: P1
effort: 5h
branch: fix/notarization-workflow-enforce
tags: [macos, settings, alerts, ram, tests]
created: 2026-03-03
---

# Overview
Implement 5 scoped Settings changes in existing Alerts flow only:
- rename `Thermal Alerts` -> `Thermal Pressure Alerts`
- reduce cooldown default/options
- add RAM alert setting + policy evaluation
- convert RAM/Storage thresholds from picker options to numeric input
- add/update tests and run targeted `xcodebuild` tests

# Scope (YAGNI/KISS/DRY)
- Reuse current architecture: `SettingsStore` -> `SystemAlertPolicyEngine` -> `SystemSummaryViewModel` -> notifier.
- Keep all edits localized to existing files.
- No new subsystem, no redesign of settings framework, no UI expansion beyond requested controls.

# Proposed Defaults/Bounds
- RAM alert default: enabled, threshold `90%`.
- Storage threshold remains bounded `60...99`.
- RAM threshold uses same bound `60...99`.
- Cooldown default: `15m` (from `45m`).
- Cooldown menu options: `[5, 10, 15, 30]`.

# Phase Breakdown
1. [Phase 01 - Update Alert Settings Model and Policy Evaluation](./phase-01-update-alert-settings-model-and-policy-evaluation.md) - pending
2. [Phase 02 - Update Settings UI Labels, Cooldown, and Numeric Threshold Inputs](./phase-02-update-settings-ui-labels-cooldown-and-numeric-threshold-inputs.md) - pending
3. [Phase 03 - Add Targeted Tests and Run xcodebuild Subset](./phase-03-add-targeted-tests-and-run-xcodebuild-subset.md) - pending

# TODO Checklist
- [ ] Extend `SystemAlertSettings` with RAM fields + backward-compatible decode.
- [ ] Evaluate RAM threshold in `SystemAlertPolicyEngine` and add `SystemAlertKind.ram`.
- [ ] Rename thermal label and replace storage/RAM threshold pickers with numeric input fields.
- [ ] Shrink cooldown default/options.
- [ ] Add/adjust unit tests for settings persistence/normalization and alert policy evaluation.
- [ ] Run targeted tests using `xcodebuild` `-only-testing`.

# Targeted Validation Command
- `xcodegen generate`
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/SettingsStoreTests -only-testing:MacMonitorTests/SystemSummaryViewModelTests -only-testing:MacMonitorTests/SystemAlertPolicyEngineTests test`

# Risks
- Adding non-optional Codable fields can silently reset old persisted alert settings if decode compatibility is not handled.
- Numeric input UX can allow invalid values unless clamped/sanitized consistently.

# Unresolved Questions
- None.
