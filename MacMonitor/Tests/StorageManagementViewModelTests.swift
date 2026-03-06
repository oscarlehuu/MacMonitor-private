import XCTest
@testable import MacMonitor

@MainActor
final class StorageManagementViewModelTests: XCTestCase {
    func testPerformRefreshLoadsGroupedData() async {
        let manager = FakeStorageManager()
        let cursorBundleID = "com.todesktop.230313mzl4w4u92"
        let appID = "app:cursor"
        let appBundle = makeItem(
            path: "/Applications/Cursor.app",
            name: "Cursor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 400,
            protected: false,
            appGroupID: appID,
            bundleIdentifier: cursorBundleID
        )
        let appCache = makeItem(
            path: "/Users/test/Library/Caches/\(cursorBundleID)",
            name: "Cursor Cache",
            category: .cache,
            kind: .appCache,
            sizeBytes: 200,
            protected: false,
            appGroupID: appID,
            bundleIdentifier: cursorBundleID
        )
        let group = StorageAppGroup(
            id: appID,
            displayName: "Cursor",
            bundleIdentifier: cursorBundleID,
            items: [appBundle, appCache]
        )
        let loose = makeItem(
            path: "/tmp/Cache-A",
            name: "Cache-A",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 120,
            protected: false
        )
        manager.scanResult = makeScanResult(
            appGroups: [group],
            looseItems: [loose]
        )

        let viewModel = makeViewModel(manager: manager)

        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.appGroups.count, 1)
        XCTAssertEqual(viewModel.appGroups.first?.displayName, "Cursor")
        XCTAssertEqual(viewModel.looseItems.count, 1)
        XCTAssertEqual(viewModel.looseItems.first?.displayName, "Cache-A")
        XCTAssertEqual(manager.scanCallCount, 1)
    }

    func testToggleSelectionSkipsProtectedItems() async {
        let manager = FakeStorageManager()
        let protected = makeItem(
            path: "/System/Library",
            name: "Library",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 1,
            protected: true
        )
        let allowed = makeItem(
            path: "/tmp/Allowed",
            name: "Allowed",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 2,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [protected, allowed])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()

        viewModel.toggleSelection(for: protected.id)
        viewModel.toggleSelection(for: allowed.id)

        XCTAssertEqual(viewModel.selectedItemIDs, [allowed.id])
    }

    func testSelectRingBucketForDeletionSelectsAllItemsInGroupBucket() async {
        let manager = FakeStorageManager()
        let groupID = "group.cursor"
        let bundleID = "com.todesktop.cursor"
        let appBundle = makeItem(
            path: "/Applications/Cursor.app",
            name: "Cursor",
            category: .application,
            kind: .appBundle,
            sizeBytes: 400,
            protected: false,
            appGroupID: groupID,
            bundleIdentifier: bundleID
        )
        let cache = makeItem(
            path: "/Users/test/Library/Caches/\(bundleID)",
            name: "Cache",
            category: .cache,
            kind: .appCache,
            sizeBytes: 120,
            protected: false,
            appGroupID: groupID,
            bundleIdentifier: bundleID
        )
        let group = StorageAppGroup(
            id: groupID,
            displayName: "Cursor",
            bundleIdentifier: bundleID,
            items: [appBundle, cache]
        )
        let loose = makeItem(
            path: "/tmp/Loose",
            name: "Loose",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 80,
            protected: false
        )
        manager.scanResult = makeScanResult(appGroups: [group], looseItems: [loose])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectRingBucketForDeletion("group:\(groupID)")

        XCTAssertTrue(viewModel.selectedItemIDs.contains(appBundle.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(cache.id))
        XCTAssertFalse(viewModel.selectedItemIDs.contains(loose.id))
    }

    func testSelectRingBucketForDeletionSelectsItemSubtree() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/Desktop",
            name: "Desktop",
            category: .folder,
            kind: .customFolder,
            sizeBytes: 300,
            protected: false
        )
        let child = makeItem(
            path: "/tmp/Desktop/nested",
            name: "nested",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 120,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent, child])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectRingBucketForDeletion("item:\(parent.id)")

        XCTAssertTrue(viewModel.selectedItemIDs.contains(parent.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(child.id))
    }

    func testSelectRingBucketForDeletionSelectsCollapsedOtherBuckets() async {
        let manager = FakeStorageManager()
        let looseItems: [StorageManagedItem] = (0..<11).map { index in
            makeItem(
                path: "/tmp/item-\(index)",
                name: "Item-\(index)",
                category: .folder,
                kind: .looseFolder,
                sizeBytes: UInt64(100 + index),
                protected: false
            )
        }
        manager.scanResult = makeScanResult(looseItems: looseItems)

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectRingBucketForDeletion("other")

        XCTAssertEqual(
            viewModel.selectedItemIDs,
            Set([
                "/tmp/item-0",
                "/tmp/item-1"
            ])
        )
    }

    func testDeletionPreviewRowsIncludeAllowedItemsSortedBySizeThenName() async {
        let manager = FakeStorageManager()
        let protected = makeItem(
            path: "/System/Library/DoNotDelete",
            name: "DoNotDelete",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 900,
            protected: true
        )
        let gamma = makeItem(
            path: "/tmp/Gamma",
            name: "Gamma",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 400,
            protected: false
        )
        let alpha = makeItem(
            path: "/tmp/Alpha",
            name: "Alpha",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 200,
            protected: false
        )
        let beta = makeItem(
            path: "/tmp/Beta",
            name: "Beta",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 200,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [protected, gamma, alpha, beta])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [protected.id, gamma.id, beta.id, alpha.id]

        XCTAssertEqual(viewModel.selectedAllowedCount, 3)
        XCTAssertEqual(viewModel.selectedAllowedBytes, 800)
        XCTAssertEqual(
            viewModel.deletionPreviewRows.map(\.displayName),
            ["Gamma", "Alpha", "Beta"]
        )
        XCTAssertEqual(
            viewModel.deletionPreviewRows.map(\.path),
            ["/tmp/Gamma", "/tmp/Alpha", "/tmp/Beta"]
        )
        XCTAssertEqual(
            viewModel.deletionPreviewListRows.map(\.item.displayName),
            ["Gamma", "Alpha", "Beta"]
        )
        XCTAssertEqual(
            viewModel.deletionPreviewListRows.map(\.depth),
            [0, 0, 0]
        )
    }

    func testSelectionDerivationCacheInvalidatesWhenSelectionChanges() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/Parent",
            name: "Parent",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 500,
            protected: false
        )
        let child = makeItem(
            path: "/tmp/Parent/Child",
            name: "Child",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 120,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent, child])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()

        viewModel.selectedItemIDs = [parent.id]
        XCTAssertEqual(viewModel.selectedAllowedCount, 1)
        XCTAssertEqual(viewModel.selectedAllowedBytes, 500)

        viewModel.selectedItemIDs = [child.id]
        XCTAssertEqual(viewModel.selectedAllowedCount, 1)
        XCTAssertEqual(viewModel.selectedAllowedBytes, 120)
    }

    func testSelectionDerivationCacheInvalidatesAfterRefreshRebuildsItemIndex() async {
        let manager = FakeStorageManager()
        let itemV1 = makeItem(
            path: "/tmp/RefreshTarget",
            name: "RefreshTarget",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 100,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [itemV1])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [itemV1.id]
        XCTAssertEqual(viewModel.selectedAllowedBytes, 100)

        let itemV2 = makeItem(
            path: "/tmp/RefreshTarget",
            name: "RefreshTarget",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 260,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [itemV2])
        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.selectedItemIDs, [itemV2.id])
        XCTAssertEqual(viewModel.selectedAllowedBytes, 260)
    }

    func testIsItemInDeletionScopeMarksDescendantsOfSelectedParent() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/Project",
            name: "Project",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 500,
            protected: false
        )
        let child = makeItem(
            path: "/tmp/Project/node_modules",
            name: "node_modules",
            category: .folder,
            kind: .nodeModules,
            sizeBytes: 300,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent, child])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [parent.id]

        XCTAssertTrue(viewModel.isItemInDeletionScope(parent.id))
        XCTAssertTrue(viewModel.isItemInDeletionScope(child.id))
    }

    func testToggleSelectionOnParentSelectsChildrenAndChildUntickKeepsParentPartial() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/Containers",
            name: "Containers",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 300,
            protected: false
        )
        let childA = makeItem(
            path: "/tmp/Containers/A",
            name: "A",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 100,
            protected: false,
            parentID: parent.id
        )
        let childB = makeItem(
            path: "/tmp/Containers/B",
            name: "B",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 120,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent, childA, childB])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()

        viewModel.toggleSelection(for: parent.id)
        XCTAssertTrue(viewModel.selectedItemIDs.contains(parent.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(childA.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(childB.id))
        XCTAssertEqual(viewModel.itemSelectionState(parent.id), .all)

        viewModel.toggleSelection(for: childA.id)
        XCTAssertFalse(viewModel.selectedItemIDs.contains(childA.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(childB.id))
        XCTAssertEqual(viewModel.itemSelectionState(parent.id), .partial)
    }

    func testItemSelectionStateTreatsSelectedAncestorAsSelectedChild() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/Parent",
            name: "Parent",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 300,
            protected: false
        )
        let child = makeItem(
            path: "/tmp/Parent/Child",
            name: "Child",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 120,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent, child])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [parent.id]

        XCTAssertEqual(viewModel.itemSelectionState(child.id), .all)
        XCTAssertTrue(viewModel.isItemInDeletionScope(child.id))
    }

    func testExpandSelectedParentAutoSelectsNewlyLoadedChildren() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/ContainerRoot",
            name: "ContainerRoot",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 200,
            protected: false
        )
        let child = makeItem(
            path: "/tmp/ContainerRoot/Data",
            name: "Data",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 140,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent])
        manager.drilledItemsByParentID[parent.id] = [child]

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.toggleSelection(for: parent.id)
        viewModel.toggleItemExpansion(parent.id)

        for _ in 0..<40 where viewModel.isLoadingChildren(for: parent.id) {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertFalse(viewModel.isLoadingChildren(for: parent.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(parent.id))
        XCTAssertTrue(viewModel.selectedItemIDs.contains(child.id))
        XCTAssertEqual(viewModel.itemSelectionState(child.id), .all)
    }

    func testDeletionPreviewExpansionDoesNotMutateMainExpansionState() async {
        let manager = FakeStorageManager()
        let parent = makeItem(
            path: "/tmp/DeletePreviewRoot",
            name: "DeletePreviewRoot",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 240,
            protected: false
        )
        let child = makeItem(
            path: "/tmp/DeletePreviewRoot/Child",
            name: "Child",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 120,
            protected: false,
            parentID: parent.id
        )
        manager.scanResult = makeScanResult(looseItems: [parent])
        manager.drilledItemsByParentID[parent.id] = [child]

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()

        viewModel.beginDeletionPreview(rootItemIDs: [parent.id])
        viewModel.toggleDeletionPreviewItemExpansion(parent.id)

        for _ in 0..<40 where viewModel.isDeletionPreviewLoadingChildren(for: parent.id) {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertTrue(viewModel.deletionPreviewExpandedItemIDs.contains(parent.id))
        XCTAssertTrue(viewModel.deletionPreviewDrilledItemsByParentID[parent.id]?.contains(child) == true)
        XCTAssertFalse(viewModel.expandedItemIDs.contains(parent.id))
        XCTAssertNil(viewModel.drilledItemsByParentID[parent.id])

        viewModel.endDeletionPreview()

        XCTAssertTrue(viewModel.deletionPreviewExpandedItemIDs.isEmpty)
        XCTAssertTrue(viewModel.deletionPreviewDrilledItemsByParentID.isEmpty)
    }

    func testDeletionPreviewGroupExpansionIsIsolatedFromMainList() async {
        let manager = FakeStorageManager()
        let groupID = "app:preview"
        let app = makeItem(
            path: "/Applications/Preview.app",
            name: "Preview.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 300,
            protected: false,
            appGroupID: groupID,
            bundleIdentifier: "com.apple.Preview"
        )
        let cache = makeItem(
            path: "/Users/test/Library/Caches/com.apple.Preview",
            name: "Preview Cache",
            category: .cache,
            kind: .appCache,
            sizeBytes: 120,
            protected: false,
            appGroupID: groupID,
            bundleIdentifier: "com.apple.Preview"
        )
        manager.scanResult = makeScanResult(
            appGroups: [
                StorageAppGroup(
                    id: groupID,
                    displayName: "Preview",
                    bundleIdentifier: "com.apple.Preview",
                    items: [app, cache]
                )
            ]
        )

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()

        viewModel.beginDeletionPreview(rootItemIDs: [app.id])
        XCTAssertTrue(viewModel.deletionPreviewExpandedGroupIDs.contains(groupID))
        XCTAssertFalse(viewModel.expandedGroupIDs.contains(groupID))

        viewModel.toggleDeletionPreviewGroupExpansion(groupID)
        XCTAssertFalse(viewModel.deletionPreviewExpandedGroupIDs.contains(groupID))
        XCTAssertFalse(viewModel.expandedGroupIDs.contains(groupID))
    }

    func testToggleSelectionClearsDeepChildWhenMultipleAncestorsSelected() async {
        let manager = FakeStorageManager()
        let root = makeItem(
            path: "/tmp/Tree",
            name: "Tree",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 300,
            protected: false
        )
        let branch = makeItem(
            path: "/tmp/Tree/Branch",
            name: "Branch",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 200,
            protected: false,
            parentID: root.id
        )
        let leaf = makeItem(
            path: "/tmp/Tree/Branch/Leaf",
            name: "Leaf",
            category: .folder,
            kind: .drillDown,
            sizeBytes: 120,
            protected: false,
            parentID: branch.id
        )
        manager.scanResult = makeScanResult(looseItems: [root, branch, leaf])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [root.id, branch.id, leaf.id]

        viewModel.toggleSelection(for: leaf.id)

        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
        XCTAssertEqual(viewModel.itemSelectionState(leaf.id), .none)
        XCTAssertFalse(viewModel.isItemInDeletionScope(leaf.id))
    }

    func testDeleteSelectedSendsOnlyAllowedIDs() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let protected = makeItem(
            path: "/System/Library",
            name: "Library",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 1,
            protected: true
        )
        let allowed = makeItem(
            path: "/tmp/Allowed",
            name: "Allowed",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 2,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [protected, allowed])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: allowed.id, displayName: allowed.displayName, outcome: .deleted)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [protected.id, allowed.id]

        await viewModel.deleteSelected()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [allowed.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 0, failed 0.")
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testDeleteFlowLockBlocksSelectionDuringDeleteAndUnlocksAfterRefresh() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let allowed = makeItem(
            path: "/tmp/Allowed-Locked",
            name: "Allowed-Locked",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 2,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [allowed])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: allowed.id, displayName: allowed.displayName, outcome: .deleted)
            ]
        )
        manager.deleteDelaySeconds = 0.25
        manager.scanDelaySeconds = 0.2

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [allowed.id]

        let deletionTask = Task {
            await viewModel.deleteSelected()
        }

        for _ in 0..<40 where !viewModel.isDeleteFlowInteractionLocked {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertTrue(viewModel.isDeleteFlowInteractionLocked)
        viewModel.toggleSelection(for: allowed.id)
        XCTAssertEqual(viewModel.selectedItemIDs, [allowed.id])

        await deletionTask.value

        XCTAssertFalse(viewModel.isDeleteFlowInteractionLocked)
        XCTAssertNil(viewModel.deleteFlowStatusMessage)
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testProjectionUsesDiskUsageAndSelection() async {
        let manager = FakeStorageManager()
        let selected = makeItem(
            path: "/tmp/FutureDelete",
            name: "FutureDelete",
            category: .folder,
            kind: .looseFolder,
            sizeBytes: 200,
            protected: false
        )
        manager.scanResult = makeScanResult(
            looseItems: [selected],
            diskUsage: StorageDiskUsage(usedBytes: 800, totalBytes: 1_000)
        )

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.toggleSelection(for: selected.id)

        XCTAssertEqual(viewModel.currentUsedBytes, 800)
        XCTAssertEqual(viewModel.currentTotalBytes, 1_000)
        XCTAssertEqual(viewModel.willDeleteBytes, 200)
        XCTAssertEqual(viewModel.projectedUsedBytes, 600)
        XCTAssertEqual(viewModel.projectedUsageRatio, 0.6, accuracy: 0.0001)
    }

    func testApplyPresetSelectsNodeTargetsOnly() async {
        let manager = FakeStorageManager()
        let nodeModules = makeItem(
            path: "/Users/test/Developer/demo/node_modules",
            name: "node_modules",
            category: .folder,
            kind: .nodeModules,
            sizeBytes: 300,
            protected: false
        )
        let npmProtected = makeItem(
            path: "/Users/test/.npm",
            name: ".npm",
            category: .cache,
            kind: .npmCache,
            sizeBytes: 250,
            protected: true
        )
        let xcode = makeItem(
            path: "/Users/test/Library/Developer/Xcode/DerivedData",
            name: "DerivedData",
            category: .cache,
            kind: .derivedData,
            sizeBytes: 500,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [nodeModules, npmProtected, xcode])

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.applyPreset(.node)

        XCTAssertEqual(viewModel.activePreset, .node)
        XCTAssertEqual(viewModel.selectedItemIDs, [nodeModules.id])
    }

    func testSummaryDiskUsageFallbackIsUsedWhenScanDiskUsageMissing() async {
        let manager = FakeStorageManager()
        manager.scanResult = makeScanResult(looseItems: [])

        let viewModel = makeViewModel(manager: manager)
        viewModel.updateDiskUsageSnapshot(StorageDiskUsage(usedBytes: 900, totalBytes: 1_500))
        await viewModel.performRefresh()

        XCTAssertEqual(viewModel.currentUsedBytes, 900)
        XCTAssertEqual(viewModel.currentTotalBytes, 1_500)
    }

    func testDeleteSelectedShowsForcePromptWhenAppStillRunning() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let groupID = "group.editor"
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            appGroupID: groupID,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        let group = StorageAppGroup(
            id: groupID,
            displayName: "Editor",
            bundleIdentifier: "com.test.editor",
            items: [app]
        )
        manager.scanResult = makeScanResult(appGroups: [group], looseItems: [cache])
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()

        XCTAssertTrue(viewModel.showingForceQuitConfirmation)
        XCTAssertEqual(viewModel.forceQuitCandidateNames, [app.displayName])
        XCTAssertEqual(manager.lastDeletedIDs, [])
        XCTAssertTrue(viewModel.isGroupBeingDeleted(groupID))
        XCTAssertTrue(viewModel.isItemBeingDeleted(app.id))
        XCTAssertTrue(viewModel.isItemBeingDeleted(cache.id))
        XCTAssertTrue(viewModel.isDeleteFlowInteractionLocked)
        XCTAssertEqual(viewModel.deleteFlowStatusMessage, "Waiting for running apps decision...")

        let selectedBeforeToggle = viewModel.selectedItemIDs
        viewModel.toggleSelection(for: app.id)
        XCTAssertEqual(viewModel.selectedItemIDs, selectedBeforeToggle)
    }

    func testCancelForceQuitPromptClearsDeletingScope() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let groupID = "group.warp"
        let app = makeItem(
            path: "/Applications/Warp.app",
            name: "Warp.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 300,
            protected: false,
            appGroupID: groupID,
            bundleIdentifier: "dev.warp.stable"
        )
        let group = StorageAppGroup(
            id: groupID,
            displayName: "Warp",
            bundleIdentifier: "dev.warp.stable",
            items: [app]
        )
        manager.scanResult = makeScanResult(appGroups: [group], looseItems: [])
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id]

        await viewModel.deleteSelected()
        XCTAssertTrue(viewModel.isGroupBeingDeleted(groupID))
        XCTAssertTrue(viewModel.isItemBeingDeleted(app.id))

        viewModel.cancelForceQuitPrompt()

        XCTAssertFalse(viewModel.isGroupBeingDeleted(groupID))
        XCTAssertFalse(viewModel.isItemBeingDeleted(app.id))
    }

    func testSkipForceQuitDeletesOtherItemsAndReportsDeclined() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: cache.id, displayName: cache.displayName, outcome: .deleted)
            ]
        )
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()
        await viewModel.skipForceQuitAndDelete()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [cache.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 1, failed 0. Force declined: 1.")
    }

    func testConfirmForceQuitDeletesRecoveredApps() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: app.id, displayName: app.displayName, outcome: .deleted),
                StorageDeletionResult(id: cache.id, displayName: cache.displayName, outcome: .deleted)
            ]
        )
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )
        coordinator.forceSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .forceTerminated)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()
        await viewModel.confirmForceQuitAndDelete()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [app.id, cache.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 2, skipped 0, failed 0.")
    }

    func testConfirmForceQuitSkipsAppsStillRunningAfterForce() async {
        let manager = FakeStorageManager()
        let coordinator = FakeRunningAppPreflightCoordinator()
        let app = makeItem(
            path: "/Applications/Editor.app",
            name: "Editor.app",
            category: .application,
            kind: .appBundle,
            sizeBytes: 200,
            protected: false,
            bundleIdentifier: "com.test.editor"
        )
        let cache = makeItem(
            path: "/tmp/EditorCache",
            name: "EditorCache",
            category: .cache,
            kind: .looseCache,
            sizeBytes: 20,
            protected: false
        )
        manager.scanResult = makeScanResult(looseItems: [app, cache])
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: cache.id, displayName: cache.displayName, outcome: .deleted)
            ]
        )
        coordinator.gracefulSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )
        coordinator.forceSummary = RunningAppPreflightSummary(
            results: [
                RunningAppPreflightResult(itemID: app.id, displayName: app.displayName, outcome: .stillRunning)
            ]
        )

        let viewModel = makeViewModel(manager: manager, preflightCoordinator: coordinator)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [app.id, cache.id]

        await viewModel.deleteSelected()
        await viewModel.confirmForceQuitAndDelete()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [cache.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 1, failed 0. Still running: 1.")
    }

    func testGrantInitialAccessPersistsPromptStateAcrossRestart() {
        let manager = FakeStorageManager()
        let suiteName = "StorageManagementViewModelTests.InitialAccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacMonitor-InitialAccess-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let firstViewModel = StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
        XCTAssertTrue(firstViewModel.shouldRequestInitialAccess())

        firstViewModel.grantInitialAccess(to: tempRoot)
        XCTAssertFalse(firstViewModel.shouldRequestInitialAccess())

        let secondViewModel = StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
        XCTAssertFalse(secondViewModel.shouldRequestInitialAccess())
    }

    func testShouldRequestInitialAccessReadsLatestPersistedFlag() {
        let manager = FakeStorageManager()
        let suiteName = "StorageManagementViewModelTests.InitialAccessFlag.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
        XCTAssertTrue(viewModel.shouldRequestInitialAccess())

        defaults.set(true, forKey: "storage.initialAccessPromptShown")
        defaults.synchronize()

        XCTAssertFalse(viewModel.shouldRequestInitialAccess())
    }

    func testAddCustomFolderSkipsPathAlreadyCoveredByDefaultSources() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let pathCoveredByDefault = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)

        viewModel.addCustomFolder(pathCoveredByDefault)

        XCTAssertTrue(viewModel.trackedFolders.isEmpty)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomFolderSkipsExactProjectsDefaultRoot() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let projectsRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects", isDirectory: true)

        viewModel.addCustomFolder(projectsRoot)

        XCTAssertTrue(viewModel.trackedFolders.isEmpty)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomFolderAllowsDescendantInsideProjectsRoot() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let fileManager = FileManager.default
        let projectsRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects", isDirectory: true)
        let projectsRootExisted = fileManager.fileExists(atPath: projectsRoot.path)
        let repoFolder = projectsRoot
            .appendingPathComponent("MacMonitor-Test-\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: repoFolder, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: repoFolder)
            if !projectsRootExisted {
                try? fileManager.removeItem(at: projectsRoot)
            }
        }

        viewModel.addCustomFolder(repoFolder)

        XCTAssertEqual(viewModel.trackedFolders.count, 1)
        XCTAssertEqual(viewModel.trackedFolders.first?.standardizedFileURL.path, repoFolder.standardizedFileURL.path)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomFolderSkipsPathAlreadyCoveredByTrackedFolder() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let fileManager = FileManager.default

        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MacMonitor-TrackedRoot-\(UUID().uuidString)", isDirectory: true)
        let child = root.appendingPathComponent("Nested", isDirectory: true)
        try? fileManager.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        viewModel.addCustomFolder(root)
        XCTAssertEqual(viewModel.trackedFolders.count, 1)

        viewModel.addCustomFolder(child)
        XCTAssertEqual(viewModel.trackedFolders.count, 1)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomFolderCollapsesTrackedChildrenWhenAddingParent() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let fileManager = FileManager.default

        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MacMonitor-CollapseRoot-\(UUID().uuidString)", isDirectory: true)
        let child = root.appendingPathComponent("Nested", isDirectory: true)
        try? fileManager.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        viewModel.addCustomFolder(child)
        XCTAssertEqual(viewModel.trackedFolders.count, 1)

        viewModel.addCustomFolder(root)
        XCTAssertEqual(viewModel.trackedFolders.count, 1)
        XCTAssertEqual(viewModel.trackedFolders.first?.standardizedFileURL.path, root.standardizedFileURL.path)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomFolderSkipsRootPath() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)

        viewModel.addCustomFolder(URL(fileURLWithPath: "/"))

        XCTAssertTrue(viewModel.trackedFolders.isEmpty)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddedScanSourcePathsExcludeMissingTrackedFolders() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let fileManager = FileManager.default

        let missingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MacMonitor-Missing-\(UUID().uuidString)", isDirectory: true)

        viewModel.addCustomFolder(missingRoot)

        XCTAssertEqual(viewModel.trackedFolders.count, 1)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 0)
    }

    func testAddCustomFolderSkipsMissingChildWhenMissingParentAlreadyTracked() {
        let manager = FakeStorageManager()
        let viewModel = makeViewModel(manager: manager)
        let fileManager = FileManager.default

        let missingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MacMonitor-MissingRoot-\(UUID().uuidString)", isDirectory: true)
        let missingChild = missingRoot.appendingPathComponent("Nested", isDirectory: true)

        viewModel.addCustomFolder(missingRoot)
        viewModel.addCustomFolder(missingChild)

        XCTAssertEqual(viewModel.trackedFolders.count, 1)
        XCTAssertEqual(viewModel.addedScanSourcePaths.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    private func makeViewModel(
        manager: FakeStorageManager,
        preflightCoordinator: FakeRunningAppPreflightCoordinator = FakeRunningAppPreflightCoordinator()
    ) -> StorageManagementViewModel {
        let suiteName = "StorageManagementViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return StorageManagementViewModel(
            storageManager: manager,
            runningAppPreflightCoordinator: preflightCoordinator,
            userDefaults: defaults
        )
    }

    private func makeItem(
        path: String,
        name: String,
        category: StorageManagedItemCategory,
        kind: StorageManagedItemKind,
        sizeBytes: UInt64,
        protected: Bool,
        appGroupID: String? = nil,
        bundleIdentifier: String? = nil,
        parentID: String? = nil,
        isDirectory: Bool = true
    ) -> StorageManagedItem {
        StorageManagedItem(
            url: URL(fileURLWithPath: path),
            displayName: name,
            category: category,
            kind: kind,
            sizeBytes: sizeBytes,
            protectionReason: protected ? .systemPath : nil,
            isDirectory: isDirectory,
            parentID: parentID,
            bundleIdentifier: bundleIdentifier,
            appGroupID: appGroupID
        )
    }

    private func makeScanResult(
        appGroups: [StorageAppGroup] = [],
        looseItems: [StorageManagedItem] = [],
        diskUsage: StorageDiskUsage? = nil
    ) -> StorageScanResult {
        StorageScanResult(diskUsage: diskUsage, appGroups: appGroups, looseItems: looseItems)
    }
}

private final class FakeStorageManager: StorageManaging, @unchecked Sendable {
    private let lock = NSLock()

    var scanResult = StorageScanResult(diskUsage: nil, appGroups: [], looseItems: [])
    var drilledItemsByParentID: [String: [StorageManagedItem]] = [:]
    var deleteSummary = StorageDeletionSummary(results: [])
    var scanDelaySeconds: TimeInterval = 0
    var deleteDelaySeconds: TimeInterval = 0
    private(set) var scanCallCount = 0
    private(set) var lastDeletedIDs: Set<String> = []

    func scan(customFolders: [URL]) -> StorageScanResult {
        if scanDelaySeconds > 0 {
            Thread.sleep(forTimeInterval: scanDelaySeconds)
        }
        lock.lock()
        defer { lock.unlock() }
        scanCallCount += 1
        return scanResult
    }

    func drillDown(item: StorageManagedItem, limit: Int) -> [StorageManagedItem] {
        lock.lock()
        defer { lock.unlock() }
        let children = drilledItemsByParentID[item.id] ?? []
        return Array(children.prefix(max(limit, 0)))
    }

    func delete(items: [StorageManagedItem], selectedItemIDs: Set<String>) -> StorageDeletionSummary {
        if deleteDelaySeconds > 0 {
            Thread.sleep(forTimeInterval: deleteDelaySeconds)
        }
        lock.lock()
        defer { lock.unlock() }
        lastDeletedIDs = selectedItemIDs
        return deleteSummary
    }
}

@MainActor
private final class FakeRunningAppPreflightCoordinator: RunningAppPreflightCoordinating {
    var gracefulSummary = RunningAppPreflightSummary(results: [])
    var forceSummary = RunningAppPreflightSummary(results: [])

    func gracefulQuitPreflight(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary {
        if !gracefulSummary.results.isEmpty {
            return gracefulSummary
        }
        return RunningAppPreflightSummary(
            results: items.map { item in
                RunningAppPreflightResult(itemID: item.id, displayName: item.displayName, outcome: .notRunning)
            }
        )
    }

    func forceQuit(for items: [StorageManagedItem]) async -> RunningAppPreflightSummary {
        if !forceSummary.results.isEmpty {
            return forceSummary
        }
        return RunningAppPreflightSummary(
            results: items.map { item in
                RunningAppPreflightResult(itemID: item.id, displayName: item.displayName, outcome: .forceTerminated)
            }
        )
    }
}
