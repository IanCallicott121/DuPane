import Foundation

struct FinderTag: Identifiable, Hashable {
    let name: String
    let count: Int

    var id: String { FinderTagMetadata.identity(for: name) }
}

enum FinderTagMetadata {
    static let userTagsAttribute = "kMDItemUserTags"

    static func tagDiscoveryPredicate() -> NSPredicate {
        NSPredicate(format: "%K == %@", userTagsAttribute, "*")
    }

    static func identity(for tagName: String) -> String {
        normalizedName(from: tagName)?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) ?? ""
    }

    static func normalizedName(from rawValue: String) -> String? {
        let name = rawValue
            .components(separatedBy: "\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    static func matches(itemTag: String, selectedTag: String) -> Bool {
        guard
            let itemName = normalizedName(from: itemTag),
            let selectedName = normalizedName(from: selectedTag)
        else { return false }

        return itemName.compare(
            selectedName,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) == .orderedSame
    }

    static func summaries(from rawTagValues: [(value: Any?, count: Int)]) -> [FinderTag] {
        var countsByIdentity: [String: (name: String, count: Int)] = [:]

        for rawTagValue in rawTagValues {
            let count = max(rawTagValue.count, 1)
            for name in tagNames(from: rawTagValue.value) {
                let identity = identity(for: name)
                guard !identity.isEmpty else { continue }
                if let existing = countsByIdentity[identity] {
                    countsByIdentity[identity] = (existing.name, existing.count + count)
                } else {
                    countsByIdentity[identity] = (name, count)
                }
            }
        }

        return countsByIdentity.values
            .map { FinderTag(name: $0.name, count: $0.count) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func summaries(from items: [FileItem]) -> [FinderTag] {
        let rawTagValues = items.flatMap { item in
            item.tags.map { tagName in (value: tagName as Any?, count: 1) }
        }
        return summaries(from: rawTagValues)
    }

    static func merged(spotlightTags: [FinderTag], paneTags: [FinderTag]) -> [FinderTag] {
        var tagsByIdentity = Dictionary(uniqueKeysWithValues: spotlightTags.map { ($0.id, $0) })
        for tag in paneTags {
            tagsByIdentity[tag.id] = tag
        }
        return tagsByIdentity.values
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func tagNames(from rawValue: Any?) -> [String] {
        if let rawValue = rawValue as? String {
            return normalizedName(from: rawValue).map { [$0] } ?? []
        }

        if let rawValues = rawValue as? [String] {
            return rawValues.compactMap { normalizedName(from: $0) }
        }

        if let rawValues = rawValue as? [Any] {
            return rawValues.compactMap { $0 as? String }.compactMap { normalizedName(from: $0) }
        }

        return []
    }
}

@MainActor
final class SidebarModel: ObservableObject {
    @Published private(set) var bookmarks: [URL] = []
    @Published private(set) var bookmarkNames: [String: String] = [:]
    @Published private(set) var tags: [FinderTag] = []
    @Published private(set) var recentURLs: [URL] = []
    @Published private(set) var systemLocations: [(name: String, url: URL, icon: String)] = []

    private static let defaultsKey  = "sidebar.bookmarks"
    private static let namesKey     = "sidebar.bookmarkNames"
    private static let recentsKey   = "sidebar.recentURLs"
    private let maxRecents = 12
    private var tagQuery: NSMetadataQuery?
    private var tagQueryObservers: [NSObjectProtocol] = []
    private var spotlightTags: [FinderTag] = []
    private var paneTags: [FinderTag] = []
    private let pathExists: @Sendable (String) -> Bool
    private var validationGeneration = 0
    private var optionalSystemLocations: [(name: String, url: URL, icon: String)] = []
    private(set) var validationTask: Task<Void, Never>?

    init(pathExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) {
        self.pathExists = pathExists
        let fm = FileManager.default
        var locs: [(String, URL, String)] = []
        locs.append(("Home", fm.homeDirectoryForCurrentUser, "house.fill"))
        let appDir = URL(fileURLWithPath: "/Applications")
        locs.append(("Applications", appDir, "app.badge"))
        if let u = fm.urls(for: .desktopDirectory,   in: .userDomainMask).first { locs.append(("Desktop",   u, "menubar.rectangle")) }
        if let u = fm.urls(for: .documentDirectory,  in: .userDomainMask).first { locs.append(("Documents", u, "doc.fill")) }
        if let u = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first { locs.append(("Downloads", u, "arrow.down.circle.fill")) }
        let iCloudPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let oneDrivePath = fm.homeDirectoryForCurrentUser.appendingPathComponent("OneDrive")
        systemLocations = locs
        optionalSystemLocations = [
            ("iCloud Drive", iCloudPath, "icloud.fill"),
            ("OneDrive", oneDrivePath, "cloud.fill")
        ]

        if let data = UserDefaults.standard.data(forKey: SidebarModel.defaultsKey),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            bookmarks = paths.map { URL(fileURLWithPath: $0) }
        }
        if let dict = UserDefaults.standard.dictionary(forKey: SidebarModel.namesKey) as? [String: String] {
            bookmarkNames = dict
        }
        if let data = UserDefaults.standard.data(forKey: SidebarModel.recentsKey),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            recentURLs = paths.map { URL(fileURLWithPath: $0) }
        }
        scheduleExistenceValidation()
    }

    deinit {
        validationTask?.cancel()
        tagQueryObservers.forEach { NotificationCenter.default.removeObserver($0) }
        tagQuery?.stop()
    }

    func startTagMonitoring() {
        guard tagQuery == nil else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryIndexedLocalComputerScope]
        query.predicate = FinderTagMetadata.tagDiscoveryPredicate()
        query.valueListAttributes = [FinderTagMetadata.userTagsAttribute]
        query.notificationBatchingInterval = 2
        query.operationQueue = .main

        let center = NotificationCenter.default
        tagQueryObservers = [
            center.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak self] notification in
                guard let query = notification.object as? NSMetadataQuery else { return }
                Task { @MainActor [weak self] in
                    self?.refreshTags(from: query)
                }
            },
            center.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: .main
            ) { [weak self] notification in
                guard let query = notification.object as? NSMetadataQuery else { return }
                Task { @MainActor [weak self] in
                    self?.refreshTags(from: query)
                }
            }
        ]

        tagQuery = query
        _ = query.start()
    }

    func updatePaneTags(from items: [FileItem]) {
        paneTags = FinderTagMetadata.summaries(from: items)
        publishTags()
    }

    private func refreshTags(from query: NSMetadataQuery) {
        query.disableUpdates()
        let valueTuples = query.valueLists[FinderTagMetadata.userTagsAttribute] ?? []
        let rawTagValues = valueTuples.map { (value: $0.value, count: $0.count) }
        spotlightTags = FinderTagMetadata.summaries(from: rawTagValues)
        query.enableUpdates()

        publishTags()
    }

    private func publishTags() {
        tags = FinderTagMetadata.merged(spotlightTags: spotlightTags, paneTags: paneTags)
    }

    // MARK: - Recents

    func recordVisit(_ url: URL) {
        var recent = recentURLs.filter { $0 != url }
        recent.insert(url, at: 0)
        if recent.count > maxRecents { recent = Array(recent.prefix(maxRecents)) }
        recentURLs = recent
        if let data = try? JSONEncoder().encode(recent.map { $0.path }) {
            UserDefaults.standard.set(data, forKey: SidebarModel.recentsKey)
        }
        scheduleExistenceValidation()
    }

    private func scheduleExistenceValidation() {
        validationGeneration += 1
        let generation = validationGeneration
        let bookmarkCandidates = bookmarks
        let recentCandidates = recentURLs
        let locationCandidates = optionalSystemLocations
        let pathExists = pathExists

        validationTask?.cancel()
        validationTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                let bookmarks = bookmarkCandidates.filter { pathExists($0.path) }
                let recents = recentCandidates.filter { pathExists($0.path) }
                let locations: [(name: String, url: URL, icon: String)] = locationCandidates.compactMap { location in
                    guard pathExists(location.url.path) else { return nil }
                    let resolved = (try? URL(resolvingAliasFileAt: location.url)) ?? location.url
                    return (name: location.name, url: resolved, icon: location.icon)
                }
                return (bookmarks, recents, locations)
            }.value
            guard let self, self.validationGeneration == generation else { return }
            self.bookmarks = result.0
            self.recentURLs = result.1
            self.systemLocations.removeAll { $0.name == "iCloud Drive" || $0.name == "OneDrive" }
            self.systemLocations.append(contentsOf: result.2)
        }
    }

    func removeRecent(_ url: URL) {
        recentURLs.removeAll { $0 == url }
        if let data = try? JSONEncoder().encode(recentURLs.map { $0.path }) {
            UserDefaults.standard.set(data, forKey: SidebarModel.recentsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: SidebarModel.recentsKey)
        }
        scheduleExistenceValidation()
    }

    func clearRecents() {
        recentURLs = []
        UserDefaults.standard.removeObject(forKey: SidebarModel.recentsKey)
        scheduleExistenceValidation()
    }

    // MARK: - Bookmarks

    func addBookmark(_ url: URL) {
        guard !bookmarks.contains(url) else { return }
        bookmarks.append(url)
        persist()
        scheduleExistenceValidation()
    }

    @discardableResult
    func addFolderBookmarks(_ urls: [URL]) -> Int {
        var addedCount = 0
        for url in urls {
            guard let directoryURL = Self.resolvedDirectoryURL(for: url) else { continue }
            let previousCount = bookmarks.count
            addBookmark(directoryURL)
            if bookmarks.count > previousCount {
                addedCount += 1
            }
        }
        return addedCount
    }

    func removeBookmark(_ url: URL) {
        bookmarks.removeAll { $0 == url }
        bookmarkNames.removeValue(forKey: url.path)
        persist()
        persistNames()
        scheduleExistenceValidation()
    }

    func toggleBookmark(_ url: URL) {
        if bookmarks.contains(url) { removeBookmark(url) } else { addBookmark(url) }
    }

    func isBookmarked(_ url: URL) -> Bool {
        bookmarks.contains(url)
    }

    func moveBookmark(from: IndexSet, to: Int) {
        bookmarks.move(fromOffsets: from, toOffset: to)
        persist()
        scheduleExistenceValidation()
    }

    func renameBookmark(_ url: URL, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == url.lastPathComponent {
            bookmarkNames.removeValue(forKey: url.path)
        } else {
            bookmarkNames[url.path] = trimmed
        }
        persistNames()
    }

    func displayName(for url: URL) -> String {
        bookmarkNames[url.path] ?? url.lastPathComponent
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks.map { $0.path }) {
            UserDefaults.standard.set(data, forKey: SidebarModel.defaultsKey)
        }
    }

    private func persistNames() {
        UserDefaults.standard.set(bookmarkNames, forKey: SidebarModel.namesKey)
    }

    private static func resolvedDirectoryURL(for url: URL) -> URL? {
        let resolved = (try? URL(resolvingAliasFileAt: url)) ?? url
        let isDirectory = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        return isDirectory ? resolved : nil
    }
}
