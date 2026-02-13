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

    func testDeleteSelectedSendsOnlyAllowedIDs() async {
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
        manager.deleteSummary = StorageDeletionSummary(
            results: [
                StorageDeletionResult(id: allowed.id, displayName: allowed.displayName, outcome: .deleted)
            ]
        )

        let viewModel = makeViewModel(manager: manager)
        await viewModel.performRefresh()
        viewModel.selectedItemIDs = [protected.id, allowed.id]

        await viewModel.deleteSelected()
        await viewModel.pendingTask?.value

        XCTAssertEqual(manager.lastDeletedIDs, [allowed.id])
        XCTAssertEqual(viewModel.resultMessage, "Deleted 1, skipped 0, failed 0.")
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

    private func makeViewModel(manager: FakeStorageManager) -> StorageManagementViewModel {
        let suiteName = "StorageManagementViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return StorageManagementViewModel(storageManager: manager, userDefaults: defaults)
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
    private(set) var scanCallCount = 0
    private(set) var lastDeletedIDs: Set<String> = []

    func scan(customFolders: [URL]) -> StorageScanResult {
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
        lock.lock()
        defer { lock.unlock() }
        lastDeletedIDs = selectedItemIDs
        return deleteSummary
    }
}
