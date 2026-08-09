# Phase 1: Navigation Model + Sidebar View

## Context
- [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift) — current `MainPopoverTab` enum (lines 4-35)
- [SystemSummaryViewModel.swift](../../MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift) — `Screen` enum (lines 38-47), navigation functions (lines 150-187)

## Overview
- **Priority:** P1 — blocks all other phases
- **Status:** Complete
- **Description:** Create the `SidebarTab` enum and extract a standalone `SidebarNavigationView` component. Update `SystemSummaryViewModel` to support direct battery navigation from sidebar without the legacy normalization that collapsed battery into RAM.

## Key Insights
- `MainPopoverTab` is a private enum inside PopoverRootView.swift — safe to replace entirely
- `SystemSummaryViewModel.Screen` already has `.battery` case — no enum changes needed on the VM
- The `normalizeLegacyScreenIfNeeded()` function (line 3029) currently force-redirects `.battery` to `.ram` — must be updated to preserve battery as a valid landing screen
- `activeTab` computed property (line 3003) maps `Screen` -> `MainPopoverTab` — needs replacement with `Screen` -> `SidebarTab`

## Requirements

### Functional
- `SidebarTab` enum with 5 cases: `.memory`, `.battery`, `.storage`, `.trends`, `.settings`
- Each case provides: SF Symbol name, tooltip string
- `SidebarNavigationView` renders vertical icon column with branding icon at top
- Settings icon pinned to bottom with visual separator
- Hover state highlights active icon
- Tooltip appears on hover (using `.help()` modifier)

### Non-functional
- SidebarNavigationView under 120 lines
- SidebarTab enum under 60 lines
- Uses existing `PopoverTheme` colors for all styling

## Architecture

### Data Flow
```
SidebarNavigationView
  @Binding activeTab: SidebarTab   ← bound to computed property in PopoverRootView
  onTabSelected: (SidebarTab) -> Void  ← calls viewModel.show*() methods
```

### SidebarTab -> Screen Mapping
| SidebarTab | Screen |
|------------|--------|
| .memory | .ram |
| .battery | .battery |
| .storage | .storage |
| .trends | .trends |
| .settings | .settings |

### Screen -> SidebarTab Reverse Mapping
| Screen | SidebarTab |
|--------|------------|
| .ram, .temperature | .memory |
| .battery | .battery |
| .storage, .storageManagement | .storage |
| .trends | .trends |
| .settings, .ramPolicyManager | .settings |

## Related Code Files

### New Files
- `MacMonitor/Sources/Features/Popover/SidebarTab.swift` — enum definition
- `MacMonitor/Sources/Features/Popover/SidebarNavigationView.swift` — sidebar view component

### Modified Files
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift` — remove `MainPopoverTab` enum (lines 4-35), remove `mainTabButton` function (lines 512-538), remove `activeTab` computed property (lines 3003-3014), remove `switchToTab` function (lines 3016-3027)
- `MacMonitor/Sources/Features/Popover/SystemSummaryViewModel.swift` — no changes needed (`.battery` case already exists)

## Implementation Steps

### Step 1: Create `SidebarTab.swift`
Location: `MacMonitor/Sources/Features/Popover/SidebarTab.swift`

```swift
import Foundation

enum SidebarTab: CaseIterable, Hashable {
    case memory
    case battery
    case storage
    case trends
    case settings

    var symbol: String {
        switch self {
        case .memory: return "memorychip"
        case .battery: return "battery.100"
        case .storage: return "internaldrive"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }

    var tooltip: String {
        switch self {
        case .memory: return "Memory"
        case .battery: return "Battery"
        case .storage: return "Storage"
        case .trends: return "Trends"
        case .settings: return "Settings"
        }
    }

    /// Top section items (above separator). Settings excluded — pinned to bottom.
    static var primaryItems: [SidebarTab] {
        [.memory, .battery, .storage, .trends]
    }
}
```

### Step 2: Create `SidebarNavigationView.swift`
Location: `MacMonitor/Sources/Features/Popover/SidebarNavigationView.swift`

Design spec:
- Width: 44pt
- Branding icon at top: `waveform.path.ecg` in accent color, 18pt, with 12pt vertical padding
- Separator line below branding
- Primary nav icons stacked vertically, 36x36pt hit area, 18pt icon size
- Active icon: `PopoverTheme.textPrimary` foreground + `PopoverTheme.bgCard` background pill
- Inactive icon: `PopoverTheme.textMuted` foreground, highlight on hover with `PopoverTheme.bgCard.opacity(0.4)`
- Bottom separator + settings icon pinned via `Spacer()`
- Each icon: `.help(tab.tooltip)` for native macOS tooltip
- Full height background: `PopoverTheme.bgPanel.opacity(0.72)`
- Right border: 1pt `PopoverTheme.borderSubtle`

```swift
struct SidebarNavigationView: View {
    let activeTab: SidebarTab
    let onTabSelected: (SidebarTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            brandingIcon
            sidebarDivider
            primaryNavItems
            Spacer(minLength: 0)
            sidebarDivider
            sidebarButton(.settings)
                .padding(.bottom, 8)
        }
        .frame(width: 44)
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(width: 1)
        }
    }
    // ... (brandingIcon, primaryNavItems, sidebarButton, sidebarDivider, sidebarBackground)
}
```

Key implementation detail for `sidebarButton`:
```swift
private func sidebarButton(_ tab: SidebarTab) -> some View {
    let isActive = activeTab == tab
    return Button { onTabSelected(tab) } label: {
        Image(systemName: tab.symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(isActive ? PopoverTheme.textPrimary : PopoverTheme.textMuted)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? PopoverTheme.bgCard : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(tab.tooltip)
}
```

### Step 3: Add `activeSidebarTab` + `switchToSidebarTab` in PopoverRootView
These replace `activeTab` and `switchToTab`. Add as private computed property and function inside `PopoverRootView`:

```swift
private var activeSidebarTab: SidebarTab {
    switch viewModel.screen {
    case .storage, .storageManagement: return .storage
    case .trends: return .trends
    case .settings, .ramPolicyManager: return .settings
    case .battery: return .battery
    case .temperature, .ram: return .memory
    }
}

private func switchToSidebarTab(_ tab: SidebarTab) {
    switch tab {
    case .memory: viewModel.showRAM()
    case .battery: viewModel.showBattery()
    case .storage: viewModel.showStorage()
    case .trends: viewModel.showTrends()
    case .settings: viewModel.showSettings()
    }
}
```

### Step 4: Update `normalizeLegacyScreenIfNeeded()`
Current (line 3029-3041):
```swift
private func normalizeLegacyScreenIfNeeded() {
    guard !hasNormalizedLegacyScreen else { return }
    hasNormalizedLegacyScreen = true
    switch viewModel.screen {
    case .temperature, .battery:      // <-- battery forced to RAM
        viewModel.showRAM()
    case .storageManagement:
        viewModel.showStorage()
    case .ram, .storage, .trends, .settings, .ramPolicyManager:
        break
    }
}
```

Updated:
```swift
private func normalizeLegacyScreenIfNeeded() {
    guard !hasNormalizedLegacyScreen else { return }
    hasNormalizedLegacyScreen = true
    switch viewModel.screen {
    case .temperature:
        viewModel.showRAM()
    case .storageManagement:
        viewModel.showStorage()
    case .battery, .ram, .storage, .trends, .settings, .ramPolicyManager:
        break
    }
}
```

### Step 5: Remove dead code from PopoverRootView
- Delete `MainPopoverTab` enum (lines 4-35)
- Delete `mainTabButton(_:)` function (lines 512-538)
- Delete `activeTab` computed property (lines 3003-3014)
- Delete `switchToTab(_:)` function (lines 3016-3027)

## Todo List

- [x] Create `SidebarTab.swift` with 5 cases, symbol, tooltip, `primaryItems`
- [x] Create `SidebarNavigationView.swift` with branding, icons, bottom-pinned settings
- [x] Add `activeSidebarTab` computed property in PopoverRootView
- [x] Add `switchToSidebarTab(_:)` function in PopoverRootView
- [x] Update `normalizeLegacyScreenIfNeeded()` — preserve `.battery` as valid screen
- [x] Remove `MainPopoverTab` enum from PopoverRootView
- [x] Remove `mainTabButton`, `activeTab`, `switchToTab` from PopoverRootView
- [x] Compile check: `xcodegen generate && xcodebuild build`

## Success Criteria
1. `SidebarTab.swift` exists, under 60 lines
2. `SidebarNavigationView.swift` exists, under 120 lines
3. `MainPopoverTab` fully removed from PopoverRootView
4. New `activeSidebarTab` / `switchToSidebarTab` work correctly
5. Project compiles (sidebar not yet wired into layout — that's Phase 2)

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Compile errors from removing MainPopoverTab before Phase 2 wires sidebar | Phase 1 adds activeSidebarTab/switchToSidebarTab immediately, so header tab buttons will use the new functions. Alternatively, keep old header code until Phase 2 and just add the new files. **Safer approach: keep old header code in Phase 1, remove in Phase 2.** |
| SF Symbol `memorychip` not available on macOS 14 | Verified: `memorychip` available since macOS 14.0 (SF Symbols 5). Safe. |

## Decision: Phase 1 Scope Adjustment
To avoid a broken compile state between Phase 1 and Phase 2, Phase 1 will:
- **Add** the new files (SidebarTab.swift, SidebarNavigationView.swift)
- **Add** `activeSidebarTab` and `switchToSidebarTab` to PopoverRootView
- **Update** `normalizeLegacyScreenIfNeeded()` 
- **NOT** remove `MainPopoverTab` or old tab functions yet (removed in Phase 2 when sidebar is wired in)

This keeps the project compilable after Phase 1.
