import SwiftUI

/// Compact icon-only vertical sidebar for navigating between app sections.
/// Branding icon at top, primary nav items in the middle, settings pinned to bottom.
struct SidebarNavigationView: View {
    let activeTab: SidebarTab
    let onTabSelected: (SidebarTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            brandingIcon
            sidebarDivider

            // Primary nav items (Memory, Battery, Storage, Trends)
            VStack(spacing: 4) {
                ForEach(SidebarTab.primaryItems, id: \.self) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.vertical, 8)

            Spacer(minLength: 0)

            sidebarDivider
            sidebarButton(.settings)
                .padding(.vertical, 8)
        }
        .frame(width: 44)
        .background(PopoverTheme.bgPanel.opacity(0.72))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(width: 1)
        }
    }

    // MARK: - Branding

    private var brandingIcon: some View {
        Image(systemName: "waveform.path.ecg")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(PopoverTheme.accent)
            .frame(width: 36, height: 36)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    // MARK: - Nav Button

    private func sidebarButton(_ tab: SidebarTab) -> some View {
        let isActive = activeTab == tab
        return Button {
            onTabSelected(tab)
        } label: {
            Image(systemName: tab.symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? PopoverTheme.textPrimary : PopoverTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? PopoverTheme.bgCard : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? PopoverTheme.borderMedium : Color.clear, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tab.tooltip)
    }

    // MARK: - Divider

    private var sidebarDivider: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.horizontal, 8)
    }
}
