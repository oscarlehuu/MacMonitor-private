---
title: "Storage Action Strip Control Order Plan"
description: "Reorder storage action strip controls to Search, Filter icon-only, Delete icon-only with behavior unchanged."
status: pending
priority: P3
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [ui, swiftui, storage-management]
created: 2026-02-26
---

# Storage Action Strip Control Order

## Objective
Keep controls in the same action-strip area and enforce left-to-right order: Search, Filter (icon only), Delete (icon only), with current behavior preserved.

## Scope
- In scope: `selectionSummaryCard` control ordering and control label presentation in `StorageManagementView`.
- Out of scope: `StorageManagementViewModel` behavior, delete/filter/search business logic, broader layout redesign.

## Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Reorder controls and preserve behavior | Pending | 0% | 2h | [phase-01-reorder-controls-and-preserve-behavior.md](./phase-01-reorder-controls-and-preserve-behavior.md) |

## Dependencies
- [StorageManagementView.swift](../../../MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift)
- Existing behavior contracts in `StorageManagementViewModel` (`searchQuery`, `applyPreset`, `requestDeleteSelection`, `canDeleteSelection`, `deleteInfoTooltip`, `isDeleting`)
