## 1) Context Links
- `./plans/2026-03-03-popover-width-resize-save-default/plan.md`
- `./MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`

## 2) Overview
- date: 2026-03-03
- priority: P1
- implementation status: pending
- description: Make popover horizontally resizable and ensure it opens at saved default width while preserving fixed height.

## 3) Key Insights
- `NSPopover` can be made resizable by configuring the underlying window after `popoverDidShow`.
- Current `.frame(width: 440, height: 620)` in `PopoverRootView` blocks meaningful width resizing.
- Height should stay fixed to reduce regression risk in existing scroll/layout behavior.

## 4) Requirements
### Functional requirements
- Enable drag-resize affordance on active popover window.
- Allow width resize only (lock height min=max fixed height).
- Apply saved default width every time popover opens.
- Report live resized width back to `SettingsStore.mainPopoverCurrentWidth`.

### Non-functional requirements
- Keep resize setup isolated in `MenuBarController`.
- Avoid introducing new controllers/services.
- Preserve current transient popover behavior and status-item interactions.

## 5) Architecture
- In `MenuBarController`:
  - Set `popover.contentSize` from `settings.mainPopoverDefaultWidth` before/when showing.
  - In `popoverDidShow`, get popover window and configure: `.resizable`, `minSize`, `maxSize`, fixed height.
  - Subscribe to window resize notification and push width updates into settings store.
  - Clean observer on close/uninstall.
- In `PopoverRootView`:
  - Replace hard fixed width frame with width-flexible frame bounded by min/max width constants.
  - Keep fixed height and existing visuals unchanged.

## 6) Related Code Files
- modify: `./MacMonitor/Sources/Features/MenuBar/MenuBarController.swift`
- modify: `./MacMonitor/Sources/Features/Popover/PopoverRootView.swift`
- create: none
- delete: none

## 7) Implementation Steps
1. Add a small private resize observer holder to `MenuBarController` lifecycle.
2. Apply saved default width in `togglePopover` open path (before show).
3. Configure popover window in `popoverDidShow` with width range + fixed height.
4. Attach `NSWindow.didResizeNotification` for current-width updates.
5. Detach resize observer in `popoverDidClose` and `uninstall`.
6. Update `PopoverRootView` top-level frame to support variable width.

## 8) Todo List
- [ ] Remove fixed-width lock from SwiftUI root container.
- [ ] Add AppKit resize configuration hook.
- [ ] Enforce width bounds + fixed height at window level.
- [ ] Push live width changes into settings store.
- [ ] Ensure observer cleanup to avoid leaks/duplicate callbacks.

## 9) Success Criteria
- User can drag left/right popover edge to change width.
- Height remains unchanged during resize.
- Current width state updates while resizing.

## 10) Risk Assessment
- Risk: macOS variation in popover window style behavior.
- Mitigation: apply configuration after popover is shown and verify on target OS versions.

## 11) Security Considerations
- No new privileged or network behavior.
- Keep resize handling on main thread to avoid UI race issues.

## 12) Next Steps
- Expose save-default action in Settings UI and validate persistence flow (Phase 3).
