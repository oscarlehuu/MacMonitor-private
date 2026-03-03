---
title: "Popover Settings: Advanced Battery Helper Gating"
description: "Hide unavailable advanced rows, gate available toggles by helper install state, and add in-section helper install action."
status: completed
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, popover, battery]
created: 2026-03-03
---

# Overview
Apply a small UI-only fix in popover Settings > Advanced Battery:
- hide rows for deferred/unavailable advanced features
- disable remaining advanced toggles when helper is unavailable
- add an install-helper button in this card when helper is unavailable

# Phases
1. [Phase 01 - Advanced Battery Settings Gating](./phase-01-advanced-battery-settings-gating.md) - completed

# Files To Modify
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`

# Key Dependencies
- `BatteryPolicyCoordinator.helperAvailability`
- `BatteryPolicyCoordinator.isInstallingHelper`
- `BatteryPolicyCoordinator.installHelperIfNeededAsync()`

# Acceptance Criteria
- Unavailable advanced feature rows are not shown in this card.
- Available advanced toggles remain visible but non-interactive when helper is unavailable.
- Install button appears in the same card only when helper is unavailable.
- Install button shows in-progress disabled state while installation runs.
- Existing settings persistence and battery policy flow are unchanged.

# Out Of Scope
- New backend/helper installation architecture.
- Changes to `SettingsStore` schema or migration.
- New test suite or broad UI refactor.

# Unresolved Questions
- None.
