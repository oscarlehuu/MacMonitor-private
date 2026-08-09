import SwiftUI

/// Full-screen modal overlay that lets the user review and confirm (or cancel)
/// moving selected storage items to the Trash.
///
/// Manages its own snapshot + preview-cache state so PopoverRootView stays thin.
struct StorageDeleteConfirmationOverlay: View {
    @ObservedObject var storageManagementViewModel: StorageManagementViewModel
    /// Set to `true` by this view right before it triggers deletion, so the
    /// caller can skip the snapshot-restore path in its own `onChange` handler.
    @Binding var didConfirmDeletion: Bool

    // MARK: Private state (was in PopoverRootView)

    @State private var deleteConfirmationAcknowledged = false
    @State private var deleteConfirmationSnapshot: StorageSelectionSnapshot?
    @State private var deleteConfirmationRootItemIDs: Set<String> = []
    @State private var cachedDeletePreviewGroupSections: [StorageDeletePreviewGroupSection] = []
    @State private var cachedDeletePreviewLooseRows: [StorageListRow] = []

    // MARK: Body

    var body: some View {
        let previewGroupSections = cachedDeletePreviewGroupSections
        let previewLooseRows = cachedDeletePreviewLooseRows
        let hasPreviewRows = !previewGroupSections.isEmpty || !previewLooseRows.isEmpty

        ZStack {
            // Dimming backdrop — tap to cancel
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture { cancel() }

            // Dialog card
            VStack(alignment: .leading, spacing: 10) {
                dialogHeader
                selectionSummary

                if !hasPreviewRows {
                    Text("No selected items.")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    previewList(sections: previewGroupSections, looseRows: previewLooseRows)
                }

                acknowledgementCheckbox
                actionButtons
            }
            .padding(12)
            .frame(maxWidth: 382)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.36), radius: 20, y: 10)
            .padding(.horizontal, 12)
        }
        .zIndex(200)
        .onAppear { handlePresented() }
        .onDisappear { handleDismissed() }
        .onChange(of: storageManagementViewModel.selectedItemIDs) { _, _ in
            deleteConfirmationAcknowledged = false
            refreshCache()
        }
        .onChange(of: storageManagementViewModel.expandedItemIDs) { _, _ in refreshCache() }
        .onChange(of: storageManagementViewModel.drilledItemsByParentID) { _, _ in refreshCache() }
    }

    // MARK: Sub-views

    private var dialogHeader: some View {
        Text("Move selected items to Trash?")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(PopoverTheme.textPrimary)
    }

    private var selectionSummary: some View {
        Text(
            "Selected: \(storageManagementViewModel.selectedAllowedCount) • " +
            MetricFormatter.bytes(storageManagementViewModel.selectedAllowedBytes)
        )
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(PopoverTheme.textSecondary)
    }

    private func previewList(
        sections: [StorageDeletePreviewGroupSection],
        looseRows: [StorageListRow]
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    storageDeletePreviewGroupRow(section)

                    if storageManagementViewModel.deletionPreviewExpandedGroupIDs.contains(section.group.id) {
                        ForEach(section.rows) { row in
                            storageDeletePreviewRow(row, depthOffset: 1)
                        }
                    }

                    if index < sections.count - 1 || !looseRows.isEmpty {
                        storageDeletePreviewDivider
                    }
                }

                if !looseRows.isEmpty {
                    storageDeletePreviewLooseHeader

                    ForEach(Array(looseRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { storageDeletePreviewDivider }
                        storageDeletePreviewRow(row, depthOffset: 0)
                    }
                }
            }
        }
        .frame(maxHeight: 212)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgElevated.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var acknowledgementCheckbox: some View {
        Button {
            deleteConfirmationAcknowledged.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(PopoverTheme.borderMedium, lineWidth: 1.2)
                        .frame(width: 16, height: 16)

                    if deleteConfirmationAcknowledged {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PopoverTheme.accent)
                            .frame(width: 16, height: 16)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PopoverTheme.accentContrastText)
                    }
                }

                Text("I reviewed these items and still want to move them to Trash.")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Cancel") { cancel() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .foregroundStyle(PopoverTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(PopoverTheme.bgElevated))
                .overlay(Capsule(style: .continuous).stroke(PopoverTheme.borderSubtle, lineWidth: 1))

            Spacer(minLength: 0)

            Button("Move to Trash") {
                didConfirmDeletion = true
                Task { await storageManagementViewModel.deleteSelected() }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .foregroundStyle(
                deleteConfirmationAcknowledged
                    ? PopoverTheme.accentContrastText
                    : PopoverTheme.textMuted
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(deleteConfirmationAcknowledged ? PopoverTheme.red : PopoverTheme.bgElevated)
            )
            .overlay(Capsule(style: .continuous).stroke(PopoverTheme.borderSubtle, lineWidth: 1))
            .disabled(
                !deleteConfirmationAcknowledged ||
                    storageManagementViewModel.selectedAllowedCount == 0 ||
                    storageManagementViewModel.isDeleteFlowInteractionLocked
            )
        }
    }

    // MARK: Lifecycle helpers

    private func handlePresented() {
        didConfirmDeletion = false
        deleteConfirmationAcknowledged = false
        deleteConfirmationSnapshot = storageManagementViewModel.makeSelectionSnapshot()
        deleteConfirmationRootItemIDs = storageManagementViewModel.deletionPreviewRootItemIDs
        storageManagementViewModel.beginDeletionPreview(rootItemIDs: deleteConfirmationRootItemIDs)
        refreshCache()
    }

    private func handleDismissed() {
        if !didConfirmDeletion, let snapshot = deleteConfirmationSnapshot {
            storageManagementViewModel.restoreSelectionSnapshot(snapshot)
        }
        storageManagementViewModel.endDeletionPreview()
        deleteConfirmationAcknowledged = false
        deleteConfirmationRootItemIDs = []
        deleteConfirmationSnapshot = nil
        clearCache()
    }

    private func cancel() {
        storageManagementViewModel.showingDeleteConfirmation = false
    }

    // MARK: Cache helpers

    private var activeDeletePreviewRootItemIDs: Set<String> {
        deleteConfirmationRootItemIDs.union(storageManagementViewModel.deletionPreviewRootItemIDs)
    }

    private func refreshCache() {
        let previewRootIDs = activeDeletePreviewRootItemIDs
        guard !previewRootIDs.isEmpty else {
            clearCache()
            return
        }

        cachedDeletePreviewGroupSections = storageManagementViewModel.appGroups.compactMap { group in
            let filteredRows = storageManagementViewModel.deletionPreviewRows(
                for: group,
                rootItemIDs: previewRootIDs
            )
            guard !filteredRows.isEmpty else { return nil }
            return StorageDeletePreviewGroupSection(group: group, rows: filteredRows)
        }

        cachedDeletePreviewLooseRows = storageManagementViewModel.deletionPreviewLooseRows(
            rootItemIDs: previewRootIDs
        )
    }

    private func clearCache() {
        cachedDeletePreviewGroupSections = []
        cachedDeletePreviewLooseRows = []
    }
}
