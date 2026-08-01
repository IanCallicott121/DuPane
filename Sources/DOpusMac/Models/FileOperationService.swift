import Foundation

struct FileOperationResult {
    let succeeded: Int
    let errors: [String]
    let resultingURLs: [URL]

    var hasSucceeded: Bool { succeeded > 0 }
    var lastError: String? { errors.last }
}

enum FileOperationService {
    @discardableResult
    static func createFolder(named rawName: String, in baseURL: URL) throws -> URL {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newURL = baseURL.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
        return newURL
    }

    @discardableResult
    static func createFile(named rawName: String, in baseURL: URL) throws -> URL {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CocoaError(.fileWriteInvalidFileName) }
        let newURL = baseURL.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        guard FileManager.default.createFile(atPath: newURL.path, contents: nil) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        return newURL
    }

    static func moveOrCopy(files: [FileItem], to destinationFolder: URL, isMove: Bool) -> FileOperationResult {
        // Guard: refuse to copy/move a folder into its own subtree
        let dstPath = destinationFolder.standardizedFileURL.path
        for file in files where file.isDirectory {
            let srcPath = file.url.standardizedFileURL.path
            if dstPath == srcPath || dstPath.hasPrefix(srcPath + "/") {
                return FileOperationResult(
                    succeeded: 0,
                    errors: ["Cannot \(isMove ? "move" : "copy") '\(file.name)' into itself or one of its subfolders."],
                    resultingURLs: []
                )
            }
        }

        var succeeded = 0
        var errors: [String] = []
        var resultingURLs: [URL] = []

        for file in files {
            let destination = destinationFolder.appendingPathComponent(file.name)
            do {
                if isMove {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: file.url, to: destination)
                } else {
                    try FileManager.default.copyItem(at: file.url, to: destination)
                }
                succeeded += 1
                resultingURLs.append(destination)
            } catch {
                errors.append("Couldn't \(isMove ? "move" : "copy") \(file.name): \(error.localizedDescription)")
            }
        }

        return FileOperationResult(succeeded: succeeded, errors: errors, resultingURLs: resultingURLs)
    }

    static func trash(urls: [URL]) -> FileOperationResult {
        var succeeded = 0
        var errors: [String] = []
        var resultingURLs: [URL] = []

        for url in urls {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                succeeded += 1
                if let resultingURL = resultingURL as URL? {
                    resultingURLs.append(resultingURL)
                }
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        return FileOperationResult(succeeded: succeeded, errors: errors, resultingURLs: resultingURLs)
    }

    /// Permanently removes items from the filesystem with no Trash recovery.
    static func delete(urls: [URL]) -> FileOperationResult {
        var succeeded = 0
        var errors: [String] = []
        var resultingURLs: [URL] = []

        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
                succeeded += 1
                resultingURLs.append(url)
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        return FileOperationResult(succeeded: succeeded, errors: errors, resultingURLs: resultingURLs)
    }
}
