import SwiftUI

struct TabbedPaneView: View {
    @ObservedObject var tabs: TabbedPaneState
    let side: PaneSide
    let isActive: Bool
    let accentColor: Color
    let otherPaneLabel: String
    let compareStatuses: [URL: FolderCompareStatus]
    let compareSummaryText: String?
    let onActivate: () -> Void
    let onMoveRequested: () -> Void
    let onCopyRequested: () -> Void
    let onDeleteRequested: () -> Void

    @State private var renamingTabIndex: Int? = nil
    @State private var renameTabText: String = ""

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
                compareStatuses: compareStatuses,
                compareSummaryText: compareSummaryText,
                onActivate: onActivate,
                onMoveRequested: onMoveRequested,
                onCopyRequested: onCopyRequested,
                onDeleteRequested: onDeleteRequested
            )
            .id(tabs.activeTabID)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipShape(paneShape)
        .overlay(
            paneShape
                .strokeBorder(
                    isActive ? Color.secondary : Color.secondary.opacity(0.22),
                    lineWidth: 1
                )
        )
        .sheet(isPresented: Binding(
            get: { renamingTabIndex != nil },
            set: { if !$0 { renamingTabIndex = nil } }
        )) {
            TextPromptSheet(
                title: "Rename Tab",
                text: $renameTabText,
                confirmLabel: "Rename",
                onConfirm: {
                    if let index = renamingTabIndex {
                        tabs.setTabLabel(renameTabText, at: index)
                    }
                    renamingTabIndex = nil
                },
                onCancel: { renamingTabIndex = nil }
            )
        }
    }

    private var paneShape: RoundedRectangle { RoundedRectangle(cornerRadius: 8) }

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
            .help("New Tab (⌘T)")
            .accessibilityIdentifier("\(side.accessibilityIDPrefix)-new-tab-button")
        }
        .frame(height: 26)
        .padding(.trailing, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    @ViewBuilder
    private func tabButton(at index: Int) -> some View {
        let tab = tabs.tabs[index]
        let isSelected = index == tabs.activeTabIndex
        let labelURL = tab.isPinned ? tab.pinnedURL : tab.pane.currentURL
        let autoLabel = labelURL?.lastPathComponent ?? "Computer"
        let label = tab.customLabel ?? autoLabel

        let tabBg: Color = {
            if let tint = tab.tint {
                return tint.color.opacity(isSelected ? 0.28 : 0.10)
            }
            if isSelected {
                return isActive ? accentColor.opacity(0.1) : Color(nsColor: .quaternaryLabelColor).opacity(0.1)
            }
            return Color.clear
        }()

        HStack(spacing: 0) {
            Button {
                onActivate()
                tabs.activateTab(at: index)
                tabs.tabs[index].pane.load()
            } label: {
                HStack(spacing: 4) {
                    if tab.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(isSelected ? accentColor : .secondary)
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: tab.isPinned ? 126 : 110, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, tabs.canCloseTab(at: index) ? 2 : 8)
                .frame(height: 26)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .accessibilityLabel("Tab: \(label)")
            .accessibilityValue(tab.isPinned ? "Pinned" : "")
            .accessibilityIdentifier("\(side.accessibilityIDPrefix)-tab-\(index)")

            if tabs.canCloseTab(at: index) {
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
                .accessibilityIdentifier("\(side.accessibilityIDPrefix)-close-tab-\(index)")
            }
        }
        .background(tabBg)
        .contextMenu {
            if index > 0 {
                Button("Move to Start") {
                    tabs.moveTab(from: index, to: 0)
                }
                Button("Move Left") {
                    tabs.moveTab(from: index, to: index - 1)
                }
            }
            if index < tabs.tabs.count - 1 {
                Button("Move to End") {
                    tabs.moveTab(from: index, to: tabs.tabs.count)
                }
                Button("Move Right") {
                    tabs.moveTab(from: index, to: index + 2)
                }
            }
            if index > 0 || index < tabs.tabs.count - 1 {
                Divider()
            }
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                tabs.toggleTabPinned(at: index)
            }
            Divider()
            Menu("Tab Color") {
                Button("None") {
                    tabs.setTabTint(nil, at: index)
                }
                Divider()
                ForEach(TabTint.allCases) { tint in
                    Button(tint.label) {
                        tabs.setTabTint(tint, at: index)
                    }
                }
            }
            Divider()
            Button("Rename Tab…") {
                renameTabText = tab.customLabel ?? autoLabel
                renamingTabIndex = index
            }
            if tab.customLabel != nil {
                Button("Reset Tab Name") {
                    tabs.setTabLabel("", at: index)
                }
            }
        }
    }
}
