import Foundation

struct StorageRingBucket: Identifiable, Equatable {
    let id: String
    let label: String
    let sizeBytes: UInt64
    let category: StorageManagedItemCategory
}

struct StorageListRow: Identifiable, Equatable {
    let item: StorageManagedItem
    let depth: Int

    var id: String { item.id }
}

struct StorageDeletionPreviewRow: Identifiable, Equatable {
    let id: String
    let displayName: String
    let path: String
    let sizeBytes: UInt64
}

struct StorageSelectionSnapshot: Equatable {
    let selectedItemIDs: Set<String>
    let expandedItemIDs: Set<String>
    let activePreset: StorageCleanupPreset?
}

@MainActor
final class StorageManagementViewModel: ObservableObject {
    private struct TrackedFolderAccess: Codable, Equatable {
        let path: String
        let bookmarkData: Data?
    }

    private struct PendingDeletionContext {
        let snapshotItems: [StorageManagedItem]
        let baseDeletionIDs: Set<String>
        let stillRunningItems: [StorageManagedItem]
    }

    @Published private(set) var diskUsage: StorageDiskUsage?
    @Published private(set) var summaryDiskUsage: StorageDiskUsage?
    @Published private(set) var appGroups: [StorageAppGroup] = []
    @Published private(set) var looseItems: [StorageManagedItem] = []
    @Published private(set) var drilledItemsByParentID: [String: [StorageManagedItem]] = [:]
    @Published private(set) var loadingParentItemIDs: Set<String> = []
    @Published private(set) var isScanning = false
    @Published private(set) var isDeleting = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var resultMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var trackedFolders: [URL] = []
    @Published private(set) var activePreset: StorageCleanupPreset?
    @Published var selectedItemIDs: Set<String> = []
    @Published var expandedGroupIDs: Set<String> = []
    @Published var expandedItemIDs: Set<String> = []
    @Published var searchQuery: String = ""
    @Published var showingDeleteConfirmation = false
    @Published var showingForceQuitConfirmation = false
    @Published private(set) var forceQuitCandidateNames: [String] = []

    private let storageManager: StorageManaging
    private let runningAppPreflightCoordinator: RunningAppPreflightCoordinating
    private let userDefaults: UserDefaults
    private var hasLoaded = false
    private var scanGeneration = 0
    private var itemIndex: [String: StorageManagedItem] = [:]
    private var childLoadTasks: [String: Task<Void, Never>] = [:]
    private var trackedFolderAccesses: [TrackedFolderAccess] = []
    private var primaryAccessBookmarkData: Data?
    private var initialAccessPromptShown = false
    private var pendingDeletionContext: PendingDeletionContext?
    private(set) var pendingTask: Task<Void, Never>?

    private let trackedFolderAccessesKey = "storage.trackedFolderAccesses"
    private let primaryAccessBookmarkKey = "storage.primaryAccessBookmark"
    private let initialAccessPromptShownKey = "storage.initialAccessPromptShown"

    init(
        storageManager: StorageManaging,
        runningAppPreflightCoordinator: RunningAppPreflightCoordinating = RunningAppPreflightCoordinator(),
        userDefaults: UserDefaults = .standard
    ) {
        self.storageManager = storageManager
        self.runningAppPreflightCoordinator = runningAppPreflightCoordinator
        self.userDefaults = userDefaults
        loadPersistedAccessState()
    }

    func stop() {
        pendingTask?.cancel()
        pendingTask = nil
        for task in childLoadTasks.values {
            task.cancel()
        }
        childLoadTasks.removeAll()
        loadingParentItemIDs.removeAll()
        resetPendingForceQuitContext()
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        refresh()
    }

    func shouldRequestInitialAccess() -> Bool {
        refreshPersistedInitialAccessState()
        return !initialAccessPromptShown
    }

    func markInitialAccessPromptHandled() {
        initialAccessPromptShown = true
        userDefaults.set(true, forKey: initialAccessPromptShownKey)
        userDefaults.synchronize()
    }

    func grantInitialAccess(to url: URL) {
        let normalized = url.standardizedFileURL
        guard let bookmarkData = makeBookmarkData(for: normalized) else {
            initialAccessPromptShown = true
            userDefaults.set(true, forKey: initialAccessPromptShownKey)
            userDefaults.synchronize()
            errorMessage = "Could not persist storage access bookmark."
            return
        }

        primaryAccessBookmarkData = bookmarkData
        initialAccessPromptShown = true
        userDefaults.set(bookmarkData, forKey: primaryAccessBookmarkKey)
        userDefaults.set(true, forKey: initialAccessPromptShownKey)
        userDefaults.synchronize()

        if hasLoaded {
            refresh()
        }
    }

    func updateDiskUsageSnapshot(_ usage: StorageDiskUsage?) {
        summaryDiskUsage = usage
    }

    func refresh() {
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            await self?.performRefresh()
        }
    }

    func performRefresh() async {
        isScanning = true
        errorMessage = nil
        scanGeneration += 1

        let currentGeneration = scanGeneration
        let manager = storageManager
        let folders = resolveTrackedFolderURLs()
        let scopedURLs = beginScopedAccess(for: scopeAccessURLs(customFolders: folders))
        defer { endScopedAccess(for: scopedURLs) }

        let scanResult = await Task.detached(priority: .userInitiated) {
            manager.scan(customFolders: folders)
        }.value

        guard !Task.isCancelled, currentGeneration == scanGeneration else { return }

        for task in childLoadTasks.values {
            task.cancel()
        }
        childLoadTasks.removeAll()
        loadingParentItemIDs.removeAll()
        drilledItemsByParentID = [:]
        expandedItemIDs.removeAll()

        diskUsage = scanResult.diskUsage
        appGroups = scanResult.appGroups
        looseItems = scanResult.looseItems
        lastUpdated = Date()

        rebuildItemIndex()
        selectedItemIDs = selectedItemIDs.intersection(selectableItemIDs)

        if let preset = activePreset {
            applyPreset(preset, keepPresetActive: true)
        } else {
            normalizeSelection()
        }

        resetPendingForceQuitContext()
        showingForceQuitConfirmation = false
        isScanning = false
    }

    func addCustomFolder(_ url: URL) {
        errorMessage = nil

        let normalized = url.standardizedFileURL
        let normalizedPath = normalized.path
        guard normalizedPath != "/" else { return }

        let fileManager = FileManager.default
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let defaultPaths = defaultScanSourceAbsolutePaths(homeDirectory: homeDirectory)
        let exactOnlyBlockedDefaults = Set([
            homeDirectory.appendingPathComponent("Developer", isDirectory: true).standardizedFileURL.path,
            homeDirectory.appendingPathComponent("Projects", isDirectory: true).standardizedFileURL.path
        ])
        let candidatePaths = customFolderCandidatePaths(
            for: normalizedPath,
            avoiding: defaultPaths,
            exactOnlyBlockedRoots: exactOnlyBlockedDefaults,
            fileManager: fileManager
        )
        guard !candidatePaths.isEmpty else { return }

        var trackedAccessByPath: [String: TrackedFolderAccess] = [:]
        for access in trackedFolderAccesses {
            let path = URL(fileURLWithPath: access.path).standardizedFileURL.path
            trackedAccessByPath[path] = TrackedFolderAccess(path: path, bookmarkData: access.bookmarkData)
        }

        var didChange = false
        for candidatePath in candidatePaths {
            if let coveringPath = trackedAccessByPath.keys.first(where: { isPathEqualOrDescendant(candidatePath, ancestor: $0) }),
               coveringPath != candidatePath {
                continue
            }

            let descendantPaths = trackedAccessByPath.keys.filter { existingPath in
                existingPath != candidatePath && isPathEqualOrDescendant(existingPath, ancestor: candidatePath)
            }
            if !descendantPaths.isEmpty {
                didChange = true
                for descendantPath in descendantPaths {
                    trackedAccessByPath.removeValue(forKey: descendantPath)
                }
            }

            if trackedAccessByPath[candidatePath] == nil {
                trackedAccessByPath[candidatePath] = TrackedFolderAccess(
                    path: candidatePath,
                    bookmarkData: makeBookmarkData(for: URL(fileURLWithPath: candidatePath, isDirectory: true))
                )
                didChange = true
            }
        }

        guard didChange else { return }

        trackedFolderAccesses = trackedAccessByPath.values.sorted { lhs, rhs in
            pathSort(lhs.path, rhs.path)
        }
        persistTrackedFolderAccesses()
        reloadTrackedFolders()
        refresh()
    }

    func removeCustomFolder(_ url: URL) {
        let targetPath = url.standardizedFileURL.path
        trackedFolderAccesses.removeAll { $0.path == targetPath }
        persistTrackedFolderAccesses()
        reloadTrackedFolders()
        refresh()
    }

    func clearPresetSelection() {
        activePreset = nil
        selectedItemIDs.removeAll()
    }

    func applyPreset(_ preset: StorageCleanupPreset) {
        applyPreset(preset, keepPresetActive: true)
    }

    func toggleGroupExpansion(_ groupID: String) {
        if expandedGroupIDs.contains(groupID) {
            expandedGroupIDs.remove(groupID)
        } else {
            expandedGroupIDs.insert(groupID)
        }
    }

    func groupSelectionState(_ group: StorageAppGroup) -> StorageSelectionState {
        let selectableIDs = selectableIDs(for: group.id)
        guard !selectableIDs.isEmpty else { return .none }

        let selectedCount = effectiveSelectedCount(in: selectableIDs)
        if selectedCount == 0 {
            return .none
        }
        if selectedCount == selectableIDs.count {
            return .all
        }
        return .partial
    }

    func toggleGroupSelection(_ groupID: String) {
        guard let group = appGroups.first(where: { $0.id == groupID }) else { return }
        let groupSelectableIDs = selectableIDs(for: groupID)
        guard !groupSelectableIDs.isEmpty else { return }

        switch groupSelectionState(group) {
        case .all:
            materializeSelectedAncestorsCovering(targetIDs: groupSelectableIDs)
            selectedItemIDs.subtract(groupSelectableIDs)
        case .none, .partial:
            selectedItemIDs.formUnion(groupSelectableIDs)
        }

        activePreset = nil
    }

    func toggleItemExpansion(_ itemID: String) {
        guard let item = itemIndex[itemID], item.isExpandable else { return }

        if expandedItemIDs.contains(itemID) {
            collapseItemAndDescendants(itemID)
            return
        }

        expandedItemIDs.insert(itemID)
        loadChildrenIfNeeded(for: item)
    }

    func isItemExpanded(_ itemID: String) -> Bool {
        expandedItemIDs.contains(itemID)
    }

    func isLoadingChildren(for parentID: String) -> Bool {
        loadingParentItemIDs.contains(parentID)
    }

    func childItems(for parentID: String) -> [StorageManagedItem] {
        drilledItemsByParentID[parentID] ?? []
    }

    func rows(for group: StorageAppGroup) -> [StorageListRow] {
        flattenRows(items: group.items)
    }

    func looseRows() -> [StorageListRow] {
        flattenRows(items: visibleLooseItems)
    }

    func allLooseRows() -> [StorageListRow] {
        flattenRows(items: looseItems)
    }

    func toggleSelection(for itemID: String) {
        guard let item = itemIndex[itemID], !item.isProtected else {
            return
        }

        let targetSubtreeIDs = subtreeSelectableIDs(for: itemID)
        guard !targetSubtreeIDs.isEmpty else { return }

        // If any ancestor is selected, expand all selected ancestors into explicit descendants first.
        let selectedAncestorIDs = selectedAncestors(of: itemID)
        if !selectedAncestorIDs.isEmpty {
            for selectedAncestorID in selectedAncestorIDs {
                let ancestorSubtreeIDs = subtreeSelectableIDs(for: selectedAncestorID)
                selectedItemIDs.remove(selectedAncestorID)
                selectedItemIDs.formUnion(ancestorSubtreeIDs.subtracting([selectedAncestorID]))
            }
        }

        let selectedInSubtreeCount = effectiveSelectedCount(in: targetSubtreeIDs)
        if selectedInSubtreeCount == targetSubtreeIDs.count {
            selectedItemIDs.subtract(targetSubtreeIDs)
        } else {
            selectedItemIDs.formUnion(targetSubtreeIDs)
        }

        activePreset = nil
    }

    func itemSelectionState(_ itemID: String) -> StorageSelectionState {
        guard let item = itemIndex[itemID], !item.isProtected else { return .none }
        let subtreeIDs = subtreeSelectableIDs(for: itemID)
        guard !subtreeIDs.isEmpty else { return .none }

        let selectedCount = effectiveSelectedCount(in: subtreeIDs)
        if selectedCount == 0 {
            return .none
        }
        if selectedCount == subtreeIDs.count {
            return .all
        }
        return .partial
    }

    func makeSelectionSnapshot() -> StorageSelectionSnapshot {
        StorageSelectionSnapshot(
            selectedItemIDs: selectedItemIDs,
            expandedItemIDs: expandedItemIDs,
            activePreset: activePreset
        )
    }

    func restoreSelectionSnapshot(_ snapshot: StorageSelectionSnapshot) {
        selectedItemIDs = snapshot.selectedItemIDs.intersection(selectableItemIDs)
        expandedItemIDs = Set(snapshot.expandedItemIDs.filter { itemIndex[$0] != nil })
        activePreset = snapshot.activePreset
    }

    func requestDeleteSelection() {
        guard canDeleteSelection else { return }
        showingDeleteConfirmation = true
    }

    func deleteSelected() async {
        let normalizedItems = normalizedSelectedItems
        let normalizedIDs = Set(normalizedItems.map(\.id))

        guard !normalizedIDs.isEmpty else {
            showingDeleteConfirmation = false
            return
        }

        showingDeleteConfirmation = false
        isDeleting = true
        errorMessage = nil
        let snapshotItems = Array(itemIndex.values)
        let preflightSummary = await runningAppPreflightCoordinator.gracefulQuitPreflight(for: normalizedItems)
        guard !Task.isCancelled else { return }

        let stillRunningIDs = preflightSummary.itemIDs(matching: .stillRunning)
        if stillRunningIDs.isEmpty {
            await executeDeletion(
                snapshotItems: snapshotItems,
                selectedIDs: normalizedIDs,
                extraSkippedResults: []
            )
            return
        }

        let stillRunningItems = normalizedItems.filter { stillRunningIDs.contains($0.id) }
        pendingDeletionContext = PendingDeletionContext(
            snapshotItems: snapshotItems,
            baseDeletionIDs: normalizedIDs.subtracting(stillRunningIDs),
            stillRunningItems: stillRunningItems
        )
        forceQuitCandidateNames = stillRunningItems.map(\.displayName).sorted()
        showingForceQuitConfirmation = true
        isDeleting = false
    }

    func confirmForceQuitAndDelete() async {
        guard let context = pendingDeletionContext else {
            showingForceQuitConfirmation = false
            return
        }

        showingForceQuitConfirmation = false
        isDeleting = true

        let forceSummary = await runningAppPreflightCoordinator.forceQuit(for: context.stillRunningItems)
        guard !Task.isCancelled else { return }

        let stillRunningAfterForceIDs = forceSummary.itemIDs(matching: .stillRunning)
        let forceSucceededIDs = forceSummary.results.compactMap { result -> String? in
            switch result.outcome {
            case .notRunning, .forceTerminated, .terminatedGracefully:
                return result.itemID
            case .notAppBundle, .stillRunning:
                return nil
            }
        }

        let extraSkippedResults = context.stillRunningItems.compactMap { item -> StorageDeletionResult? in
            guard stillRunningAfterForceIDs.contains(item.id) else { return nil }
            return StorageDeletionResult(
                id: item.id,
                displayName: item.displayName,
                outcome: .skippedStillRunning
            )
        }

        await executeDeletion(
            snapshotItems: context.snapshotItems,
            selectedIDs: context.baseDeletionIDs.union(forceSucceededIDs),
            extraSkippedResults: extraSkippedResults
        )
    }

    func skipForceQuitAndDelete() async {
        guard let context = pendingDeletionContext else {
            showingForceQuitConfirmation = false
            return
        }

        showingForceQuitConfirmation = false
        isDeleting = true

        let extraSkippedResults = context.stillRunningItems.map { item in
            StorageDeletionResult(
                id: item.id,
                displayName: item.displayName,
                outcome: .skippedForceDeclined
            )
        }

        await executeDeletion(
            snapshotItems: context.snapshotItems,
            selectedIDs: context.baseDeletionIDs,
            extraSkippedResults: extraSkippedResults
        )
    }

    func cancelForceQuitPrompt() {
        showingForceQuitConfirmation = false
        isDeleting = false
        resetPendingForceQuitContext()
    }

    var selectedAllowedCount: Int {
        normalizedSelectedItems.count
    }

    var selectedAllowedBytes: UInt64 {
        normalizedSelectedItems.reduce(0) { $0 + $1.sizeBytes }
    }

    var deletionPreviewRows: [StorageDeletionPreviewRow] {
        sortedDeletionPreviewItems
            .map { item in
                StorageDeletionPreviewRow(
                    id: item.id,
                    displayName: item.displayName,
                    path: item.url.path,
                    sizeBytes: item.sizeBytes
                )
            }
    }

    var deletionPreviewRootItemIDs: Set<String> {
        Set(sortedDeletionPreviewItems.map(\.id))
    }

    var deletionPreviewListRows: [StorageListRow] {
        deletionPreviewListRows(rootItemIDs: deletionPreviewRootItemIDs)
    }

    func deletionPreviewListRows(rootItemIDs: Set<String>) -> [StorageListRow] {
        let rootItems = rootItemIDs.compactMap { itemIndex[$0] }.sorted { lhs, rhs in
            if lhs.sizeBytes == rhs.sizeBytes {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.sizeBytes > rhs.sizeBytes
        }
        return flattenRows(items: rootItems)
    }

    func isItemInDeletionScope(_ itemID: String) -> Bool {
        normalizedSelectedItems.contains { selectedItem in
            isAncestorPath(ancestor: selectedItem.id, descendant: itemID)
        }
    }

    var forceQuitPromptMessage: String {
        if forceQuitCandidateNames.isEmpty {
            return "Some selected apps are still running. Force quitting may lose unsaved work."
        }
        if forceQuitCandidateNames.count == 1, let name = forceQuitCandidateNames.first {
            return "\(name) is still running. Force quitting may lose unsaved work."
        }
        if forceQuitCandidateNames.count <= 3 {
            let joinedNames = forceQuitCandidateNames.joined(separator: ", ")
            return "\(joinedNames) are still running. Force quitting may lose unsaved work."
        }
        return "\(forceQuitCandidateNames.count) selected apps are still running. Force quitting may lose unsaved work."
    }

    var canDeleteSelection: Bool {
        selectedAllowedCount > 0 && !isDeleting && pendingDeletionContext == nil
    }

    var isDeleteFlowInteractionLocked: Bool {
        isDeleting || pendingDeletionContext != nil || showingForceQuitConfirmation
    }

    var deleteInfoTooltip: String {
        "Only non-protected items are moved to Trash."
    }

    var scannedTopLevelBytes: UInt64 {
        let appBytes = appGroups.reduce(0) { $0 + $1.totalBytes }
        let looseBytes = looseItems.reduce(0) { $0 + $1.sizeBytes }
        return appBytes + looseBytes
    }

    var currentUsedBytes: UInt64 {
        summaryDiskUsage?.usedBytes ?? diskUsage?.usedBytes ?? scannedTopLevelBytes
    }

    var currentTotalBytes: UInt64 {
        let fallbackTotal = max(scannedTopLevelBytes, 1)
        return summaryDiskUsage?.totalBytes ?? diskUsage?.totalBytes ?? fallbackTotal
    }

    var willDeleteBytes: UInt64 {
        selectedAllowedBytes
    }

    var projectedUsedBytes: UInt64 {
        let current = currentUsedBytes
        let deleting = willDeleteBytes
        return current > deleting ? current - deleting : 0
    }

    var currentUsageRatio: Double {
        let total = currentTotalBytes
        guard total > 0 else { return 0 }
        return Double(currentUsedBytes) / Double(total)
    }

    var projectedUsageRatio: Double {
        let total = currentTotalBytes
        guard total > 0 else { return 0 }
        return Double(projectedUsedBytes) / Double(total)
    }

    var ringBuckets: [StorageRingBucket] {
        let sorted = sortedRingSourceBuckets()

        guard sorted.count > 10 else { return sorted }

        let kept = Array(sorted.prefix(9))
        let otherBytes = sorted.dropFirst(9).reduce(UInt64(0)) { $0 + $1.sizeBytes }
        guard otherBytes > 0 else { return kept }

        return kept + [
            StorageRingBucket(
                id: "other",
                label: "Other",
                sizeBytes: otherBytes,
                category: .folder
            )
        ]
    }

    func selectRingBucketForDeletion(_ bucketID: String) {
        guard ringBuckets.contains(where: { $0.id == bucketID }) else { return }

        let targetItemIDs = selectableItemIDsForRingBucket(bucketID)
        guard !targetItemIDs.isEmpty else { return }

        selectedItemIDs.formUnion(targetItemIDs)
        activePreset = nil
    }

    var visibleAppGroups: [StorageAppGroup] {
        let term = normalizedSearchQuery
        guard !term.isEmpty else { return appGroups }

        return appGroups.filter { group in
            groupMatchesSearch(group, term: term)
        }
    }

    var visibleLooseItems: [StorageManagedItem] {
        let term = normalizedSearchQuery
        guard !term.isEmpty else { return looseItems }

        return looseItems.filter { item in
            matchesSearch(item: item, term: term)
        }
    }

    var hasLooseItems: Bool {
        !visibleLooseItems.isEmpty
    }

    var defaultScanSourcePaths: [String] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return defaultScanSourceAbsolutePaths(homeDirectory: homeDirectory)
            .map { formatDisplayPath($0, homeDirectory: homeDirectory) }
    }

    var addedScanSourcePaths: [String] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return resolveTrackedFolderURLs()
            .map(\.path)
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            .map { formatDisplayPath($0, homeDirectory: homeDirectory) }
    }

    private func executeDeletion(
        snapshotItems: [StorageManagedItem],
        selectedIDs: Set<String>,
        extraSkippedResults: [StorageDeletionResult]
    ) async {
        let manager = storageManager
        let summary = await Task.detached(priority: .userInitiated) {
            manager.delete(items: snapshotItems, selectedItemIDs: selectedIDs)
        }.value

        guard !Task.isCancelled else { return }

        var mergedResultsByID: [String: StorageDeletionResult] = [:]
        for result in summary.results {
            mergedResultsByID[result.id] = result
        }
        for result in extraSkippedResults where mergedResultsByID[result.id] == nil {
            mergedResultsByID[result.id] = result
        }

        let mergedSummary = StorageDeletionSummary(results: mergedResultsByID.values.sorted { lhs, rhs in
            if lhs.id.count == rhs.id.count {
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
            return lhs.id.count < rhs.id.count
        })

        resultMessage = mergedSummary.message
        selectedItemIDs.removeAll()
        isDeleting = false
        resetPendingForceQuitContext()
        refresh()
    }

    private func resetPendingForceQuitContext() {
        pendingDeletionContext = nil
        forceQuitCandidateNames = []
    }

    private func selectableItemIDsForRingBucket(_ bucketID: String) -> Set<String> {
        if bucketID == "other" {
            return Set(
                sortedRingSourceBuckets()
                    .dropFirst(9)
                    .flatMap { selectableItemIDsForRingSourceID($0.id) }
            )
        }
        return selectableItemIDsForRingSourceID(bucketID)
    }

    private func selectableItemIDsForRingSourceID(_ ringSourceID: String) -> Set<String> {
        if ringSourceID.hasPrefix("group:") {
            let groupID = String(ringSourceID.dropFirst("group:".count))
            return selectableIDs(for: groupID)
        }
        if ringSourceID.hasPrefix("item:") {
            let itemID = String(ringSourceID.dropFirst("item:".count))
            return subtreeSelectableIDs(for: itemID)
        }
        return []
    }

    private func sortedRingSourceBuckets() -> [StorageRingBucket] {
        var buckets: [StorageRingBucket] = []
        buckets.reserveCapacity(appGroups.count + looseItems.count)

        for group in appGroups where group.totalBytes > 0 {
            buckets.append(
                StorageRingBucket(
                    id: "group:\(group.id)",
                    label: group.displayName,
                    sizeBytes: group.totalBytes,
                    category: .application
                )
            )
        }

        for item in looseItems where item.sizeBytes > 0 {
            buckets.append(
                StorageRingBucket(
                    id: "item:\(item.id)",
                    label: item.displayName,
                    sizeBytes: item.sizeBytes,
                    category: item.category
                )
            )
        }

        return buckets.sorted { lhs, rhs in
            if lhs.sizeBytes == rhs.sizeBytes {
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return lhs.sizeBytes > rhs.sizeBytes
        }
    }

    private func applyPreset(_ preset: StorageCleanupPreset, keepPresetActive: Bool) {
        let candidateItems = itemIndex.values
            .filter { !$0.isProtected }
            .filter { matchesPreset(preset: preset, item: $0) }
            .sorted { lhs, rhs in
                if lhs.id.count == rhs.id.count {
                    return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
                }
                return lhs.id.count < rhs.id.count
            }

        selectedItemIDs = Set(candidateItems.map(\.id))

        if keepPresetActive {
            activePreset = preset
        }
    }

    private func matchesPreset(preset: StorageCleanupPreset, item: StorageManagedItem) -> Bool {
        switch preset {
        case .browsers:
            if let bundleIdentifier = item.bundleIdentifier?.lowercased(),
               browserBundleIdentifiers.contains(bundleIdentifier) {
                return true
            }
            if let groupID = item.appGroupID,
               let groupName = appGroups.first(where: { $0.id == groupID })?.displayName.lowercased() {
                return browserNameFragments.contains(where: { groupName.contains($0) })
            }
            return false
        case .xcode:
            if item.bundleIdentifier?.lowercased() == "com.apple.dt.xcode" {
                return true
            }
            return xcodeKinds.contains(item.kind)
        case .node:
            if nodeKinds.contains(item.kind) {
                return true
            }
            return item.id.lowercased().contains("/node_modules")
        case .caches:
            return item.category == .cache
        }
    }

    private var normalizedSearchQuery: String {
        searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func groupMatchesSearch(_ group: StorageAppGroup, term: String) -> Bool {
        if group.displayName.lowercased().contains(term) {
            return true
        }
        if let bundleIdentifier = group.bundleIdentifier?.lowercased(), bundleIdentifier.contains(term) {
            return true
        }
        return group.items.contains { item in
            matchesSearch(item: item, term: term)
        }
    }

    private func matchesSearch(item: StorageManagedItem, term: String) -> Bool {
        if item.displayName.lowercased().contains(term) {
            return true
        }
        if item.id.lowercased().contains(term) {
            return true
        }
        if item.kind.title.lowercased().contains(term) {
            return true
        }
        if let bundleIdentifier = item.bundleIdentifier?.lowercased(), bundleIdentifier.contains(term) {
            return true
        }
        return false
    }

    private func defaultScanSourceAbsolutePaths(homeDirectory: URL) -> [String] {
        [
            "/Applications",
            homeDirectory.appendingPathComponent("Applications", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true).path,
            "/Library/Caches",
            homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Containers", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Logs", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Preferences", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true).path,
            homeDirectory.appendingPathComponent(".npm", isDirectory: true).path,
            homeDirectory.appendingPathComponent(".pnpm-store", isDirectory: true).path,
            homeDirectory.appendingPathComponent(".cache/yarn", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Caches/Yarn", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Library/Caches/pnpm", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Developer", isDirectory: true).path,
            homeDirectory.appendingPathComponent("Projects", isDirectory: true).path
        ]
        .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    }

    private func pathsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = URL(fileURLWithPath: lhs).standardizedFileURL.path
        let normalizedRHS = URL(fileURLWithPath: rhs).standardizedFileURL.path

        return isPathEqualOrDescendant(normalizedLHS, ancestor: normalizedRHS) ||
            isPathEqualOrDescendant(normalizedRHS, ancestor: normalizedLHS)
    }

    private func customFolderCandidatePaths(
        for rootPath: String,
        avoiding blockedPaths: [String],
        exactOnlyBlockedRoots: Set<String>,
        fileManager: FileManager
    ) -> [String] {
        let normalizedRoot = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        guard normalizedRoot != "/" else { return [] }

        var pendingPaths: [String] = [normalizedRoot]
        var acceptedPaths = Set<String>()
        var visitedPaths = Set<String>()
        let maxPathVisits = 1024

        while let currentPath = pendingPaths.popLast() {
            guard visitedPaths.insert(currentPath).inserted else { continue }
            if visitedPaths.count > maxPathVisits {
                return []
            }

            if isBlockedPath(
                currentPath,
                blockedPaths: blockedPaths,
                exactOnlyBlockedRoots: exactOnlyBlockedRoots
            ) {
                continue
            }

            let containsBlockedDescendant = blockedPaths.contains { blockedPath in
                blockedPath != currentPath && isPathEqualOrDescendant(blockedPath, ancestor: currentPath)
            }
            if !containsBlockedDescendant {
                acceptedPaths.insert(currentPath)
                continue
            }

            let childPaths = childDirectoryPaths(of: currentPath, fileManager: fileManager)
            if childPaths.isEmpty {
                continue
            }
            pendingPaths.append(contentsOf: childPaths)
        }

        return acceptedPaths.sorted(by: pathSort)
    }

    private func isBlockedPath(
        _ path: String,
        blockedPaths: [String],
        exactOnlyBlockedRoots: Set<String>
    ) -> Bool {
        for blockedPath in blockedPaths {
            if path == blockedPath {
                return true
            }
            if isPathEqualOrDescendant(path, ancestor: blockedPath),
               !exactOnlyBlockedRoots.contains(blockedPath) {
                return true
            }
        }
        return false
    }

    private func isPathEqualOrDescendant(_ path: String, ancestor: String) -> Bool {
        if path == ancestor {
            return true
        }
        if ancestor == "/" {
            return true
        }
        return path.hasPrefix(ancestor + "/")
    }

    private func childDirectoryPaths(of parentPath: String, fileManager: FileManager) -> [String] {
        let parentURL = URL(fileURLWithPath: parentPath, isDirectory: true)
        guard let childURLs = try? fileManager.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return childURLs.compactMap { childURL in
            let values = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }
            return childURL.standardizedFileURL.path
        }
        .sorted(by: pathSort)
    }

    private func pathSort(_ lhs: String, _ rhs: String) -> Bool {
        let lhsDepth = lhs.split(separator: "/").count
        let rhsDepth = rhs.split(separator: "/").count
        if lhsDepth == rhsDepth {
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return lhsDepth < rhsDepth
    }

    private func formatDisplayPath(_ path: String, homeDirectory: URL) -> String {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path

        if normalizedPath == homePath {
            return "~"
        }
        if normalizedPath.hasPrefix(homePath + "/") {
            return "~" + normalizedPath.dropFirst(homePath.count)
        }
        return normalizedPath
    }

    private func loadChildrenIfNeeded(for item: StorageManagedItem) {
        guard item.isExpandable else { return }
        guard drilledItemsByParentID[item.id] == nil else { return }
        guard !loadingParentItemIDs.contains(item.id) else { return }

        let parentID = item.id
        let generation = scanGeneration
        let manager = storageManager

        loadingParentItemIDs.insert(parentID)

        let task = Task { [weak self] in
            let children = await Task.detached(priority: .userInitiated) {
                manager.drillDown(item: item, limit: 40)
            }.value

            guard let self, !Task.isCancelled, generation == scanGeneration else { return }

            let selectedIDsBeforeChildLoad = selectedItemIDs
            loadingParentItemIDs.remove(parentID)
            drilledItemsByParentID[parentID] = children
            rebuildItemIndex()
            selectedItemIDs = selectedItemIDs.intersection(selectableItemIDs)

            let loadedChildIDs = Set(children.filter { !$0.isProtected }.map(\.id))
            if !loadedChildIDs.isEmpty {
                for loadedChildID in loadedChildIDs {
                    let hasSelectedAncestor = selectedIDsBeforeChildLoad.contains { selectedID in
                        isAncestorPath(ancestor: selectedID, descendant: loadedChildID)
                    }
                    if hasSelectedAncestor {
                        selectedItemIDs.insert(loadedChildID)
                    }
                }
            }

            if let preset = activePreset {
                applyPreset(preset, keepPresetActive: true)
            } else {
                normalizeSelection()
            }

            childLoadTasks[parentID] = nil
        }

        childLoadTasks[parentID] = task
    }

    private func collapseItemAndDescendants(_ itemID: String) {
        expandedItemIDs.remove(itemID)
        expandedItemIDs = Set(
            expandedItemIDs.filter { !isAncestorPath(ancestor: itemID, descendant: $0) }
        )
    }

    private func rebuildItemIndex() {
        var index: [String: StorageManagedItem] = [:]

        for group in appGroups {
            for item in group.items {
                index[item.id] = item
            }
        }

        for item in looseItems {
            index[item.id] = item
        }

        for childItems in drilledItemsByParentID.values {
            for item in childItems {
                index[item.id] = item
            }
        }

        itemIndex = index
    }

    private var selectableItemIDs: Set<String> {
        Set(itemIndex.values.filter { !$0.isProtected }.map(\.id))
    }

    private func selectableIDs(for groupID: String) -> Set<String> {
        Set(
            itemIndex.values
                .filter { $0.appGroupID == groupID && !$0.isProtected }
                .map(\.id)
        )
    }

    private func normalizeSelection() {
        selectedItemIDs = selectedItemIDs.intersection(selectableItemIDs)
    }

    private var normalizedSelectedItems: [StorageManagedItem] {
        let selected = selectedItemIDs.compactMap { itemIndex[$0] }.filter { !$0.isProtected }
        let ordered = selected.sorted { lhs, rhs in
            if lhs.id.count == rhs.id.count {
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
            return lhs.id.count < rhs.id.count
        }

        var normalized: [StorageManagedItem] = []
        normalized.reserveCapacity(ordered.count)

        for item in ordered {
            let hasAncestor = normalized.contains { selectedItem in
                isAncestorPath(ancestor: selectedItem.id, descendant: item.id)
            }
            if !hasAncestor {
                normalized.append(item)
            }
        }

        return normalized
    }

    private var sortedDeletionPreviewItems: [StorageManagedItem] {
        normalizedSelectedItems.sorted { lhs, rhs in
            if lhs.sizeBytes == rhs.sizeBytes {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.sizeBytes > rhs.sizeBytes
        }
    }

    private func subtreeSelectableIDs(for itemID: String) -> Set<String> {
        let normalizedRootID = itemID
        let prefix = normalizedRootID + "/"

        return Set(
            itemIndex.values
                .filter { !$0.isProtected }
                .filter { item in
                    item.id == normalizedRootID || item.id.hasPrefix(prefix)
                }
                .map(\.id)
        )
    }

    private func effectiveSelectedCount(in candidateIDs: Set<String>) -> Int {
        candidateIDs.reduce(into: 0) { partial, candidateID in
            if isEffectivelySelected(candidateID) {
                partial += 1
            }
        }
    }

    private func isEffectivelySelected(_ itemID: String) -> Bool {
        if selectedItemIDs.contains(itemID) {
            return true
        }

        return selectedItemIDs.contains { selectedID in
            selectedID != itemID && isAncestorPath(ancestor: selectedID, descendant: itemID)
        }
    }

    private func materializeSelectedAncestorsCovering(targetIDs: Set<String>) {
        let selectedAncestorIDs = selectedItemIDs.filter { selectedID in
            targetIDs.contains { targetID in
                selectedID != targetID && isAncestorPath(ancestor: selectedID, descendant: targetID)
            }
        }
        .sorted { lhs, rhs in lhs.count < rhs.count }

        guard !selectedAncestorIDs.isEmpty else { return }

        for selectedAncestorID in selectedAncestorIDs {
            let ancestorSubtreeIDs = subtreeSelectableIDs(for: selectedAncestorID)
            selectedItemIDs.remove(selectedAncestorID)
            selectedItemIDs.formUnion(ancestorSubtreeIDs.subtracting([selectedAncestorID]))
        }
    }

    private func selectedAncestors(of itemID: String) -> [String] {
        selectedItemIDs
            .filter { selectedID in
                selectedID != itemID && isAncestorPath(ancestor: selectedID, descendant: itemID)
            }
            .sorted { lhs, rhs in lhs.count < rhs.count }
    }

    private func isAncestorPath(ancestor: String, descendant: String) -> Bool {
        if ancestor == descendant {
            return true
        }
        return descendant.hasPrefix(ancestor + "/")
    }

    private func loadPersistedAccessState() {
        refreshPersistedInitialAccessState()

        guard let storedData = userDefaults.data(forKey: trackedFolderAccessesKey),
              let decoded = try? JSONDecoder().decode([TrackedFolderAccess].self, from: storedData) else {
            trackedFolderAccesses = []
            reloadTrackedFolders()
            return
        }

        trackedFolderAccesses = decoded.sorted { lhs, rhs in
            lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
        reloadTrackedFolders()
    }

    private func persistTrackedFolderAccesses() {
        if trackedFolderAccesses.isEmpty {
            userDefaults.removeObject(forKey: trackedFolderAccessesKey)
            return
        }

        guard let encoded = try? JSONEncoder().encode(trackedFolderAccesses) else {
            return
        }
        userDefaults.set(encoded, forKey: trackedFolderAccessesKey)
    }

    private func refreshPersistedInitialAccessState() {
        let persistedPromptShown = userDefaults.bool(forKey: initialAccessPromptShownKey)
        if let persistedBookmarkData = userDefaults.data(forKey: primaryAccessBookmarkKey) {
            primaryAccessBookmarkData = persistedBookmarkData
            initialAccessPromptShown = true
            if !persistedPromptShown {
                userDefaults.set(true, forKey: initialAccessPromptShownKey)
                userDefaults.synchronize()
            }
        } else {
            primaryAccessBookmarkData = nil
            initialAccessPromptShown = persistedPromptShown
        }
    }

    private func reloadTrackedFolders() {
        trackedFolders = trackedFolderAccesses
            .map { URL(fileURLWithPath: $0.path, isDirectory: true).standardizedFileURL }
            .sorted { lhs, rhs in
                lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
            }
    }

    private func resolveTrackedFolderURLs() -> [URL] {
        var resolved: [URL] = []
        resolved.reserveCapacity(trackedFolderAccesses.count)

        for access in trackedFolderAccesses {
            let resolvedURL = resolveURL(for: access)
            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                resolved.append(resolvedURL)
            }
        }

        var deduplicatedByPath: [String: URL] = [:]
        for url in resolved {
            deduplicatedByPath[url.path] = url
        }

        return deduplicatedByPath.values.sorted { lhs, rhs in
            lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
    }

    private func resolveURL(for access: TrackedFolderAccess) -> URL {
        guard let bookmarkData = access.bookmarkData else {
            return URL(fileURLWithPath: access.path, isDirectory: true).standardizedFileURL
        }

        var isStale = false
        if let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            let normalized = resolvedURL.standardizedFileURL
            if isStale,
               let refreshedBookmarkData = makeBookmarkData(for: normalized),
               let index = trackedFolderAccesses.firstIndex(where: { $0.path == access.path }) {
                trackedFolderAccesses[index] = TrackedFolderAccess(path: access.path, bookmarkData: refreshedBookmarkData)
                persistTrackedFolderAccesses()
            }
            return normalized
        }

        return URL(fileURLWithPath: access.path, isDirectory: true).standardizedFileURL
    }

    private func resolvePrimaryAccessURL() -> URL? {
        guard let bookmarkData = primaryAccessBookmarkData else { return nil }

        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        let normalized = resolvedURL.standardizedFileURL
        if isStale, let refreshedBookmarkData = makeBookmarkData(for: normalized) {
            primaryAccessBookmarkData = refreshedBookmarkData
            userDefaults.set(refreshedBookmarkData, forKey: primaryAccessBookmarkKey)
        }
        return normalized
    }

    private func makeBookmarkData(for url: URL) -> Data? {
        let normalized = url.standardizedFileURL

        if let bookmark = try? normalized.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return bookmark
        }

        return try? normalized.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func scopeAccessURLs(customFolders: [URL]) -> [URL] {
        var urls: [URL] = customFolders
        if let primaryAccessURL = resolvePrimaryAccessURL() {
            urls.append(primaryAccessURL)
        }

        var deduplicatedByPath: [String: URL] = [:]
        for url in urls {
            deduplicatedByPath[url.standardizedFileURL.path] = url.standardizedFileURL
        }
        return Array(deduplicatedByPath.values)
    }

    private func beginScopedAccess(for urls: [URL]) -> [URL] {
        var started: [URL] = []
        started.reserveCapacity(urls.count)
        for url in urls {
            if url.startAccessingSecurityScopedResource() {
                started.append(url)
            }
        }
        return started
    }

    private func endScopedAccess(for urls: [URL]) {
        for url in urls {
            url.stopAccessingSecurityScopedResource()
        }
    }

    private let browserBundleIdentifiers: Set<String> = [
        "com.apple.safari",
        "com.google.chrome",
        "org.mozilla.firefox",
        "com.brave.browser",
        "com.microsoft.edgemac",
        "com.operasoftware.opera"
    ]

    private let browserNameFragments: [String] = [
        "safari",
        "chrome",
        "firefox",
        "brave",
        "edge",
        "opera",
        "arc",
        "cursor"
    ]

    private let xcodeKinds: Set<StorageManagedItemKind> = [
        .derivedData,
        .xcodeArchives,
        .simulatorData
    ]

    private let nodeKinds: Set<StorageManagedItemKind> = [
        .nodeModules,
        .npmCache,
        .yarnCache,
        .pnpmStore
    ]

    private func flattenRows(items: [StorageManagedItem]) -> [StorageListRow] {
        var rows: [StorageListRow] = []
        appendRows(items: items, depth: 0, into: &rows)
        return rows
    }

    private func appendRows(items: [StorageManagedItem], depth: Int, into rows: inout [StorageListRow]) {
        for item in items {
            rows.append(StorageListRow(item: item, depth: depth))
            guard expandedItemIDs.contains(item.id) else { continue }
            if let children = drilledItemsByParentID[item.id], !children.isEmpty {
                appendRows(items: children, depth: depth + 1, into: &rows)
            }
        }
    }
}
