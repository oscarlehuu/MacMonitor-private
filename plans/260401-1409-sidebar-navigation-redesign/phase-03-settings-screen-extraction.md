# Phase 3: Settings Screen Extraction

## Context
- [PopoverRootView.swift](../../MacMonitor/Sources/Features/Popover/PopoverRootView.swift) — settings code spans lines 1479-2700 (~1,220 lines)
- [SettingsStore.swift](../../MacMonitor/Sources/Features/Settings/SettingsStore.swift) — settings persistence
- [SettingsView.swift](../../MacMonitor/Sources/Features/Settings/SettingsView.swift) — existing separate settings file (if exists, may be unused)

## Overview
- **Priority:** P2 — modularization, no functional change
- **Status:** Complete
- **Blocked by:** Phase 2
- **Description:** Extract the inline settings screen from PopoverRootView into a standalone `PopoverSettingsScreenView.swift`. This is the largest single contributor to PopoverRootView's 3,480-line count (~1,220 lines, 35% of file).

## Key Insights
- Settings code is self-contained: `settingsOverviewScreen` (line 1479) plus ~40 private helpers/sub-views that are only used by settings
- Settings helpers reference these from PopoverRootView:
  - `viewModel` (ObservedObject) — for `showRAMPolicyManager()`, `showBattery()`
  - `settings` (ObservedObject) — for all settings reads/writes
  - `appUpdateController` (ObservedObject) — update status
  - `diagnosticsExporter` — export function
  - `diagnosticsStatusMessage` (@State) — transient status string
  - `isMenuBarComposerPresented` (@State) — sheet presentation
  - `menuBarComposerDraftConfiguration` (@State) — composer draft
  - `batteryPolicyCoordinator` (ObservedObject) — helper availability for diagnostics
- All the `settingsCompact*`, `settingsCard`, `settingsSectionHeader`, `settingsAlerts*`, `settingsAdvancedBattery*`, `settingsAbout*`, `settingsMenuBar*`, `settingsGeneral*`, `menuBarComposerSheet` views are extraction candidates
- The color picker helpers (`settingsAlertsHeaderHighlightColorPicker`, `colorHexValue`, `settingsTextMuted`, `settingsCardFill`, etc.) are also settings-only

## Requirements

### Functional
- Zero visual or behavioral change — pure extraction refactor
- Settings screen must receive all dependencies via init parameters
- Navigation callbacks (`showRAMPolicyManager`, `showBattery`) passed as closures

### Non-functional
- Extracted file under 200 lines if possible — if not, split into sub-components
- PopoverRootView reduced by ~1,200 lines after extraction

## Architecture

### Dependency Injection
```swift
struct PopoverSettingsScreenView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    let diagnosticsExporter: DiagnosticsExporter
    let onShowRAMPolicies: () -> Void
    let onShowBattery: () -> Void
    let popoverWindowProvider: (() -> NSWindow?)?

    @State private var diagnosticsStatusMessage: String?
    @State private var isMenuBarComposerPresented: Bool = false
    @State private var menuBarComposerDraftConfiguration: MenuBarComposerConfiguration = .default
    // ... body
}
```

### Data Flow
```
PopoverRootView
  └── PopoverSettingsScreenView
        ├── reads: settings, appUpdateController, batteryPolicyCoordinator
        ├── calls: diagnosticsExporter.exportDiagnosticsBundle()
        ├── calls: onShowRAMPolicies() → viewModel.showRAMPolicyManager()
        └── calls: onShowBattery() → viewModel.showBattery()
```

## Related Code Files

### New Files
- `MacMonitor/Sources/Features/Settings/PopoverSettingsScreenView.swift` — main settings screen container

Given the settings code is ~1,220 lines, it should be split further. The natural split:
- `PopoverSettingsScreenView.swift` — orchestrates sections (~120 lines)
- `MacMonitor/Sources/Features/Settings/SettingsMenuBarCard.swift` — menu bar config section (~100 lines)
- `MacMonitor/Sources/Features/Settings/SettingsAlertsCard.swift` — alerts configuration (~120 lines)
- `MacMonitor/Sources/Features/Settings/SettingsBatteryCard.swift` — advanced battery section (~110 lines)
- `MacMonitor/Sources/Features/Settings/SettingsAboutCard.swift` — about/diagnostics section (~100 lines)
- `MacMonitor/Sources/Features/Settings/SettingsGeneralCard.swift` — general settings (launch, width, updates) (~150 lines)
- `MacMonitor/Sources/Features/Settings/SettingsCardHelpers.swift` — shared card wrapper, section header, theme color helpers (~100 lines)
- `MacMonitor/Sources/Features/Settings/MenuBarComposerSheetView.swift` — menu bar composer sheet (~150 lines)

### Modified Files
- `MacMonitor/Sources/Features/Popover/PopoverRootView.swift`:
  - Replace `settingsOverviewScreen` body with single `PopoverSettingsScreenView(...)` call
  - Remove all `settings*` private views/functions (lines 1479-2700)
  - Remove `diagnosticsStatusMessage` @State (moved to PopoverSettingsScreenView)
  - Remove `isMenuBarComposerPresented` @State (moved)
  - Remove `menuBarComposerDraftConfiguration` @State (moved)
  - Remove `exportDiagnostics()` function (moved)
  - Remove `openPublicReleasePage()` function (moved)

## Implementation Steps

### Step 1: Identify exact extraction boundary
Scan every `private var settings*` and `private func settings*` in PopoverRootView. Also include:
- `menuBarComposerSheet` (line 2278)
- `exportDiagnostics()` (line 3055)
- `openPublicReleasePage()` (line 3073)
- `formattedMainPopoverWidth` (line 2689)
- `infoBanner` (line 2693) — check if used outside settings
- `colorHexValue` (line 2640) — settings-only
- `settingsPickerWidth` (line 2677)
- Settings theme color helpers (lines 2585-2612)

Verify `infoBanner` and `panelCard` are not used by non-settings screens before extracting.

### Step 2: Create shared helpers file
`SettingsCardHelpers.swift` with:
- `settingsCard` view builder
- `settingsSectionHeader` helper
- Theme color computed properties (if needed across multiple settings files)

### Step 3: Extract cards one-by-one
Extract each settings card into its own file, starting from the most self-contained:
1. `SettingsAboutCard.swift` — version info, diagnostics export, release link
2. `SettingsBatteryCard.swift` — advanced battery controls
3. `SettingsAlertsCard.swift` — alert thresholds + color picker
4. `SettingsMenuBarCard.swift` — menu bar composer button + config
5. `SettingsGeneralCard.swift` — launch, popover width, updates

### Step 4: Create `PopoverSettingsScreenView.swift`
Composes all cards in a VStack:
```swift
var body: some View {
    VStack(alignment: .leading, spacing: 16) {
        SettingsMenuBarCard(settings: settings, ...)
        SettingsGeneralCard(settings: settings, appUpdateController: appUpdateController, ...)
        SettingsAlertsCard(settings: settings, ...)
        SettingsBatteryCard(settings: settings, onShowBattery: onShowBattery, ...)
        SettingsAboutCard(appUpdateController: appUpdateController, ...)
    }
}
```

### Step 5: Wire into PopoverRootView
Replace `settingsOverviewScreen` body:
```swift
private var settingsOverviewScreen: some View {
    PopoverSettingsScreenView(
        settings: settings,
        appUpdateController: appUpdateController,
        batteryPolicyCoordinator: batteryPolicyCoordinator,
        diagnosticsExporter: diagnosticsExporter,
        onShowRAMPolicies: viewModel.showRAMPolicyManager,
        onShowBattery: viewModel.showBattery,
        popoverWindowProvider: popoverWindowProvider
    )
}
```

### Step 6: Remove extracted code from PopoverRootView
Delete all `settings*` private views, helper functions, and moved @State properties.

### Step 7: Compile check
```bash
xcodegen generate && xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -destination 'platform=macOS' build
```

## Todo List

- [x] Audit settings code boundary — confirm which helpers are settings-only
- [x] Create `SettingsCardHelpers.swift` with shared card wrapper + section header
- [x] Extract `SettingsAboutCard.swift`
- [x] Extract `SettingsBatteryCard.swift`
- [x] Extract `SettingsAlertsCard.swift`
- [x] Extract `SettingsMenuBarCard.swift` + `MenuBarComposerSheetView.swift`
- [x] Extract `SettingsGeneralCard.swift`
- [x] Create `PopoverSettingsScreenView.swift` composing all cards
- [x] Wire `PopoverSettingsScreenView` into PopoverRootView
- [x] Remove all extracted settings code from PopoverRootView
- [x] Compile check

## Success Criteria
1. Settings screen looks and behaves identically to before
2. PopoverRootView reduced by ~1,200 lines
3. Each new settings file under 200 lines
4. Navigation to RAM policies and battery from settings still works
5. Menu bar composer sheet still opens and saves correctly
6. Diagnostics export still works
7. Project compiles cleanly

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| `panelCard` or `infoBanner` used by non-settings screens | Grep before extracting. If shared, keep in PopoverRootView or extract to a common helpers file. |
| `PopoverColorPanelController` (@StateObject at line 269) used only by settings alerts color picker | Verify scope. If settings-only, move into SettingsAlertsCard. If shared, keep in PopoverRootView and pass as binding. |
| Theme color helpers depend on `settings.appTheme` observation | Pass `settings` as @ObservedObject to each card — SwiftUI handles reactivity. |
| Menu bar composer sheet presentation state | Move `isMenuBarComposerPresented` + `menuBarComposerDraftConfiguration` @State into PopoverSettingsScreenView or SettingsMenuBarCard. Sheet modifier stays local. |

## Net Line Count Impact
- Removed from PopoverRootView: ~1,220 lines
- Added to PopoverRootView: ~15 lines (wiring)
- New files total: ~850 lines across 8 files (avg ~106 lines each)
- **Net PopoverRootView reduction: ~1,205 lines**
