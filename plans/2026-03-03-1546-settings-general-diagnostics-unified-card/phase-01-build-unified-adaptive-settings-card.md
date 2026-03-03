## Context Links
- [plan.md](./plan.md)
- [PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- [SettingsStore.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Settings/SettingsStore.swift)

## Overview
- Priority: P2
- Current status: completed
- Brief description: Replace two settings cards with one reusable adaptive card that keeps current behavior identical.

## Key Insights
- Existing general + diagnostics sections are already isolated in `settingsGeneralCard`, `settingsPopoverWidthRow`, and `settingsDiagnosticsCard`.
- All required behavior is already implemented via existing bindings/actions; this change is layout/composition only.
- Popover supports widths down to `SettingsStore.mainPopoverMinWidth` (360), so horizontal layout needs adaptive fallback.

## Requirements
- Functional requirements:
  - One reusable settings card containing 3 sections/columns: launch toggle, popover width controls, diagnostics export.
  - Keep all copy, state updates, bindings, and action handlers unchanged.
  - Preserve diagnostics status message rendering.
  - Provide narrow-width fallback layout.
- Non-functional requirements:
  - Restrict edits to `PopoverRootView.swift`.
  - Keep implementation simple and readable (no new architecture).

## Architecture
- Add a new card builder (e.g., `settingsGeneralAndDiagnosticsCard`).
- Inside card, build a 3-column layout first (`HStack`), with adaptive fallback (`ViewThatFits(in: .horizontal)` to stacked sections).
- Reuse existing row/section builders to avoid logic duplication.

## Related Code Files
- List of files to modify:
  - [PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- List of files to create:
  - none
- List of files to delete:
  - none

## Implementation Steps
1. In `settingsOverviewScreen`, replace `settingsGeneralCard` + `settingsDiagnosticsCard` with one new card property call.
2. Introduce a new reusable card property (name aligned with file conventions) using `settingsCard { ... }`.
3. Extract three section subviews/helpers from existing content:
   - General launch toggle block (from `settingsGeneralCard` first row).
   - Popover width block (existing `settingsPopoverWidthRow`).
   - Diagnostics block (from `settingsDiagnosticsCard`, including status text).
4. Compose primary layout as an `HStack(alignment: .top, spacing: ...)` with three equally flexible columns.
5. Wrap layout in `ViewThatFits(in: .horizontal)` and add fallback `VStack` section ordering: General -> Popover Width -> Diagnostics.
6. Keep actions and bindings exactly as-is:
   - `$settings.launchAtLoginEnabled`
   - `settings.saveCurrentPopoverWidthAsDefault()`
   - `exportDiagnostics()`
7. Keep existing disabled/opacity behavior for “Save Current Width as Default” and diagnostics status text rendering.
8. Remove or inline now-obsolete duplicated card wrappers (`settingsGeneralCard`, `settingsDiagnosticsCard`) only if no longer referenced.

## Todo List
- [x] Add unified reusable card skeleton.
- [x] Move general launch content into reusable section.
- [x] Reuse popover width section in unified layout.
- [x] Move diagnostics export + status into reusable section.
- [x] Add adaptive fallback (`ViewThatFits`) for narrow widths.
- [x] Replace old card usage in settings screen.
- [x] Build + run targeted tests.

## Success Criteria
- Settings screen shows one combined card for General + Popover Width + Diagnostics.
- Wide width: 3 horizontal columns visible.
- Narrow width: fallback stacked layout shows all sections without clipped controls.
- Launch toggle, width save action, diagnostics export, and diagnostics status message behave exactly as before.
- Project builds successfully and targeted tests pass.

## Risk Assessment
- Risk: accidental binding/action rewiring during extraction.
- Mitigation: move UI blocks with original bindings/actions unchanged; no closure signature changes.
- Risk: overly rigid column widths cause truncation.
- Mitigation: use flexible frames + `ViewThatFits` fallback.

## Security Considerations
- No new privileged operations or data paths.
- Diagnostics export still uses existing exporter flow.

## Next Steps
- None. Phase completed and validated.

## Unresolved Questions
- None.
