import Foundation
import Combine

enum PaneSelectionMode {
    case replace
    case toggle
    case range
}

/// nil currentURL means the virtual "Computer" root — a live list of mounted volumes.
@MainActor
final class PaneState: ObservableObject {
    @Published var currentURL: URL?
    @Published var items: [FileItem] = []
    @Published var selection: Set<URL> = []
    @Published var sortKey: SortKey = .name
    @Published var sortAscending: Bool = true
    @Published var filterText: String = ""
    @Published var activeTagFilters: Set<String> = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var showCommandRunner: Bool = false
    @Published var requestRename: Bool = false
    @Published var requestGoToPath: Bool = false
    @Published private(set) var searchResults: [FileItem]? = nil
    @Published private(set) var isSearching: Bool = false
    var isInSearchMode: Bool { searchResults != nil || isSearching }
    var showHiddenFiles: Bool = false
    var showHiddenFolders: Bool = false
    @Published var foldersFirst: Bool = true
    @Published var requestGetInfo: Bool = false
    @Published var requestFocusFilter: Bool = false

    private var history: [URL?]
    private var historyIndex: Int = 0
    private var selectionAnchor: URL?
    private var spotlightQuery: NSMetadataQuery?
    private var spotlightObservers: [NSObjectProtocol] = []
    private var searchRootURL: URL?

    /// Tracks the in-flight directory load so callers can await it and stale
    /// loads can be cancelled when the user navigates before they finish.
    private(set) var loadingTask: Task<Void, Never>?

    init(initialURL: URL? = nil) {
        self.currentURL = initialURL
        self.history = [initialURL]
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }
    var canGoUp: Bool { currentURL != nil }

    /// All real folder URLs visited in this pane's session history, oldest first.
    var recentURLs: [URL] { history.compactMap { $0 } }

    /// "Computer" plus each real path component, with the implicit /Volumes
    /// segment hidden so a card at /Volumes/SD-512-1 reads as Computer › SD-512-1.
    var breadcrumbs: [(label: String, url: URL?)] {
        var crumbs: [(label: String, url: URL?)] = [("Computer", nil)]
        guard let url = currentURL else { return crumbs }
        let standardized = url.standardizedFileURL
        let components = standardized.pathComponents.filter { $0 != "/" }
        // Paths not under /Volumes are on the boot volume. Inject its name so the
        // breadcrumb reads "Computer / Macintosh HD / …" instead of just "Computer / …".
        let isOnBootVolume = !standardized.path.hasPrefix("/Volumes/") && standardized.path != "/Volumes"
        if isOnBootVolume {
            let rootURL = URL(fileURLWithPath: "/")
            let volumeName = (try? rootURL.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? "/"
            crumbs.append((volumeName, rootURL))
        }
        var running = URL(fileURLWithPath: "/")
        for component in components {
            running.appendPathComponent(component)
            if component == "Volumes" && running.path == "/Volumes" {
                continue
            }
            crumbs.append((component, running))
        }
        return crumbs
    }

    var displayedItems: [FileItem] {
        var result = searchResults ?? items
        if searchResults == nil {
            if !activeTagFilters.isEmpty {
                result = result.filter { item in
                    item.tags.contains {
                        itemTag in activeTagFilters.contains {
                            FinderTagMetadata.matches(itemTag: itemTag, selectedTag: $0)
                        }
                    }
                }
            }
            if !filterText.isEmpty {
                result = result.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
            }
        }
        result.sort { a, b in
            if foldersFirst && a.isDirectory != b.isDirectory { return a.isDirectory }
            let ascending = sortAscending
            switch sortKey {
            case .name:
                return a.name.localizedStandardCompare(b.name) == (ascending ? .orderedAscending : .orderedDescending)
            case .size:
                let sizeA = a.size ?? 0
                let sizeB = b.size ?? 0
                if sizeA != sizeB { return ascending ? sizeA < sizeB : sizeA > sizeB }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .kind:
                if a.kind != b.kind { return ascending ? a.kind < b.kind : a.kind > b.kind }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .modified:
                let dateA = a.modified ?? .distantPast
                let dateB = b.modified ?? .distantPast
                if dateA != dateB { return ascending ? dateA < dateB : dateA > dateB }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .info:
                // Metadata loads asynchronously; PaneView re-sorts by loaded values.
                // Fall back to name so displayedItems is always deterministic.
                return a.name.localizedStandardCompare(b.name) == (ascending ? .orderedAscending : .orderedDescending)
            }
        }
        return result
    }

    /// Selected items that are files only — used for byte-count display.
    var selectedFileItems: [FileItem] {
        (searchResults ?? items).filter { selection.contains($0.url) && !$0.isDirectory }
    }

    /// All selected items including folders — used for move/copy/delete.
    var selectedItems: [FileItem] {
        (searchResults ?? items).filter { selection.contains($0.url) }
    }

    func start() {
        load()
    }

    /// Kicks off a background directory read. Cancels any in-flight load first
    /// so rapid navigation never delivers stale results.
    func load() {
        loadingTask?.cancel()
        errorMessage = nil
        isLoading = true
        let urlToLoad = currentURL
        let showHidden = showHiddenFiles
        let showHiddenFolders = self.showHiddenFolders
        loadingTask = Task {
            do {
                let loaded: [FileItem]
                if let url = urlToLoad {
                    loaded = try await Task.detached(priority: .userInitiated) {
                        try PaneState.loadFolder(url, showHidden: showHidden, showHiddenFolders: showHiddenFolders)
                    }.value
                } else {
                    loaded = await Task.detached(priority: .userInitiated) {
                        PaneState.loadVolumes()
                    }.value
                }
                guard !Task.isCancelled else { return }
                self.items = loaded
                self.isLoading = false
            } catch is CancellationError {
                self.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self.items = []
                self.isLoading = false
                self.errorMessage = "Couldn't read \(urlToLoad?.lastPathComponent ?? ""): \(error.localizedDescription)"
            }
        }
    }

    func navigate(to url: URL?, pushHistory: Bool = true) {
        endDeepSearch()
        currentURL = url
        selection.removeAll()
        selectionAnchor = nil
        filterText = ""
        if let url = url, let pref = SortPreference.load(url: url) {
            sortKey = pref.key
            sortAscending = pref.ascending
        }
        if pushHistory {
            if historyIndex + 1 < history.count {
                history.removeSubrange((historyIndex + 1)...)
            }
            history.append(url)
            historyIndex = history.count - 1
        }
        load()
    }

    func goBack() {
        guard canGoBack else { return }
        endDeepSearch()
        historyIndex -= 1
        currentURL = history[historyIndex]
        selection.removeAll()
        selectionAnchor = nil
        filterText = ""
        load()
    }

    func goForward() {
        guard canGoForward else { return }
        endDeepSearch()
        historyIndex += 1
        currentURL = history[historyIndex]
        selection.removeAll()
        selectionAnchor = nil
        filterText = ""
        load()
    }

    func goUp() {
        guard let url = currentURL else { return }
        if url.path == "/Volumes" {
            navigate(to: nil)
            return
        }
        let parent = url.deletingLastPathComponent()
        if parent.path == "/Volumes" || parent == url {
            navigate(to: nil)
        } else {
            navigate(to: parent)
        }
    }

    func duplicate() {
        guard let dir = currentURL else {
            errorMessage = "Duplicate is not available at the Computer level."
            return
        }
        guard !selectedItems.isEmpty else { return }
        let targets = selectedItems
        Task.detached(priority: .userInitiated) { [weak self] in
            var errors: [String] = []
            for item in targets {
                let url = item.url
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
                    errors.append(error.localizedDescription)
                }
            }
            let capturedErrors = errors
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !capturedErrors.isEmpty {
                    self.errorMessage = capturedErrors.joined(separator: "\n")
                }
                if let dir = self.currentURL {
                    NotificationCenter.default.post(name: .paneContentsChanged, object: nil, userInfo: ["url": dir])
                }
                self.load()
            }
        }
    }

    func setSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        if let url = currentURL {
            SortPreference.save(url: url, key: sortKey, ascending: sortAscending)
        }
    }

    func select(_ item: FileItem, from displayedItems: [FileItem], mode: PaneSelectionMode) {
        switch mode {
        case .replace:
            selection = [item.url]
            selectionAnchor = item.url
        case .toggle:
            if selection.contains(item.url) {
                selection.remove(item.url)
            } else {
                selection.insert(item.url)
            }
            selectionAnchor = item.url
        case .range:
            guard
                let anchor = selectionAnchor,
                let anchorIndex = displayedItems.firstIndex(where: { $0.url == anchor }),
                let targetIndex = displayedItems.firstIndex(where: { $0.url == item.url })
            else {
                selection = [item.url]
                selectionAnchor = item.url
                return
            }
            let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
            selection = Set(displayedItems[range].map(\.url))
        }
    }

    func selectAll() {
        selection = Set(displayedItems.map { $0.url })
    }

    @discardableResult
    func rename(item: FileItem, to newName: String) -> Task<Void, Never>? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return nil }
        guard !trimmed.contains("/") else {
            errorMessage = "Name cannot contain '/'"
            return nil
        }
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        let folderURL = currentURL
        return Task.detached { [weak self] in
            do {
                try FileManager.default.moveItem(at: item.url, to: newURL)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if self.isInSearchMode { self.endDeepSearch() }
                    self.load()
                    self.selection = [newURL]
                    self.selectionAnchor = newURL
                    if let url = folderURL {
                        NotificationCenter.default.post(name: .paneContentsChanged,
                                                        object: nil,
                                                        userInfo: ["url": url])
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "Couldn't rename \(item.name): \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Deep Search

    func beginDeepSearch(query: String) {
        guard let rootURL = currentURL else { return }
        endDeepSearch()
        isSearching = true
        searchRootURL = rootURL

        let q = NSMetadataQuery()
        q.searchScopes = [rootURL]
        q.predicate = NSPredicate(format: "%K LIKE[cd] %@", NSMetadataItemFSNameKey, "*\(query)*")
        q.operationQueue = .main

        let center = NotificationCenter.default
        spotlightObservers = [
            center.addObserver(forName: .NSMetadataQueryGatheringProgress, object: q, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.applySearchResults() }
            },
            center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applySearchResults()
                    self?.isSearching = false
                }
            },
            center.addObserver(forName: .NSMetadataQueryDidUpdate, object: q, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.applySearchResults() }
            }
        ]
        spotlightQuery = q
        q.start()
    }

    private func applySearchResults() {
        guard let q = spotlightQuery, let rootURL = searchRootURL else { return }
        q.disableUpdates()
        var results: [FileItem] = []
        for i in 0..<q.resultCount {
            guard let mdItem = q.result(at: i) as? NSMetadataItem,
                  let path = mdItem.value(forAttribute: NSMetadataItemPathKey) as? String
            else { continue }
            let url = URL(fileURLWithPath: path)
            guard url != rootURL else { continue }
            let name = mdItem.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? url.lastPathComponent
            let size = (mdItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value
            let modified = mdItem.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            let kind = isDir.boolValue
                ? "Folder"
                : (url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased() + " File")
            results.append(FileItem(
                id: url, name: name, url: url,
                isDirectory: isDir.boolValue, isVolume: false, isRemovable: false,
                size: isDir.boolValue ? nil : size,
                kind: kind, modified: modified, tags: [],
                isRestricted: isDir.boolValue && !FileManager.default.isReadableFile(atPath: path)
            ))
        }
        q.enableUpdates()
        searchResults = results
    }

    func endDeepSearch() {
        guard spotlightQuery != nil || searchResults != nil || isSearching else { return }
        spotlightObservers.forEach { NotificationCenter.default.removeObserver($0) }
        spotlightObservers = []
        spotlightQuery?.stop()
        spotlightQuery = nil
        searchRootURL = nil
        searchResults = nil
        isSearching = false
    }

#if DEBUG
    func _setSearchResults(_ results: [FileItem]?) {
        searchResults = results
        isSearching = false
    }
#endif

    // MARK: - Loading

    /// Thread-safe: reads only from FileManager, no actor-isolated state.
    nonisolated static func loadVolumes() -> [FileItem] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = values?.volumeName ?? url.lastPathComponent
            let removable = values?.volumeIsRemovable ?? false
            return FileItem(
                id: url, name: name, url: url,
                isDirectory: true, isVolume: true, isRemovable: removable,
                size: nil, kind: removable ? "Removable Volume" : "Volume",
                modified: nil, tags: []
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Thread-safe: reads only from FileManager, no actor-isolated state.
    nonisolated static func loadFolder(_ url: URL, showHidden: Bool = false, showHiddenFolders: Bool = false) throws -> [FileItem] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .localizedTypeDescriptionKey, .tagNamesKey
        ]
        let needsAllItems = showHidden || showHiddenFolders
        let options: FileManager.DirectoryEnumerationOptions = needsAllItems ? [] : [.skipsHiddenFiles]
        let fileManager = FileManager.default
        let raw = try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: options
        )
        let mapped = raw.map { itemURL in
            let values = try? itemURL.resourceValues(forKeys: Set(keys))
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)
            let isDir = values?.isDirectory ?? (exists && isDirectory.boolValue)
            return FileItem(
                id: itemURL,
                name: itemURL.lastPathComponent,
                url: itemURL,
                isDirectory: isDir,
                isVolume: false,
                isRemovable: false,
                size: isDir ? nil : Int64(values?.fileSize ?? 0),
                kind: values?.localizedTypeDescription ?? (isDir ? "Folder" : itemURL.pathExtension.uppercased() + " File"),
                modified: values?.contentModificationDate,
                tags: values?.tagNames ?? [],
                isRestricted: isDir && !fileManager.isReadableFile(atPath: itemURL.path)
            )
        }
        if showHiddenFolders && !showHidden {
            return mapped.filter { !$0.name.hasPrefix(".") || $0.isDirectory }
        }
        return mapped
    }
}

// MARK: - Sort Persistence

enum SortPreference {
    static let orderKey = "sortPrefKeysList"
    static let maxCount = 200

    static func save(url: URL, key: SortKey, ascending: Bool, userDefaults: UserDefaults = .standard) {
        let prefKey = "sortPref_\(url.path)"
        userDefaults.set([key.rawValue, ascending ? "1" : "0"], forKey: prefKey)
        var order = userDefaults.stringArray(forKey: orderKey) ?? []
        order.removeAll { $0 == prefKey }
        order.append(prefKey)
        if order.count > maxCount {
            let evicted = order.removeFirst()
            userDefaults.removeObject(forKey: evicted)
        }
        userDefaults.set(order, forKey: orderKey)
    }

    static func load(url: URL, userDefaults: UserDefaults = .standard) -> (key: SortKey, ascending: Bool)? {
        guard
            let arr = userDefaults.stringArray(forKey: "sortPref_\(url.path)"),
            arr.count == 2,
            let key = SortKey(rawValue: arr[0])
        else { return nil }
        return (key: key, ascending: arr[1] == "1")
    }
}
