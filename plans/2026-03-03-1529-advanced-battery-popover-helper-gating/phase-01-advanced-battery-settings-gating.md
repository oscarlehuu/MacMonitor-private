## Context Links
- [plan.md](./plan.md)
- [PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- [BatteryPolicyCoordinator.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Core/BatteryControl/BatteryPolicyCoordinator.swift)

## Overview
- Priority: P2
- Current status: completed
- Brief description: keep Advanced Battery card truthful and actionable with minimal UI changes.

## Key Insights
- Card already reads helper availability and has toggle rows with built-in `isEnabled`.
- Install flow already exists in battery screen; reuse coordinator async install API.
- Two rows are explicitly marked unavailable; simplest fix is to hide them.

## Requirements
- Functional requirements:
  - Hide deferred advanced rows ("Calibration Workflow", "MagSafe LED Control").
  - Disable available toggles when helper unavailable.
  - Show install-helper button in the same section when helper unavailable.
- Non-functional requirements:
  - Keep diff localized to one file.
  - Preserve existing visual language and spacing patterns.

## Architecture
- No architecture changes.
- Update only `settingsAdvancedBatteryCard` composition and reuse existing coordinator state.

## Related Code Files
- List of files to modify:
  - [PopoverRootView.swift](/Users/oscar/Desktop/Projects/OscarProjects/MacMonitor/MacMonitor/Sources/Features/Popover/PopoverRootView.swift)
- List of files to create:
  - none
- List of files to delete:
  - none

## Implementation Steps
1. Add local helper availability bool in `settingsAdvancedBatteryCard` scope.
2. Pass `isEnabled: helperAvailable` to the three available advanced toggle rows.
3. Remove unavailable/deferred rows from this card.
4. Under helper-unavailable banner, add a button to run `Task { await batteryPolicyCoordinator.installHelperIfNeededAsync() }`.
5. Disable install button and reduce opacity while `batteryPolicyCoordinator.isInstallingHelper` is true.
6. Keep dividers balanced after row removal to avoid visual artifacts.

## Todo List
- [x] Wire helper availability bool for toggle gating.
- [x] Hide deferred rows from card.
- [x] Add install-helper action button in card.
- [x] Validate compile + quick UI behavior.

## Success Criteria
- Helper unavailable:
  - three advanced toggles visible but disabled
  - install button visible and clickable
- Helper available:
  - toggles enabled
  - helper install button hidden
- No compile errors.

## Risk Assessment
- Risk: over-disabling unrelated controls if helper availability bool is applied too broadly.
- Mitigation: gate only three advanced toggles in this specific card.
- Risk: divider layout mismatch after hiding rows.
- Mitigation: verify card spacing manually in settings view.

## Security Considerations
- Keep install action routed through existing coordinator/backend path.
- Do not alter privileged helper install internals or auth flow.

## Next Steps
- Implement edits in one commit-sized change.
- Run targeted build/test command for compilation safety.

## Unresolved Questions
- None.
