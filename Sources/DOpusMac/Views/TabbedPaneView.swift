import SwiftUI

struct TabbedPaneView: View {
    @ObservedObject var tabs: TabbedPaneState
    let side: PaneSide
    let isActive: Bool
    let accentColor: Color
    let otherPaneLabel: String
    let onActivate: () -> Void
    let onMoveRequested: () -> Void
    let onCopyRequested: () -> Void
    let onDeleteRequested: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            PaneView(
                pane: tabs.activePaneState,
                side: side,
                isActive: isActive,
                accentColor: accentColor,
                otherPaneLabel: otherPaneLabel,
                onActivate: onActivate,
                onMoveRequested: onMoveRequested,
                onCopyRequested: onCopyRequested,
                onDeleteRequested: onDeleteRequested
            )
            .id(tabs.activeTabIndex)
        }
        .overlay(
            Rectangle()
                .strokeBorder(isActive ? Color.secondary : .clear, lineWidth: 1)
        )
    }

    // MARK: - Tab Strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs.tabs.indices, id: \.self) { index in
                        tabButton(at: index)
                        if index < tabs.tabs.count - 1 {
                            Divider().frame(height: 16)
                        }
                    }
                }
                .padding(.leading, 2)
            }
            Divider().frame(height: 16)
            Button {
                onActivate()
                tabs.openTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.borderless)
            .help("New Tab")
        }
        .frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    @ViewBuilder
    private func tabButton(at index: Int) -> some View {
        let tab = tabs.tabs[index]
        let isSelected = index == tabs.activeTabIndex
        let label = tab.pane.currentURL?.lastPathComponent ?? "Computer"

        HStack(spacing: 0) {
            Button {
                onActivate()
                tabs.switchTab(to: index)
            } label: {
                Text(label)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 110, alignment: .leading)
                    .padding(.leading, 8)
                    .padding(.trailing, tabs.tabs.count > 1 ? 2 : 8)
                    .frame(height: 26)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .accessibilityLabel("Tab: \(label)")

            if tabs.tabs.count > 1 {
                Button {
                    tabs.closeTab(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 20, height: 26)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Close tab \(label)")
            }
        }
        .background(
            isSelected
                ? (isActive ? accentColor.opacity(0.1) : Color(nsColor: .quaternaryLabelColor).opacity(0.1))
                : Color.clear
        )
    }
}
