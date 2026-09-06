import SwiftUI
import AppKit

struct PaneView: View {
    @ObservedObject var pane: PaneState
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

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sidebarModel: SidebarModel
    @ObservedObject private var metadataService = SmartMetadataService.shared

    @State private var renamingItem: FileItem?
    @State private var renameText: String = ""
    @State private var showGoToPath: Bool = false
    @State private var goToPathText: String = ""
    @StateObject private var typeAhead = TypeAheadController()
    @State private var typeBuffer: String = ""
    @State private var typeBufferTimer: Timer? = nil
    @State private var typeAheadScrollURL: URL? = nil
    @FocusState private var filterFocused: Bool
    @State private var folderSizeItem: FileItem? = nil
    @State private var propertiesItem: FileItem? = nil
    @State private var pendingShellScript: FileItem? = nil
    @State private var uncompressConflicts: [String] = []
    @State private var pendingUncompressURL: URL? = nil
    @State private var showUncompressAlert = false
    @State private var dropTargetURL: URL? = nil
    @State private var isPaneDropTarget: Bool = false
    @State private var pendingDropFiles: [FileItem] = []
    @State private var pendingDropDest: URL? = nil
    @State private var pendingDropIsMove: Bool = false
    @State private var pendingDropSourceURL: URL? = nil
    @State private var showDropConflictAlert = false

    private var panelBgColor: Color {
        if let themed = settings.appColorScheme.panelBackground { return themed }
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.14, alpha: 1)
                : NSColor(white: 0.925, alpha: 1)
        }))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    navToolbar
                    Color.primary.opacity(0.15).frame(height: 1)
                    sortHeader(availableWidth: geometry.size.width)
                    Color.primary.opacity(0.15).frame(height: 1)
                    if pane.isInSearchMode { searchBanner }
                    fileList(availableWidth: geometry.size.width)
                }
                if pane.showCommandRunner {
                    CommandRunnerView(isVisible: $pane.showCommandRunner, workingDirectory: pane.currentURL)
                }
                statusBar
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
        .sheet(isPresented: $showGoToPath) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Go to Folder").font(.headline)
                TextField("/", text: $goToPathText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { commitGoToPath() }
                HStack {
                    Spacer()
                    Button("Cancel") { showGoToPath = false }
                    Button("Go") { commitGoToPath() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(goToPathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 440)
        }
        .sheet(item: $folderSizeItem) { item in
            FolderSizeView(folderURL: item.url, onDismiss: { folderSizeItem = nil })
        }
        .sheet(item: $propertiesItem) { item in
            PropertiesView(item: item, onDismiss: { propertiesItem = nil })
        }
        .alert("Execute Shell Script?", isPresented: Binding(
            get: { pendingShellScript != nil },
            set: { if !$0 { pendingShellScript = nil } }
        ), presenting: pendingShellScript) { script in
            Button("Execute") { executeShellScript(script.url); pendingShellScript = nil }
            Button("Cancel", role: .cancel) { pendingShellScript = nil }
        } message: { script in
            Text("\u{201C}\(script.name)\u{201D} is a shell script and could modify or delete files. Run it?")
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
        .alert("Items Already Exist", isPresented: $showDropConflictAlert) {
            Button("Overwrite") { resolveDropConflict(.overwrite) }
            Button("Skip") { resolveDropConflict(.skip) }
            Button("Keep Both") { resolveDropConflict(.rename) }
            Button("Cancel", role: .cancel) { clearDropConflictState() }
        } message: {
            Text(dropConflictAlertMessage)
        }
        .onChange(of: pane.items, perform: { newItems in
            metadataService.loadIfNeeded(for: newItems)
        })
        .onChange(of: pane.filterText, perform: { newValue in
            if newValue.isEmpty { pane.endDeepSearch() }
        })
        .onChange(of: pane.requestGetInfo, perform: { newValue in
            guard newValue else { return }
            pane.requestGetInfo = false
            guard let item = pane.selectedItems.first else { return }
            propertiesItem = item
        })
        .onChange(of: pane.requestFocusFilter, perform: { newValue in
            guard newValue else { return }
            pane.requestFocusFilter = false
            filterFocused = true
        })
        .onChange(of: pane.requestRename, perform: { shouldRename in
            guard shouldRename else { return }
            pane.requestRename = false
            guard let item = pane.selectedItems.first else { return }
            beginRename(item)
        })
        .onChange(of: pane.requestGoToPath, perform: { should in
            guard should else { return }
            pane.requestGoToPath = false
            goToPathText = pane.currentURL?.path ?? ""
            showGoToPath = true
        })
        .onAppear {
            typeAhead.isActive = isActive
            typeAhead.install { char in handleTypeAhead(char: char) }
        }
        .onDisappear { typeAhead.remove() }
        .onChange(of: isActive) { typeAhead.isActive = $0 }
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
                    .focused($filterFocused)
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

                    Button {
                        onActivate()
                        if pane.isInSearchMode {
                            pane.endDeepSearch()
                        } else {
                            pane.beginDeepSearch(query: pane.filterText)
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(pane.isInSearchMode ? Color.accentColor : Color.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(pane.isInSearchMode ? "Exit subfolder search" : "Search subfolders (Spotlight)")
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(panelBgColor)
    }

    // MARK: - Sortable header

    private func sortHeader(availableWidth: CGFloat) -> some View {
        let columnWidths = constrainedColumnWidths(availableWidth: availableWidth)

        return HStack(spacing: FileColumnLayout.nameColumnGap) {
            sortHeaderLabel("Name", .name, alignment: .leading)
                .frame(minWidth: FileRowView.minimumNameWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { setSort(.name) }
            metadataHeaderColumns(columnWidths: columnWidths, availableWidth: availableWidth)
        }
        .padding(.horizontal, FileColumnLayout.horizontalPadding)
        .padding(.leading, settings.hiddenColumns.contains("Icon") ? 0 : FileColumnLayout.nameLeadingPadding)
        .frame(height: FileColumnLayout.headerHeight)
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
        .background(panelBgColor)
        .contextMenu {
            Text("Columns").font(.caption)
            Divider()
            columnToggleButton("Icon")
            columnToggleButton("Size")
            columnToggleButton("Kind")
            columnToggleButton("Modified")
            columnToggleButton("Info")
            Divider()
            Button("Reset Column Widths") { settings.resetColumnWidths(for: side) }
            Divider()
            ForEach(settings.columnOrder.indices, id: \.self) { idx in
                let col = settings.columnOrder[idx]
                Menu("\(col) column") {
                    if idx > 0 {
                        Button("Move Left") {
                            withAnimation { settings.columnOrder.swapAt(idx, idx - 1) }
                        }
                    }
                    if idx < settings.columnOrder.count - 1 {
                        Button("Move Right") {
                            withAnimation { settings.columnOrder.swapAt(idx, idx + 1) }
                        }
                    }
                }
            }
        }
    }

    private func metadataHeaderColumns(
        columnWidths: [String: CGFloat],
        availableWidth: CGFloat
    ) -> some View {
        let visibleColumns = self.visibleColumns

        return HStack(spacing: 0) {
            ForEach(Array(visibleColumns.enumerated()), id: \.element) { index, col in
                headerColumn(
                    col,
                    columnIndex: index,
                    columnWidths: columnWidths,
                    availableWidth: availableWidth
                )
            }
        }
    }

    private func headerColumn(
        _ col: String,
        columnIndex: Int,
        columnWidths: [String: CGFloat],
        availableWidth: CGFloat
    ) -> some View {
        let width = columnWidth(for: col, columnWidths: columnWidths)
        let sortKey = columnSortKey(for: col)

        return HStack(spacing: 0) {
            ColumnResizeHandle(
                currentWidth: width,
                resizesFromLeadingEdge: true,
                onResize: { newWidth in
                    resizeDivider(
                        beforeColumnAt: columnIndex,
                        to: newWidth,
                        availableWidth: availableWidth,
                        currentColumnWidths: columnWidths
                    )
                }
            )
            .frame(width: FileColumnLayout.resizeHandleWidth, height: FileColumnLayout.resizeHandleHeight)
            .id("\(side.rawValue)-\(col)-resize-handle")

            sortHeaderLabel(col, sortKey, alignment: columnAlignment(for: col))
                .padding(.leading, FileColumnLayout.contentLeadingInset)
                .frame(width: width, height: FileColumnLayout.headerHeight, alignment: columnAlignment(for: col))
                .contentShape(Rectangle())
                .onTapGesture { setSort(sortKey) }
                .clipped()
        }
    }

    private func columnSortKey(for name: String) -> SortKey {
        switch name {
        case "Size": return .size
        case "Kind": return .kind
        case "Modified": return .modified
        case "Info": return .info
        default: return .name
        }
    }

    private func columnWidth(for name: String) -> CGFloat {
        settings.columnWidth(for: name, in: side)
    }

    private func columnWidth(for name: String, columnWidths: [String: CGFloat]) -> CGFloat {
        columnWidths[name, default: FileColumnLayout.defaultWidth(for: name)]
    }

    private func resizeDivider(
        beforeColumnAt index: Int,
        to width: CGFloat,
        availableWidth: CGFloat,
        currentColumnWidths: [String: CGFloat]
    ) {
        let visibleColumns = self.visibleColumns
        guard visibleColumns.indices.contains(index) else { return }

        let name = visibleColumns[index]
        var updatedColumnWidths = currentColumnWidths

        if index == 0 {
            let maxWidth = maximumFirstMetadataColumnWidth(
                for: name,
                availableWidth: availableWidth,
                currentColumnWidths: currentColumnWidths
            )
            updatedColumnWidths[name] = min(max(width, FileColumnLayout.minWidth), maxWidth)
        } else {
            let previousName = visibleColumns[index - 1]
            let currentWidth = columnWidth(for: name, columnWidths: currentColumnWidths)
            let previousWidth = columnWidth(for: previousName, columnWidths: currentColumnWidths)

            let lowerBound = max(
                FileColumnLayout.minWidth,
                currentWidth - (FileColumnLayout.maxWidth - previousWidth)
            )
            let upperBound = min(
                FileColumnLayout.maxWidth,
                currentWidth + (previousWidth - FileColumnLayout.minWidth)
            )
            let clampedWidth = min(max(width, lowerBound), upperBound)
            let delta = clampedWidth - currentWidth

            updatedColumnWidths[name] = clampedWidth
            updatedColumnWidths[previousName] = previousWidth - delta
        }

        settings.setColumnWidths(updatedColumnWidths, for: side)
    }

    private var visibleColumns: [String] {
        settings.columnOrder.filter { !settings.hiddenColumns.contains($0) }
    }

    private func constrainedColumnWidths(availableWidth: CGFloat) -> [String: CGFloat] {
        let visibleColumns = self.visibleColumns
        guard !visibleColumns.isEmpty else {
            return settings.columnWidths(for: side)
        }

        var widths = settings.columnWidths(for: side)
        for column in visibleColumns {
            widths[column] = FileColumnLayout.clampedWidth(
                widths[column, default: FileColumnLayout.defaultWidth(for: column)]
            )
        }

        var overflow = visibleColumns.reduce(CGFloat(0)) { total, column in
            total + widths[column, default: FileColumnLayout.defaultWidth(for: column)]
        } - metadataColumnBudget(availableWidth: availableWidth, visibleColumnCount: visibleColumns.count)

        while overflow > 0.5 {
            var reducedAnyColumn = false
            for column in visibleColumns.sorted(by: {
                widths[$0, default: FileColumnLayout.minWidth] > widths[$1, default: FileColumnLayout.minWidth]
            }) {
                let currentWidth = widths[column, default: FileColumnLayout.minWidth]
                let reducibleWidth = currentWidth - FileColumnLayout.minWidth
                guard reducibleWidth > 0 else { continue }

                let reduction = min(reducibleWidth, overflow)
                widths[column] = currentWidth - reduction
                overflow -= reduction
                reducedAnyColumn = true

                if overflow <= 0.5 {
                    break
                }
            }

            if !reducedAnyColumn {
                break
            }
        }

        return widths
    }

    private func maximumFirstMetadataColumnWidth(
        for name: String,
        availableWidth: CGFloat,
        currentColumnWidths: [String: CGFloat]
    ) -> CGFloat {
        let visibleColumns = self.visibleColumns
        let budget = metadataColumnBudget(
            availableWidth: availableWidth,
            visibleColumnCount: visibleColumns.count
        )
        let otherColumnWidth = visibleColumns
            .filter { $0 != name }
            .reduce(CGFloat(0)) { total, column in
                total + FileColumnLayout.clampedWidth(
                    currentColumnWidths[column, default: FileColumnLayout.defaultWidth(for: column)]
                )
            }
        let availableWidth = budget - otherColumnWidth

        return min(FileColumnLayout.maxWidth, max(FileColumnLayout.minWidth, availableWidth))
    }

    private func metadataColumnBudget(availableWidth: CGFloat, visibleColumnCount: Int) -> CGFloat {
        guard visibleColumnCount > 0 else { return 0 }

        let iconSpace = settings.hiddenColumns.contains("Icon") ? 0 : FileColumnLayout.nameLeadingPadding
        let reservedWidth = (FileColumnLayout.horizontalPadding * 2)
            + iconSpace
            + FileRowView.minimumNameWidth
            + FileColumnLayout.nameColumnGap
            + (CGFloat(visibleColumnCount) * FileColumnLayout.resizeHandleWidth)
        let minimumColumnTotal = CGFloat(visibleColumnCount) * FileColumnLayout.minWidth

        return max(minimumColumnTotal, availableWidth - reservedWidth)
    }

    private func columnAlignment(for name: String) -> Alignment {
        switch name {
        case "Size", "Info": return .trailing
        default: return .leading
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

    private func sortHeaderLabel(_ title: String, _ key: SortKey, alignment: Alignment) -> some View {
        HStack(spacing: 2) {
            Text(title)
            if pane.sortKey == key {
                Image(systemName: pane.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    private func setSort(_ key: SortKey) {
        onActivate()
        pane.setSort(key)
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

    private func fileList(availableWidth: CGFloat) -> some View {
        let columnWidths = constrainedColumnWidths(availableWidth: availableWidth)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleItems, id: \.url) { item in
                        fileRow(for: item, columnWidths: columnWidths)
                        Divider()
                            .padding(.leading, 36)
                    }
                }
                .padding(.vertical, 2)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                if visibleItems.isEmpty && !pane.filterText.isEmpty && !pane.isInSearchMode {
                    filterEmptyState
                }
            }
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
            .onChange(of: typeAheadScrollURL) { url in
                guard let url else { return }
                proxy.scrollTo(url, anchor: .center)
                typeAheadScrollURL = nil
            }
        }
    }

    @ViewBuilder
    private func fileRow(for item: FileItem, columnWidths: [String: CGFloat]) -> some View {
        let base = FileRowView(
            item: item,
            side: side,
            accentColor: accentColor,
            columnWidths: columnWidths,
            isSelected: pane.selection.contains(item.url),
            extraInfo: metadataService.info(for: item),
            compareStatus: compareStatuses[item.url]
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(side.accessibilityIDPrefix)-file-row-\(item.name)")
        .accessibilityLabel(item.name)
        .accessibilityValue(accessibilityValue(for: item))
        .overlay {
            if dropTargetURL == item.url {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RowMouseEventView(
                onSelect: { flags in select(item, modifierFlags: flags) },
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
        // Open group
        Button("Open") { open(item) }
        openWithMenu(for: item)
        Button("Quick Look") {
            onActivate()
            let urls = pane.selectedItems.isEmpty ? [item.url] : pane.selectedItems.map { $0.url }
            QuickLookCoordinator.shared.toggle(urls: urls)
        }
        if item.isDirectory {
            Button("Show Folder / File Sizes") { folderSizeItem = item }
        }
        Divider()
        // File info group
        if pane.selection.count <= 1 {
            Button("Rename\u{2026}") { beginRename(item) }
        }
        Button("Get Info\u{2026}") { propertiesItem = item }
        Divider()
        // Transfer group
        Button("Move to \(otherPaneLabel)") { onMoveRequested() }
        Button("Copy to \(otherPaneLabel)") { onCopyRequested() }
        Divider()
        // File manipulation group
        Button("Duplicate") {
            if !pane.selectedItems.contains(where: { $0.url == item.url }) {
                pane.selection = [item.url]
            }
            pane.duplicate()
        }
        Button("Compress") {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            compressItems(targets.map { $0.url })
        }
        if item.url.pathExtension.lowercased() == "zip" {
            Button("Uncompress") { uncompressItem(item.url) }
        }
        Divider()
        // Clipboard / sharing group
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
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
        Button("Share\u{2026}") {
            let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
            shareItems(targets.map { $0.url })
        }
        Button(sidebarModel.isBookmarked(item.url) ? "Remove Bookmark" : "Bookmark") {
            sidebarModel.toggleBookmark(item.url)
        }
        Divider()
        // Tags
        tagMenu(for: item)
        Divider()
        // Destructive — kept last so it's never accidentally triggered
        Button("Delete", role: .destructive) { onDeleteRequested() }
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
            if let extraInfo = singleSelectionMetadata {
                Text("·")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Text(extraInfo)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if let error = pane.errorMessage {
                Text("·")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(1)
                Button(action: { pane.errorMessage = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Dismiss error")
            }
            if let compareSummaryText {
                Text("·")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Text(compareSummaryText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(panelBgColor)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(side.accessibilityIDPrefix)-pane-status")
        .accessibilityLabel(statusText)
    }

    private var dropConflictAlertMessage: String {
        guard let dest = pendingDropDest else { return "" }
        let count = pendingDropFiles.filter {
            FileManager.default.fileExists(atPath: dest.appendingPathComponent($0.name).path)
        }.count
        let items = count == 1 ? "1 item already exists" : "\(count) items already exist"
        return "\(items) in \u{201C}\(dest.lastPathComponent)\u{201D}. Choose how to handle the conflict."
    }

    private var statusText: String {
        PaneStatusFormatter.text(
            itemCount: pane.displayedItems.count,
            selectedCount: pane.selection.count,
            selectedBytes: pane.selectedFileItems.reduce(Int64(0)) { $0 + ($1.size ?? 0) },
            isFiltered: !pane.filterText.isEmpty || !pane.activeTagFilters.isEmpty
        )
    }

    private var searchBanner: some View {
        HStack(spacing: 5) {
            if pane.isSearching {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
                Text("Searching subfolders…")
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9))
                let n = pane.displayedItems.count
                Text("\(n) result\(n == 1 ? "" : "s") in subfolders")
            }
            Spacer()
            Button("Clear search") { pane.filterText = "" }
                .font(.system(size: 10))
                .buttonStyle(.plain)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.08))
    }

    private var filterEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No items match \"\(pane.filterText)\"")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if pane.currentURL != nil {
                Button {
                    onActivate()
                    pane.beginDeepSearch(query: pane.filterText)
                } label: {
                    Label("Search subfolders", systemImage: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            } else {
                Text("Navigate into a folder to search")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var singleSelectionMetadata: String? {
        guard pane.selection.count == 1,
              let item = pane.selectedItems.first,
              !item.isDirectory
        else { return nil }
        return metadataService.info(for: item)
    }

    private func accessibilityValue(for item: FileItem) -> String {
        var values = [pane.selection.contains(item.url) ? "selected" : "unselected"]
        if let status = compareStatuses[item.url] {
            values.append(compareAccessibilityText(for: status))
        }
        return values.joined(separator: ", ")
    }

    private func compareAccessibilityText(for status: FolderCompareStatus) -> String {
        switch status {
        case .same:
            return "same"
        case .onlyLeft, .onlyRight:
            return "only in this pane"
        case .newerLeft:
            return side == .left ? "newer than other pane" : "older than other pane"
        case .newerRight:
            return side == .right ? "newer than other pane" : "older than other pane"
        case .different:
            return "different from other pane"
        }
    }

    // MARK: - Actions

    private func select(_ item: FileItem, modifierFlags: NSEvent.ModifierFlags) {
        onActivate()
        pane.select(item, from: pane.displayedItems, mode: selectionMode(from: modifierFlags))
    }

    private func selectionMode(from flags: NSEvent.ModifierFlags) -> PaneSelectionMode {
        let f = flags.intersection(.deviceIndependentFlagsMask)
        if f.contains(.shift)   { return .range }
        if f.contains(.command) { return .toggle }
        return .replace
    }

    private func open(_ item: FileItem) {
        onActivate()
        let resolved = (try? URL(resolvingAliasFileAt: item.url)) ?? item.url
        let isDir = item.isDirectory ||
            (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        if resolved.pathExtension.lowercased() == "app" {
            NSWorkspace.shared.open(resolved)
        } else if isDir {
            pane.navigate(to: resolved)
        } else if item.url.pathExtension.lowercased() == "zip" {
            uncompressItem(item.url)
        } else if item.url.pathExtension.lowercased() == "sh" {
            pendingShellScript = item
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    private func executeShellScript(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", url.path]
        try? process.run()
    }

    private func beginRename(_ item: FileItem) {
        renameText = item.name
        renamingItem = item
    }

    private func handleTypeAhead(char: String) {
        typeBufferTimer?.invalidate()
        typeBuffer += char
        let query = typeBuffer
        if let match = visibleItems.first(where: { $0.name.lowercased().hasPrefix(query.lowercased()) }) {
            pane.selection = [match.url]
            typeAheadScrollURL = match.url
        }
        typeBufferTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            Task { @MainActor in typeBuffer = "" }
        }
    }

    private func commitGoToPath() {
        let raw = goToPathText.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (raw as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            showGoToPath = false
            pane.errorMessage = "\u{201C}\(expanded)\u{201D} is not a folder."
            return
        }
        showGoToPath = false
        onActivate()
        pane.navigate(to: url)
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
                    notifyPaneContentsChanged()
                }
            }
        }
    }

    private func tagButton(_ tagName: String, item: FileItem) -> some View {
        let targets = pane.selectedItems.isEmpty ? [item] : pane.selectedItems
        let allHaveTag = targets.allSatisfy { $0.tags.contains(tagName) }
        return Button {
            for target in targets {
                var tags = (try? target.url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? target.tags
                if allHaveTag {
                    tags.removeAll { $0 == tagName }
                } else if !tags.contains(tagName) {
                    tags.append(tagName)
                }
                applyTags(tags, to: target.url)
            }
            pane.load()
            notifyPaneContentsChanged()
        } label: {
            Label(tagName, systemImage: allHaveTag ? "circle.fill" : "circle")
        }
    }

    private func notifyPaneContentsChanged() {
        guard let dir = pane.currentURL else { return }
        NotificationCenter.default.post(name: .paneContentsChanged, object: nil, userInfo: ["url": dir])
    }

    private func applyTags(_ tags: [String], to url: URL) {
        // NSURL Obj-C API avoids the macOS 26+ restriction on URLResourceValues.tagNames setter.
        try? (url as NSURL).setResourceValue(tags as NSArray, forKey: .tagNamesKey)
    }

    // MARK: - File operations

    private func duplicateItems(_ urls: [URL]) {
        guard let dir = pane.currentURL else { return }
        Task.detached {
            var errors: [String] = []
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
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                } catch {
                    errors.append("Couldn't duplicate \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            let errorMessage = Self.aggregatedErrorMessage(errors, label: "duplicate errors")
            await MainActor.run {
                pane.load()
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": dir])
                if let errorMessage {
                    pane.errorMessage = errorMessage
                }
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
            let errorMessage: String?
            do {
                let result = try await ProcessRunner.run(
                    executableURL: URL(fileURLWithPath: "/usr/bin/zip"),
                    arguments: ["-r", finalDestPath] + names,
                    currentDirectoryURL: dir
                )
                errorMessage = result.terminationStatus == 0
                    ? nil
                    : Self.processErrorMessage(action: "compress", result: result)
            } catch {
                errorMessage = "Couldn't compress: \(error.localizedDescription)"
            }
            await MainActor.run {
                pane.load()
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": dir])
                if let errorMessage {
                    pane.errorMessage = errorMessage
                }
            }
        }
    }

    private func uncompressItem(_ url: URL) {
        let dir = url.deletingLastPathComponent()
        Task.detached {
            let listResult: ProcessExecutionResult
            do {
                listResult = try await ProcessRunner.run(
                    executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
                    arguments: ["-Z1", url.path]
                )
            } catch {
                await MainActor.run {
                    pane.errorMessage = "Couldn't inspect archive: \(error.localizedDescription)"
                }
                return
            }
            guard listResult.terminationStatus == 0 else {
                await MainActor.run {
                    pane.errorMessage = Self.processErrorMessage(action: "inspect archive", result: listResult)
                }
                return
            }

            let infoResult: ProcessExecutionResult
            do {
                infoResult = try await ProcessRunner.run(
                    executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
                    arguments: ["-Z", "-l", url.path]
                )
            } catch {
                await MainActor.run {
                    pane.errorMessage = "Couldn't inspect archive metadata: \(error.localizedDescription)"
                }
                return
            }
            guard infoResult.terminationStatus == 0 else {
                await MainActor.run {
                    pane.errorMessage = Self.processErrorMessage(action: "inspect archive metadata", result: infoResult)
                }
                return
            }

            let entries = ArchiveExtractionSafety.listedEntryNames(from: listResult.stdout)
            let fileEntries: [String]
            do {
                fileEntries = try ArchiveExtractionSafety.validatedFileEntries(from: entries)
                if let symlink = ArchiveExtractionSafety.symbolicLinkEntries(from: infoResult.stdout).first {
                    throw ArchiveExtractionSafetyError.unsupportedSymbolicLink(symlink)
                }
            } catch {
                await MainActor.run {
                    pane.errorMessage = "Couldn't uncompress: \(error.localizedDescription)"
                }
                return
            }

            let conflicts = ArchiveExtractionSafety.conflicts(for: fileEntries, in: dir)

            await MainActor.run {
                if conflicts.isEmpty {
                    performUncompress(url: url, overwrite: false)
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
            let errorMessage: String?
            do {
                let result = try await ProcessRunner.run(
                    executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
                    arguments: [overwrite ? "-o" : "-n", url.path, "-d", dir.path]
                )
                errorMessage = result.terminationStatus == 0
                    ? nil
                    : Self.processErrorMessage(action: "uncompress", result: result)
            } catch {
                errorMessage = "Couldn't uncompress: \(error.localizedDescription)"
            }
            await MainActor.run {
                pane.load()
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": dir])
                if let errorMessage {
                    pane.errorMessage = errorMessage
                }
            }
        }
    }

    nonisolated private static func processErrorMessage(action: String, result: ProcessExecutionResult) -> String {
        let output = result.trimmedCombinedOutput
        if output.isEmpty {
            return "Couldn't \(action): process exited with status \(result.terminationStatus)."
        }
        return "Couldn't \(action): \(output)"
    }

    nonisolated private static func aggregatedErrorMessage(_ errors: [String], label: String) -> String? {
        if errors.count == 1 {
            return errors[0]
        }
        if errors.count > 1 {
            return "\(errors.count) \(label) - \(errors[0])"
        }
        return nil
    }

    // MARK: - Drag and drop

    @discardableResult
    private func handleDrop(destination: URL, operation: NSDragOperation, externalURLs: [URL]) -> Bool {
        let sessionItems = DragSession.shared.items
        let sourceURL = DragSession.shared.sourceDirectoryURL
        let isMove = operation.contains(.move) && !operation.contains(.copy)
        DragSession.shared.clear()

        let fileItems: [FileItem]
        let effectiveIsMove: Bool
        let effectiveSourceURL: URL?

        if !sessionItems.isEmpty {
            // Within-app drag.
            let draggedURLs = Set(sessionItems.map { $0.url })
            guard destination != sourceURL, !draggedURLs.contains(destination) else { return false }
            fileItems = sessionItems
            effectiveIsMove = isMove
            effectiveSourceURL = sourceURL
        } else {
            // External drag (from Finder or another app) — always copy, never move.
            let items = externalURLs.map { url -> FileItem in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                return FileItem(
                    id: url, name: url.lastPathComponent, url: url,
                    isDirectory: isDir, isVolume: false, isRemovable: false,
                    size: nil, kind: "", modified: nil, tags: []
                )
            }
            guard !items.isEmpty else { return false }
            fileItems = items
            effectiveIsMove = false
            effectiveSourceURL = nil
        }

        let conflicts = FileOperationService.detectConflicts(files: fileItems, in: destination)
        if !conflicts.isEmpty {
            pendingDropFiles = fileItems
            pendingDropDest = destination
            pendingDropIsMove = effectiveIsMove
            pendingDropSourceURL = effectiveSourceURL
            showDropConflictAlert = true
            return true
        }

        performDrop(files: fileItems, destination: destination, isMove: effectiveIsMove,
                    sourceURL: effectiveSourceURL, resolution: .overwrite)
        return true
    }

    private func resolveDropConflict(_ resolution: ConflictResolution) {
        guard let dest = pendingDropDest else { return }
        performDrop(files: pendingDropFiles, destination: dest, isMove: pendingDropIsMove,
                    sourceURL: pendingDropSourceURL, resolution: resolution)
        clearDropConflictState()
    }

    private func clearDropConflictState() {
        pendingDropFiles = []
        pendingDropDest = nil
        pendingDropSourceURL = nil
    }

    private func performDrop(files: [FileItem], destination: URL, isMove: Bool,
                              sourceURL: URL?, resolution: ConflictResolution) {
        Task.detached {
            let result = FileOperationService.moveOrCopy(
                files: files, to: destination, isMove: isMove, conflictResolution: resolution
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
    }

    private func shareItems(_ urls: [URL]) {
        let picker = NSSharingServicePicker(items: urls as [Any])
        if let view = NSApp.keyWindow?.contentView {
            let anchor = NSRect(x: view.bounds.midX - 1, y: view.bounds.midY - 1, width: 2, height: 2)
            picker.show(relativeTo: anchor, of: view, preferredEdge: .minY)
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
        // Primary: source-tracked intent via flags monitor — most reliable during drag loop.
        if DragSession.shared.isCopy { return .copy }
        // Secondary: direct physical key state (CGEventSource / HIToolbox).
        if DragSession.isOptionKeyPressed { return .copy }
        // Tertiary: AppKit's modifier-filtered source mask (option → copy-only mask).
        let sourceMask = sender.draggingSourceOperationMask
        if sourceMask.contains(.copy) && !sourceMask.contains(.move) { return .copy }
        return .move
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

@MainActor
private final class TypeAheadController: ObservableObject {
    var isActive: Bool = false
    private var monitor: Any?
    private var onCharacter: ((String) -> Void)?

    func install(onCharacter: @escaping (String) -> Void) {
        self.onCharacter = onCharacter
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event) ?? event
        }
    }

    func remove() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        onCharacter = nil
    }

    private func handle(event: NSEvent) -> NSEvent? {
        guard isActive else { return event }
        let responder = NSApp.keyWindow?.firstResponder
        if responder is NSTextView || responder is NSTextField { return event }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isSubset(of: [.shift, .capsLock]) else { return event }
        guard event.specialKey == nil else { return event }
        guard let chars = event.charactersIgnoringModifiers,
              chars.count == 1,
              let scalar = chars.unicodeScalars.first,
              scalar.value > 32
        else { return event }
        onCharacter?(chars)
        return nil
    }
}
