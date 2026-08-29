import SwiftUI
import AppKit

struct SidebarView: View {
    static let defaultWidth: CGFloat = 180
    static let minWidth: CGFloat = 120
    static let maxWidth: CGFloat = 320
    static let cornerRadius: CGFloat = 8

    @ObservedObject var model: SidebarModel
    @EnvironmentObject private var settings: AppSettings
    let selectedTags: Set<String>
    let onNavigate: (URL) -> Void
    let onTagSelected: (String, Bool) -> Void
    @StateObject private var menuObserver = SidebarMenuObserver()
    @State private var hoveredURL: URL? = nil
    @State private var renamingBookmark: URL? = nil
    @State private var renameBookmarkText = ""
    @State private var pendingShellScript: URL? = nil
    @State private var isFolderDropTargeted = false
    @State private var showConnectToServer = false
    @State private var connectAddress = "smb://"
    @State private var connectError: String? = nil

    // MARK: - Visible places (filtered by settings)

    private var visiblePlaces: [(name: String, url: URL, icon: String)] {
        model.systemLocations.filter { settings.enabledPlaces.contains($0.name) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Places section
                if settings.showSidebarPlaces && !visiblePlaces.isEmpty {
                    sectionHeader("Places")
                    ForEach(visiblePlaces, id: \.name) { loc in
                        placeRow(name: loc.name, url: loc.url, icon: loc.icon)
                    }
                }

                // User bookmarks
                if !model.bookmarks.isEmpty {
                    sectionHeader("Bookmarks")
                    VStack(spacing: 0) {
                        ForEach(model.bookmarks, id: \.self) { url in
                            bookmarkRow(url: url)
                        }
                    }
                }

                // Recents section
                if settings.showSidebarRecents && !model.recentURLs.isEmpty {
                    sectionHeader("Recents")
                    ForEach(model.recentURLs, id: \.self) { url in
                        recentRow(url: url)
                    }
                    Button {
                        model.clearRecents()
                    } label: {
                        Text("Clear Recents")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }

                if !model.tags.isEmpty {
                    sectionHeader("Tags")
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.tags) { tag in
                            tagRow(tag)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if settings.showNetworkSection {
                    sectionHeader("Network")
                    connectToServerRow
                }
                Spacer(minLength: 12)
            }
        }
        .background(sidebarBgColor)
        .clipShape(sidebarShape)
        .overlay(
            sidebarShape
                .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
        )
        .overlay {
            ZStack {
                SidebarFolderDropTargetView(isTargeted: $isFolderDropTargeted) { urls in
                    model.addFolderBookmarks(urls) > 0
                }
                if isFolderDropTargeted {
                    sidebarShape
                        .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { renamingBookmark != nil },
            set: { if !$0 { renamingBookmark = nil } }
        )) {
            if let url = renamingBookmark {
                TextPromptSheet(
                    title: "Rename Bookmark",
                    text: $renameBookmarkText,
                    confirmLabel: "Rename",
                    onConfirm: {
                        model.renameBookmark(url, to: renameBookmarkText)
                        renamingBookmark = nil
                    },
                    onCancel: { renamingBookmark = nil }
                )
            }
        }
        .alert("Execute Shell Script?", isPresented: Binding(
            get: { pendingShellScript != nil },
            set: { if !$0 { pendingShellScript = nil } }
        ), presenting: pendingShellScript) { scriptURL in
            Button("Execute") {
                executeShellScript(scriptURL)
                pendingShellScript = nil
            }
            Button("Cancel", role: .cancel) { pendingShellScript = nil }
        } message: { scriptURL in
            Text("\u{201C}\(scriptURL.lastPathComponent)\u{201D} is a shell script and could modify or delete files. Run it?")
        }
        .sheet(isPresented: $showConnectToServer) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect to Server")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Server Address:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("smb://server/share", text: $connectAddress)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { connectToServer() }
                }
                if let err = connectError {
                    Text(err).font(.system(size: 11)).foregroundStyle(.red)
                }
                Text("macOS will prompt for credentials if required. The mounted share will appear in /Volumes/.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { showConnectToServer = false; connectError = nil }
                    Button("Connect") { connectToServer() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(connectAddress.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 400)
        }
        .onAppear { menuObserver.startObserving() }
        .onDisappear { menuObserver.stopObserving() }
    }

    private func executeShellScript(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", url.path]
        try? process.run()
    }

    private var sidebarBgColor: Color {
        if let themed = settings.appColorScheme.panelBackground { return themed }
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.18, alpha: 1)
                : NSColor(white: 0.955, alpha: 1)
        }))
    }

    private var sidebarShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    // MARK: - Places row

    private func placeRow(name: String, url: URL, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(Color.accentColor.opacity(0.7))
            Text(name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(hoveredURL == url || menuObserver.contextMenuURL == url ? Color.primary.opacity(0.08) : Color.clear)
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            hoveredURL = isHovering ? url : nil
            menuObserver.setHovered(isHovering ? url : nil)
        }
        .onTapGesture { onNavigate(url) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Recents row

    private func recentRow(url: URL) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(url.lastPathComponent)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(hoveredURL == url || menuObserver.contextMenuURL == url ? Color.primary.opacity(0.08) : Color.clear)
        }
        .contentShape(Rectangle())
        .onHover { isHovering in
            hoveredURL = isHovering ? url : nil
            menuObserver.setHovered(isHovering ? url : nil)
        }
        .onTapGesture { onNavigate(url) }
        .contextMenu {
            Button("Remove from Recents") {
                // Remove by filtering
                let remaining = model.recentURLs.filter { $0 != url }
                if remaining.count != model.recentURLs.count {
                    for u in model.recentURLs where !remaining.contains(u) {
                        // re-record all except removed
                        _ = u
                    }
                    // Rebuild by recording all remaining in reverse order
                    model.clearRecents()
                    for u in remaining.reversed() { model.recordVisit(u) }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Bookmark row

    private func bookmarkRow(url: URL) -> some View {
        let name = model.displayName(for: url)
        let resolved = (try? URL(resolvingAliasFileAt: url)) ?? url
        let isDir = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        let iconName = isDir ? "folder.fill" : "doc.fill"
        return HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(Color.accentColor.opacity(0.7))
            Text(name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 2)
            Button {
                model.removeBookmark(url)
                if hoveredURL == url { hoveredURL = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .opacity(hoveredURL == url ? 1 : 0)
            .animation(.easeInOut(duration: 0.12), value: hoveredURL == url)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(hoveredURL == url || menuObserver.contextMenuURL == url ? Color.primary.opacity(0.08) : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let resolved = (try? URL(resolvingAliasFileAt: url)) ?? url
            let isDir = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            if isDir {
                onNavigate(resolved)
            } else if resolved.pathExtension.lowercased() == "sh" {
                pendingShellScript = resolved
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        .onHover { isHovering in
            hoveredURL = isHovering ? url : nil
            menuObserver.setHovered(isHovering ? url : nil)
        }
        .contextMenu {
            Button("Rename\u{2026}") {
                renameBookmarkText = model.displayName(for: url)
                renamingBookmark = url
            }
            if let index = model.bookmarks.firstIndex(of: url) {
                if index > 0 {
                    Button("Move Up") {
                        model.moveBookmark(from: IndexSet(integer: index), to: index - 1)
                    }
                }
                if index < model.bookmarks.count - 1 {
                    Button("Move Down") {
                        model.moveBookmark(from: IndexSet(integer: index), to: index + 2)
                    }
                }
            }
            Divider()
            Button("Remove Bookmark") { model.removeBookmark(url) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
    }

    private func tagRow(_ tag: FinderTag) -> some View {
        let isSelected = selectedTags.contains {
            FinderTagMetadata.matches(itemTag: tag.name, selectedTag: $0)
        }

        return Button {
            let isCommandClick = NSApp.currentEvent?.modifierFlags.contains(.command) == true
            onTagSelected(tag.name, isCommandClick)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(finderTagColor(tag.name))
                    .frame(width: 9, height: 9)
                Text(tag.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(tag.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.24) : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sidebar-tag-\(tag.name)")
        .accessibilityLabel(tag.name)
        .accessibilityValue(isSelected ? "selected" : "unselected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func finderTagColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "red":           return .red
        case "orange":        return .orange
        case "yellow":        return .yellow
        case "green":         return .green
        case "blue":          return .blue
        case "purple":        return .purple
        case "gray", "grey":  return .gray
        default:              return .accentColor
        }
    }

    // MARK: - Network section

    private var connectToServerRow: some View {
        Button {
            connectAddress = "smb://"
            connectError = nil
            showConnectToServer = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 11))
                    .frame(width: 16)
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                Text("Connect to Server\u{2026}")
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func connectToServer() {
        let raw = connectAddress.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: raw), url.scheme != nil else {
            connectError = "Enter a valid server address, e.g. smb://server/share"
            return
        }
        connectError = nil
        showConnectToServer = false
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Sidebar menu observer (context-menu highlight lock)

private final class SidebarMenuObserver: ObservableObject {
    @Published var contextMenuURL: URL? = nil
    private var hoveredURL: URL? = nil
    private var beganToken: Any?
    private var endedToken: Any?

    func setHovered(_ url: URL?) { hoveredURL = url }

    func startObserving() {
        beganToken = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.contextMenuURL = self?.hoveredURL
        }
        endedToken = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.contextMenuURL = nil
        }
    }

    func stopObserving() {
        if let t = beganToken { NotificationCenter.default.removeObserver(t); beganToken = nil }
        if let t = endedToken { NotificationCenter.default.removeObserver(t); endedToken = nil }
    }

    deinit {
        if let t = beganToken { NotificationCenter.default.removeObserver(t) }
        if let t = endedToken { NotificationCenter.default.removeObserver(t) }
    }
}

// MARK: - Sidebar resize handle

final class SidebarResizeNSView: NSView {
    var isDragging = false
    var currentWidth: CGFloat = SidebarView.defaultWidth
    var onWidthChange: (CGFloat) -> Void = { _ in }

    private var dragStartWindowX: CGFloat = 0
    private var dragStartWidth: CGFloat = 0
    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self, userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { NSCursor.resizeLeftRight.set() }

    override func mouseExited(with event: NSEvent) {
        guard !isDragging else { return }
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartWindowX = event.locationInWindow.x
        dragStartWidth = currentWidth
        NSCursor.resizeLeftRight.push()
    }

    override func mouseDragged(with event: NSEvent) {
        let delta = event.locationInWindow.x - dragStartWindowX
        let newWidth = (dragStartWidth + delta)
            .clamped(to: SidebarView.minWidth...SidebarView.maxWidth)
        onWidthChange(newWidth)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        NSCursor.pop()
    }
}

struct SidebarResizeHandle: NSViewRepresentable {
    @Binding var width: CGFloat

    func makeNSView(context: Context) -> SidebarResizeNSView {
        let v = SidebarResizeNSView()
        v.currentWidth = width
        v.onWidthChange = { newWidth in
            width = newWidth
            UserDefaults.standard.set(newWidth, forKey: "sidebarWidth")
        }
        return v
    }

    func updateNSView(_ nsView: SidebarResizeNSView, context: Context) {
        if !nsView.isDragging { nsView.currentWidth = width }
        nsView.onWidthChange = { newWidth in
            width = newWidth
            UserDefaults.standard.set(newWidth, forKey: "sidebarWidth")
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Sidebar folder drop target

private struct SidebarFolderDropTargetView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Bool

    func makeNSView(context: Context) -> SidebarFolderDropTargetNSView {
        let view = SidebarFolderDropTargetNSView()
        view.onTargetedChange = { isTargeted = $0 }
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: SidebarFolderDropTargetNSView, context: Context) {
        nsView.onTargetedChange = { isTargeted = $0 }
        nsView.onDrop = onDrop
    }
}

private final class SidebarFolderDropTargetNSView: NSView {
    var onTargetedChange: ((Bool) -> Void)?
    var onDrop: (([URL]) -> Bool)?

    private var currentFolderURLs: [URL] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        switch window?.currentEvent?.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return nil
        default:
            return super.hitTest(point)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearTarget()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        updateOperation(for: sender) != []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        _ = updateOperation(for: sender)
        guard !currentFolderURLs.isEmpty else {
            clearTarget()
            return false
        }

        let accepted = onDrop?(currentFolderURLs) ?? false
        clearTarget()
        DragSession.shared.clear()
        return accepted
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        clearTarget()
    }

    private func updateOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let folderURLs = folderURLs(from: sender)
        guard !folderURLs.isEmpty else {
            clearTarget()
            return []
        }

        currentFolderURLs = folderURLs
        onTargetedChange?(true)
        return .copy
    }

    private func folderURLs(from sender: NSDraggingInfo) -> [URL] {
        if !DragSession.shared.items.isEmpty {
            return folderURLs(from: DragSession.shared.items.map(\.url))
        }

        guard sender.draggingSource == nil else { return [] }
        return folderURLs(from: pasteboardFileURLs(sender.draggingPasteboard))
    }

    private func folderURLs(from urls: [URL]) -> [URL] {
        var seenPaths: Set<String> = []
        return urls.compactMap { url in
            let resolved = (try? URL(resolvingAliasFileAt: url)) ?? url
            let isDirectory = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            guard isDirectory else { return nil }
            let standardizedPath = resolved.standardizedFileURL.path
            guard seenPaths.insert(standardizedPath).inserted else { return nil }
            return resolved
        }
    }

    private func pasteboardFileURLs(_ pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] ?? []
        return urls.map { $0 as URL }
    }

    private func clearTarget() {
        currentFolderURLs = []
        onTargetedChange?(false)
    }
}
