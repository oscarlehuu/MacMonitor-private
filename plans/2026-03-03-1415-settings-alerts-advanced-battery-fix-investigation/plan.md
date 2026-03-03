---
title: "Investigate + Fix Non-Working Settings: Alerts and Advanced Battery"
description: "Concise implementation plan to diagnose and fix broken settings behavior for Alerts and Advanced Battery."
status: in-progress
priority: P1
effort: 8h
branch: fix/notarization-workflow-enforce
tags: [macos, settings, alerts, battery, diagnostics]
created: 2026-03-03
---

# Overview
Investigate and fix non-working Settings behavior for `Alerts` and `Advanced Battery` in the popover Settings screen. Keep fixes minimal and focused on existing architecture.

# Scope (YAGNI/KISS/DRY)
- Trace end-to-end flow: Settings UI -> `SettingsStore` -> runtime consumers -> observable behavior.
- Fix only broken/unused existing controls and regressions.
- Avoid broad redesign, new subsystems, or new feature families.

# Baseline Findings (from code read)
- Alerts UI currently exposes partial controls compared to `SystemAlertSettings` model.
- Alerts execution path is present (`SystemSummaryViewModel` -> `SystemAlertPolicyEngine` -> `SystemAlertNotifier`) but lacks dedicated tests.
- Advanced Battery settings expose 5 toggles; only a subset currently influences runtime behavior.
- Deferred advanced features were historically documented as out-of-scope, so current UI may overpromise.

# Phase Breakdown
1. [Phase 01 - Reproduce and Pinpoint Root Causes](./phase-01-reproduce-and-pinpoint-root-causes.md) - completed
2. [Phase 02 - Minimal Fix Design and Implementation Plan](./phase-02-minimal-fix-design-and-implementation-plan.md) - completed
3. [Phase 03 - Validation, Regression Tests, and Release Checks](./phase-03-validation-regression-tests-and-release-checks.md) - in progress

# TODO Checklist
- [x] Capture reproducible failure cases for Alerts and Advanced Battery toggles.
- [x] Map each control to concrete consumer logic and identify dead/unwired paths.
- [x] Finalize fix decision per toggle: wire, disable/hide, or relabel as unavailable.
- [x] Add/extend targeted tests for alert policy and advanced battery behavior.
- [ ] Run full build/tests and manual settings verification.

# Validation Steps (post-fix)
- Build + tests:
  - `xcodegen generate`
  - `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual verification:
  - Toggle each Alerts setting and verify alert generation/cooldown behavior with controlled thresholds.
  - Toggle each Advanced Battery option and verify corresponding lifecycle/policy effect (or explicit unavailable state).
  - Relaunch app and confirm settings persistence.

# Risks
- Fixing UI/logic mismatch can change perceived feature availability.
- Notification permission/cooldown behavior can mask true outcomes during testing.

# Unresolved Questions
- Manual verification on installed app still pending for Alerts + Advanced Battery controls?
