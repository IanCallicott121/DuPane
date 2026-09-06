import SwiftUI

struct GlobalToolbar: View {
    let isLeftToRight: Bool
    let canMoveOrCopy: Bool
    let canDelete: Bool
    let canRename: Bool
    let showSidebar: Bool
    let bookmarkEnabled: Bool
    let isBookmarked: Bool
    let isTerminalShown: Bool
    let isFollowMode: Bool
    let showLabels: Bool
    let canCompare: Bool
    let isCompareMode: Bool
    let compareSummary: String?
    let canSyncLeftToRight: Bool
    let canSyncRightToLeft: Bool
    let onToggleSidebar: () -> Void
    let onBookmarkCurrent: () -> Void
    let onNewFolder: () -> Void
    let onNewFile: () -> Void
    let onMove: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let canFindDuplicates: Bool
    let onToggleTerminal: () -> Void
    let onToggleFollow: () -> Void
    let onToggleCompare: () -> Void
    let onSyncLeftToRight: () -> Void
    let onSyncRightToLeft: () -> Void
    let onFindDuplicates: () -> Void

    private var moveIcon: String { isLeftToRight ? "arrow.right.circle" : "arrow.left.circle" }
    private var copyIcon: String { isLeftToRight ? "arrow.right.square" : "arrow.left.square" }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleSidebar) {
                toolbarLabel("Sidebar", icon: "sidebar.left")
                    .foregroundStyle(showSidebar ? Color.accentColor : Color.secondary)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .help("Toggle Sidebar (⌥⌘S)")

            Divider().frame(height: 20)

            Button(action: onNewFolder) {
                toolbarLabel("New Folder", icon: "folder.badge.plus")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(action: onNewFile) {
                toolbarLabel("New File", icon: "doc.badge.plus")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button(action: onMove) {
                toolbarLabel("Move", icon: moveIcon)
            }
            .disabled(!canMoveOrCopy)
            .accessibilityIdentifier("toolbar-move-button")

            Button(action: onCopy) {
                toolbarLabel("Copy", icon: copyIcon)
            }
            .disabled(!canMoveOrCopy)
            .accessibilityIdentifier("toolbar-copy-button")

            Divider().frame(height: 20)

            Button(action: onToggleCompare) {
                toolbarLabel("Compare", icon: "arrow.left.arrow.right")
                    .foregroundStyle(isCompareMode ? Color.accentColor : Color.secondary)
            }
            .disabled(!canCompare)
            .accessibilityIdentifier("toolbar-compare-button")
            .help(canCompare ? "Compare both active folders" : "Navigate both panes into folders to compare")

            if isCompareMode {
                Button(action: onSyncLeftToRight) {
                    toolbarLabel("Sync L->R", icon: "arrow.right")
                }
                .disabled(!canSyncLeftToRight)
                .accessibilityIdentifier("toolbar-sync-left-to-right-button")
                .help("Sync eligible differences from the left pane to the right pane")

                Button(action: onSyncRightToLeft) {
                    toolbarLabel("Sync R->L", icon: "arrow.left")
                }
                .disabled(!canSyncRightToLeft)
                .accessibilityIdentifier("toolbar-sync-right-to-left-button")
                .help("Sync eligible differences from the right pane to the left pane")
            }

            Button(action: onDelete) {
                toolbarLabel("Delete", icon: "trash")
            }
            .disabled(!canDelete)
            .keyboardShortcut(.delete, modifiers: .command)

            Button(action: onRename) {
                toolbarLabel("Rename", icon: "pencil")
            }
            .disabled(!canRename)
            .accessibilityIdentifier("toolbar-rename-button")
            .help("Rename selected item")

            Button(action: onFindDuplicates) {
                toolbarLabel("Dupes", icon: "doc.on.doc")
            }
            .disabled(!canFindDuplicates)
            .help("Find duplicate files in the current folder tree")

            Divider().frame(height: 20)

            Button(action: onBookmarkCurrent) {
                toolbarLabel("Bookmark", icon: isBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isBookmarked ? Color.accentColor : Color.secondary)
            }
            .disabled(!bookmarkEnabled)
            .help(isBookmarked ? "Remove Bookmark" : "Add to Sidebar")

            Button(action: onToggleTerminal) {
                toolbarLabel("Terminal", icon: isTerminalShown ? "terminal.fill" : "terminal")
                    .foregroundStyle(isTerminalShown ? Color.accentColor : Color.secondary)
            }
            .accessibilityIdentifier("toolbar-terminal-button")
            .help("Toggle command runner (⌥`)")

            Button(action: onToggleFollow) {
                toolbarLabel("Follow", icon: "link")
                    .foregroundStyle(isFollowMode ? Color.accentColor : Color.secondary)
            }
            .help(isFollowMode ? "Follow Mode on — navigation mirrors between panes" : "Follow Mode — navigation in one pane mirrors to the other")

            if isCompareMode, let compareSummary {
                Text(compareSummary)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("toolbar-compare-summary")
            }

            Spacer()
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func toolbarLabel(_ title: String, icon: String) -> some View {
        if showLabels {
            Label(title, systemImage: icon)
        } else {
            Image(systemName: icon)
        }
    }
}
