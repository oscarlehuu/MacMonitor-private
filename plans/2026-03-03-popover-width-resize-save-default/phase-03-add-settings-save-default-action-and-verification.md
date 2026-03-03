## 1) Context Links
- `./plans/2026-03-03-popover-width-resize-save-default/plan.md`
- `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`
- `./MacMonitor/Tests/SettingsStoreTests.swift`

## 2) Overview
- date: 2026-03-03
- priority: P1
- implementation status: pending
- description: Add Settings control to save current popover width as default and validate launch/open behavior.

## 3) Key Insights
- Active settings UI lives in `PopoverRootView.settingsGeneralCard`.
- Requirement is explicit user action to persist width, not implicit auto-save on drag.
- Keeping one button-driven flow reduces accidental preference churn.

## 4) Requirements
### Functional requirements
- Add Settings row that shows current/default width values.
- Add `Save Current Width as Default` action wired to `SettingsStore`.
- Disable button when current width already equals default width (optional but recommended).
- On next popover open and app relaunch, width uses saved default.

### Non-functional requirements
- Keep UI copy concise and consistent with existing settings cards.
- No additional tabs/screens.
- Maintain existing theme styling and accessibility (button labels/help text).

## 5) Architecture
- Extend `settingsGeneralCard` with one small width block:
  - value summary text (`Current`, `Default`)
  - save action button
- Reuse `SettingsStore` APIs from Phase 1.
- Keep validation split:
  - unit tests for store logic
  - manual verification for AppKit resize path.

## 6) Related Code Files
- modify: `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- modify: `./MacMonitor/Tests/SettingsStoreTests.swift`
- create: none
- delete: none

## 7) Implementation Steps
1. Add width summary row into `settingsGeneralCard` beneath launch-at-login toggle.
2. Add save button invoking `settings.saveCurrentPopoverWidthAsDefault()`.
3. Add disabled state when no width delta exists.
4. Add/adjust tests for save action (writes expected width key/value).
5. Execute full test suite and manual popover behavior checks.

## 8) Todo List
- [ ] Add settings copy for current/default width display.
- [ ] Add save-default button and button state logic.
- [ ] Validate styling in dark/light themes.
- [ ] Complete unit test updates.
- [ ] Run manual relaunch persistence validation.

## 9) Success Criteria
- User can intentionally save resized width from Settings.
- Relaunch/open behavior consistently applies saved width.
- No regression in existing settings controls.

## 10) Risk Assessment
- Risk: UI crowding in General card.
- Mitigation: use compact row and existing card styles; no new card unless spacing forces it.

## 11) Security Considerations
- Settings action updates local preference only; no privileged operations.
- Keep user-controlled values bounded through store clamp logic.

## 12) Next Steps
- If requested later: add "Reset to 440" action as a separate follow-up (out of current scope).
