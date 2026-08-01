import SwiftUI
import Foundation
import AppKit

struct ContentView: View {
    @StateObject private var leftTabs: TabbedPaneState
    @StateObject private var rightTabs: TabbedPaneState
    @StateObject private var sidebarModel: SidebarModel
    @StateObject private var warpViewModel: WarpSearchViewModel
    @StateObject private var customActionsModel: CustomActionsModel
    @EnvironmentObject private var settings: AppSettings

    @State private var activePane: PaneSide = .left
    @State private var showSidebar: Bool = UserDefaults.standard.bool(forKey: "showSidebar")
    @State private var showWarp: Bool = false
    @State private var showCustomActionsSettings: Bool = false
    @State private var toastMessage: String?
    @State private var showDeleteConfirm = false
    @State private var showNewFolderSheet = false
    @State private var newFolderName = "New Folder"
    @State private var showNewFileSheet = false
    @State private var newFileName = "untitled"
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
        _warpViewModel = StateObject(wrappedValue: WarpSearchViewModel())
        _customActionsModel = StateObject(wrappedValue: CustomActionsModel())
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GlobalToolbar(
                    isLeftToRight: activePane == .left,
                    canMoveOrCopy: !active.selectedItems.isEmpty,
                    canDelete: !active.selection.isEmpty,
                    canRename: active.selection.count == 1,
                    showSidebar: showSidebar,
                    bookmarkEnabled: bookmarkTarget != nil,
                    isBookmarked: bookmarkTarget.map { sidebarModel.isBookmarked($0) } ?? false,
                    isTerminalShown: active.showCommandRunner,
                    onToggleSidebar: toggleSidebar,
                    onBookmarkCurrent: {
                        if let url = bookmarkTarget { sidebarModel.toggleBookmark(url) }
                    },
                    onNewFolder: requestNewFolder,
                    onNewFile: requestNewFile,
                    onMove: { moveOrCopy(isMove: true) },
                    onCopy: { moveOrCopy(isMove: false) },
                    onDelete: requestDelete,
                    onRename: { active.requestRename = true },
                    onWarp: { openWarp() },
                    onCustomActions: { showCustomActionsSettings = true },
                    onToggleTerminal: { active.showCommandRunner.toggle() }
                )
                Divider()
                HStack(spacing: 0) {
                    if showSidebar {
                        SidebarView(model: sidebarModel) { url in
                            active.navigate(to: url)
                        }
                        .layoutPriority(1)
                        Divider()
                    }
                    TabbedPaneView(
                        tabs: leftTabs,
                        side: .left,
                        isActive: activePane == .left,
                        accentColor: .blue,
                        otherPaneLabel: pathLabel(rightTabs),
                        onActivate: { activePane = .left },
                        onMoveRequested: { activePane = .left; moveOrCopy(isMove: true) },
                        onCopyRequested: { activePane = .left; moveOrCopy(isMove: false) },
                        onDeleteRequested: { activePane = .left; requestDelete() }
                    )
                    Divider()
                    TabbedPaneView(
                        tabs: rightTabs,
                        side: .right,
                        isActive: activePane == .right,
                        accentColor: .blue,
                        otherPaneLabel: pathLabel(leftTabs),
                        onActivate: { activePane = .right },
                        onMoveRequested: { activePane = .right; moveOrCopy(isMove: true) },
                        onCopyRequested: { activePane = .right; moveOrCopy(isMove: false) },
                        onDeleteRequested: { activePane = .right; requestDelete() }
                    )
                }
            }
            .environmentObject(customActionsModel)
            .environmentObject(sidebarModel)

            // Warp overlay
            if showWarp {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { showWarp = false }
                VStack {
                    WarpSearchView(
                        viewModel: warpViewModel,
                        onSelect: { url in
                            active.navigate(to: url)
                            showWarp = false
                        },
                        onDismiss: { showWarp = false }
                    )
                    .padding(.top, 80)
                    Spacer()
                }
            }
        }
        .onAppear {
            leftTabs.start()
            rightTabs.start()
            // Apply initial display settings to all pane states
            leftTabs.showHiddenFiles  = settings.showHiddenFiles
            rightTabs.showHiddenFiles = settings.showHiddenFiles
        }
        // Quick Look via Space key (posted by AppDelegate)
        .onReceive(NotificationCenter.default.publisher(for: .quickLookRequested)) { _ in
            let urls = active.selectedItems.map { $0.url }
            guard !urls.isEmpty else { return }
            QuickLookCoordinator.shared.toggle(urls: urls)
        }
        // Reload peer pane when same folder contents change (rename, duplicate, compress, etc.)
        .onReceive(NotificationCenter.default.publisher(for: .paneContentsChanged)) { notif in
            guard let changedURL = notif.userInfo?["url"] as? URL else { return }
            reloadPeerIfSameFolder(changedURL: changedURL)
        }
        // Propagate display settings to all tabs when they change
        .onChange(of: settings.showHiddenFiles, perform: { newValue in
            leftTabs.showHiddenFiles  = newValue
            rightTabs.showHiddenFiles = newValue
        })
        // Persist sidebar visibility
        .onChange(of: showSidebar, perform: { newValue in
            UserDefaults.standard.set(newValue, forKey: "showSidebar")
        })
        // Remember last folder for each pane
        .onChange(of: leftTabs.activePaneState.currentURL, perform: { url in
            if settings.leftStartupMode == .rememberLast {
                UserDefaults.standard.set(url?.path, forKey: "lastLeftURL")
            }
        })
        .onChange(of: rightTabs.activePaneState.currentURL, perform: { url in
            if settings.rightStartupMode == .rememberLast {
                UserDefaults.standard.set(url?.path, forKey: "lastRightURL")
            }
        })
        // Keyboard shortcuts
        .background {
            Group {
                Button("New Tab") { activeTabs.openTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") { activeTabs.closeTab(at: activeTabs.activeTabIndex) }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Go Back") { active.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Go Forward") { active.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                Button("Go Up") { active.goUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button("Open Selected") { openSelected() }
                    .keyboardShortcut(.return, modifiers: [])
                Button("Refresh") { active.load() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Select All") { active.selectAll() }
                    .keyboardShortcut("a", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
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
        .sheet(isPresented: $showCustomActionsSettings) {
            CustomActionsSettingsView(model: customActionsModel)
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteConfirm) {
            Button("Move to Trash", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteAlertMessage)
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(currentErrorMessage)
        }
    }

    // MARK: - Warp

    private func openWarp() {
        let openURLs = ([leftTabs, rightTabs] as [TabbedPaneState])
            .flatMap { $0.tabs.compactMap { $0.pane.currentURL } }
        warpViewModel.configure(
            systemLocations: sidebarModel.systemLocations,
            bookmarks: sidebarModel.bookmarks,
            openURLs: openURLs
        )
        warpViewModel.query = ""
        showWarp = true
    }

    // MARK: - Computed

    private var deleteAlertTitle: String {
        "Delete \(active.selection.count) item\(active.selection.count == 1 ? "" : "s")?"
    }

    private var deleteAlertMessage: String {
        let selected = active.items.filter { active.selection.contains($0.url) }
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
        leftTabs.activePaneState.errorMessage ?? rightTabs.activePaneState.errorMessage ?? ""
    }

    private func pathLabel(_ tabs: TabbedPaneState) -> String {
        tabs.activePaneState.currentURL?.lastPathComponent ?? "Computer"
    }

    private func toggleSidebar() {
        showSidebar.toggle()
    }

    private func reloadPeerIfSameFolder(changedURL: URL) {
        // Reload any pane showing the changed folder — handles both same-folder
        // and cross-pane drag where source and destination are different folders.
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
        guard let url = active.selection.first,
              let item = active.items.first(where: { $0.url == url }) else { return }
        if item.isDirectory {
            active.navigate(to: url)
        } else {
            NSWorkspace.shared.open(url)
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
            Task { @MainActor in
                await active.loadingTask?.value
                active.selection = [fileURL]
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
        let result = FileOperationService.moveOrCopy(files: active.selectedItems, to: destBase, isMove: isMove)
        if result.errors.count == 1 {
            active.errorMessage = result.errors[0]
        } else if result.errors.count > 1 {
            active.errorMessage = "\(result.errors.count) errors — \(result.errors[0])"
        }
        active.load()
        inactive.load()
        if isMove { active.selection.removeAll() }
        if result.hasSucceeded {
            showToast("\(isMove ? "Moved" : "Copied") \(result.succeeded) file\(result.succeeded == 1 ? "" : "s") to \(destBase.lastPathComponent)")
        }
    }

    // MARK: - Delete

    private func requestDelete() {
        let selected = active.items.filter { active.selection.contains($0.url) }
        let hasDirectories = selected.contains { $0.isDirectory }
        let skipConfirm = hasDirectories ? settings.directoryDeleteNoConfirm : settings.fileDeleteNoConfirm
        if skipConfirm { performDelete() } else { showDeleteConfirm = true }
    }

    private func performDelete() {
        let pane = active
        let baseURL = pane.currentURL
        let selected = pane.items.filter { pane.selection.contains($0.url) }
        let result = FileOperationService.trash(urls: selected.map { $0.url })
        if let error = result.errors.last { pane.errorMessage = error }
        pane.selection.removeAll()
        pane.load()
        if let url = baseURL { reloadPeerIfSameFolder(changedURL: url) }
        if result.succeeded > 0 {
            showToast("Moved \(result.succeeded) item\(result.succeeded == 1 ? "" : "s") to Trash.")
        }
    }
}
