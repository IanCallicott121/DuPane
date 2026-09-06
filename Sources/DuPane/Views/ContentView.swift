import SwiftUI
import Foundation
import AppKit

struct ContentView: View {
    private enum Layout {
        static let outerMargin: CGFloat = 6
        static let paneSpacing: CGFloat = 6
        static let resizeHandleWidth: CGFloat = 8
    }

    @StateObject private var leftTabs: TabbedPaneState
    @StateObject private var rightTabs: TabbedPaneState
    @StateObject private var sidebarModel: SidebarModel
    @EnvironmentObject private var settings: AppSettings

    @State private var activePane: PaneSide = .left
    @State private var showSidebar: Bool = UserDefaults.standard.bool(forKey: "showSidebar")
    @State private var sidebarWidth: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "sidebarWidth")
        return stored > 0 ? stored : SidebarView.defaultWidth
    }()
    @State private var activeTagFilters: Set<String> = []
    @State private var toastMessage: String?
    @State private var showDeleteConfirm = false
    @State private var showNewFolderSheet = false
    @State private var newFolderName = "New Folder"
    @State private var showNewFileSheet = false
    @State private var newFileName = "untitled"
    @State private var pendingConflictFiles: [FileItem] = []
    @State private var pendingConflictDest: URL? = nil
    @State private var pendingConflictIsMove: Bool = false
    @State private var showConflictAlert = false
    @State private var isCompareModeEnabled: Bool = false
    @State private var isFollowMode: Bool = false
    @State private var pendingSyncPlan: FolderSyncPlan? = nil
    @State private var showDuplicateFinder: Bool = false
    @State private var duplicateScanURL: URL? = nil
    @StateObject private var duplicateFinderViewModel = DuplicateFinderViewModel()
    @State private var fileOpInfo: (label: String, completed: Int, total: Int)? = nil
    @State private var fileOpVisible: Bool = false
    @State private var fileOpRevealTask: Task<Void, Never>? = nil
    private var active: PaneState { activePane == .left ? leftTabs.activePaneState : rightTabs.activePaneState }
    private var inactive: PaneState { activePane == .left ? rightTabs.activePaneState : leftTabs.activePaneState }
    private var activeTabs: TabbedPaneState { activePane == .left ? leftTabs : rightTabs }

    private var bookmarkTarget: URL? {
        guard active.selectedItems.count == 1 else { return nil }
        return active.selectedItems.first?.url
    }

    init(configuration: AppLaunchConfiguration = .current()) {
        _leftTabs  = StateObject(wrappedValue: TabbedPaneState(initialURLs: configuration.leftTabURLs, tabsKey: "leftTabState"))
        _rightTabs = StateObject(wrappedValue: TabbedPaneState(initialURLs: configuration.rightTabURLs, tabsKey: "rightTabState"))
        _sidebarModel = StateObject(wrappedValue: SidebarModel())
    }

    // MARK: - Body

    var body: some View {
        let snapshot = compareSnapshot
        let leftToRightPlan = syncPlan(.leftToRight, snapshot: snapshot)
        let rightToLeftPlan = syncPlan(.rightToLeft, snapshot: snapshot)

        // Delegate the heavy layout + observer chain to a separate function so
        // the Swift type-checker can handle each expression tree independently.
        coreView(snapshot: snapshot, leftToRightPlan: leftToRightPlan, rightToLeftPlan: rightToLeftPlan)
            .sheet(isPresented: $showNewFolderSheet) {
                TextPromptSheet(
                    title: "New Folder",
                    text: $newFolderName,
                    confirmLabel: "Create",
                    onConfirm: performCreateFolder,
                    onCancel: { showNewFolderSheet = false }
                )
            }
            .sheet(isPresented: $showNewFileSheet) {
                TextPromptSheet(
                    title: "New File",
                    text: $newFileName,
                    confirmLabel: "Create",
                    onConfirm: performCreateFile,
                    onCancel: { showNewFileSheet = false }
                )
            }
            .sheet(isPresented: $showDuplicateFinder, onDismiss: { duplicateFinderViewModel.cancel() }) {
                if let rootURL = duplicateScanURL {
                    DuplicateFinderView(
                        viewModel: duplicateFinderViewModel,
                        rootURL: rootURL,
                        onDismiss: {
                            showDuplicateFinder = false
                            leftTabs.activePaneState.load()
                            rightTabs.activePaneState.load()
                        }
                    )
                }
            }
            .alert(deleteAlertTitle, isPresented: $showDeleteConfirm) {
                Button("Move to Trash", role: .destructive) { performDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteAlertMessage)
            }
            .alert("Items Already Exist", isPresented: $showConflictAlert) {
                Button("Overwrite") { executeConflictResolution(.overwrite) }
                Button("Skip") { executeConflictResolution(.skip) }
                Button("Keep Both") { executeConflictResolution(.rename) }
                Button("Cancel", role: .cancel) { pendingConflictFiles = []; pendingConflictDest = nil }
            } message: {
                Text(conflictAlertMessage)
            }
            .alert("Confirm Sync", isPresented: syncPlanBinding) {
                Button("Sync", role: .destructive) {
                    if let plan = pendingSyncPlan {
                        executeSyncPlan(plan)
                    }
                    pendingSyncPlan = nil
                }
                Button("Cancel", role: .cancel) { pendingSyncPlan = nil }
            } message: {
                Text(pendingSyncPlan?.confirmationMessage ?? "")
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK") {}
            } message: {
                Text(currentErrorMessage)
            }
    }

    // MARK: - Core Layout

    private func coreView(snapshot: FolderCompareSnapshot?, leftToRightPlan: FolderSyncPlan?, rightToLeftPlan: FolderSyncPlan?) -> some View {
        // Assign to a typed local so the closure-heavy initializer is type-checked
        // in isolation rather than inside the ZStack @ViewBuilder expression tree.
        let toolbar: GlobalToolbar = buildToolbar(snapshot: snapshot, leftToRightPlan: leftToRightPlan, rightToLeftPlan: rightToLeftPlan)
        return ZStack {
            VStack(spacing: 0) {
                toolbar
                panesArea(snapshot: snapshot)
            }
            .environmentObject(sidebarModel)

        }
        .onAppear {
            leftTabs.start()
            rightTabs.start()
            sidebarModel.startTagMonitoring()
            refreshSidebarTags()
            leftTabs.showHiddenFiles  = settings.showHiddenFiles
            rightTabs.showHiddenFiles = settings.showHiddenFiles
            leftTabs.showHiddenFolders  = settings.showHiddenFolders
            rightTabs.showHiddenFolders = settings.showHiddenFolders
            leftTabs.foldersFirst  = settings.foldersFirst
            rightTabs.foldersFirst = settings.foldersFirst
        }
        .onChange(of: sidebarModel.tags, perform: { tags in
            guard !activeTagFilters.isEmpty else { return }
            let remainingTags = activeTagFilters.filter { selectedTag in
                tags.contains {
                    FinderTagMetadata.matches(itemTag: $0.name, selectedTag: selectedTag)
                }
            }
            if remainingTags != activeTagFilters {
                applyTagFilters(remainingTags)
            }
        })
        .onChange(of: leftTabs.activeTabIndex, perform: { _ in refreshSidebarTags() })
        .onChange(of: rightTabs.activeTabIndex, perform: { _ in refreshSidebarTags() })
        .onChange(of: leftTabs.activePaneState.items, perform: { _ in refreshSidebarTags() })
        .onChange(of: rightTabs.activePaneState.items, perform: { _ in refreshSidebarTags() })
        .onReceive(NotificationCenter.default.publisher(for: .quickLookRequested)) { _ in
            let urls = active.selectedItems.map { $0.url }
            guard !urls.isEmpty else { return }
            QuickLookCoordinator.shared.toggle(urls: urls)
        }
        .onReceive(NotificationCenter.default.publisher(for: .paneContentsChanged)) { notif in
            guard let changedURL = notif.userInfo?["url"] as? URL else { return }
            reloadPeerIfSameFolder(changedURL: changedURL)
        }
        .onChange(of: settings.showHiddenFiles, perform: { newValue in
            leftTabs.showHiddenFiles  = newValue
            rightTabs.showHiddenFiles = newValue
        })
        .onChange(of: settings.showHiddenFolders, perform: { newValue in
            leftTabs.showHiddenFolders  = newValue
            rightTabs.showHiddenFolders = newValue
        })
        .onChange(of: settings.foldersFirst, perform: { newValue in
            leftTabs.foldersFirst  = newValue
            rightTabs.foldersFirst = newValue
        })
        .onChange(of: showSidebar, perform: { newValue in
            UserDefaults.standard.set(newValue, forKey: "showSidebar")
        })
        .onChange(of: leftTabs.activePaneState.currentURL, perform: { url in
            if settings.leftStartupMode == .rememberLast {
                UserDefaults.standard.set(url?.path, forKey: "lastLeftURL")
            }
            if let url { sidebarModel.recordVisit(url) }
            disableCompareIfNeeded()
            if isFollowMode, activePane == .left, let url,
               rightTabs.activePaneState.currentURL != url {
                rightTabs.activePaneState.navigate(to: url)
            }
        })
        .onChange(of: rightTabs.activePaneState.currentURL, perform: { url in
            if settings.rightStartupMode == .rememberLast {
                UserDefaults.standard.set(url?.path, forKey: "lastRightURL")
            }
            if let url { sidebarModel.recordVisit(url) }
            disableCompareIfNeeded()
            if isFollowMode, activePane == .right, let url,
               leftTabs.activePaneState.currentURL != url {
                leftTabs.activePaneState.navigate(to: url)
            }
        })
        .background { keyboardButtons }
        .overlay(alignment: .bottom) {
            if fileOpVisible, let info = fileOpInfo {
                VStack(spacing: 4) {
                    Text(info.label)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    ProgressView(value: Double(info.completed), total: Double(max(info.total, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 220)
                    Text("\(info.completed) of \(info.total)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 70)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 12))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 34)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    @ViewBuilder
    private func panesArea(snapshot: FolderCompareSnapshot?) -> some View {
        HStack(spacing: Layout.paneSpacing) {
            if showSidebar {
                SidebarView(
                    model: sidebarModel,
                    selectedTags: activeTagFilters,
                    onNavigate: { url in active.navigate(to: url) },
                    onTagSelected: applyTagFilter
                )
                .frame(width: sidebarWidth)
                .overlay(alignment: .trailing) {
                    SidebarResizeHandle(width: $sidebarWidth)
                        .frame(width: Layout.resizeHandleWidth)
                        .offset(x: Layout.resizeHandleWidth / 2)
                }
                .layoutPriority(1)
            }
            TabbedPaneView(
                tabs: leftTabs,
                side: .left,
                isActive: activePane == .left,
                accentColor: .blue,
                otherPaneLabel: pathLabel(rightTabs),
                compareStatuses: snapshot?.leftStatuses ?? [:],
                compareSummaryText: snapshot?.summary.detailText,
                onActivate: { activePane = .left },
                onMoveRequested: { activePane = .left; moveOrCopy(isMove: true) },
                onCopyRequested: { activePane = .left; moveOrCopy(isMove: false) },
                onDeleteRequested: { activePane = .left; requestDelete() }
            )
            TabbedPaneView(
                tabs: rightTabs,
                side: .right,
                isActive: activePane == .right,
                accentColor: .blue,
                otherPaneLabel: pathLabel(leftTabs),
                compareStatuses: snapshot?.rightStatuses ?? [:],
                compareSummaryText: snapshot?.summary.detailText,
                onActivate: { activePane = .right },
                onMoveRequested: { activePane = .right; moveOrCopy(isMove: true) },
                onCopyRequested: { activePane = .right; moveOrCopy(isMove: false) },
                onDeleteRequested: { activePane = .right; requestDelete() }
            )
        }
        .padding(.horizontal, Layout.outerMargin)
        .padding(.bottom, Layout.outerMargin)
    }

    @ViewBuilder
    private var keyboardButtons: some View {
        Group {
            Button("New Tab") { activeTabs.openTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Close Tab") { activeTabs.closeTab(at: activeTabs.activeTabIndex) }
                .keyboardShortcut("w", modifiers: .command)
            Button("Go Back") { active.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Go Forward") { active.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("Go Up") { active.goUp() }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("Open Selected") { openSelected() }
                .keyboardShortcut(.return, modifiers: [])
            Button("Open Selected") { openSelected() }
                .keyboardShortcut(.downArrow, modifiers: .command)
            Button("Refresh") { active.load() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Select All") { active.selectAll() }
                .keyboardShortcut("a", modifiers: .command)
            Button("Go to Path") { active.requestGoToPath = true }
                .keyboardShortcut("l", modifiers: .command)
        }
        Group {
            Button("Go to Path") { active.requestGoToPath = true }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("Go Home") { active.navigate(to: FileManager.default.homeDirectoryForCurrentUser) }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Go Desktop") { active.navigate(to: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Go Documents") { active.navigate(to: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Go Computer") { active.navigate(to: nil) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Go Applications") { active.navigate(to: URL(fileURLWithPath: "/Applications")) }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Button("Go Utilities") { active.navigate(to: URL(fileURLWithPath: "/Applications/Utilities")) }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            Button("Copy to Other Pane") { moveOrCopy(isMove: false) }
                .keyboardShortcut("c", modifiers: .command)
            Button("Move to Other Pane") { moveOrCopy(isMove: true) }
                .keyboardShortcut("v", modifiers: .command)
            Button("Duplicate") { active.duplicate() }
                .keyboardShortcut("d", modifiers: .command)
            Button("Quick Look") {
                let urls = active.selectedItems.map { $0.url }
                guard !urls.isEmpty else { return }
                QuickLookCoordinator.shared.toggle(urls: urls)
            }
            .keyboardShortcut(" ", modifiers: [])
            Button("Get Info") { active.requestGetInfo = true }
                .keyboardShortcut("i", modifiers: .command)
            Button("Focus Filter") { active.requestFocusFilter = true }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    private func buildToolbar(snapshot: FolderCompareSnapshot?, leftToRightPlan: FolderSyncPlan?, rightToLeftPlan: FolderSyncPlan?) -> GlobalToolbar {
        GlobalToolbar(
            isLeftToRight: activePane == .left,
            canMoveOrCopy: !active.selectedItems.isEmpty,
            canDelete: !active.selection.isEmpty,
            canRename: active.selection.count == 1,
            showSidebar: showSidebar,
            bookmarkEnabled: bookmarkTarget != nil,
            isBookmarked: bookmarkTarget.map { sidebarModel.isBookmarked($0) } ?? false,
            isTerminalShown: active.showCommandRunner,
            isFollowMode: isFollowMode,
            showLabels: settings.showToolbarLabels,
            canCompare: canCompareLocations,
            isCompareMode: isCompareModeEnabled,
            compareSummary: compareToolbarSummary(snapshot),
            canSyncLeftToRight: leftToRightPlan?.isEmpty == false,
            canSyncRightToLeft: rightToLeftPlan?.isEmpty == false,
            onToggleSidebar: toggleSidebar,
            onBookmarkCurrent: { [self] in if let url = bookmarkTarget { sidebarModel.toggleBookmark(url) } },
            onNewFolder: requestNewFolder,
            onNewFile: requestNewFile,
            onMove: { self.moveOrCopy(isMove: true) },
            onCopy: { self.moveOrCopy(isMove: false) },
            onDelete: requestDelete,
            onRename: { self.active.requestRename = true },
            canFindDuplicates: active.currentURL != nil,
            onToggleTerminal: { self.active.showCommandRunner.toggle() },
            onToggleFollow: {
                self.isFollowMode.toggle()
                if self.isFollowMode, let url = self.active.currentURL,
                   self.inactive.currentURL != url {
                    self.inactive.navigate(to: url)
                }
            },
            onToggleCompare: toggleCompareMode,
            onSyncLeftToRight: { self.requestSync(.leftToRight) },
            onSyncRightToLeft: { self.requestSync(.rightToLeft) },
            onFindDuplicates: { self.openDuplicateFinder() }
        )
    }

    // MARK: - Duplicate Finder

    private func openDuplicateFinder() {
        guard let url = active.currentURL else { return }
        duplicateScanURL = url
        duplicateFinderViewModel.startScan(at: url)
        showDuplicateFinder = true
    }

    private func applyTagFilter(_ tagName: String, extendingSelection: Bool) {
        if extendingSelection {
            var updatedFilters = activeTagFilters
            let matchingTag = updatedFilters.first {
                FinderTagMetadata.matches(itemTag: $0, selectedTag: tagName)
            }
            if let matchingTag {
                updatedFilters.remove(matchingTag)
            } else {
                updatedFilters.insert(tagName)
            }
            applyTagFilters(updatedFilters)
        } else {
            let isOnlySelected = activeTagFilters.count == 1 && activeTagFilters.contains {
                FinderTagMetadata.matches(itemTag: $0, selectedTag: tagName)
            }
            applyTagFilters(isOnlySelected ? [] : [tagName])
        }
    }

    private func applyTagFilters(_ tagNames: Set<String>) {
        activeTagFilters = tagNames
        leftTabs.activeTagFilters = tagNames
        rightTabs.activeTagFilters = tagNames
    }

    private func refreshSidebarTags() {
        sidebarModel.updatePaneTags(from: leftTabs.activePaneState.items + rightTabs.activePaneState.items)
    }

    // MARK: - Computed

    private var canCompareLocations: Bool {
        leftTabs.activePaneState.currentURL != nil && rightTabs.activePaneState.currentURL != nil
    }

    private var compareSnapshot: FolderCompareSnapshot? {
        guard isCompareModeEnabled, canCompareLocations else { return nil }
        guard !leftTabs.activePaneState.isLoading, !rightTabs.activePaneState.isLoading else { return nil }
        return FolderCompareService.compare(
            leftItems: leftTabs.activePaneState.items,
            rightItems: rightTabs.activePaneState.items
        )
    }

    private func compareToolbarSummary(_ snapshot: FolderCompareSnapshot?) -> String? {
        guard isCompareModeEnabled else { return nil }
        return snapshot?.summary.compactText ?? "Comparing..."
    }

    private func syncPlan(_ direction: FolderSyncDirection, snapshot: FolderCompareSnapshot?) -> FolderSyncPlan? {
        guard
            let snapshot,
            let leftFolder = leftTabs.activePaneState.currentURL,
            let rightFolder = rightTabs.activePaneState.currentURL
        else {
            return nil
        }
        return FolderCompareService.syncPlan(
            from: snapshot,
            direction: direction,
            leftFolder: leftFolder,
            rightFolder: rightFolder
        )
    }

    private var conflictAlertMessage: String {
        guard let dest = pendingConflictDest else { return "" }
        let count = pendingConflictFiles.filter {
            FileManager.default.fileExists(atPath: dest.appendingPathComponent($0.name).path)
        }.count
        let items = count == 1 ? "1 item already exists" : "\(count) items already exist"
        return "\(items) in \u{201C}\(dest.lastPathComponent)\u{201D}. Choose how to handle the conflict."
    }

    private var deleteAlertTitle: String {
        "Delete \(active.selection.count) item\(active.selection.count == 1 ? "" : "s")?"
    }

    private var syncPlanBinding: Binding<Bool> {
        Binding(
            get: { pendingSyncPlan != nil },
            set: { newValue in
                if !newValue { pendingSyncPlan = nil }
            }
        )
    }

    private var deleteAlertMessage: String {
        let selected = active.selectedItems
        let dirCount  = selected.filter { $0.isDirectory }.count
        let fileCount = selected.count - dirCount
        var parts: [String] = []
        if fileCount > 0 { parts.append("\(fileCount) file\(fileCount == 1 ? "" : "s")") }
        if dirCount  > 0 { parts.append("\(dirCount) director\(dirCount == 1 ? "y" : "ies")") }
        let countDesc = parts.joined(separator: " and ")
        return "\(countDesc) will be moved to Trash."
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: {
                leftTabs.activePaneState.errorMessage != nil ||
                rightTabs.activePaneState.errorMessage != nil
            },
            set: { newValue in
                if !newValue {
                    leftTabs.activePaneState.errorMessage  = nil
                    rightTabs.activePaneState.errorMessage = nil
                }
            }
        )
    }

    private var currentErrorMessage: String {
        [leftTabs.activePaneState.errorMessage, rightTabs.activePaneState.errorMessage]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }

    private func pathLabel(_ tabs: TabbedPaneState) -> String {
        tabs.activePaneState.currentURL?.lastPathComponent ?? "Computer"
    }

    private func toggleSidebar() {
        showSidebar.toggle()
    }

    private func toggleCompareMode() {
        guard canCompareLocations else {
            showToast("Navigate both panes into folders first.")
            return
        }
        isCompareModeEnabled.toggle()
    }

    private func disableCompareIfNeeded() {
        guard isCompareModeEnabled, !canCompareLocations else { return }
        isCompareModeEnabled = false
        pendingSyncPlan = nil
    }

    private func requestSync(_ direction: FolderSyncDirection) {
        guard canCompareLocations else {
            showToast("Navigate both panes into folders first.")
            return
        }
        let sourcePane = direction == .leftToRight ? leftTabs.activePaneState : rightTabs.activePaneState
        let destinationPane = direction == .leftToRight ? rightTabs.activePaneState : leftTabs.activePaneState
        guard let destination = destinationPane.currentURL else { return }
        guard FileManager.default.isWritableFile(atPath: destination.path) else {
            sourcePane.errorMessage = "Destination folder is not writable."
            return
        }
        guard let plan = syncPlan(direction, snapshot: compareSnapshot) else {
            showToast("Compare is still loading.")
            return
        }
        guard !plan.isEmpty else {
            showToast("No eligible changes to sync \(direction.label).")
            return
        }
        pendingSyncPlan = plan
    }

    private func executeSyncPlan(_ plan: FolderSyncPlan) {
        fileOpRevealTask?.cancel()
        let total = plan.entries.count
        let label = "Syncing \(total) item\(total == 1 ? "" : "s") \(plan.direction.label)…"
        fileOpInfo = (label: label, completed: 0, total: total)
        fileOpRevealTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self.fileOpVisible = true }
        }
        let sourcePane = plan.direction == .leftToRight ? leftTabs.activePaneState : rightTabs.activePaneState
        let destinationPane = plan.direction == .leftToRight ? rightTabs.activePaneState : leftTabs.activePaneState
        let files = plan.entries.map(\.source)

        Task.detached {
            let result = FileOperationService.moveOrCopy(
                files: files,
                to: plan.destinationFolder,
                isMove: false,
                conflictResolution: .overwrite,
                onProgress: { completed, _ in
                    Task { @MainActor in
                        self.fileOpInfo = (label: label, completed: completed, total: total)
                    }
                }
            )
            await MainActor.run {
                self.fileOpRevealTask?.cancel()
                self.fileOpRevealTask = nil
                withAnimation { self.fileOpVisible = false }
                self.fileOpInfo = nil
                sourcePane.load()
                destinationPane.load()
                if result.errors.count == 1 {
                    sourcePane.errorMessage = result.errors[0]
                } else if result.errors.count > 1 {
                    sourcePane.errorMessage = "\(result.errors.count) errors - \(result.errors[0])"
                }
                if result.hasSucceeded {
                    showToast("Synced \(result.succeeded) item\(result.succeeded == 1 ? "" : "s") \(plan.direction.label).")
                }
            }
        }
    }

    private func reloadPeerIfSameFolder(changedURL: URL) {
        if leftTabs.activePaneState.currentURL == changedURL { leftTabs.activePaneState.load() }
        if rightTabs.activePaneState.currentURL == changedURL { rightTabs.activePaneState.load() }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Navigation

    private func openSelected() {
        guard let item = active.selectedItems.first else { return }
        if item.isDirectory {
            active.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    // MARK: - New Folder

    private func requestNewFolder() {
        guard active.currentURL != nil else { showToast("Navigate into a folder first."); return }
        newFolderName = "New Folder"
        showNewFolderSheet = true
    }

    private func performCreateFolder() {
        guard let baseURL = active.currentURL else { return }
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        showNewFolderSheet = false
        do {
            try FileOperationService.createFolder(named: name, in: baseURL)
            active.load()
            reloadPeerIfSameFolder(changedURL: baseURL)
            showToast("Created folder '\(name)'.")
        } catch {
            active.errorMessage = error.localizedDescription
        }
    }

    // MARK: - New File

    private func requestNewFile() {
        guard active.currentURL != nil else { showToast("Navigate into a folder first."); return }
        newFileName = "untitled"
        showNewFileSheet = true
    }

    private func performCreateFile() {
        guard let baseURL = active.currentURL else { return }
        let name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        showNewFileSheet = false
        do {
            let fileURL = try FileOperationService.createFile(named: name, in: baseURL)
            active.load()
            reloadPeerIfSameFolder(changedURL: baseURL)
            let pane = active
            Task { @MainActor in
                await pane.loadingTask?.value
                pane.selection = [fileURL]
            }
            showToast("Created file '\(name)'.")
        } catch {
            active.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Move / Copy

    private func moveOrCopy(isMove: Bool) {
        guard let destBase = inactive.currentURL else {
            showToast("Navigate the other pane into a folder first.")
            return
        }
        let files = active.selectedItems
        let conflicts = FileOperationService.detectConflicts(files: files, in: destBase)
        if !conflicts.isEmpty {
            pendingConflictFiles = files
            pendingConflictDest = destBase
            pendingConflictIsMove = isMove
            showConflictAlert = true
            return
        }
        executeMoveOrCopy(files: files, destination: destBase, isMove: isMove, resolution: .overwrite)
    }

    private func executeConflictResolution(_ resolution: ConflictResolution) {
        guard let dest = pendingConflictDest else { return }
        executeMoveOrCopy(files: pendingConflictFiles, destination: dest, isMove: pendingConflictIsMove, resolution: resolution)
        pendingConflictFiles = []
        pendingConflictDest = nil
    }

    private func executeMoveOrCopy(files: [FileItem], destination: URL, isMove: Bool, resolution: ConflictResolution) {
        fileOpRevealTask?.cancel()
        let label = "\(isMove ? "Moving" : "Copying") \(files.count) item\(files.count == 1 ? "" : "s") to \(destination.lastPathComponent)…"
        let total = files.count
        fileOpInfo = (label: label, completed: 0, total: total)
        fileOpRevealTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self.fileOpVisible = true }
        }
        let sourcePane = active
        let destPane = inactive
        Task.detached {
            let result = FileOperationService.moveOrCopy(
                files: files, to: destination, isMove: isMove, conflictResolution: resolution,
                onProgress: { completed, _ in
                    Task { @MainActor in
                        self.fileOpInfo = (label: label, completed: completed, total: total)
                    }
                }
            )
            await MainActor.run {
                self.fileOpRevealTask?.cancel()
                self.fileOpRevealTask = nil
                withAnimation { self.fileOpVisible = false }
                self.fileOpInfo = nil
                if result.errors.count == 1 {
                    sourcePane.errorMessage = result.errors[0]
                } else if result.errors.count > 1 {
                    sourcePane.errorMessage = "\(result.errors.count) errors — \(result.errors[0])"
                }
                if sourcePane.isInSearchMode { sourcePane.endDeepSearch() }
                sourcePane.load()
                destPane.load()
                if isMove { sourcePane.selection.removeAll() }
                if result.hasSucceeded {
                    showToast("\(isMove ? "Moved" : "Copied") \(result.succeeded) file\(result.succeeded == 1 ? "" : "s") to \(destination.lastPathComponent)")
                }
            }
        }
    }

    // MARK: - Delete

    private func requestDelete() {
        let selected = active.selectedItems
        let hasDirectories = selected.contains { $0.isDirectory }
        let skipConfirm = hasDirectories ? settings.directoryDeleteNoConfirm : settings.fileDeleteNoConfirm
        if skipConfirm { performDelete() } else { showDeleteConfirm = true }
    }

    private func performDelete() {
        let pane = active
        let peer = inactive
        let urls = pane.selectedItems.map { $0.url }
        pane.selection.removeAll()
        Task.detached {
            let result = FileOperationService.trash(urls: urls)
            await MainActor.run {
                if let error = result.errors.last { pane.errorMessage = error }
                if pane.isInSearchMode { pane.endDeepSearch() }
                pane.load()
                if let peerURL = peer.currentURL,
                   let culprit = urls.first(where: { peerURL == $0 || peerURL.path.hasPrefix($0.path + "/") }) {
                    peer.navigate(to: culprit.deletingLastPathComponent())
                } else {
                    peer.load()
                }
                if result.succeeded > 0 {
                    showToast("Moved \(result.succeeded) item\(result.succeeded == 1 ? "" : "s") to Trash.")
                }
            }
        }
    }
}
