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

    var fileExtension: String {
        url.pathExtension.lowercased()
    }
}
