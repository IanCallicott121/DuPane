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
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var showCommandRunner: Bool = false
    @Published var requestRename: Bool = false
    var showHiddenFiles: Bool = false

    private var history: [URL?]
    private var historyIndex: Int = 0
    private var selectionAnchor: URL?

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

    /// "Computer" plus each real path component, with the implicit /Volumes
    /// segment hidden so a card at /Volumes/SD-512-1 reads as Computer › SD-512-1.
    var breadcrumbs: [(label: String, url: URL?)] {
        var crumbs: [(label: String, url: URL?)] = [("Computer", nil)]
        guard let url = currentURL else { return crumbs }
        let components = url.standardizedFileURL.pathComponents.filter { $0 != "/" }
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
        var result = items
        if !filterText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
        }
        result.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
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
        items.filter { selection.contains($0.url) && !$0.isDirectory }
    }

    /// All selected items including folders — used for move/copy/delete.
    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.url) }
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
        loadingTask = Task {
            do {
                let loaded: [FileItem]
                if let url = urlToLoad {
                    loaded = try await Task.detached(priority: .userInitiated) {
                        try PaneState.loadFolder(url, showHidden: showHidden)
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
        historyIndex -= 1
        currentURL = history[historyIndex]
        selection.removeAll()
        selectionAnchor = nil
        load()
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentURL = history[historyIndex]
        selection.removeAll()
        selectionAnchor = nil
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

    func rename(item: FileItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        guard !trimmed.contains("/") else {
            errorMessage = "Name cannot contain '/'"
            return
        }
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            load()
            selection = [newURL]
            selectionAnchor = newURL
            if let url = currentURL {
                NotificationCenter.default.post(name: .paneContentsChanged,
                                                object: nil,
                                                userInfo: ["url": url])
            }
        } catch {
            errorMessage = "Couldn't rename \(item.name): \(error.localizedDescription)"
        }
    }

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
    nonisolated static func loadFolder(_ url: URL, showHidden: Bool = false) throws -> [FileItem] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .localizedTypeDescriptionKey, .tagNamesKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let fileManager = FileManager.default
        let raw = try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: options
        )
        return raw.map { itemURL in
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
    }
}

// MARK: - Sort Persistence

private enum SortPreference {
    static func save(url: URL, key: SortKey, ascending: Bool) {
        UserDefaults.standard.set(
            [key.rawValue, ascending ? "1" : "0"],
            forKey: "sortPref_\(url.path)"
        )
    }

    static func load(url: URL) -> (key: SortKey, ascending: Bool)? {
        guard
            let arr = UserDefaults.standard.stringArray(forKey: "sortPref_\(url.path)"),
            arr.count == 2,
            let key = SortKey(rawValue: arr[0])
        else { return nil }
        return (key: key, ascending: arr[1] == "1")
    }
}
