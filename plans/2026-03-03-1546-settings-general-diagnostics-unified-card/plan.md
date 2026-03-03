---
title: "Settings UI Refactor: Unified General + Diagnostics Card"
description: "Concise plan to merge General and Diagnostics settings into one reusable adaptive three-column card."
status: completed
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, settings, popover, refactor]
created: 2026-03-03
---

# Overview
Refactor `PopoverRootView` settings UI by merging current `settingsGeneralCard` + `settingsDiagnosticsCard` content into one reusable card with three columns:
- General launch toggle
- Popover width controls
- Diagnostics export

Behavior/bindings/actions must remain unchanged. Use adaptive layout fallback for narrow widths.

# Scope (YAGNI/KISS/DRY)
- UI composition refactor only in one file.
- Reuse existing bindings/actions (`$settings.launchAtLoginEnabled`, `settings.saveCurrentPopoverWidthAsDefault()`, `exportDiagnostics()`).
- No changes to models, persistence, diagnostics payload, or business logic.

# Phase Breakdown
1. [Phase 01 - Build Unified Adaptive Settings Card](./phase-01-build-unified-adaptive-settings-card.md) - completed

# TODO Checklist
- [x] Replace `settingsGeneralCard` + `settingsDiagnosticsCard` usage with one unified reusable card.
- [x] Extract/compose three reusable column sections (General, Popover Width, Diagnostics).
- [x] Implement adaptive fallback for narrow width (`ViewThatFits` horizontal-first).
- [x] Preserve all existing bindings, button actions, copy, disabled/opacity states.
- [x] Validate compile + targeted tests.

# Validation Scope
- `xcodegen generate`
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' build`
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' -only-testing:MacMonitorTests/SettingsStoreTests test`

# Risks
- Horizontal 3-column layout may crowd at low widths (minimum popover width is 360).
- Divider/spacing regressions if card sections are moved without consistent separators.

# Unresolved Questions
- None.
