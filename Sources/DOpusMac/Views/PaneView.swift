import SwiftUI
import AppKit

struct PaneView: View {
    @ObservedObject var pane: PaneState
    let side: PaneSide
    let isActive: Bool
    let accentColor: Color
    let otherPaneLabel: String
    let onActivate: () -> Void
    let onMoveRequested: () -> Void
    let onCopyRequested: () -> Void
    let onDeleteRequested: () -> Void

    @EnvironmentObject private var customActionsModel: CustomActionsModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sidebarModel: SidebarModel
    @ObservedObject private var metadataService = SmartMetadataService.shared

    @State private var renamingItem: FileItem?
    @State private var renameText: String = ""
    @State private var folderSizeItem: FileItem? = nil
    @State private var uncompressConflicts: [String] = []
    @State private var pendingUncompressURL: URL? = nil
    @State private var showUncompressAlert = false
    @State private var dropTargetURL: URL? = nil
    @State private var isPaneDropTarget: Bool = false

    static let panelBgColor = Color(NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.14, alpha: 1)
            : NSColor(white: 0.925, alpha: 1)
    }))

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                navToolbar
                Color.primary.opacity(0.15).frame(height: 1)
                sortHeader
                Color.primary.opacity(0.15).frame(height: 1)
                fileList
                Divider()
            }
            if pane.showCommandRunner {
                CommandRunnerView(isVisible: $pane.showCommandRunner, workingDirectory: pane.currentURL)
            }
            statusBar
        }
        .contentShape(Rectangle())
        .accessibilityIdentifier("\(side.accessibilityIDPrefix)-pane")
        .accessibilityValue(isActive ? "active" : "inactive")
        .onTapGesture { onActivate() }
        .sheet(item: $renamingItem) { item in
            TextPromptSheet(
                title: "Rename",
                text: $renameText,
                confirmLabel: "Rename",
                onConfirm: { pane.rename(item: item, to: renameText); renamingItem = nil },
                onCancel: { renamingItem = nil }
            )
        }
        .sheet(item: $folderSizeItem) { item in
            FolderSizeView(folderURL: item.url, onDismiss: { folderSizeItem = nil })
        }
        .alert("File conflicts found", isPresented: $showUncompressAlert, presenting: pendingUncompressURL) { zipURL in
            Button("Overwrite") { performUncompress(url: zipURL, overwrite: true) }
            Button("Skip existing") { performUncompress(url: zipURL, overwrite: false) }
            Button("Cancel", role: .cancel) {
                uncompressConflicts = []
                pendingUncompressURL = nil
            }
        } message: { _ in
            let count = uncompressConflicts.count
            Text("\(count) file\(count == 1 ? "" : "s") already exist in the destination folder.")
        }
        .onChange(of: pane.items, perform: { newItems in
            metadataService.loadIfNeeded(for: newItems)
        })
        .onChange(of: pane.requestRename, perform: { shouldRename in
            guard shouldRename else { return }
            pane.requestRename = false
            guard let item = pane.selectedItems.first else { return }
            beginRename(item)
        })
        // ⌥` toggles the command runner from anywhere in the pane
        .background {
            Button("Toggle Command Runner") { pane.showCommandRunner.toggle() }
                .keyboardShortcut("`", modifiers: .option)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Navigation toolbar

    private var navToolbar: some View {
        HStack(spacing: 4) {
            // Back / Forward / Up
            Button(action: { onActivate(); pane.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(Color.primary)
            }
            .disabled(!pane.canGoBack)

            Button(action: { onActivate(); pane.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(Color.primary)
            }
            .disabled(!pane.canGoForward)

            Button(action: { onActivate(); pane.goUp() }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(Color.primary)
            }
            .disabled(!pane.canGoUp)

            // Breadcrumbs — scroll anchored to trailing so deepest folder is always visible
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(Array(pane.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                            if index > 0 {
                                Text("/").foregroundColor(.primary)
                            }
                            Button(crumb.label) {
                                onActivate()
                                pane.navigate(to: crumb.url)
                            }
                            .id("b\(index)")
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        if let last = pane.breadcrumbs.indices.last {
                            proxy.scrollTo("b\(last)", anchor: .trailing)
                        }
                    }
                }
                .onChange(of: pane.breadcrumbs.count, perform: { _ in
                    DispatchQueue.main.async {
                        if let last = pane.breadcrumbs.indices.last {
                            proxy.scrollTo("b\(last)", anchor: .trailing)
                        }
                    }
                })
            }

            // Loading indicator
            if pane.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            // Refresh
            Button(action: { onActivate(); pane.load() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(Color.primary)
            }
            .help("Refresh folder (⌘R)")

            // Filter field with × clear
            HStack(spacing: 3) {
                TextField("Filter…", text: $pane.filterText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(width: 92)
                    .font(.system(size: 11))
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(
                                Color.secondary.opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .onTapGesture { onActivate() }

                if !pane.filterText.isEmpty {
                    Button {
                        pane.filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Clear filter")
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Self.panelBgColor)
    }

    // MARK: - Sortable header

    private var sortHeader: some View {
        HStack(spacing: 8) {
            sortButton("Name", .name)
                .frame(minWidth: FileRowView.minimumNameWidth, maxWidth: .infinity, alignment: .leading)
            if !settings.hiddenColumns.contains("Size") {
                sortButton("Size", .size).frame(width: 74, alignment: .trailing)
            }
            if !settings.hiddenColumns.contains("Kind") {
                sortButton("Kind", .kind).frame(width: 120, alignment: .leading)
            }
            if !settings.hiddenColumns.contains("Modified") {
                sortButton("Modified", .modified).frame(width: 92, alignment: .leading)
            }
            if !settings.hiddenColumns.contains("Info") {
                sortButton("Info", .info).frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .padding(.leading, 28)
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
        .background(Self.panelBgColor)
        .contextMenu {
            Text("Columns").font(.caption)
            Divider()
            columnToggleButton("Size")
            columnToggleButton("Kind")
            columnToggleButton("Modified")
            columnToggleButton("Info")
        }
    }

    private func columnToggleButton(_ name: String) -> some View {
        Button {
            settings.toggleColumn(name)
        } label: {
            Label(
                settings.hiddenColumns.contains(name) ? "Show \(name)" : "Hide \(name)",
                systemImage: settings.hiddenColumns.contains(name) ? "eye" : "eye.slash"
            )
        }
    }

    private func sortButton(_ title: String, _ key: SortKey) -> some View {
        Button {
            onActivate()
            pane.setSort(key)
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if pane.sortKey == key {
                    Image(systemName: pane.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - File list

    private var visibleItems: [FileItem] {
        var result = pane.displayedItems
        // Info sort is deferred here because metadata loads asynchronously.
        if pane.sortKey == .info {
            result.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                let ia = metadataService.info(for: a) ?? ""
                let ib = metadataService.info(for: b) ?? ""
                if ia != ib { return pane.sortAscending ? ia < ib : ia > ib }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
        return result
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleItems, id: \.url) { item in
                    fileRow(for: item)
                    Divider()
                        .padding(.leading, 36)
                }
            }
            .padding(.vertical, 2)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityIdentifier("\(side.accessibilityIDPrefix)-pane-file-list")
        .background {
            AppKitFileDropTargetView(destinationURL: pane.currentURL, isTargeted: $isPaneDropTarget) { destination, operation, urls in
                handleDrop(destination: destination, operation: operation, externalURLs: urls)
            }
        }
        .overlay {
            if isPaneDropTarget {
                Rectangle()
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func fileRow(for item: FileItem) -> some View {
        let base = FileRowView(
            item: item,
            accentColor: accentColor,
            isSelected: pane.selection.contains(item.url),
            extraInfo: metadataService.info(for: item)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(side.accessibilityIDPrefix)-file-row-\(item.name)")
        .accessibilityLabel(item.name)
        .overlay {
            if dropTargetURL == item.url {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RowMouseEventView(
                onSelect: { select(item) },
                onOpen: { open(item) },
                isSelected: pane.selection.contains(item.url),
                getDragItems: {
                    pane.selection.contains(item.url) ? pane.selectedItems : [item]
                }
            )
        }
        .contextMenu {
            contextMenuContent(for: item)
        }

        base
            .overlay {
                AppKitFileDropTargetView(
                    destinationURL: item.isDirectory ? item.url : pane.currentURL,
                    isTargeted: item.isDirectory
                        ? Binding(
                            get: { dropTargetURL == item.url },
                            set: { isTargeted in
                                if isTargeted { dropTargetURL = item.url }
                                else if dropTargetURL == item.url { dropTargetURL = nil }
                            }
                        )
                        : $isPaneDropTarget
                ) { destination, operation, urls in
                    dropTargetURL = nil
                    return handleDrop(destination: destination, operation: operation, externalURLs: urls)
                }
            }
    }

    @ViewBuilder
    private func contextMenuContent(for item: FileItem) -> some View {
        Button("Delete", role: .destructive) { onDeleteRequested() }
        Divider()
        Button("Open") { open(item) }
        openWithMenu(for: item)
        if pane.selection.count <= 1 {
            Button("Rename…") { beginRename(item) }
        }
        Divider()
        Button("Quick Look") {
            onActivate()
            let urls = pane.selectedItems.isEmpty ? [item.url] : pane.selectedItems.map { $0.url }
            QuickLookCoordinator.shared.toggle(urls: urls)
        }
        if item.isDirectory {
            Button("Show Folder Sizes") { folderSizeItem = item }
        }
        Divider()
        Button("Duplicate") {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            duplicateItems(targets.map { $0.url })
        }
        Button("Compress") {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            compressItems(targets.map { $0.url })
        }
        if item.url.pathExtension.lowercased() == "zip" {
            Button("Uncompress") { uncompressItem(item.url) }
        }
        Divider()
        Button("Move to \(otherPaneLabel)") { onMoveRequested() }
        Button("Copy to \(otherPaneLabel)") { onCopyRequested() }
        Divider()
        Button("Copy") {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(targets.map { $0.url as NSURL })
        }
        Button("Copy Path") {
            onActivate()
            let paths = pane.selectedItems.isEmpty
                ? [item.url.path]
                : pane.selectedItems.map { $0.url.path }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
        }
        Button("Share…") {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            shareItems(targets.map { $0.url })
        }
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
        Button(sidebarModel.isBookmarked(item.url) ? "Remove Bookmark" : "Bookmark") {
            sidebarModel.toggleBookmark(item.url)
        }
        Divider()
        tagMenu(for: item)
        if !customActionsModel.actions.isEmpty {
            Divider()
            ForEach(customActionsModel.actions) { action in
                Button(action.name) {
                    let selected = pane.selectedItems
                    let targets = selected.isEmpty ? [item] : selected
                    action.run(selectedFiles: targets.map { $0.url }, workingDirectory: pane.currentURL)
                }
            }
        }
    }

    @ViewBuilder
    private func openWithMenu(for item: FileItem) -> some View {
        Menu("Open With…") {
            let apps = Array(NSWorkspace.shared.urlsForApplications(toOpen: item.url).prefix(8))
            if apps.isEmpty {
                Text("No applications found")
            } else {
                ForEach(apps, id: \.self) { appURL in
                    Button(appURL.deletingPathExtension().lastPathComponent) {
                        NSWorkspace.shared.open(
                            [item.url], withApplicationAt: appURL,
                            configuration: NSWorkspace.OpenConfiguration(),
                            completionHandler: nil
                        )
                    }
                }
            }
            Divider()
            Button("Other…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                panel.message = "Choose an application to open \"\(item.name)\""
                if panel.runModal() == .OK, let appURL = panel.url {
                    NSWorkspace.shared.open(
                        [item.url], withApplicationAt: appURL,
                        configuration: NSWorkspace.OpenConfiguration(),
                        completionHandler: nil
                    )
                }
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            Text(statusText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .accessibilityIdentifier("\(side.accessibilityIDPrefix)-pane-status")
            if let extraInfo = singleSelectionMetadata {
                Text("·")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Text(extraInfo)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if let error = pane.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Self.panelBgColor)
    }

    private var statusText: String {
        PaneStatusFormatter.text(
            itemCount: pane.displayedItems.count,
            selectedCount: pane.selection.count,
            selectedBytes: pane.selectedFileItems.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        )
    }

    private var singleSelectionMetadata: String? {
        guard pane.selection.count == 1,
              let url = pane.selection.first,
              let item = pane.items.first(where: { $0.url == url }),
              !item.isDirectory
        else { return nil }
        return metadataService.info(for: item)
    }

    // MARK: - Actions

    private func select(_ item: FileItem) {
        onActivate()
        pane.select(item, from: pane.displayedItems, mode: currentSelectionMode)
    }

    private var currentSelectionMode: PaneSelectionMode {
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.shift)   { return .range }
        if flags.contains(.command) { return .toggle }
        return .replace
    }

    private func open(_ item: FileItem) {
        onActivate()
        if item.isDirectory {
            pane.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    private func beginRename(_ item: FileItem) {
        renameText = item.name
        renamingItem = item
    }

    // MARK: - Tag management

    @ViewBuilder
    private func tagMenu(for item: FileItem) -> some View {
        Menu("Tag") {
            tagButton("Red", item: item)
            tagButton("Orange", item: item)
            tagButton("Yellow", item: item)
            tagButton("Green", item: item)
            tagButton("Blue", item: item)
            tagButton("Purple", item: item)
            tagButton("Grey", item: item)
            if !item.tags.isEmpty {
                Divider()
                Button("Remove All Tags") {
                    let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
                    for t in targets { applyTags([], to: t.url) }
                    pane.load()
                }
            }
        }
    }

    private func tagButton(_ tagName: String, item: FileItem) -> some View {
        Button {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            for target in targets {
                var tags = (try? target.url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? target.tags
                if tags.contains(tagName) {
                    tags.removeAll { $0 == tagName }
                } else {
                    tags.append(tagName)
                }
                applyTags(tags, to: target.url)
            }
            pane.load()
        } label: {
            Label(tagName, systemImage: item.tags.contains(tagName) ? "circle.fill" : "circle")
        }
    }

    private func applyTags(_ tags: [String], to url: URL) {
        // NSURL Obj-C API avoids the macOS 26+ restriction on URLResourceValues.tagNames setter.
        try? (url as NSURL).setResourceValue(tags as NSArray, forKey: .tagNamesKey)
    }

    // MARK: - File operations

    private func duplicateItems(_ urls: [URL]) {
        guard let dir = pane.currentURL else { return }
        Task.detached {
            for url in urls {
                let base = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension
                var dest = dir.appendingPathComponent(ext.isEmpty ? "\(base) copy" : "\(base) copy.\(ext)")
                var n = 2
                while FileManager.default.fileExists(atPath: dest.path) {
                    let name = ext.isEmpty ? "\(base) copy \(n)" : "\(base) copy \(n).\(ext)"
                    dest = dir.appendingPathComponent(name)
                    n += 1
                }
                try? FileManager.default.copyItem(at: url, to: dest)
            }
            await MainActor.run {
                pane.load()
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": dir])
            }
        }
    }

    private func compressItems(_ urls: [URL]) {
        guard let dir = pane.currentURL else { return }
        let archiveName = urls.count == 1
            ? urls[0].deletingPathExtension().lastPathComponent
            : "Archive"
        var destPath = dir.appendingPathComponent(archiveName + ".zip").path
        var n = 2
        while FileManager.default.fileExists(atPath: destPath) {
            destPath = dir.appendingPathComponent(archiveName + " \(n).zip").path
            n += 1
        }
        let names = urls.map { $0.lastPathComponent }
        let finalDestPath = destPath
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-r", finalDestPath] + names
            process.currentDirectoryURL = dir
            try? process.run()
            process.waitUntilExit()
            await MainActor.run {
                pane.load()
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": dir])
            }
        }
    }

    private func uncompressItem(_ url: URL) {
        let dir = url.deletingLastPathComponent()
        Task.detached {
            // List zip contents to detect conflicts before extracting
            let listProcess = Process()
            listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            listProcess.arguments = ["-Z1", url.path]
            let pipe = Pipe()
            listProcess.standardOutput = pipe
            listProcess.standardError = Pipe()
            try? listProcess.run()
            listProcess.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let entries = output.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasSuffix("/") }

            let conflicts = entries.filter { entry in
                FileManager.default.fileExists(atPath: dir.appendingPathComponent(entry).path)
            }

            await MainActor.run {
                if conflicts.isEmpty {
                    Task.detached {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                        process.arguments = ["-n", url.path, "-d", dir.path]
                        try? process.run()
                        process.waitUntilExit()
                        await MainActor.run { pane.load() }
                    }
                } else {
                    uncompressConflicts = conflicts
                    pendingUncompressURL = url
                    showUncompressAlert = true
                }
            }
        }
    }

    private func performUncompress(url: URL, overwrite: Bool) {
        let dir = url.deletingLastPathComponent()
        uncompressConflicts = []
        pendingUncompressURL = nil
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = [overwrite ? "-o" : "-n", url.path, "-d", dir.path]
            try? process.run()
            process.waitUntilExit()
            await MainActor.run {
                pane.load()
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": dir])
            }
        }
    }

    // MARK: - Drag and drop

    @discardableResult
    private func handleDrop(destination: URL, operation: NSDragOperation, externalURLs: [URL]) -> Bool {
        let sessionItems = DragSession.shared.items
        let sourceURL = DragSession.shared.sourceDirectoryURL
        let isMove = operation.contains(.move) && !operation.contains(.copy)
        DragSession.shared.clear()

        if !sessionItems.isEmpty {
            // Within-app drag: full FileItem info is available in DragSession.
            let draggedURLs = Set(sessionItems.map { $0.url })
            // Skip no-op: dropping into the same directory, or a folder onto itself.
            guard destination != sourceURL, !draggedURLs.contains(destination) else { return false }

            Task.detached {
                let result = FileOperationService.moveOrCopy(
                    files: sessionItems, to: destination, isMove: isMove
                )
                await MainActor.run {
                    pane.load()
                    if let src = sourceURL {
                        NotificationCenter.default.post(
                            name: .paneContentsChanged, object: nil,
                            userInfo: ["url": src]
                        )
                    }
                    if let error = result.lastError {
                        pane.errorMessage = error
                    }
                }
            }
        } else {
            // External drag (from Finder or another app) — always copy, never move.
            let fileItems = externalURLs.map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                return FileItem(
                    id: url, name: url.lastPathComponent, url: url,
                    isDirectory: isDir, isVolume: false, isRemovable: false,
                    size: nil, kind: "", modified: nil, tags: []
                )
            }
            guard !fileItems.isEmpty else { return false }
            Task.detached {
                let result = FileOperationService.moveOrCopy(files: fileItems, to: destination, isMove: false)
                await MainActor.run {
                    pane.load()
                    if let error = result.lastError {
                        pane.errorMessage = error
                    }
                }
            }
        }
        return true
    }

    private func shareItems(_ urls: [URL]) {
        let picker = NSSharingServicePicker(items: urls as [Any])
        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
}

private struct AppKitFileDropTargetView: NSViewRepresentable {
    let destinationURL: URL?
    @Binding var isTargeted: Bool
    let onDrop: (URL, NSDragOperation, [URL]) -> Bool

    func makeNSView(context: Context) -> AppKitFileDropTargetNSView {
        let view = AppKitFileDropTargetNSView()
        view.destinationURL = destinationURL
        view.onTargetedChange = { isTargeted = $0 }
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: AppKitFileDropTargetNSView, context: Context) {
        nsView.destinationURL = destinationURL
        nsView.onTargetedChange = { isTargeted = $0 }
        nsView.onDrop = onDrop
    }
}

private final class AppKitFileDropTargetNSView: NSView {
    var destinationURL: URL?
    var onTargetedChange: ((Bool) -> Void)?
    var onDrop: ((URL, NSDragOperation, [URL]) -> Bool)?

    private var currentOperation: NSDragOperation = []

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
        _ = updateOperation(for: sender)
        return currentOperation != []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        _ = updateOperation(for: sender)
        guard let destinationURL, currentOperation != [] else {
            clearTarget()
            return false
        }
        let urls = pasteboardFileURLs(sender.draggingPasteboard)
        let accepted = onDrop?(destinationURL, currentOperation, urls) ?? false
        clearTarget()
        return accepted
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        clearTarget()
    }

    private func updateOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard destinationURL != nil else {
            clearTarget()
            return []
        }

        if !DragSession.shared.items.isEmpty {
            currentOperation = requestedLocalOperation(in: sender)
            DragSession.shared.setCopyIntent(currentOperation == .copy)
        } else {
            currentOperation = .copy
        }

        onTargetedChange?(currentOperation != [])
        return currentOperation
    }

    private func requestedLocalOperation(in sender: NSDraggingInfo) -> NSDragOperation {
        if DragSession.isOptionKeyPressed {
            return .copy
        }

        let sourceMask = sender.draggingSourceOperationMask
        if sourceMask.contains(.copy) && !sourceMask.contains(.move) {
            return .copy
        }
        if sourceMask.contains(.move) && !sourceMask.contains(.copy) {
            return .move
        }
        if isOptionPressed(in: sender) {
            return .copy
        }
        return .move
    }

    private func isOptionPressed(in sender: NSDraggingInfo) -> Bool {
        let currentFlags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
        if currentFlags.contains(.option) { return true }
        if DragSession.isOptionKeyPressed { return true }
        return false
    }

    private func pasteboardFileURLs(_ pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] ?? []
        return urls.map { $0 as URL }
    }

    private func clearTarget() {
        currentOperation = []
        onTargetedChange?(false)
    }
}
