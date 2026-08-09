# Phase 2: PopoverRootView Layout Swap

## Context
- [Phase 1](phase-01-navigation-model-and-sidebar-view.md) — provides SidebarTab, SidebarNavigationView, activeSidebarTab, switchToSidebarTab
- [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift) — current VStack layout (lines 322-346), header (lines 426-475), content switch (lines 540-580), footer (lines 2722-2759)
- [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift) — popover dimensions (lines 488-491)

## Overview
- **Priority:** P1 — core layout change
- **Status:** Complete
- **Blocked by:** Phase 1
- **Description:** Replace the `VStack(header, content, footer)` layout with `HStack(sidebar, VStack(topBar, content, footer))`. Remove the old horizontal tab header. Wire in `SidebarNavigationView`. Extract a slim top-bar with thermal badge + theme toggle.

## Key Insights
- The `body` of PopoverRootView (line 322) is the single integration point — change layout here
- Header currently has two logical halves: (a) branding + thermal + theme toggle, (b) tab buttons. We keep (a) as a slim top-bar, discard (b) since sidebar replaces it
- The storage delete confirmation overlay (line 341-344) uses `.overlay {}` on the root — must remain on the outermost container to cover both sidebar and content
- Popover resize handle (line 338-340) overlays bottom-trailing — stays on outermost container
- Popover width range 360-760pt. Sidebar takes 44pt. Content area: 316-716pt. Sufficient for all existing screens.
- Footer currently has `padding(.horizontal, 20)` — will need adjustment since content area is narrower by 44pt. No change needed: the 20pt padding applies within the content column, which is correct.

## Requirements

### Functional
- Sidebar visible on the left at all times
- Top-bar: thermal badge + theme toggle in a single slim row (no "MacMonitor" text — branding moved to sidebar icon)
- Content area takes remaining width and full height between top-bar and footer
- Delete confirmation overlay covers entire popover (sidebar + content)
- Resize handle still at bottom-trailing of entire popover

### Non-functional
- No visual regression in content screens
- Popover dimensions stay within existing min/max constraints
- PopoverRootView `body` remains readable

## Architecture

### New Layout Structure
```swift
// PopoverRootView.body
HStack(spacing: 0) {
    SidebarNavigationView(
        activeTab: activeSidebarTab,
        onTabSelected: switchToSidebarTab
    )
    VStack(spacing: 0) {
        topBar
        content
        footer
    }
}
.frame(width: ..., height: ...)
.background(popoverBackground)
// ... existing overlays (resize handle, delete confirmation)
```

### Top Bar (replaces `header`)
```
┌─────────────────────────────────────────┐
│  [🟢 Normal]              [🌙]         │
└─────────────────────────────────────────┘
```
- Thermal badge on the left
- Theme toggle on the right
- Height: ~40pt (down from ~80pt header)
- Background: same `PopoverTheme.bgPanel.opacity(0.72)` + bottom border

## Related Code Files

### Modified Files
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`:
  - **body** (line 322): VStack -> HStack(sidebar, VStack(topBar, content, footer))
  - **header** (line 426): replaced by `topBar` — remove MacMonitor label, tab buttons row; keep thermal badge + theme toggle
  - Remove `MainPopoverTab` enum (lines 4-35)
  - Remove `mainTabButton(_:)` (lines 512-538)
  - Remove `activeTab` (lines 3003-3014)
  - Remove `switchToTab(_:)` (lines 3016-3027)

### Unchanged Files
- `SidebarTab.swift` — created in Phase 1
- `SidebarNavigationView.swift` — created in Phase 1
- `SystemSummaryViewModel.swift` — no changes
- `SettingsStore.swift` — no changes (existing width range accommodates sidebar)
- All feature views (Battery, Storage, Trends, etc.) — unchanged

## Implementation Steps

### Step 1: Replace `body` layout
Current (lines 322-346):
```swift
var body: some View {
    VStack(spacing: 0) {
        header
        content
        footer
    }
    .frame(width: ..., height: ...)
    ...
}
```

New:
```swift
var body: some View {
    HStack(spacing: 0) {
        SidebarNavigationView(
            activeTab: activeSidebarTab,
            onTabSelected: switchToSidebarTab
        )
        VStack(spacing: 0) {
            topBar
            content
            footer
        }
    }
    .frame(width: ..., height: ...)
    ...
}
```

All existing modifiers (`.background`, `.clipShape`, `.overlay`, `.shadow`, `.preferredColorScheme`, `.id`, `.onAppear`, `.onDisappear`, `.onChange`) stay attached to the outermost container — no changes needed.

### Step 2: Create `topBar` (replaces `header`)
New slim view — thermal badge and theme toggle only:

```swift
private var topBar: some View {
    HStack(spacing: 10) {
        thermalStatusBadge
        Spacer(minLength: 8)
        Button {
            toggleTheme()
        } label: {
            Image(systemName: settings.appTheme.isDark ? "sun.max" : "moon")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PopoverTheme.textMuted)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PopoverTheme.bgCard.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
        .help("Toggle Light/Dark Theme")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(PopoverTheme.bgPanel.opacity(0.72))
    .overlay(alignment: .bottom) {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
    }
}
```

### Step 3: Remove old `header` computed property
Delete the entire `header` computed property (lines 426-475). The MacMonitor branding label is replaced by the sidebar branding icon. The tab buttons row is replaced by the sidebar.

### Step 4: Remove dead `MainPopoverTab` code
- Delete `MainPopoverTab` enum (lines 4-35, plus the two helper structs `MemoryUsageSegment` and `StorageUsageSegment` stay — they are unrelated)
- Delete `mainTabButton(_:)` function (lines 512-538)
- Delete `activeTab` computed property (lines 3003-3014)
- Delete `switchToTab(_:)` function (lines 3016-3027)

### Step 5: Adjust content padding
Current content screens use `.padding(20)`. With sidebar taking 44pt, the content area is narrower. The 20pt padding within the content column is fine — screens already use `maxWidth: .infinity` and will reflow.

Review each screen in the `content` switch statement (lines 540-580) — no changes expected. The `.padding(20)` stays.

### Step 6: Verify resize handle coordinate space
The resize handle (line 2761) uses `DragGesture(coordinateSpace: .global)` — sidebar addition doesn't affect global coordinates. The handle stays at bottom-trailing of the outermost container. No change needed.

### Step 7: Compile and visual test
```bash
cd /Users/oscar/Desktop/Projects/OscarProjects/MacMonitor
xcodegen generate && xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' build
```

## Todo List

- [x] Replace `body` VStack with HStack(sidebar, VStack(topBar, content, footer))
- [x] Create `topBar` computed property (thermal badge + theme toggle)
- [x] Delete old `header` computed property
- [x] Delete `MainPopoverTab` enum
- [x] Delete `mainTabButton(_:)` function
- [x] Delete `activeTab` computed property
- [x] Delete `switchToTab(_:)` function
- [x] Verify content padding renders correctly
- [x] Verify delete confirmation overlay covers full popover
- [x] Verify resize handle still works
- [x] Compile check: `xcodegen generate && xcodebuild build`

## Success Criteria
1. Popover opens with sidebar on left, content on right
2. 5 icons in sidebar — Memory, Battery, Storage, Trends, Settings (bottom-pinned)
3. Clicking each sidebar icon navigates to correct screen
4. Top-bar shows thermal badge + theme toggle
5. No "MacMonitor" text visible (branding is sidebar icon only)
6. Storage delete confirmation overlay covers full popover
7. Resize handle functional
8. Project compiles cleanly

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Content area too narrow at min width (316pt) | Current screens render well at 360pt. 316pt is 12% narrower. Storage management list may need testing. If too tight, increase `mainPopoverMinWidth` to 404pt (360+44). |
| Sidebar clips rounded corners of popover | `.clipShape(RoundedRectangle(cornerRadius: 16))` on outermost container handles this automatically. |
| `.onAppear`/`.onDisappear` timing changes with layout change | These are attached to the outermost container and fire on popover show/hide — unaffected by internal layout change. |

## Net Line Count Impact
- Removed: ~90 lines (MainPopoverTab enum: 35, header: 50, mainTabButton: 27, activeTab: 12, switchToTab: 12)
- Added: ~25 lines (topBar: 20, body restructure: 5)
- **Net reduction: ~65 lines**
