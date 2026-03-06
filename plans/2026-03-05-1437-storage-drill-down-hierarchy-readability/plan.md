---
title: "Storage Drill-down Hierarchy Readability"
description: "Improve drill-down connector visibility and parent-child clarity in light/dark themes without changing storage behavior."
status: pending
priority: P2
effort: 2.5h
branch: codex/performance-optimization-brainstorm
tags: [swiftui, storage, ui-readability, hierarchy]
created: 2026-03-05
---

## Objective
Fix two UX issues in storage drill-down rows:
1. Connector lines are too faint in both dark/light themes.
2. Parent-child relationship is not clear enough at a glance.

## Scope
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift`
- `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Existing files only. No behavior change to scan/select/delete logic.

## Implementation TODOs
1. Add minimal hierarchy metadata in `StorageListRow` (ViewModel)
- Add parent context needed by UI (for example: immediate parent display name/id and/or branch marker flags).
- Populate metadata in `appendRows(...)` while preserving current recursion and expansion behavior.
- Keep row flattening logic DRY; no duplicate traversal paths.

2. Improve connector contrast + branch legibility in main storage list (`StorageManagementView.swift`)
- Replace current ultra-subtle connector stroke (`borderSubtle.opacity(...)`) with theme-adaptive, higher-contrast stroke derived from existing theme colors.
- Slightly increase stroke emphasis (color/width) so lines are visible in both dark and light presets.
- Add a tiny branch anchor cue at the elbow/join (dot or equivalent) to clarify parent→child linkage.

3. Add explicit parent-child cue in row content (`StorageManagementView.swift`)
- For nested rows (`depth > 0`), render one compact secondary hint using metadata from step 1 (example: “Child of …” or compact breadcrumb).
- Keep label single-line and low-noise to avoid visual clutter.
- Ensure root rows remain unchanged.

4. Keep delete-confirmation preview hierarchy consistent (`PopoverRootView.swift`)
- Apply the same connector contrast + branch cue rules used in main list.
- Reuse the same `StorageListRow` metadata to show the same parent-child cue for nested rows.
- Maintain current selection/inclusion states and loading indicators.

5. Regression safety checks
- Verify expand/collapse, lazy child loading, selection toggles, and delete preview behavior unchanged.
- Verify no layout truncation regressions at narrow popover widths.

## Validation Commands
```bash
# Regenerate project
make generate

# Compile
make build

# Run tests
make test
```

## Manual Validation Checklist
- Light theme: connector lines clearly visible at depth 1-3.
- Dark theme: connector lines clearly visible at depth 1-3.
- Nested rows show a clear parent-child cue; root rows do not.
- Expand/collapse interactions unchanged in main list and delete preview.
- “Included via parent selection” still appears correctly when applicable.

## Risks + Mitigation
- Risk: visual noise from stronger lines.
- Mitigation: use moderate contrast increase + compact parent cue only for nested rows.

- Risk: duplicated connector tweaks diverge between two views.
- Mitigation: apply identical rendering rules and shared row metadata contract.

## Unresolved Questions
- Final copy for parent hint: `Child of <name>` vs compact breadcrumb `↳ <parent>`?
