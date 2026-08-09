## Code Review: Sidebar Navigation Redesign

### Scope
- **New files:** 16 (SidebarTab, SidebarNavigationView, settings cards, storage delete overlay, helpers)
- **Modified:** PopoverRootView (3,480 -> 1,426 lines)
- **Focus:** correctness, SwiftUI patterns, layout, thread safety, code quality

### Overall Assessment
Clean modularization. The extraction is well-structured with clear responsibility boundaries. One **high-priority** layout issue and a few medium items.

---

### Critical Issues
None.

### High Priority

**1. Layout squeeze at minimum width (360pt)**
`SettingsStore.mainPopoverMinWidth` is 360pt. The 44pt sidebar (SidebarNavigationView:28) leaves only **316pt** for content. At that width the settings cards with their 96pt pickers + toggle switches + labels will clip or overflow.

**Fix:** Increase `mainPopoverMinWidth` to ~404pt (360 + 44) or make the sidebar width deducted before the content frame is calculated. Alternatively, set `minWidth` on the content `VStack` and let AppKit prevent the popover from shrinking below sidebar + content minimum.

### Medium Priority

**2. Global mutable cache without invalidation** -- `StorageDeletePreviewHelpers.swift:17`
`nonisolated(unsafe) let storageDeletePreviewAppIconCache` is a process-global `NSCache`. It survives across overlay presentations and is never explicitly cleared. The `clearCache()` in `StorageDeleteConfirmationOverlay` only clears the local `@State` arrays, not this icon cache. This is functionally fine (NSCache auto-evicts under memory pressure) but the `nonisolated(unsafe)` annotation means concurrent reads/writes from different actors are technically unsound in strict concurrency mode. `NSCache` is thread-safe, so in practice no crash, but the annotation deserves a comment.

**3. `StorageDeletePreviewRowViews.swift` at 221 lines** -- Slightly over the 200-line guideline. Minor.

**4. `updateState` string matching is fragile** -- `SettingsGeneralCard.swift:103-110`
The computed `updateState` matches on substrings of `appUpdateController.statusMessage.lowercased()`. If the message format changes, the state detection silently falls back to `.ready`. Consider using a typed status enum from `AppUpdateController` instead.

**5. Missing `@MainActor` on free functions** -- `SettingsAlertRowBuilders.swift` marks its functions `@MainActor` correctly. But the helper functions in `SettingsCardHelpers.swift` (`settingsSectionHeader`, `settingsDivider`, `settingsCompactRowLabel`, `settingsInfoBanner`, `formattedMainPopoverWidth`) lack `@MainActor`. They only return `some View` so they are currently fine being called from `@MainActor` contexts, but for consistency and future safety should match.

### Low Priority

**6. Sidebar keyboard navigability** -- `SidebarNavigationView` buttons have `.help()` tooltips (good) but no `.accessibilityIdentifier()` or arrow-key focus cycling. Not blocking but worth noting for accessibility audit.

**7. Dead code path** -- `activeSidebarTab` maps `.temperature` -> `.memory` and `normalizeLegacyScreenIfNeeded()` immediately redirects `.temperature` to `.ram`. The `.temperature` case in the sidebar mapping is effectively unreachable after the first `onAppear`. Harmless but could be simplified.

---

### Positive Observations
- Sidebar tab enum with `CaseIterable`, `primaryItems` static var is well-designed
- `SettingsCard` wrapper + theme struct eliminate duplication across all card files
- `StorageDeleteConfirmationOverlay` fully encapsulates its own snapshot/cache state -- good separation from PopoverRootView
- `PopoverColorPanelController` correctly handles single-ownership handoff of the shared NSColorPanel
- All `@ObservedObject` vs `@State` vs `@Binding` usage is correct across extracted views

### Metrics
- New files all under 200 lines except StorageDeletePreviewRowViews (221)
- PopoverRootView reduced from ~3,480 to 1,426 lines
- All sidebar tab cases exhaustively handled in both `activeSidebarTab` and `switchToSidebarTab`

### Recommended Actions
1. **[High]** Bump `mainPopoverMinWidth` from 360 to 404+ to account for the 44pt sidebar
2. **[Med]** Add comment to `nonisolated(unsafe)` cache explaining thread-safety reliance on NSCache
3. **[Low]** Consider typed status enum for update controller instead of string matching
