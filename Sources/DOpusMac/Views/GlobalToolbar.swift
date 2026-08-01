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
    let onToggleSidebar: () -> Void
    let onBookmarkCurrent: () -> Void
    let onNewFolder: () -> Void
    let onNewFile: () -> Void
    let onMove: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onWarp: () -> Void
    let onCustomActions: () -> Void
    let onToggleTerminal: () -> Void

    private var moveIcon: String { isLeftToRight ? "arrow.right.circle" : "arrow.left.circle" }
    private var copyIcon: String { isLeftToRight ? "arrow.right.square" : "arrow.left.square" }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleSidebar) {
                Label("Sidebar", systemImage: "sidebar.left")
                    .foregroundStyle(showSidebar ? Color.accentColor : Color.secondary)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .help("Toggle Sidebar (⌥⌘S)")

            Button(action: onWarp) {
                Label("Jump", systemImage: "location.magnifyingglass")
            }
            .keyboardShortcut("k", modifiers: .command)
            .help("Warp — jump to folder (⌘K)")

            Divider().frame(height: 20)

            Button(action: onNewFolder) {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(action: onNewFile) {
                Label("New File", systemImage: "doc.badge.plus")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button(action: onMove) {
                Label("Move", systemImage: moveIcon)
            }
            .disabled(!canMoveOrCopy)

            Button(action: onCopy) {
                Label("Copy", systemImage: copyIcon)
            }
            .disabled(!canMoveOrCopy)

            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!canDelete)
            .keyboardShortcut(.delete, modifiers: .command)

            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            .disabled(!canRename)
            .help("Rename selected item")

            Divider().frame(height: 20)

            Button(action: onBookmarkCurrent) {
                Label("Bookmark", systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isBookmarked ? Color.accentColor : Color.secondary)
            }
            .disabled(!bookmarkEnabled)
            .help(isBookmarked ? "Remove Bookmark" : "Add to Sidebar")

            Button(action: onCustomActions) {
                Label("Actions", systemImage: "bolt.circle")
                    .foregroundStyle(Color.secondary)
            }
            .help("Manage Custom Actions")

            Button(action: onToggleTerminal) {
                Label("Terminal", systemImage: isTerminalShown ? "terminal.fill" : "terminal")
                    .foregroundStyle(isTerminalShown ? Color.accentColor : Color.secondary)
            }
            .help("Toggle command runner (⌥`)")

            Spacer()
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
