import Foundation

@MainActor
final class SidebarModel: ObservableObject {
    @Published private(set) var bookmarks: [URL] = []

    private static let defaultsKey = "sidebar.bookmarks"

    let systemLocations: [(name: String, url: URL, icon: String)]

    init() {
        let fm = FileManager.default
        var locs: [(String, URL, String)] = []
        locs.append(("Home", fm.homeDirectoryForCurrentUser, "house.fill"))
        if let u = fm.urls(for: .desktopDirectory, in: .userDomainMask).first    { locs.append(("Desktop", u, "menubar.rectangle")) }
        if let u = fm.urls(for: .documentDirectory, in: .userDomainMask).first   { locs.append(("Documents", u, "doc.fill")) }
        if let u = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first  { locs.append(("Downloads", u, "arrow.down.circle.fill")) }
        let oneDrivePath = fm.homeDirectoryForCurrentUser.appendingPathComponent("OneDrive")
        if fm.fileExists(atPath: oneDrivePath.path) {
            let resolved = (try? URL(resolvingAliasFileAt: oneDrivePath)) ?? oneDrivePath
            locs.append(("OneDrive", resolved, "cloud.fill"))
        }
        systemLocations = locs

        if let data = UserDefaults.standard.data(forKey: SidebarModel.defaultsKey),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            bookmarks = paths
                .map { URL(fileURLWithPath: $0) }
                .filter { fm.fileExists(atPath: $0.path) }
        }
    }

    func addBookmark(_ url: URL) {
        guard !bookmarks.contains(url) else { return }
        bookmarks.append(url)
        persist()
    }

    func removeBookmark(_ url: URL) {
        bookmarks.removeAll { $0 == url }
        persist()
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
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks.map { $0.path }) {
            UserDefaults.standard.set(data, forKey: SidebarModel.defaultsKey)
        }
    }
}
