import Foundation
import Combine
import SwiftUI

enum TabTint: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, blue, purple, pink, graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .red:      return "Red"
        case .orange:   return "Orange"
        case .yellow:   return "Yellow"
        case .green:    return "Green"
        case .blue:     return "Blue"
        case .purple:   return "Purple"
        case .pink:     return "Pink"
        case .graphite: return "Graphite"
        }
    }

    var color: Color {
        switch self {
        case .red:      return .red
        case .orange:   return .orange
        case .yellow:   return .yellow
        case .green:    return .green
        case .blue:     return .blue
        case .purple:   return .purple
        case .pink:     return .pink
        case .graphite: return .gray
        }
    }
}

enum TabPersistence {
    static let labelsSuffix = "_labels"
    static let pinsSuffix = "_pins"
    static let pinnedPathsSuffix = "_pinnedPaths"
    static let tintsSuffix = "_tints"

    static func paths(forKey key: String, userDefaults: UserDefaults = .standard) -> [String?] {
        guard let data = userDefaults.data(forKey: key),
              let paths = try? JSONDecoder().decode([String?].self, from: data) else {
            return []
        }
        return paths
    }

    static func labels(forKey key: String, userDefaults: UserDefaults = .standard) -> [String?] {
        guard let data = userDefaults.data(forKey: key + labelsSuffix),
              let labels = try? JSONDecoder().decode([String?].self, from: data) else {
            return []
        }
        return labels
    }

    static func pins(forKey key: String, userDefaults: UserDefaults = .standard) -> [Bool] {
        guard let data = userDefaults.data(forKey: key + pinsSuffix),
              let pins = try? JSONDecoder().decode([Bool].self, from: data) else {
            return []
        }
        return pins
    }

    static func pinnedPaths(forKey key: String, userDefaults: UserDefaults = .standard) -> [String?] {
        guard let data = userDefaults.data(forKey: key + pinnedPathsSuffix),
              let pinnedPaths = try? JSONDecoder().decode([String?].self, from: data) else {
            return []
        }
        return pinnedPaths
    }

    static func tints(forKey key: String, userDefaults: UserDefaults = .standard) -> [String?] {
        guard let data = userDefaults.data(forKey: key + tintsSuffix),
              let tints = try? JSONDecoder().decode([String?].self, from: data) else {
            return []
        }
        return tints
    }

    static func save(
        paths: [String?],
        labels: [String?],
        pins: [Bool],
        pinnedPaths: [String?],
        tints: [String?],
        forKey key: String,
        userDefaults: UserDefaults = .standard
    ) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(paths) {
            userDefaults.set(data, forKey: key)
        }
        if let data = try? encoder.encode(labels) {
            userDefaults.set(data, forKey: key + labelsSuffix)
        }
        if let data = try? encoder.encode(pins) {
            userDefaults.set(data, forKey: key + pinsSuffix)
        }
        if let data = try? encoder.encode(pinnedPaths) {
            userDefaults.set(data, forKey: key + pinnedPathsSuffix)
        }
        if let data = try? encoder.encode(tints) {
            userDefaults.set(data, forKey: key + tintsSuffix)
        }
    }

    static func pinnedStartupURLs(
        forKey key: String,
        excluding firstURL: URL?,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> [URL?] {
        let savedPaths = paths(forKey: key, userDefaults: userDefaults)
        let savedPins = pins(forKey: key, userDefaults: userDefaults)
        let savedPinnedPaths = pinnedPaths(forKey: key, userDefaults: userDefaults)
        guard !savedPaths.isEmpty, !savedPins.isEmpty else { return [] }

        var restoredURLs: [URL?] = []
        var seenIdentities = Set<String>()
        let excludedIdentity = identity(for: firstURL)

        for index in savedPaths.indices {
            guard index < savedPins.count, savedPins[index] else { continue }
            let path = pinnedPath(
                at: index,
                savedPaths: savedPaths,
                savedPinnedPaths: savedPinnedPaths
            )
            let url: URL?
            if let path {
                guard fileManager.fileExists(atPath: path) else { continue }
                url = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                url = nil
            }

            let tabIdentity = identity(for: url)
            guard tabIdentity != excludedIdentity, !seenIdentities.contains(tabIdentity) else { continue }
            seenIdentities.insert(tabIdentity)
            restoredURLs.append(url)
        }

        return restoredURLs
    }

    private static func identity(for url: URL?) -> String {
        url?.standardizedFileURL.path ?? "__computer_root__"
    }

    private static func pinnedPath(
        at index: Int,
        savedPaths: [String?],
        savedPinnedPaths: [String?]
    ) -> String? {
        if index < savedPinnedPaths.count {
            return savedPinnedPaths[index]
        }
        return savedPaths[index]
    }
}

@MainActor
final class TabbedPaneState: ObservableObject {
    struct Tab: Identifiable {
        let id = UUID()
        let pane: PaneState
        var customLabel: String? = nil
        var isPinned: Bool = false
        var pinnedURL: URL? = nil
        var tint: TabTint? = nil
    }

    private(set) var tabs: [Tab]
    private(set) var activeTabIndex: Int = 0

    var showHiddenFiles: Bool = false {
        didSet {
            guard oldValue != showHiddenFiles else { return }
            tabs.forEach {
                $0.pane.showHiddenFiles = showHiddenFiles
                $0.pane.load()
            }
        }
    }

    var showHiddenFolders: Bool = false {
        didSet {
            guard oldValue != showHiddenFolders else { return }
            tabs.forEach {
                $0.pane.showHiddenFolders = showHiddenFolders
                $0.pane.load()
            }
        }
    }

    var foldersFirst: Bool = true {
        didSet {
            guard oldValue != foldersFirst else { return }
            tabs.forEach { $0.pane.foldersFirst = foldersFirst }
        }
    }

    var activeTagFilters: Set<String> = [] {
        didSet {
            guard oldValue != activeTagFilters else { return }
            tabs.forEach { $0.pane.activeTagFilters = activeTagFilters }
        }
    }

    private var activeTabCancellable: AnyCancellable?
    private var urlCancellables: Set<AnyCancellable> = []
    private let tabsKey: String?

    convenience init(initialURL: URL? = nil) {
        self.init(initialURLs: [initialURL], tabsKey: nil)
    }

    init(initialURLs: [URL?] = [nil], tabsKey: String? = nil) {
        self.tabsKey = tabsKey
        let urls = initialURLs.isEmpty ? [nil as URL?] : initialURLs
        tabs = urls.map { Tab(pane: PaneState(initialURL: $0)) }
        activeTabIndex = 0
        applyPersistedTabMetadata()
        subscribeToActiveTab()
        subscribeAllTabURLs()
    }

    /// Stable identity of the active tab. Views must key on this rather than on
    /// `activeTabIndex`: closing a tab can leave the index unchanged while it now
    /// refers to a different tab, so an index-keyed view is never rebuilt and keeps
    /// state captured from the tab that is gone.
    var activeTabID: UUID {
        tabs.indices.contains(activeTabIndex) ? tabs[activeTabIndex].id : UUID()
    }

    var activePaneState: PaneState {
        tabs[activeTabIndex].pane
    }

    func start() {
        activePaneState.start()
    }

    func openTab(url: URL? = nil) {
        objectWillChange.send()
        let pane = PaneState(initialURL: url ?? activePaneState.currentURL)
        pane.showHiddenFiles = showHiddenFiles
        pane.showHiddenFolders = showHiddenFolders
        pane.foldersFirst = foldersFirst
        pane.activeTagFilters = activeTagFilters
        tabs.append(Tab(pane: pane))
        activeTabIndex = tabs.count - 1
        subscribeToActiveTab()
        subscribeAllTabURLs()
        pane.start()
        saveTabs()
    }

    func closeTab(at index: Int) {
        guard canCloseTab(at: index) else { return }
        objectWillChange.send()
        let wasActive = index == activeTabIndex
        tabs.remove(at: index)
        if index < activeTabIndex {
            activeTabIndex -= 1
        } else if wasActive {
            activeTabIndex = min(activeTabIndex, tabs.count - 1)
            subscribeToActiveTab()
        }
        subscribeAllTabURLs()
        saveTabs()
    }

    func canCloseTab(at index: Int) -> Bool {
        tabs.indices.contains(index) && tabs.count > 1 && !tabs[index].isPinned
    }

    func setTabLabel(_ label: String, at index: Int) {
        guard tabs.indices.contains(index) else { return }
        objectWillChange.send()
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        tabs[index].customLabel = trimmed.isEmpty ? nil : trimmed
        saveTabLabels()
    }

    func setTabPinned(_ isPinned: Bool, at index: Int) {
        guard tabs.indices.contains(index), tabs[index].isPinned != isPinned else { return }
        objectWillChange.send()
        tabs[index].isPinned = isPinned
        tabs[index].pinnedURL = isPinned ? tabs[index].pane.currentURL : nil
        saveTabs()
    }

    func toggleTabPinned(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        setTabPinned(!tabs[index].isPinned, at: index)
    }

    func setTabTint(_ tint: TabTint?, at index: Int) {
        guard tabs.indices.contains(index) else { return }
        objectWillChange.send()
        tabs[index].tint = tint
        saveTabs()
    }

    func switchTab(to index: Int) {
        guard index != activeTabIndex, tabs.indices.contains(index) else { return }
        objectWillChange.send()
        activeTabIndex = index
        subscribeToActiveTab()
    }

    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard tabs.indices.contains(sourceIndex),
              (0...tabs.count).contains(destinationIndex),
              destinationIndex != sourceIndex,
              destinationIndex != sourceIndex + 1 else {
            return
        }

        objectWillChange.send()
        let activeTabID = tabs[activeTabIndex].id
        tabs.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex)
        activeTabIndex = tabs.firstIndex { $0.id == activeTabID } ?? min(activeTabIndex, tabs.count - 1)
        subscribeToActiveTab()
        subscribeAllTabURLs()
        saveTabs()
    }

    func activateTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        if index != activeTabIndex {
            objectWillChange.send()
            activeTabIndex = index
            subscribeToActiveTab()
        }
        restorePinnedTabIfNeeded(at: index)
    }

    private func subscribeToActiveTab() {
        guard activeTabIndex < tabs.count else { return }
        activeTabCancellable = tabs[activeTabIndex].pane.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    private func subscribeAllTabURLs() {
        urlCancellables.removeAll()
        for tab in tabs {
            tab.pane.$currentURL
                .dropFirst()
                .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
                .sink { [weak self] _ in self?.saveTabState() }
                .store(in: &urlCancellables)
        }
    }

    private func applyPersistedTabMetadata() {
        guard let key = tabsKey else { return }

        let savedPaths = TabPersistence.paths(forKey: key)
        let savedLabels = TabPersistence.labels(forKey: key)
        let savedPins = TabPersistence.pins(forKey: key)
        let savedPinnedPaths = TabPersistence.pinnedPaths(forKey: key)
        let savedTints = TabPersistence.tints(forKey: key)
        var usedMetadataIndexes = Set<Int>()

        for index in tabs.indices {
            let path = tabs[index].pane.currentURL?.path
            let metadataIndex = matchingMetadataIndex(
                for: path,
                savedPaths: savedPaths,
                usedMetadataIndexes: &usedMetadataIndexes
            ) ?? fallbackMetadataIndex(
                for: index,
                savedPaths: savedPaths,
                savedLabels: savedLabels,
                savedPins: savedPins,
                usedMetadataIndexes: &usedMetadataIndexes
            )

            guard let metadataIndex else { continue }
            if metadataIndex < savedLabels.count {
                tabs[index].customLabel = savedLabels[metadataIndex]
            }
            if metadataIndex < savedPins.count {
                let isPinned = savedPins[metadataIndex]
                tabs[index].isPinned = isPinned
                tabs[index].pinnedURL = isPinned
                    ? restoredPinnedURL(
                        for: metadataIndex,
                        savedPaths: savedPaths,
                        savedPinnedPaths: savedPinnedPaths
                    )
                    : nil
            }
            if metadataIndex < savedTints.count, let rawValue = savedTints[metadataIndex] {
                tabs[index].tint = TabTint(rawValue: rawValue)
            }
        }
    }

    private func restorePinnedTabIfNeeded(at index: Int) {
        guard tabs[index].isPinned, tabs[index].pane.currentURL != tabs[index].pinnedURL else { return }
        tabs[index].pane.navigate(to: tabs[index].pinnedURL)
    }

    private func restoredPinnedURL(
        for metadataIndex: Int,
        savedPaths: [String?],
        savedPinnedPaths: [String?]
    ) -> URL? {
        let path: String?
        // Only use savedPinnedPaths when its count matches savedPaths; a mismatch
        // indicates a partial write (e.g. crash mid-save) and we fall back to savedPaths.
        let pinnedPathsConsistent = savedPinnedPaths.isEmpty || savedPinnedPaths.count == savedPaths.count
        if pinnedPathsConsistent, metadataIndex < savedPinnedPaths.count {
            path = savedPinnedPaths[metadataIndex]
        } else if metadataIndex < savedPaths.count {
            path = savedPaths[metadataIndex]
        } else {
            path = nil
        }
        guard let path else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func matchingMetadataIndex(
        for path: String?,
        savedPaths: [String?],
        usedMetadataIndexes: inout Set<Int>
    ) -> Int? {
        guard let match = savedPaths.indices.first(where: {
            !usedMetadataIndexes.contains($0) && savedPaths[$0] == path
        }) else {
            return nil
        }
        usedMetadataIndexes.insert(match)
        return match
    }

    private func fallbackMetadataIndex(
        for tabIndex: Int,
        savedPaths: [String?],
        savedLabels: [String?],
        savedPins: [Bool],
        usedMetadataIndexes: inout Set<Int>
    ) -> Int? {
        guard savedPaths.count == tabs.count else {
            return nil
        }
        guard !usedMetadataIndexes.contains(tabIndex) else { return nil }
        usedMetadataIndexes.insert(tabIndex)
        return tabIndex
    }

    private func saveTabs() {
        saveTabState()
    }

    private func saveTabLabels() {
        saveTabState()
    }

    private func saveTabState() {
        guard let key = tabsKey else { return }
        let paths = tabs.map { $0.pane.currentURL?.path }
        let labels = tabs.map { $0.customLabel }
        let pins = tabs.map { $0.isPinned }
        let pinnedPaths = tabs.map { $0.isPinned ? $0.pinnedURL?.path : nil }
        let tints = tabs.map { $0.tint?.rawValue }
        TabPersistence.save(
            paths: paths,
            labels: labels,
            pins: pins,
            pinnedPaths: pinnedPaths,
            tints: tints,
            forKey: key
        )
    }
}
