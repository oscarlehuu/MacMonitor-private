import SwiftUI

/// Row-rendering sub-views for `StorageDeleteConfirmationOverlay`.
/// Kept in a separate file to respect the 200-line-per-file guideline.
extension StorageDeleteConfirmationOverlay {

    // MARK: Section chrome

    var storageDeletePreviewLooseHeader: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 12)
            Image(systemName: "tray.full")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PopoverTheme.mint)
                .frame(width: 12)
            Text("Other Targets")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    var storageDeletePreviewDivider: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.leading, 8)
    }

    // MARK: Group row

    func storageDeletePreviewGroupRow(_ section: StorageDeletePreviewGroupSection) -> some View {
        let group = section.group
        let selectionState = storageManagementViewModel.groupSelectionState(group)
        let isExpanded = storageManagementViewModel.deletionPreviewExpandedGroupIDs.contains(group.id)

        return HStack(spacing: 8) {
            Button {
                storageManagementViewModel.toggleDeletionPreviewGroupExpansion(group.id)
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .frame(width: 10)
            }
            .buttonStyle(.plain)
            .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)

            Button {
                storageManagementViewModel.toggleGroupSelection(group.id)
            } label: {
                Image(systemName: modalGroupSelectionSymbol(selectionState))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(modalGroupSelectionColor(selectionState))
            }
            .buttonStyle(.plain)
            .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)

            if let appIcon = modalAppIconImage(for: group) {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PopoverTheme.blue)
                    .frame(width: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let bundleIdentifier = group.bundleIdentifier {
                    Text(bundleIdentifier)
                        .font(.system(size: 9))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            Text(MetricFormatter.bytes(group.totalBytes))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(PopoverTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    selectionState == .none
                        ? Color.clear
                        : PopoverTheme.bgCardHover.opacity(selectionState == .all ? 0.9 : 0.6)
                )
        )
    }

    // MARK: Individual item row

    func storageDeletePreviewRow(_ row: StorageListRow, depthOffset: Int) -> some View {
        let item = row.item
        let isDirectlySelected = storageManagementViewModel.selectedItemIDs.contains(item.id)
        let isInDeletionScope = storageManagementViewModel.isItemInDeletionScope(item.id)
        let isIncludedByAncestor = isInDeletionScope && !isDirectlySelected
        let isExpanded = storageManagementViewModel.isDeletionPreviewItemExpanded(item.id)
        let isLoading = storageManagementViewModel.isDeletionPreviewLoadingChildren(for: item.id)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Spacer().frame(width: CGFloat(row.depth + depthOffset) * 12)

                if item.isExpandable {
                    Button {
                        storageManagementViewModel.toggleDeletionPreviewItemExpansion(item.id)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .frame(width: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(storageManagementViewModel.isDeleteFlowInteractionLocked)
                } else {
                    Spacer().frame(width: 10)
                }

                Button {
                    storageManagementViewModel.toggleSelection(for: item.id)
                } label: {
                    Image(systemName: modalSelectionSymbol(
                        isDirectlySelected: isDirectlySelected,
                        isIncludedByAncestor: isIncludedByAncestor,
                        item: item
                    ))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(modalSelectionColor(
                        isDirectlySelected: isDirectlySelected,
                        isIncludedByAncestor: isIncludedByAncestor,
                        item: item
                    ))
                }
                .buttonStyle(.plain)
                .disabled(
                    item.isProtected ||
                        storageManagementViewModel.isDeleteFlowInteractionLocked
                )

                if let appIcon = modalAppIconImage(for: item) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                } else {
                    Image(systemName: storageItemIcon(for: item))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(storageItemColor(for: item.category))
                        .frame(width: 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.url.path)
                        .font(.system(size: 9))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if isIncludedByAncestor {
                        Text("Included via parent selection")
                            .font(.system(size: 8))
                            .foregroundStyle(PopoverTheme.orange)
                    }
                }

                Spacer(minLength: 8)

                Text(MetricFormatter.bytes(item.sizeBytes))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }

            if isExpanded && isLoading {
                HStack(spacing: 4) {
                    Spacer().frame(width: CGFloat(row.depth + depthOffset + 1) * 12 + 16)
                    ProgressView().controlSize(.small)
                    Text("Loading children...")
                        .font(.system(size: 8))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    isInDeletionScope
                        ? PopoverTheme.bgCardHover.opacity(isDirectlySelected ? 1 : 0.62)
                        : Color.clear
                )
        )
    }
}
