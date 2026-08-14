import SwiftUI

struct PillTabBar: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        HStack(spacing: 4) {
            tab(.cycle, icon: "arrow.trianglehead.2.clockwise.rotate.90", key: "nav.cycle")
            tab(.month, icon: "calendar", key: "nav.month")
            tab(.more, icon: "ellipsis", key: "nav.more")
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Theme.cream.opacity(0.95))
        .overlay(alignment: .top) { Rectangle().fill(Theme.blush100).frame(height: 1) }
        .accessibilityLabel(app.t("nav.aria"))
    }

    private func tab(_ tab: AppModel.Tab, icon: String, key: String) -> some View {
        let active = app.selectedTab == tab
        return Button {
            app.selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(app.t(key))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? Theme.blush800 : Theme.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? Theme.blush100 : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
