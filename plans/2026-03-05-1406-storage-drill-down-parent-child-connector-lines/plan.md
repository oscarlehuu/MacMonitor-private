---
title: "Storage Drill-down Connector Lines"
description: "Add visible parent-child connector lines for storage drill-down rows without behavior regressions."
status: pending
priority: P2
effort: 3h
branch: codex/performance-optimization-brainstorm
tags: [swiftui, storage, ui, regression-safe]
created: 2026-03-05
---

# Implementation Plan

## Goal
Add visible parent-child connector lines to storage drill-down rows so hierarchy is obvious at a glance.

## Constraints
- Keep scope minimal (YAGNI/KISS/DRY).
- Update existing files only.
- Preserve current selection, expand/collapse, and child-loading behavior.

## Phases
1. [Phase 01 - Row Metadata for Connector Rendering](./phase-01-row-metadata-for-connector-rendering.md) - `pending`
2. [Phase 02 - Render Connector Lines in Storage Rows](./phase-02-render-connector-lines-in-storage-rows.md) - `pending`
3. [Phase 03 - Validation and Regression Checks](./phase-03-validation-and-regression-checks.md) - `pending`

## Primary Files
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Tests/StorageManagementViewModelTests.swift`

## Done Criteria
- Connectors appear for nested drill-down rows.
- Existing row interactions behave exactly as before.
- Build and tests pass (or skipped items explicitly noted with reason).

## Unresolved Questions
- Should connector lines also appear in delete-confirmation preview rows for parity with the main storage list?
