# Phase 01: Update Group Icons and Ring Bucket Colors

## Context Links
- Plan: [plan.md](./plan.md)
- Target files:
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
  - `MacMonitor/Sources/Features/StorageManagement/StorageRingChartView.swift`

## Overview
- Priority: P2
- Status: Pending
- Goal: Improve visual clarity in Storage & Apps without changing scan, selection, delete, or sorting behavior.

## Key Insights
- App groups already include an `.app` item URL in `group.items` (kind `.appBundle`), so no new data plumbing is required.
- Disk Distribution colors are currently mapped only by category (`application/cache/folder`), causing repeated colors across many buckets.
- The chart and legend are in the same view, enabling a single shared color resolver for strict consistency.

## Requirements
- Functional:
  - Replace app group header `app.dashed` placeholder with real app icon from app bundle/system when possible.
  - Use per-bucket distinct colors for both chart segments and legend markers.
  - Keep fallback behavior so UI remains stable when icon or color lookup fails.
- Non-functional:
  - Keep render performance acceptable; avoid expensive repeated work where practical.
  - No behavior regressions in selection, expansion, deletion, filtering, or refresh.
  - Modify existing files only.

## Architecture
- App icon path:
  - In `StorageManagementView`, resolve icon using group’s app bundle item URL (`kind == .appBundle`) and `NSWorkspace.shared.icon(forFile:)`.
  - If not resolvable, keep current symbol fallback (`app.dashed`).
- Bucket color path:
  - In `StorageRingChartView`, replace `color(for category:)` with `color(for bucket:)`.
  - Use deterministic mapping by bucket identity (e.g., stable string hash over `bucket.id`) into a multi-color palette from existing `PopoverTheme` colors.
  - Reuse same resolver for chart segment fill and legend dot.

## Related Code Files
- Files to modify:
  - `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift`
  - `MacMonitor/Sources/Features/StorageManagement/StorageRingChartView.swift`
- Files to create:
  - None
- Files to delete:
  - None

## Implementation Steps
1. In `StorageManagementView`, add a small helper that resolves a group app icon from the group’s `.appBundle` item URL; return optional `NSImage`.
2. Update group row icon view:
   - Render `Image(nsImage: resolvedIcon)` when available.
   - Keep existing SF Symbol placeholder + style as fallback.
3. In `StorageRingChartView`, add a deterministic per-bucket color resolver using a broader palette (existing `PopoverTheme` colors only).
4. Replace all category-color call sites in chart and legend with the new bucket-color resolver.
5. Keep all existing sorting, truncation (`prefix(6)`), and bucket aggregation behavior unchanged.
6. Compile and run tests; perform quick manual visual verification in Storage & Apps.

## Todo List
- [ ] Add app-group icon resolver and fallback rendering.
- [ ] Add deterministic per-bucket color resolver.
- [ ] Wire chart + legend to same bucket color resolver.
- [ ] Build + test + manual verify no regressions.

## Success Criteria
- Group rows show accurate app icons for resolvable app bundles.
- Missing/unresolvable icons still show current placeholder glyph.
- Disk Distribution chart + legend use matching per-bucket colors.
- No functional behavior changes outside visual icon/color updates.
- Project builds and tests pass.

## Risk Assessment
- Risk: `NSWorkspace` icon retrieval may add repeated work during view updates.
  - Mitigation: keep resolver lightweight; optionally memoize in-view if profiling indicates cost.
- Risk: Non-deterministic hashing would cause color drift across runs.
  - Mitigation: use a stable custom string-hash routine, not `hashValue`.
- Risk: Low-contrast colors in some themes.
  - Mitigation: choose palette from existing theme semantic colors already used in UI.

## Security Considerations
- No network, auth, or permission model changes.
- Reads app icon metadata from local filesystem paths already scanned by current feature.

## Next Steps
1. Implement phase 01 exactly in listed files.
2. Validate with `xcodebuild` tests and manual Storage & Apps visual check.
3. If accepted, update roadmap/changelog entries per project doc workflow.

## Unresolved Questions
- None.
