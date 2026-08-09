---
title: "Sidebar Navigation Redesign"
description: "Replace horizontal top tabs with compact icon-only sidebar; promote Battery to top-level; modularize PopoverRootView"
status: completed
priority: P1
effort: 6h
branch: codex/sidebar-navigation-redesign
tags: [ui, navigation, refactor, modularization]
created: 2026-04-01
completed: 2026-04-01
---

# Sidebar Navigation Redesign

## Summary

Replace the 4-button horizontal tab header in PopoverRootView with a narrow icon-only vertical sidebar. Promote Battery from a hidden sub-item to a first-class nav entry. Modularize the 3,480-line PopoverRootView during the refactor.

## Current State

```
VStack(spacing: 0) {
  header   // "MacMonitor" title + thermal badge + theme toggle + 4 TAB BUTTONS
  content  // switched on viewModel.screen
  footer   // version + update badge
}
```

- **MainPopoverTab** enum: `.memory`, `.storageApps`, `.trends`, `.settings`
- **Screen** enum: `.temperature`, `.battery`, `.ram`, `.storage`, `.trends`, `.storageManagement`, `.settings`, `.ramPolicyManager`
- Battery is buried — only reachable from within Memory tab
- PopoverRootView: 3,480 lines in single file

## Target State

```
HStack(spacing: 0) {
  sidebar  // icon-only vertical nav, branding icon top, settings icon bottom
  VStack(spacing: 0) {
    topBar    // thermal badge + theme toggle (slim)
    content   // switched on viewModel.screen
    footer    // version + update badge
  }
}
```

- **SidebarTab** enum: `.memory`, `.battery`, `.storage`, `.trends`, `.settings`
- Battery promoted to top-level sidebar item
- Sidebar width: ~44pt, icon-only, tooltip on hover
- PopoverRootView modularized: sidebar, top-bar, settings, storage delete confirmation extracted

## Phases

| # | Phase | Status | Effort | Files |
|---|-------|--------|--------|-------|
| 1 | [Navigation model + sidebar view](phase-01-navigation-model-and-sidebar-view.md) | Complete | 1.5h | 3 new, 1 modified |
| 2 | [PopoverRootView layout swap](phase-02-popover-layout-swap.md) | Complete | 2h | 1 modified |
| 3 | [Settings screen extraction](phase-03-settings-screen-extraction.md) | Complete | 1.5h | 8 new, 1 modified |
| 4 | [Storage delete overlay extraction](phase-04-storage-delete-overlay-extraction.md) | Complete | 1h | 2 new, 1 modified |

## Dependency Graph

```
Phase 1 ─── Phase 2 ─┬─ Phase 3
                      └─ Phase 4
```

Phase 1 must complete before Phase 2. Phases 3 and 4 are independent extractions that can run in parallel after Phase 2.

## Risk Assessment

| Risk | L x I | Mitigation |
|------|-------|------------|
| NSPopover width change breaks layout | M x H | Test sidebar + content fits within existing min/max width constraints (360-760pt). Sidebar is 44pt — leaves 316pt min content area, sufficient. |
| Storage delete overlay doesn't render over sidebar | M x M | Overlay is `.overlay {}` on the entire root HStack, so it inherits full frame. Verify in Phase 2. |
| Theme toggle moves from header to top-bar — muscle memory | L x L | Top-bar is still top-right area. Minimal disruption. |
| PopoverRootView modularization breaks `@State` bindings | M x H | Extract views as separate `struct`s that receive bindings via init. Keep all `@State` in PopoverRootView until extraction is validated. |

## Rollback Plan

Each phase is a single git commit. Revert in reverse order. No data migrations — purely UI changes. Settings/persistence untouched.

## Test Matrix

| Category | What | How |
|----------|------|-----|
| Compile | Project builds | `xcodegen generate && xcodebuild build` after each phase |
| Visual | Sidebar renders, icons visible, tooltips work | Manual popover inspection |
| Navigation | All 5 sidebar items switch screens correctly | Manual click-through |
| Existing | Battery, Memory, Storage, Trends, Settings screens render unchanged | Manual comparison |
| Resize | Popover resize handle still works | Manual drag test |
| Theme | Dark/light toggle works from top-bar | Manual toggle |
| Delete overlay | Storage delete confirmation renders over full popover | Manual trigger |

## Backwards Compatibility

- No API changes
- No persistence format changes
- `SystemSummaryViewModel.Screen` enum unchanged (battery case already exists)
- `MainPopoverTab` replaced by `SidebarTab` — private enum, no external consumers
- `normalizeLegacyScreenIfNeeded()` updated to not collapse battery to RAM

## File Inventory

### New Files (12 total)
| File | Phase | Lines (est) |
|------|-------|-------------|
| `Popover/SidebarTab.swift` | 1 | ~50 |
| `Popover/SidebarNavigationView.swift` | 1 | ~120 |
| `Settings/PopoverSettingsScreenView.swift` | 3 | ~120 |
| `Settings/SettingsMenuBarCard.swift` | 3 | ~100 |
| `Settings/SettingsAlertsCard.swift` | 3 | ~120 |
| `Settings/SettingsBatteryCard.swift` | 3 | ~110 |
| `Settings/SettingsAboutCard.swift` | 3 | ~100 |
| `Settings/SettingsGeneralCard.swift` | 3 | ~150 |
| `Settings/SettingsCardHelpers.swift` | 3 | ~100 |
| `Settings/MenuBarComposerSheetView.swift` | 3 | ~150 |
| `StorageManagement/StorageDeleteConfirmationOverlay.swift` | 4 | ~200 |
| `StorageManagement/StorageDeletePreviewHelpers.swift` | 4 | ~180 |

### Modified Files
| File | Phases | Net Change |
|------|--------|------------|
| `Popover/PopoverRootView.swift` | 1,2,3,4 | -1,802 lines (3,480 -> ~1,678) |

### Cumulative Impact
| Phase | PopoverRootView delta | New file lines |
|-------|----------------------|----------------|
| 1 | +20 (add new functions, no removal) | ~170 |
| 2 | -65 (header, MainPopoverTab, tab funcs) | 0 |
| 3 | -1,205 (settings extraction) | ~850 |
| 4 | -552 (storage delete overlay) | ~380 |
| **Total** | **-1,802** | **~1,400** |

Note: PopoverRootView at ~1,678 lines is above the 1,000-line target. Further extractions (storage summary card, memory summary card, theme palette, storage top actions) would reach <1,000 but are out of scope — this plan focuses on navigation redesign + the two largest inline blocks.

## Success Criteria

1. Popover opens with icon-only sidebar on the left
2. 5 nav items: Memory, Battery, Storage, Trends, Settings (settings pinned to bottom)
3. Battery is directly accessible as top-level nav item
4. All existing screens render identically to current state
5. PopoverRootView reduced to ~1,678 lines (down from 3,480)
6. No new files exceed 200 lines
7. Project compiles with zero errors
