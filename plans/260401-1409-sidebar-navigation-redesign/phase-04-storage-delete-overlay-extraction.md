# Phase 4: Storage Delete Overlay Extraction

## Context
- [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift) — storage delete confirmation code spans lines 713-1150 (~437 lines) plus helper functions (lines 1150-1275, ~125 lines)
- [StorageManagementViewModel.swift](../../MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift) — drives delete flow state

## Overview
- **Priority:** P2 — modularization, no functional change
- **Status:** Complete
- **Blocked by:** Phase 2
- **Description:** Extract the storage delete confirmation overlay and its supporting helpers from PopoverRootView into a standalone view. This is the second-largest inline block (~560 lines, 16% of file).

## Key Insights
- The delete confirmation overlay is a modal-style overlay that covers the entire popover when `storageManagementViewModel.showingDeleteConfirmation` is true
- It has its own @State properties in PopoverRootView: `deleteConfirmationAcknowledged`, `deleteConfirmationSnapshot`, `deleteConfirmationRootItemIDs`, `didConfirmStorageDeletion`, `cachedDeletePreviewGroupSections`, `cachedDeletePreviewLooseRows`
- It also uses `hoveredStorageSegmentID` — but that may also be used by the storage summary card. Must verify.
- The overlay interacts with `storageManagementViewModel` heavily — selection state, deletion preview, confirmation flow
- Helper functions like `modalAppIconImage`, `modalSelectionSymbol`, `modalSelectionColor`, `modalGroupSelectionSymbol`, `modalGroupSelectionColor`, `storageItemIcon`, `storageItemColor` are only used by the overlay and the storage list (which is already in StorageManagementView)
- Private structs `StorageDeletePreviewGroupSection` (line 53) and `StorageScanSourceChipView` (line 60) + `PopoverColorPanelController` (line 153) live at the top of the file — the first two are storage-related

## Requirements

### Functional
- Zero visual or behavioral change — pure extraction
- Delete confirmation overlay must still cover entire popover (rendered at root level)
- All delete/cancel/acknowledge flows work identically

### Non-functional
- Extracted file(s) under 200 lines each
- PopoverRootView reduced by ~500 lines

## Architecture

### Dependency Injection
```swift
struct StorageDeleteConfirmationOverlay: View {
    @ObservedObject var storageManagementViewModel: StorageManagementViewModel

    // Bindings from PopoverRootView state (or local @State if fully owned)
    @Binding var didConfirmDeletion: Bool

    // ... body renders the full overlay
}
```

**Key question:** Can the 6 @State properties move entirely into the new view?

Analysis:
- `deleteConfirmationAcknowledged` — only read/written inside overlay. **Move.**
- `deleteConfirmationSnapshot` — set in `.onChange(of: showingDeleteConfirmation)` in PopoverRootView body. That onChange handler must stay in PopoverRootView since it also calls `storageManagementViewModel.restoreSelectionSnapshot`. **Keep as @State in new view, but trigger via onAppear/onDisappear.**
- `deleteConfirmationRootItemIDs` — set in same onChange. Same analysis. **Move into overlay, set on `.onAppear`.**
- `didConfirmStorageDeletion` — read in the `.onChange` dismiss handler in PopoverRootView. **Keep as @Binding from PopoverRootView.**
- `cachedDeletePreviewGroupSections` / `cachedDeletePreviewLooseRows` — only used inside overlay. **Move.**

Revised approach: Move most @State into the overlay. Only `didConfirmStorageDeletion` remains as a @Binding because PopoverRootView's `.onChange(of: showingDeleteConfirmation)` dismiss handler reads it to decide whether to restore the selection snapshot.

### Data Flow
```
PopoverRootView
  .overlay {
    if showingDeleteConfirmation {
      StorageDeleteConfirmationOverlay(
        storageManagementViewModel: storageManagementViewModel,
        didConfirmDeletion: $didConfirmStorageDeletion
      )
    }
  }
  .onChange(of: showingDeleteConfirmation) { _, isPresented in
    // dismiss handler: reads didConfirmStorageDeletion to decide snapshot restore
    // this stays in PopoverRootView
  }
```

## Related Code Files

### New Files
- `MacMonitor/Sources/Features/StorageManagement/StorageDeleteConfirmationOverlay.swift` — overlay view (~200 lines)
- `MacMonitor/Sources/Features/StorageManagement/StorageDeletePreviewHelpers.swift` — preview row rendering, icon helpers (~180 lines)

Move `StorageDeletePreviewGroupSection` struct into `StorageDeletePreviewHelpers.swift`.

### Modified Files
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`:
  - Replace `storageDeleteConfirmationOverlay` body with `StorageDeleteConfirmationOverlay(...)`
  - Remove all `storageDeletePreview*`, `modalAppIcon*`, `modalSelection*`, `modalGroupSelection*`, `isPreviewRowVisible`, `isAncestorPath`, `activeDeletePreviewRootItemIDs`, `refreshDeletePreviewCache`, `clearDeletePreviewCache` functions
  - Remove moved @State properties: `deleteConfirmationAcknowledged`, `deleteConfirmationSnapshot`, `deleteConfirmationRootItemIDs`, `cachedDeletePreviewGroupSections`, `cachedDeletePreviewLooseRows`
  - Keep `didConfirmStorageDeletion` @State + bind to overlay
  - Simplify `.onChange(of: showingDeleteConfirmation)` handler — snapshot logic moves into overlay

## Implementation Steps

### Step 1: Identify extraction boundary
Functions to extract (all storage-delete-only):

Lines 713-882: `storageDeleteConfirmationOverlay`, `cancelStorageDeleteConfirmation`
Lines 886-1149: `storageDeletePreviewLooseHeader`, `storageDeletePreviewDivider`, `storageDeletePreviewGroupRow`, `storageDeletePreviewRow`, `refreshDeletePreviewCache`, `clearDeletePreviewCache`, `isPreviewRowVisible`, `activeDeletePreviewRootItemIDs`, `isAncestorPath`
Lines 1150-1275: `modalGroupSelectionSymbol`, `modalGroupSelectionColor`, `modalAppIconImage` (x2 overloads), `modalSelectionSymbol`, `modalSelectionColor`, `storageItemIcon`, `storageItemColor`

**Verify `storageItemIcon` and `storageItemColor` are not used by the storage list screen.** If shared, keep in a common file or move to StorageManagement module.

### Step 2: Create `StorageDeletePreviewHelpers.swift`
Move `StorageDeletePreviewGroupSection` struct and all preview rendering helpers:
- `storageDeletePreviewGroupRow`
- `storageDeletePreviewRow`
- `storageDeletePreviewLooseHeader`
- `storageDeletePreviewDivider`
- `modalAppIconImage` (both overloads)
- `modalGroupSelectionSymbol/Color`
- `modalSelectionSymbol/Color`
- `storageItemIcon/Color`
- `isPreviewRowVisible`, `isAncestorPath`

### Step 3: Create `StorageDeleteConfirmationOverlay.swift`
Main overlay view:
- Receives `storageManagementViewModel` as ObservedObject
- Receives `didConfirmDeletion` as Binding
- Owns @State: `acknowledged`, `snapshot`, `rootItemIDs`, `cachedGroupSections`, `cachedLooseRows`
- `.onAppear` initializes snapshot and root item IDs
- `.onDisappear` handles restore-if-not-confirmed logic
- Calls helpers from `StorageDeletePreviewHelpers`

### Step 4: Simplify PopoverRootView
Replace inline overlay with:
```swift
.overlay {
    if storageManagementViewModel.showingDeleteConfirmation {
        StorageDeleteConfirmationOverlay(
            storageManagementViewModel: storageManagementViewModel,
            didConfirmDeletion: $didConfirmStorageDeletion
        )
    }
}
```

Simplify `.onChange(of: showingDeleteConfirmation)` — the overlay now manages its own snapshot restore in `.onDisappear`. The onChange in PopoverRootView can be removed or reduced to just resetting `didConfirmStorageDeletion = false` on dismiss.

Also simplify/remove the two other `.onChange` handlers that called `refreshDeletePreviewCache` (lines 385-400) — that logic moves into the overlay.

### Step 5: Remove extracted code from PopoverRootView
- All `storageDeletePreview*` views/functions
- All `modal*` helper functions
- All `storageItem*` helper functions (if confirmed overlay-only)
- Moved @State properties
- `refreshDeletePreviewCache`, `clearDeletePreviewCache`
- `cancelStorageDeleteConfirmation`
- `StorageDeletePreviewGroupSection` struct (line 53)

### Step 6: Compile check
```bash
xcodegen generate && xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' build
```

## Todo List

- [x] Verify `storageItemIcon`/`storageItemColor` are not used outside delete overlay
- [x] Verify `hoveredStorageSegmentID` scope — used by storage summary or overlay?
- [x] Create `StorageDeletePreviewHelpers.swift` with preview rendering helpers
- [x] Create `StorageDeleteConfirmationOverlay.swift` with overlay view
- [x] Wire overlay into PopoverRootView via `.overlay {}`
- [x] Remove extracted code from PopoverRootView
- [x] Simplify/remove `.onChange` handlers that managed delete preview cache
- [x] Move `StorageDeletePreviewGroupSection` struct out of PopoverRootView
- [x] Compile check

## Success Criteria
1. Storage delete confirmation overlay looks and behaves identically
2. Delete flow: select items -> confirm -> acknowledge -> delete works
3. Cancel flow: cancel -> selection restored works
4. PopoverRootView reduced by ~500 lines
5. Each new file under 200 lines
6. Project compiles cleanly

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| `storageItemIcon`/`storageItemColor` shared with non-overlay code | Grep usage before extracting. If shared, place in StorageManagement shared helpers file. |
| Snapshot restore timing changes with onAppear/onDisappear vs onChange | Test cancel flow carefully. If timing issues, keep the onChange handler in PopoverRootView and pass the snapshot via Binding. |
| `NSCache` for `modalAppIconCache` (line 292) is a static on PopoverRootView | Move to file-level `private let` in the helpers file, or make it a static on the overlay. NSCache is thread-safe. |
| `StorageScanSourceChipView` (line 60) is also a top-level private struct in PopoverRootView | This is used by the storage screen (not the overlay). Move to StorageManagement module in a separate cleanup, or leave in PopoverRootView for now. Out of scope for this phase. |

## Net Line Count Impact
- Removed from PopoverRootView: ~560 lines
- Added to PopoverRootView: ~8 lines (wiring)
- New files total: ~380 lines across 2 files
- **Net PopoverRootView reduction: ~552 lines**

## Cumulative Impact (All Phases)

| Phase | PopoverRootView lines removed | New file lines |
|-------|------------------------------|----------------|
| Phase 1 | +20 (new functions, no removal yet) | ~170 (SidebarTab + SidebarNavigationView) |
| Phase 2 | -65 (header, MainPopoverTab, tab functions) | 0 |
| Phase 3 | -1,205 (settings) | ~850 (8 settings files) |
| Phase 4 | -552 (storage delete overlay) | ~380 (2 storage files) |
| **Total** | **-1,802 lines** | **~1,400 lines** |

**PopoverRootView final size: ~3,480 - 1,802 = ~1,678 lines**

Note: further extractions (storage summary card, memory summary card, theme palette) could bring PopoverRootView under 1,000 lines, but those are out of scope for this plan. The navigation redesign is complete after Phase 4.
