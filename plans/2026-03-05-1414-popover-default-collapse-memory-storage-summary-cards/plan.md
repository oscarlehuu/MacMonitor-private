---
title: "Popover: Default-Collapse Memory and Storage Summary Cards"
description: "Default-collapse memory and storage summary cards while keeping top rows visible and preserving current expanded behavior."
status: pending
priority: P2
effort: 1.5h
branch: codex/performance-optimization-brainstorm
tags: [swiftui, popover, ui, memory, storage]
created: 2026-03-05
---

# Overview
Apply a minimal UI-only change in `PopoverRootView`:
- memory summary card starts collapsed by default
- storage summary card starts collapsed by default
- collapsed state keeps top rows visible
- expanded state keeps current full detail UI and behavior

# Scope (YAGNI/KISS/DRY)
- In scope:
  - Local expand/collapse state in `PopoverRootView`
  - Conditional rendering inside `memorySummaryCard` and `storageSummaryCard`
- Out of scope:
  - RAM details screen behavior
  - Storage management logic/scanning/deletion flow
  - New files/components or view model/API changes

# Phases
| # | Phase | Status | Progress | Effort | Link |
|---|---|---|---|---|---|
| 1 | Implement card collapse toggles + regression-safe validation | Pending | 0% | 1.5h | [phase-01-implement-card-collapse-toggles-and-validate.md](./phase-01-implement-card-collapse-toggles-and-validate.md) |

# Primary File
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`

# Risks
- Stale hovered storage segment label can remain visible when collapsing after hover.
- Toggle placement can conflict with existing storage action buttons (`Refresh`, `Add Folder`).
- Missing-memory snapshot state must remain readable and not regress loading copy.

# Validation
- `xcodegen generate`
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual UI checks on RAM and Storage screens for collapsed defaults, expand/collapse behavior, and unchanged actions.

# Unresolved Questions
- None.
