## 1) Context Links
- `./plan.md`
- `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`

## 2) Overview
- Priority: P1
- Current status: pending
- Description: apply requested Alerts UI copy + control changes with minimal view updates.

## 3) Key Insights
- Current Alerts card already follows a stable row pattern (toggle + picker rows).
- Numeric threshold inputs should reuse one helper row to avoid duplicated parsing logic.

## 4) Requirements
- Functional requirements:
  - Rename label to `Thermal Pressure Alerts`.
  - Reduce cooldown picker options to `[5, 10, 15, 30]`.
  - Add RAM alert toggle row.
  - Replace `Storage Threshold` picker with numeric percent input.
  - Add RAM threshold numeric percent input.
- Non-functional requirements:
  - Keep current card layout, theme tokens, spacing.
  - Keep inputs clamped and persisted via `settings.systemAlertSettings`.

## 5) Architecture
- Continue using `settings.systemAlertSettings` as single source of truth.
- Add one reusable percent-input row helper in `PopoverRootView` (no new file).

## 6) Related Code Files
- Modify:
  - `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- Create:
  - none
- Delete:
  - none

## 7) Implementation Steps
1. Rename existing thermal toggle title text.
2. Replace storage threshold picker row with numeric input row bound to `storageUsagePercentThreshold`.
3. Insert RAM alert toggle + RAM threshold numeric row bound to new RAM fields.
4. Reduce cooldown options in existing cooldown picker row.
5. Ensure invalid/empty input resolves to safe clamped values and does not break binding.

## 8) Todo List
- [ ] Rename thermal label.
- [ ] Add reusable numeric percent row helper.
- [ ] Convert storage threshold to numeric input.
- [ ] Add RAM toggle + threshold numeric input.
- [ ] Update cooldown options.

## 9) Success Criteria
- Settings card shows requested label text.
- Storage/RAM thresholds are editable via numeric input only.
- Cooldown choices are the reduced set.
- UI remains visually and behaviorally consistent.

## 10) Risk Assessment
- Risk: text input state can desync with persisted Int values.
- Mitigation: central parse/clamp helper + on-submit/on-focus-loss normalization.

## 11) Security Considerations
- No new external IO.
- Input handling only affects in-app persisted settings values.

## 12) Next Steps
- Add targeted tests and run `xcodebuild` subset in Phase 03.
