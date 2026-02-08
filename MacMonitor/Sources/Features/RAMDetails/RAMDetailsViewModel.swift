import Combine
import Foundation

@MainActor
final class RAMDetailsViewModel: ObservableObject {
    @Published private(set) var processes: [ProcessMemoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isTerminating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var resultMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var scopeMode: ProcessScopeMode = .sameUserOnly
    @Published private(set) var showAllMine = false
    @Published private(set) var myProcessBytes: UInt64 = 0
    @Published private(set) var allProcessBytes: UInt64 = 0
    @Published private(set) var myProcessCount: Int = 0
    @Published private(set) var allProcessCount: Int = 0
    @Published var selectedProcessIDs: Set<Int32> = []
    @Published var showingTerminateConfirmation = false

    private let processCollector: ProcessListCollecting
    private let processTerminator: ProcessTerminating
    private let maxRows: Int
    private let refreshInterval: TimeInterval
    private let currentUserID: uid_t

    private var refreshCancellable: AnyCancellable?
    private var hasStarted = false
    private(set) var pendingRefreshTask: Task<Void, Never>?

    init(
        processCollector: ProcessListCollecting,
        processTerminator: ProcessTerminating,
        maxRows: Int = 20,
        refreshInterval: TimeInterval = 5,
        currentUserID: uid_t = getuid()
    ) {
        self.processCollector = processCollector
        self.processTerminator = processTerminator
        self.maxRows = maxRows
        self.refreshInterval = refreshInterval
        self.currentUserID = currentUserID
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refresh()

        refreshCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        refreshCancellable?.cancel()
        refreshCancellable = nil
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
    }

    func setScopeMode(_ scope: ProcessScopeMode) {
        guard scope != scopeMode else { return }
        scopeMode = scope
        if scope != .sameUserOnly {
            showAllMine = false
        }
        selectedProcessIDs.removeAll()
        refresh()
    }

    func setShowAllMine(_ enabled: Bool) {
        guard enabled != showAllMine else { return }
        showAllMine = enabled
        selectedProcessIDs.removeAll()
        refresh()
    }

    func refresh() {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { await performRefresh() }
    }

    func performRefresh() async {
        if processes.isEmpty {
            isLoading = true
        }

        let collector = processCollector
        let showAll = showAllMine
        let rows = maxRows
        let scope = scopeMode

        do {
            let (allMineRows, allRows) = try await Task.detached(priority: .userInitiated) {
                let mine = try collector.collectTopProcesses(limit: 10_000, scope: .sameUserOnly)
                let all = try collector.collectTopProcesses(limit: 10_000, scope: .allDiscoverable)
                return (mine, all)
            }.value

            guard !Task.isCancelled else { return }

            myProcessBytes = allMineRows.reduce(0) { $0 + $1.rankingBytes }
            allProcessBytes = allRows.reduce(0) { $0 + $1.rankingBytes }
            myProcessCount = allMineRows.count
            allProcessCount = allRows.count

            let mineRows = showAll ? allMineRows : Array(allMineRows.prefix(rows))

            let refreshed: [ProcessMemoryItem]
            switch scope {
            case .sameUserOnly:
                refreshed = mineRows
            case .allDiscoverable:
                refreshed = Array(allRows.prefix(rows))
            }

            processes = refreshed
            selectedProcessIDs = selectedProcessIDs.intersection(Set(refreshed.filter { !$0.isProtected }.map(\.pid)))
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleSelection(for processID: Int32) {
        guard let process = processes.first(where: { $0.pid == processID }), !process.isProtected else { return }

        if selectedProcessIDs.contains(processID) {
            selectedProcessIDs.remove(processID)
        } else {
            selectedProcessIDs.insert(processID)
        }
    }

    func requestTerminateSelected() {
        guard selectedAllowedCount > 0, !isTerminating else { return }
        showingTerminateConfirmation = true
    }

    func terminateSelected() async {
        let allowedIDs = Set(
            processes
                .filter { selectedProcessIDs.contains($0.pid) && !$0.isProtected }
                .map(\.pid)
        )

        guard !allowedIDs.isEmpty else {
            showingTerminateConfirmation = false
            return
        }

        isTerminating = true
        showingTerminateConfirmation = false

        // Yield so SwiftUI can observe the isTerminating state before
        // performing the synchronous kill() calls.
        await Task.yield()

        let summary = processTerminator.terminate(processes: processes, selectedProcessIDs: allowedIDs)
        resultMessage = summary.message
        selectedProcessIDs.removeAll()
        refresh()

        isTerminating = false
    }

    var selectedAllowedCount: Int {
        processes.filter { selectedProcessIDs.contains($0.pid) && !$0.isProtected }.count
    }

    var selectedAllowedBytes: UInt64 {
        processes
            .filter { selectedProcessIDs.contains($0.pid) && !$0.isProtected }
            .reduce(0) { $0 + $1.rankingBytes }
    }

    var canTerminateSelection: Bool {
        selectedAllowedCount > 0 && !isTerminating
    }

    var listedRowsBytes: UInt64 {
        processes.reduce(0) { $0 + $1.rankingBytes }
    }

    var defaultTopRows: Int {
        maxRows
    }

    var canToggleAllMine: Bool {
        scopeMode == .sameUserOnly && myProcessCount > maxRows
    }

    var areDisplayedRowsCurrentUserOnly: Bool {
        !processes.isEmpty && processes.allSatisfy { $0.userID == currentUserID }
    }

    var hasMoreAllRowsThanDisplayed: Bool {
        allProcessCount > processes.count
    }

    var terminationInfoTooltip: String {
        "This action proceeds with allowed processes only."
    }
}
