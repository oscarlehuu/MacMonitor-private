---
title: "Add Compact RAM Details Search (Processes + Ports)"
description: "Concise plan to add a subtle search box in RAMDetailsView with mode-aware filtering in RAMDetailsViewModel."
status: completed
priority: P2
effort: 2h
branch: fix/notarization-workflow-enforce
tags: [macos, swiftui, ram-details, search, filtering]
created: 2026-03-03
---

# Overview
Add a compact, theme-consistent search control to `RAMDetailsView` and move all filtering logic into `RAMDetailsViewModel`.

# Scope (YAGNI/KISS/DRY)
- One shared search field in RAM details screen.
- Processes mode: filter by process name, allow PID match.
- Ports mode: filter by process name, port, endpoint, allow PID match.
- Keep existing refresh/selection/termination flows unchanged.
- Add focused unit tests for filtering behavior.

# Out of Scope
- No fuzzy search, ranking, debounce, or persistence.
- No changes to collectors/termination policy.

# Files to Update
- `MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- `MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`
- `MacMonitor/Tests/RAMDetailsViewModelTests.swift`

# Implementation Checklist
- [x] Add `searchQuery` state and normalized query helper in `RAMDetailsViewModel`.
- [x] Add mode-aware computed collections:
  - `filteredProcesses` (name + PID)
  - `filteredListeningPorts` (process name + port + endpoint + PID)
- [x] Keep filtering case-insensitive and whitespace-trimmed.
- [x] Update `RAMDetailsView` to render filtered collections instead of raw arrays.
- [x] Add compact subtle search UI (small font, icon, clear button, `PopoverTheme` colors, minimal footprint).
- [x] Use mode-aware placeholder text:
  - Processes: `Search process or PID`
  - Ports: `Search process, port, endpoint, or PID`
- [x] Add empty-state branch for no matches (query present but filtered results empty).
- [x] Add/update `RAMDetailsViewModelTests` for:
  - process filtering by name and PID
  - port filtering by process name, port, endpoint, and PID
  - case-insensitive + trimmed matching

# Validation
- `xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' test`
- Manual check in popover RAM details:
  - search is visually subtle and consistent with current theme
  - both modes filter correctly with expected fields

# Risks
- Low: selection can reference rows hidden by filter; acceptable for minimal scope, verify no termination regression.

# Unresolved Questions
- None.
