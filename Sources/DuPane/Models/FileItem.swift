import Foundation

struct FileItem: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
    let isVolume: Bool
    let isRemovable: Bool
    let size: Int64?
    let kind: String
    let modified: Date?
    var tags: [String]
    var isRestricted: Bool = false
    let dateAdded: Date?

    init(
        id: URL,
        name: String,
        url: URL,
        isDirectory: Bool,
        isVolume: Bool,
        isRemovable: Bool,
        size: Int64?,
        kind: String,
        modified: Date?,
        tags: [String],
        isRestricted: Bool = false,
        dateAdded: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.isVolume = isVolume
        self.isRemovable = isRemovable
        self.size = size
        self.kind = kind
        self.modified = modified
        self.tags = tags
        self.isRestricted = isRestricted
        self.dateAdded = dateAdded
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }
}
