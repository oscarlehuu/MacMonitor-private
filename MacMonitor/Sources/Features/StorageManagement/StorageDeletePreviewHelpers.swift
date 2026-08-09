import AppKit
import SwiftUI

// MARK: - Data model

/// Represents one app-group section in the delete confirmation preview list.
struct StorageDeletePreviewGroupSection: Identifiable {
    let group: StorageAppGroup
    let rows: [StorageListRow]

    var id: String { group.id }
}

// MARK: - App icon cache

/// Shared cache scoped to the delete-confirmation overlay lifetime.
nonisolated(unsafe) let storageDeletePreviewAppIconCache = NSCache<NSString, NSImage>()

// MARK: - App icon helpers

func modalAppIconImage(for group: StorageAppGroup) -> NSImage? {
    let cacheKey = "group:\(group.id)" as NSString
    if let cachedIcon = storageDeletePreviewAppIconCache.object(forKey: cacheKey) {
        return cachedIcon
    }

    guard let appBundle = group.items.first(where: { $0.kind == .appBundle }),
          appBundle.url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
          FileManager.default.fileExists(atPath: appBundle.url.path) else {
        return nil
    }

    let icon = NSWorkspace.shared.icon(forFile: appBundle.url.path)
    storageDeletePreviewAppIconCache.setObject(icon, forKey: cacheKey)
    return icon
}

func modalAppIconImage(for item: StorageManagedItem) -> NSImage? {
    guard item.kind == .appBundle else { return nil }

    let cacheKey = "item:\(item.id)" as NSString
    if let cachedIcon = storageDeletePreviewAppIconCache.object(forKey: cacheKey) {
        return cachedIcon
    }

    guard item.url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
          FileManager.default.fileExists(atPath: item.url.path) else {
        return nil
    }

    let icon = NSWorkspace.shared.icon(forFile: item.url.path)
    storageDeletePreviewAppIconCache.setObject(icon, forKey: cacheKey)
    return icon
}

// MARK: - Selection symbol / color helpers

func modalGroupSelectionSymbol(_ state: StorageSelectionState) -> String {
    switch state {
    case .none:    return "circle"
    case .partial: return "minus.circle.fill"
    case .all:     return "checkmark.circle.fill"
    }
}

func modalGroupSelectionColor(_ state: StorageSelectionState) -> Color {
    switch state {
    case .none:    return PopoverTheme.textMuted
    case .partial: return PopoverTheme.orange
    case .all:     return PopoverTheme.accent
    }
}

func modalSelectionSymbol(
    isDirectlySelected: Bool,
    isIncludedByAncestor: Bool,
    item: StorageManagedItem
) -> String {
    if item.isProtected        { return "lock.square.fill" }
    if isDirectlySelected      { return "checkmark.square.fill" }
    if isIncludedByAncestor    { return "checkmark.square" }
    return "square"
}

func modalSelectionColor(
    isDirectlySelected: Bool,
    isIncludedByAncestor: Bool,
    item: StorageManagedItem
) -> Color {
    if item.isProtected        { return PopoverTheme.orange }
    if isDirectlySelected      { return PopoverTheme.accent }
    if isIncludedByAncestor    { return PopoverTheme.orange }
    return PopoverTheme.textSecondary
}

// MARK: - Storage item icon / color helpers

func storageItemIcon(for item: StorageManagedItem) -> String {
    switch item.kind {
    case .appBundle:
        return "app.dashed"
    case .appCache, .looseCache, .npmCache, .pnpmStore, .yarnCache:
        return "externaldrive.badge.timemachine"
    case .derivedData:
        return "hammer"
    case .xcodeArchives:
        return "archivebox"
    case .simulatorData:
        return "iphone.rear.camera"
    case .nodeModules:
        return "shippingbox"
    case .appSupport, .appContainer, .customFolder, .looseFolder, .drillDown:
        return item.category.symbolName
    case .appLogs:
        return "doc.text"
    case .appPreferences:
        return "slider.horizontal.3"
    }
}

func storageItemColor(for category: StorageManagedItemCategory) -> Color {
    switch category {
    case .application: return PopoverTheme.blue
    case .cache:       return PopoverTheme.mint
    case .folder:      return PopoverTheme.purple
    }
}

// MARK: - Path ancestry helper

func isAncestorPath(ancestor: String, descendant: String) -> Bool {
    ancestor == descendant || descendant.hasPrefix(ancestor + "/")
}
