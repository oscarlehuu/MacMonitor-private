---
title: "Align RAM Metrics/UI With Activity Monitor Semantics"
description: "Minimal-risk plan to remap MacMonitor memory metrics and labels to Activity Monitor style fields."
status: completed
priority: P2
effort: 6h
branch: fix/notarization-workflow-enforce
tags: [macos, swift, memory, metrics, ui]
created: 2026-03-02
---

# Overview
Goal: align RAM metrics and labels with Activity Monitor terminology while keeping current data flow and persistence backward-safe.

## Scope
- Include fields: Physical Memory, Memory Used, Cached Files, Swap Used, App Memory, Wired Memory, Compressed.
- Update memory summary UI in popover + RAM details view to display these labels clearly.
- Keep compatibility with existing snapshots/history and existing menu bar/trend flows.

## Implemented metric semantics
- `Physical Memory` = `totalBytes` (already available).
- `Wired Memory` = `wire_count * pageSize`.
- `Compressed` = `compressor_page_count * pageSize`.
- `Cached Files` = `(inactive_count + speculative_count) * pageSize` (fallback to `inactive_count` only).
- `App Memory` = derived from VM stats using `internal_page_count * pageSize` when present; fallback `max(used - wired - compressed, 0)`.
- `Memory Used` = `physical - (cached files + free excluding speculative)` (clamped to `>= 0`).
- `Swap Used` = `xsw_usage.xsu_used` via `sysctlbyname("vm.swapusage", ...)`.

## Phase 1: Data model + collector (minimal API expansion)
- [x] Extend `MemorySnapshot` with optional Activity Monitor-style fields (`appMemoryBytes`, `wiredMemoryBytes`, `cachedFilesBytes`, `swapUsedBytes`).
- [x] Keep legacy fields (`inactiveBytes`, `compressedBytes`, `freeBytes`, `usedBytes`) and map them for compatibility.
- [x] Update `MemoryCollector` calculations to populate both legacy and new fields; set `usedBytes` to Activity Monitor-style `Memory Used`.
- [x] Add safe fallbacks when VM fields/sysctl are unavailable.

## Phase 2: RAM UI relabel + layout clarity
- [x] Update popover memory card to show top-line `Physical Memory` + `Memory Used` and a secondary grid: `App`, `Wired`, `Compressed`, `Cached Files`, `Swap Used`.
- [x] Update RAM details summary strip labels/tooltips to Activity Monitor wording (remove "Used = Active + Wired").
- [x] Preserve existing process list/termination UX unchanged.

## Phase 3: Backward safety + validation
- [x] Confirm decoding of old snapshot history still works (new fields optional).
- [x] Ensure trend/menu bar continue reading `usedBytes/totalBytes` without regressions.
- [x] Validate nil/partial collector data renders placeholder values, not crashes.

## Affected files
- `MacMonitor/Sources/Core/Domain/SystemSnapshot.swift`
- `MacMonitor/Sources/Core/Metrics/Collectors/MemoryCollector.swift`
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift` (tooltip/status wording if needed)
- `MacMonitor/Tests/MetricsEngineTests.swift`
- `MacMonitor/Tests/SnapshotStoreTests.swift`
- `MacMonitor/Tests/SystemSummaryViewModelTests.swift`

## Test updates (implemented)
- Added collector tests for `memoryUsedBytes(total, cached, free)` subtraction and clamp-at-zero behavior.
- Added codable compatibility test to decode legacy `MemorySnapshot` JSON without new keys.
- Updated view-model navigation expectation tied to the latest popover storage routing.
- Verified trend/menu bar continue reading `usedBytes/totalBytes` with the new memory semantics.

## Rollout notes
- No schema version bump required if only optional fields are added.
- Keep old fields populated during transition to avoid downstream breakage.
- Defer any deeper metric-source redesign (YAGNI) until after parity feedback.

## Resolved decisions
- `Cached Files` uses `inactive + speculative` as the default source, with fallback support through legacy `inactiveBytes`.
- Menu bar RAM percentage now reflects the updated `Memory Used` semantics immediately through `usedBytes/totalBytes`.
