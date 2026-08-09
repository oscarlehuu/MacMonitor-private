---
title: "Storage hierarchical tree drill-down"
description: "Replace flat storage list with unlimited-depth tree grouped by filesystem location"
status: pending
priority: P1
effort: 6h
branch: codex/storage-apps-advisor-v2
tags: [storage, ui, tree, drill-down]
created: 2026-04-01
---

# Storage Hierarchical Tree Drill-Down

## Overview

Replace the flat `StorageListEntry` list in the Storage view with an unlimited-depth tree structure. Items are grouped by filesystem location (Applications, Caches, Developer, Package Caches, Projects, etc.). App groups with multiple sub-items expand to show children. Everything starts collapsed.

**Scanner remains unchanged** — tree is built purely from existing `StorageScanResult` data.

## Data Flow

```
Scanner (unchanged)
  |
  v
StorageScanResult { appGroups, looseItems }
  |
  v
StorageTreeBuilder.buildTree(from:)   <-- NEW
  |
  v
[StorageTreeNode]  (root-level nodes)  <-- NEW
  |
  v
ViewModel exposes `treeNodes` + manages expandedNodeIDs, selection
  |
  v
View renders recursively with indentation per depth
```

## Architecture Decisions

1. **Tree is a view-model concern, not a model concern.** The scanner returns flat data; the tree is built for display purposes only.
2. **`StorageTreeNode` is a class (reference type)** with `children` array for recursive rendering. Identity via `id: String` (path-based).
3. **`StorageTreeBuilder` is a standalone struct** in its own file — keeps VM from growing beyond 1200 lines.
4. **Selection stays leaf-level** — `selectedItemIDs: Set<String>` contains only `StorageManagedItem.id` values (file paths). Parent selection/deselection is derived.
5. **`StorageListEntry` is kept** for backwards compat in delete confirmation overlay and anywhere else that references it. Tree nodes reference leaf items but don't replace the entry enum.

---

## Phase 1 — StorageTreeNode Model

| | |
|---|---|
| **Status** | Pending |
| **Files** | `MacMonitor/Sources/Core/Storage/StorageTreeNode.swift` (NEW, ~60 lines) |
| **Risk** | Low |

### Requirements

Create `StorageTreeNode` — the recursive node for the tree.

```swift
final class StorageTreeNode: Identifiable, ObservableObject {
    let id: String                              // unique path-based key
    let label: String                           // display name
    let iconSystemName: String?                 // SF Symbol, nil for intermediate dirs
    let sizeBytes: UInt64                       // sum of all descendant leaf sizes
    let depth: Int                              // 0 = root category
    let appGroup: StorageAppGroup?              // non-nil if this node IS an app group
    let leafItem: StorageManagedItem?           // non-nil if this node IS a single leaf item
    var children: [StorageTreeNode]             // empty = leaf or unexpandable
    
    var isLeaf: Bool { children.isEmpty }
    var isExpandable: Bool { !children.isEmpty }
    
    // Computed: all leaf item IDs under this node (recursive, cached)
    var allLeafItemIDs: Set<String>
}
```

**Identity design:**
- Root category nodes: `"cat:Applications"`, `"cat:Caches"`, `"cat:Developer"`, etc.
- App group nodes: `"group:<appGroupID>"`
- Leaf items: `item.id` (which is the standardized file path)
- Intermediate directory nodes: `"dir:<path>"` for path-derived intermediates (e.g., `"dir:~/Projects/OscarProjects"`)

### Success Criteria
- [ ] `StorageTreeNode` compiles
- [ ] `allLeafItemIDs` returns correct set recursively
- [ ] Node with no children reports `isLeaf == true`

### Rollback
Delete the file. No other files depend on it yet.

---

## Phase 2 — StorageTreeBuilder

| | |
|---|---|
| **Status** | Pending |
| **Files** | `MacMonitor/Sources/Core/Storage/StorageTreeBuilder.swift` (NEW, ~150 lines) |
| **Depends on** | Phase 1 |
| **Risk** | Medium — categorization logic is the heart of the feature |

### Requirements

Pure function that takes `StorageScanResult` and returns `[StorageTreeNode]` (root-level categories, sorted by size desc).

**Categorization rules:**

| Item Kind(s) | Root Category | Grouping |
|---|---|---|
| `.appBundle`, `.appCache`, `.appSupport`, `.appContainer`, `.appLogs`, `.appPreferences` | "Applications" | Grouped under their `StorageAppGroup` |
| `.looseCache` | "Caches" | Flat under category |
| `.derivedData`, `.xcodeArchives`, `.simulatorData`, `.unavailableSimulator` | "Developer" | Flat under category |
| `.npmCache`, `.yarnCache`, `.pnpmStore` | "Package Caches" | Flat under category |
| `.nodeModules` | Derive from path | Under intermediate dirs matching URL path segments relative to home |
| `.customFolder` | Derive from path | Under intermediate dirs matching URL path segments relative to home |
| `.looseFolder` | Derive from path | Under intermediate dirs if deep, or "Other" if shallow |

**App group handling:**
- Single-item app groups (after filtering protected/zero-size) = leaf node, no expand
- Multi-item app groups = expandable node, children are the individual `StorageManagedItem` entries sorted by size desc

**Intermediate directories:**
- For items like `~/Projects/OscarProjects/MacMonitor/node_modules`, build intermediate nodes: "Projects" (root) > "OscarProjects" (dir) > "MacMonitor" (dir) > leaf
- Only create intermediates when there are 2+ items at different sub-paths under the same root

**Size aggregation:**
- Each node's `sizeBytes` = sum of all descendant leaf `sizeBytes`
- Empty categories (0 bytes or 0 items after filtering) are omitted

### Implementation Steps

1. Partition items by root category based on `kind`
2. For each category, build child nodes:
   - "Applications": one node per app group
   - Others: one node per item, or intermediate dirs for path-derived items
3. Compute sizes bottom-up
4. Sort children at each level by size desc
5. Omit empty categories
6. Cache `allLeafItemIDs` at construction time

### Test Matrix

| Scenario | Expected |
|---|---|
| Empty scan result | Returns `[]` |
| Only app groups, no loose | Single "Applications" root with children |
| Single-item app group | Leaf node under Applications (no expand) |
| Multi-item app group | Expandable node with sorted children |
| Loose caches | "Caches" category with flat children |
| Dev tools items | "Developer" category |
| node_modules at depth | Intermediate dir nodes created |
| Protected items | Excluded from tree |
| Zero-byte items | Excluded from tree |
| Mixed everything | All categories present, sorted by size |

### Failure Modes

| Failure | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Wrong categorization of item kind | Medium | High | Exhaustive switch, no default case |
| Infinite loop in intermediate dir building | Low | High | Max depth guard (20 levels) |
| Performance on large scans | Low | Medium | Tree built once per scan, cached |

### Rollback
Delete the file. No other files depend on it yet.

---

## Phase 3 — ViewModel Integration

| | |
|---|---|
| **Status** | Pending |
| **Files** | `MacMonitor/Sources/Features/StorageManagement/StorageManagementViewModel.swift` (MODIFY) |
| **Depends on** | Phase 1, Phase 2 |
| **Risk** | Medium — largest change surface, touches selection logic |

### Requirements

**Add to ViewModel:**

```swift
// New published state
@Published private(set) var treeNodes: [StorageTreeNode] = []
@Published var expandedNodeIDs: Set<String> = []

// New private state
private var treeNodeIndex: [String: StorageTreeNode] = [:]
```

**Modify existing methods:**

1. **`rebuildItemIndex()`** — after rebuilding item index, also call `StorageTreeBuilder.buildTree(from:)` and store result in `treeNodes`. Build a `treeNodeIndex` for O(1) node lookup by ID.

2. **`filteredEntries`** — keep existing for delete confirmation overlay. Add new `filteredTreeNodes` computed property that applies filter chips to tree (filter at root category level or prune branches).

3. **Selection methods — adapt for tree node IDs:**
   - `toggleSelection(for nodeID: String)` — if node has children, toggle all `allLeafItemIDs`. If leaf, toggle single item.
   - `nodeSelectionState(_ nodeID: String) -> StorageSelectionState` — derive from `allLeafItemIDs` intersection with `selectedItemIDs`.
   - Keep existing `toggleSelection(for entryID:)` and `entrySelectionState(_:)` for delete confirmation (they still use `StorageListEntry`).

4. **Expansion:**
   - Replace `expandedEntryIDs` with `expandedNodeIDs` (or keep both during transition)
   - `toggleExpansion(for nodeID:)`, `isExpanded(_ nodeID:)` — same pattern, new set
   - Remove old `hasChildren`, `childItems`, `isExpanded`, `toggleExpansion` that use entry IDs (or deprecate)

5. **Filter logic for tree:**
   - `.all` — show all root categories
   - `.apps` — show only "Applications" root
   - `.caches` — show only "Caches" root
   - `.devTools` — show only "Developer" and "Package Caches" roots
   - Search: filter leaf nodes by name/path, keep parent chain visible if any leaf matches

### Data Flow Changes

```
performRefresh()
  -> rebuildItemIndex()      (existing)
  -> buildTree()             (NEW - calls StorageTreeBuilder)
  -> normalizeSelection()    (existing, unchanged)
```

### Methods to Add (~80 lines)

- `func toggleNodeSelection(for nodeID: String)`
- `func nodeSelectionState(_ nodeID: String) -> StorageSelectionState`
- `func toggleNodeExpansion(for nodeID: String)`
- `func isNodeExpanded(_ nodeID: String) -> Bool`
- `var filteredTreeNodes: [StorageTreeNode]` (computed)
- Private `buildTree()` that calls `StorageTreeBuilder`

### Methods to Remove/Deprecate

- `hasChildren(_ entryID:)` — replaced by `node.isExpandable`
- `childItems(for entryID:)` — replaced by `node.children`
- `expandedEntryIDs` — replaced by `expandedNodeIDs`

### Backwards Compatibility

- `filteredEntries`, `listEntries`, `selectedEntriesForConfirmation` — **kept as-is** for delete confirmation overlay
- `selectedItemIDs: Set<String>` — **unchanged**, still leaf-level file paths
- `entrySelectionState` — kept for delete confirmation

### Success Criteria
- [ ] `treeNodes` populated after `performRefresh()`
- [ ] `toggleNodeSelection` on parent selects/deselects all descendants
- [ ] `nodeSelectionState` returns `.partial` when subset selected
- [ ] Filter chips filter tree at root category level
- [ ] Search prunes tree to matching branches
- [ ] Delete flow still works (uses existing `selectedItemIDs` + `selectedEntriesForConfirmation`)

### Rollback
Revert changes to ViewModel. Tree methods are additive — removing them restores flat list behavior.

---

## Phase 4 — View Rendering

| | |
|---|---|
| **Status** | Pending |
| **Files** | `MacMonitor/Sources/Features/StorageManagement/StorageManagementView.swift` (MODIFY), `MacMonitor/Sources/Features/StorageManagement/StorageTreeRowView.swift` (NEW, ~120 lines) |
| **Depends on** | Phase 3 |
| **Risk** | Medium — recursive SwiftUI rendering needs care for performance |

### Requirements

**New file: `StorageTreeRowView.swift`**

Recursive SwiftUI view that renders a single tree node row with:
- Indentation: `leading padding = depth * 20`
- Disclosure chevron (rotated when expanded) — only if `node.isExpandable`
- Checkbox (checkmark.circle.fill / minus.circle.fill / circle) based on selection state
- Icon (from `node.iconSystemName` or app icon)
- Label (from `node.label`)
- Size bar (proportional to sibling max)
- Size text

When expanded, recursively renders children with depth+1.

**Modify `StorageManagementView.swift`:**

Replace the `ForEach(entries)` + `listEntryRow` + `childItemRow` block with:
```swift
ForEach(viewModel.filteredTreeNodes) { rootNode in
    StorageTreeRowView(
        node: rootNode,
        viewModel: viewModel,
        appIconsByGroupID: appIconsByGroupID,
        maxBytes: maxBytes,
        reduceMotion: reduceMotion
    )
}
```

Remove:
- `listEntryRow(entry:maxBytes:)` — replaced by `StorageTreeRowView`
- `childItemRow(child:maxBytes:)` — replaced by recursive rendering
- References to `viewModel.filteredEntries` in the scroll view body (keep for animation value)
- `entryBarColor(for:)` — move color logic into `StorageTreeRowView` or keep as shared helper

Keep:
- `deleteConfirmationOverlay` — still uses `StorageListEntry` via `selectedEntriesForConfirmation`
- `entryIcon(for:)` — still needed for delete confirmation
- All status cards, disk usage bar, filter chips, search bar — unchanged
- App icon loading — unchanged, keyed by group ID

### Visual Design

```
[checkbox] [icon] Applications (82 GB)          [====] 82 GB
  [checkbox] [icon] Docker (19.5 GB)            [===]  19.5 GB
    [checkbox] [icon] App Bundle (2.1 GB)       [=]    2.1 GB
    [checkbox] [icon] App Cache (15.2 GB)       [===]  15.2 GB
    [checkbox] [icon] App Support (2.2 GB)      [=]    2.2 GB
  [checkbox] [icon] League of Legends (37 GB)   [====] 37 GB
[checkbox] [icon] Caches (6.0 GB)               [==]   6.0 GB
  [checkbox] [icon] com.docker.docker (2 GB)    [==]   2.0 GB
```

- Root categories: slightly bolder text, no checkbox (or select-all behavior)
- Depth 1+: standard row style with increasing indent
- Size bars proportional to siblings at same level

### Performance Considerations

- Use `LazyVStack` — only renders visible rows
- Expanded state changes use `withAnimation` — same as current
- `ForEach` keyed on `node.id` — stable identity for animations

### Success Criteria
- [ ] Tree renders with proper indentation at each depth
- [ ] Chevron rotates on expand/collapse
- [ ] Clicking parent checkbox selects all descendants
- [ ] Partial selection (some descendants) shows indeterminate checkbox
- [ ] Clicking row body expands/collapses if expandable; toggles selection if leaf
- [ ] Filter chips hide/show root categories
- [ ] Search filters to matching branches
- [ ] Delete confirmation overlay still works
- [ ] Animations smooth (expand/collapse, selection highlight)

### Rollback
Revert View changes, delete `StorageTreeRowView.swift`. Restore `ForEach(entries)` block.

---

## Phase 5 — Tests

| | |
|---|---|
| **Status** | Pending |
| **Files** | `MacMonitor/Tests/StorageTreeBuilderTests.swift` (NEW, ~180 lines), `MacMonitor/Tests/StorageManagementViewModelTests.swift` (MODIFY) |
| **Depends on** | Phase 2, Phase 3 |
| **Risk** | Low |

### StorageTreeBuilderTests (NEW)

Unit tests for the builder in isolation:

| Test | Asserts |
|---|---|
| `testEmptyScanReturnsEmptyTree` | `buildTree(from: empty) == []` |
| `testAppGroupsCreateApplicationsCategory` | Root node labeled "Applications" exists |
| `testSingleItemAppGroupIsLeaf` | Node has no children |
| `testMultiItemAppGroupIsExpandable` | Node has children sorted by size |
| `testLooseCacheCreatesCachesCategory` | Root "Caches" with children |
| `testDevToolsItemsCreateDeveloperCategory` | Root "Developer" with children |
| `testPackageCacheKindsGrouped` | npm/yarn/pnpm under "Package Caches" |
| `testNodeModulesCreateIntermediateDirs` | Path segments become intermediate nodes |
| `testProtectedItemsExcluded` | Protected items not in tree |
| `testZeroBytesExcluded` | Zero-byte items not in tree |
| `testSizesAggregateBottomUp` | Parent size = sum of children |
| `testRootsSortedBySizeDesc` | Categories sorted largest first |
| `testAllLeafItemIDsRecursive` | Correct set at each level |

### StorageManagementViewModelTests (MODIFY)

Add tree-specific VM tests:

| Test | Asserts |
|---|---|
| `testTreeNodesPopulatedAfterRefresh` | `treeNodes` not empty after scan |
| `testToggleNodeSelectionSelectsAllDescendants` | Parent toggle → all leaf IDs in `selectedItemIDs` |
| `testToggleNodeSelectionDeselectsAllDescendants` | Parent toggle off → all leaf IDs removed |
| `testNodeSelectionStatePartial` | Some descendants selected → `.partial` |
| `testNodeSelectionStateAll` | All descendants selected → `.all` |
| `testNodeSelectionStateNone` | No descendants selected → `.none` |
| `testFilteredTreeNodesAppsFilter` | Only "Applications" root visible |
| `testFilteredTreeNodesCachesFilter` | Only "Caches" root visible |
| `testFilteredTreeNodesDevToolsFilter` | "Developer" + "Package Caches" roots visible |
| `testSearchPrunesTreeToBranches` | Only matching branches visible |

### Success Criteria
- [ ] All builder tests pass
- [ ] All VM tree tests pass
- [ ] All existing VM tests still pass (no regressions)

### Rollback
Delete new test file, revert test modifications.

---

## Phase 6 — Cleanup & Polish

| | |
|---|---|
| **Status** | Pending |
| **Files** | All modified files |
| **Depends on** | Phase 4, Phase 5 |
| **Risk** | Low |

### Tasks
- [ ] Remove deprecated flat-list methods from VM if fully replaced
- [ ] Remove `listEntryRow` and `childItemRow` from View if fully replaced
- [ ] Verify `xcodegen generate` succeeds with new files
- [ ] Verify full build: `xcodebuild build`
- [ ] Verify all tests: `xcodebuild test`
- [ ] Verify delete flow end-to-end (selection → confirmation → deletion → refresh)
- [ ] Check file sizes — split any file exceeding 200 lines

### Success Criteria
- [ ] Build succeeds
- [ ] All tests pass
- [ ] No file exceeds 200 lines (new files)
- [ ] Delete flow works with tree selection

---

## File Ownership Matrix

| File | Phase | Action |
|---|---|---|
| `StorageTreeNode.swift` | 1 | NEW |
| `StorageTreeBuilder.swift` | 2 | NEW |
| `StorageManagementViewModel.swift` | 3 | MODIFY |
| `StorageManagementView.swift` | 4 | MODIFY |
| `StorageTreeRowView.swift` | 4 | NEW |
| `StorageTreeBuilderTests.swift` | 5 | NEW |
| `StorageManagementViewModelTests.swift` | 5 | MODIFY |
| `StorageManagementModels.swift` | — | UNCHANGED |
| `LocalStorageManager.swift` | — | UNCHANGED |

No two phases touch the same file except:
- Phase 3 and Phase 6 both touch ViewModel (Phase 6 is cleanup after Phase 3 is done)
- Phase 4 and Phase 6 both touch View (same — Phase 6 is cleanup)

## Dependency Graph

```
Phase 1 (TreeNode model)
  |
  v
Phase 2 (TreeBuilder)
  |         \
  v          v
Phase 3    Phase 5 (builder tests can start)
(ViewModel)
  |
  v
Phase 4 (View) -----> Phase 5 (VM tests after Phase 3)
  |                      |
  v                      v
Phase 6 (Cleanup — after 4 + 5 done)
```

## Risk Summary

| Risk | L | I | Mitigation |
|---|---|---|---|
| Categorization misses a `kind` | M | H | Exhaustive switch, no default |
| VM grows past maintainability | M | M | Builder in separate file; new methods are additive |
| Recursive SwiftUI perf at 100+ nodes | L | M | LazyVStack; real data unlikely >50 visible rows |
| Selection sync breaks delete flow | M | H | `selectedItemIDs` unchanged; delete still uses existing paths |
| Tree rebuilds on every scan | L | L | One build per scan; scan is already debounced |

## Backwards Compatibility

- `StorageManaging` protocol: **unchanged**
- `StorageScanResult`: **unchanged**
- `selectedItemIDs: Set<String>`: **unchanged** (still leaf file paths)
- `StorageListEntry`: **kept** for delete confirmation overlay
- Delete flow: **unchanged** — still uses `selectedItemIDs` + `normalizedSelectedItems`
- `filteredEntries`: **kept** for animation value + confirmation

## Unresolved Questions

1. **Root category checkbox behavior**: Should root categories (Applications, Caches) have a checkbox that selects ALL items in that category? The wireframe shows checkboxes at all levels, but selecting 80 GB of apps in one click is dangerous. **Recommendation:** Include checkbox but require it goes through same confirmation flow — no special guard needed since the delete confirmation already shows everything.

2. **App icon at root category level**: Root categories don't have app icons — just SF Symbols (folder, archivebox, etc.). The existing `entryIcon` logic is per-app-group. **Recommendation:** Use category-level SF Symbols for roots, app icons for group nodes.

3. **Intermediate dir collapsing**: If a path like `~/Projects/OscarProjects/MacMonitor/node_modules` is the ONLY item under `~/Projects`, should we collapse intermediates to show `Projects/OscarProjects/MacMonitor/node_modules` as a single leaf? **Recommendation:** Yes — collapse single-child intermediate chains into one node with combined label (e.g., `OscarProjects/MacMonitor`). Simpler UX, less clicking.
