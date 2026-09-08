import Foundation

struct FileOperationResult {
    let succeeded: Int
    let errors: [String]
    let resultingURLs: [URL]
    // Populated by trash(): pairs each trashed item's original location with its
    // location inside the Trash, so a partial or full deletion can be undone.
    let trashedItems: [TrashedItem]

    init(succeeded: Int, errors: [String], resultingURLs: [URL], trashedItems: [TrashedItem] = []) {
        self.succeeded = succeeded
        self.errors = errors
        self.resultingURLs = resultingURLs
        self.trashedItems = trashedItems
    }

    var hasSucceeded: Bool { succeeded > 0 }
    var lastError: String? { errors.last }
}

/// One item that was moved to the Trash: its original path and where it now lives inside
/// the Trash, so `restoreFromTrash` can move it back.
struct TrashedItem: Equatable {
    let original: URL
    let trashURL: URL
}

enum ConflictResolution {
    case automatic
    case overwrite
    case skip
    case rename
}

enum FileOperationService {
    typealias TrashHandler = (URL) throws -> URL?

    @discardableResult
    static func createFolder(named rawName: String, in baseURL: URL) throws -> URL {
        let newURL = try validatedNewItemURL(named: rawName, in: baseURL)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
        return newURL
    }

    @discardableResult
    static func createFile(named rawName: String, in baseURL: URL) throws -> URL {
        let newURL = try validatedNewItemURL(named: rawName, in: baseURL)
        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        guard FileManager.default.createFile(atPath: newURL.path, contents: nil) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        return newURL
    }

    // Returns names of files that already exist in destinationFolder.
    static func detectConflicts(files: [FileItem], in destinationFolder: URL) -> [String] {
        files.compactMap { file in
            let dest = destinationFolder.appendingPathComponent(file.name)
            return FileManager.default.fileExists(atPath: dest.path) ? file.name : nil
        }
    }

    static func moveOrCopy(
        files: [FileItem],
        to destinationFolder: URL,
        isMove: Bool,
        conflictResolution: ConflictResolution = .automatic,
        onProgress: ((Int, Int) -> Void)? = nil
    ) -> FileOperationResult {
        let dstPath = destinationFolder.standardizedFileURL.resolvingSymlinksInPath().path
        var succeeded = 0
        var errors: [String] = []
        var resultingURLs: [URL] = []

        for (index, file) in files.enumerated() {
            defer { onProgress?(index + 1, files.count) }
            // Guard: refuse to copy/move a folder into its own subtree; skip this item only.
            if file.isDirectory {
                let srcPath = file.url.standardizedFileURL.resolvingSymlinksInPath().path
                if dstPath == srcPath || dstPath.hasPrefix(srcPath + "/") {
                    errors.append("Cannot \(isMove ? "move" : "copy") '\(file.name)' into itself or one of its subfolders.")
                    continue
                }
            }
            let proposed = destinationFolder.appendingPathComponent(file.name)
            let exists = FileManager.default.fileExists(atPath: proposed.path)

            let destination: URL
            if exists {
                switch conflictResolution {
                case .automatic:
                    if isMove {
                        destination = proposed
                    } else {
                        errors.append("Couldn't copy \(file.name): a file with the same name already exists.")
                        continue
                    }
                case .overwrite:
                    destination = proposed
                case .skip:
                    continue
                case .rename:
                    destination = uniqueDestination(for: file.url, in: destinationFolder)
                }
            } else {
                destination = proposed
            }

            guard !sameFileLocation(file.url, destination) else {
                errors.append("Cannot \(isMove ? "move" : "copy") '\(file.name)': source and destination are the same.")
                continue
            }

            // Overwriting a folder with a folder merges rather than replaces. Replacing
            // deletes every file that exists only in the destination, permanently and
            // without Trash recovery. Packages (.app, .rtfd) are directories on disk but
            // opaque to the user, so those still replace wholesale.
            if conflictResolution == .overwrite,
               isMergeableDirectory(file.url),
               isMergeableDirectory(destination) {
                do {
                    try mergeDirectory(from: file.url, to: destination, isMove: isMove)
                    succeeded += 1
                    resultingURLs.append(destination)
                } catch {
                    errors.append("Couldn't merge \(file.name): \(error.localizedDescription)")
                }
                continue
            }

            // Step 1: atomically back up any existing destination (same-volume rename).
            // This ensures the destination is restored if the subsequent operation fails,
            // preventing permanent data loss on a copy/move error.
            var backupURL: URL? = nil
            if FileManager.default.fileExists(atPath: destination.path) {
                let tmp = destination.deletingLastPathComponent()
                    .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
                do {
                    try FileManager.default.moveItem(at: destination, to: tmp)
                    backupURL = tmp
                } catch {
                    errors.append("Couldn't \(isMove ? "move" : "copy") \(file.name): \(error.localizedDescription)")
                    continue
                }
            }

            // Step 2: perform the actual operation; restore backup on failure.
            do {
                if isMove {
                    try FileManager.default.moveItem(at: file.url, to: destination)
                } else {
                    try FileManager.default.copyItem(at: file.url, to: destination)
                }
                if let backup = backupURL { try? FileManager.default.removeItem(at: backup) }
                succeeded += 1
                resultingURLs.append(destination)
            } catch {
                if let backup = backupURL {
                    do {
                        try restoreBackup(backup, to: destination)
                    } catch {
                        errors.append(
                            "Couldn't restore the original '\(destination.lastPathComponent)' after a failed \(isMove ? "move" : "copy"). " +
                            "The backup is still at \(backup.path): \(error.localizedDescription)"
                        )
                        continue
                    }
                }
                errors.append("Couldn't \(isMove ? "move" : "copy") \(file.name): \(error.localizedDescription)")
            }
        }

        return FileOperationResult(succeeded: succeeded, errors: errors, resultingURLs: resultingURLs)
    }

    static func trash(urls: [URL], trashHandler: TrashHandler = defaultTrashHandler) -> FileOperationResult {
        var succeeded = 0
        var errors: [String] = []
        var resultingURLs: [URL] = []
        var trashedItems: [TrashedItem] = []

        for url in urls {
            do {
                let resultingURL = try trashHandler(url)
                succeeded += 1
                if let resultingURL {
                    resultingURLs.append(resultingURL)
                    trashedItems.append(TrashedItem(original: url, trashURL: resultingURL))
                }
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        return FileOperationResult(
            succeeded: succeeded, errors: errors,
            resultingURLs: resultingURLs, trashedItems: trashedItems
        )
    }

    /// Moves previously-trashed items back to their original locations. Skips any item
    /// whose original path is occupied again so a restore never overwrites a newer file.
    static func restoreFromTrash(_ items: [TrashedItem]) -> FileOperationResult {
        var succeeded = 0
        var errors: [String] = []
        var resultingURLs: [URL] = []

        for item in items {
            do {
                if FileManager.default.fileExists(atPath: item.original.path) {
                    throw CocoaError(.fileWriteFileExists)
                }
                try FileManager.default.moveItem(at: item.trashURL, to: item.original)
                succeeded += 1
                resultingURLs.append(item.original)
            } catch {
                errors.append(
                    "Couldn't restore '\(item.original.lastPathComponent)': \(error.localizedDescription)"
                )
            }
        }

        return FileOperationResult(succeeded: succeeded, errors: errors, resultingURLs: resultingURLs)
    }

    /// All-or-nothing overwrite copy used by folder sync. Every existing destination is
    /// backed up before it is overwritten and every newly-created file is tracked; if any
    /// single copy fails the whole batch is rolled back, so a crash-free failure never
    /// leaves the destination partially synced. Backups are deleted only once the entire
    /// plan has succeeded. Sync plans only ever contain files (directories are excluded
    /// upstream), so no directory-merge handling is needed here.
    static func transactionalCopy(
        files: [FileItem],
        to destinationFolder: URL,
        onProgress: ((Int, Int) -> Void)? = nil
    ) -> FileOperationResult {
        let fileManager = FileManager.default
        var performed: [(destination: URL, backup: URL?)] = []

        func rollback() {
            for op in performed.reversed() {
                try? fileManager.removeItem(at: op.destination)
                if let backup = op.backup {
                    try? fileManager.moveItem(at: backup, to: op.destination)
                }
            }
        }

        for (index, file) in files.enumerated() {
            let destination = destinationFolder.appendingPathComponent(file.name)

            guard !sameFileLocation(file.url, destination) else {
                rollback()
                return FileOperationResult(
                    succeeded: 0,
                    errors: ["Cannot sync '\(file.name)': source and destination are the same."],
                    resultingURLs: []
                )
            }

            var backup: URL? = nil
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    let tmp = destinationFolder.appendingPathComponent(
                        ".\(destination.lastPathComponent).\(UUID().uuidString).tmp"
                    )
                    try fileManager.moveItem(at: destination, to: tmp)
                    backup = tmp
                }
                try fileManager.copyItem(at: file.url, to: destination)
                performed.append((destination, backup))
                onProgress?(index + 1, files.count)
            } catch {
                // Undo this item's half-finished step, then roll back the committed ones.
                try? fileManager.removeItem(at: destination)
                if let backup { try? fileManager.moveItem(at: backup, to: destination) }
                rollback()
                return FileOperationResult(
                    succeeded: 0,
                    errors: ["Couldn't sync '\(file.name)': \(error.localizedDescription)"],
                    resultingURLs: []
                )
            }
        }

        for op in performed {
            if let backup = op.backup { try? fileManager.removeItem(at: backup) }
        }
        return FileOperationResult(
            succeeded: performed.count, errors: [], resultingURLs: performed.map(\.destination)
        )
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

    private static func isMergeableDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else {
            return false
        }
        return values.isDirectory == true && values.isPackage != true
    }

    /// Copies or moves every entry of `source` into `destination`, recursing into
    /// subdirectories and overwriting colliding files. Never removes a destination entry
    /// that has no counterpart in the source — that is the whole point of merging.
    private static func mergeDirectory(from source: URL, to destination: URL, isMove: Bool) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        let entries = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: []
        )

        for entry in entries {
            let target = destination.appendingPathComponent(entry.lastPathComponent)
            if isMergeableDirectory(entry), isMergeableDirectory(target) {
                try mergeDirectory(from: entry, to: target, isMove: isMove)
            } else {
                if fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }
                try transferItem(entry, to: target, isMove: isMove)
            }
        }

        if isMove, (try? fileManager.contentsOfDirectory(atPath: source.path))?.isEmpty == true {
            try? fileManager.removeItem(at: source)
        }
    }

    private static func transferItem(_ source: URL, to destination: URL, isMove: Bool) throws {
        if isMove {
            try FileManager.default.moveItem(at: source, to: destination)
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    // Returns a destination URL that doesn't exist by appending a numeric suffix.
    private static func uniqueDestination(for url: URL, in folder: URL) -> URL {
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 2
        var dest: URL
        repeat {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            dest = folder.appendingPathComponent(name)
            n += 1
        } while FileManager.default.fileExists(atPath: dest.path)
        return dest
    }

    private static func sameFileLocation(_ first: URL, _ second: URL) -> Bool {
        first.standardizedFileURL.resolvingSymlinksInPath().path ==
            second.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func validatedNewItemURL(named rawName: String, in baseURL: URL) throws -> URL {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CocoaError(.fileWriteInvalidFileName) }
        guard !name.contains("/") && !name.contains("\0") else { throw CocoaError(.fileWriteInvalidFileName) }

        let newURL = baseURL.appendingPathComponent(name)
        let standardized = newURL.standardizedFileURL
        guard sameFileLocation(standardized.deletingLastPathComponent(), baseURL),
              standardized.lastPathComponent == name else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return newURL
    }

    private static func restoreBackup(_ backup: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: backup, to: destination)
    }

    private static let defaultTrashHandler: TrashHandler = { url in
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }
}

struct ProcessExecutionResult {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        stdout + stderr
    }

    var trimmedCombinedOutput: String {
        combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) async throws -> ProcessExecutionResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        // Drain pipes concurrently to prevent pipe-buffer-full deadlocks with chatty processes.
        let stdoutTask = Task.detached { outPipe.fileHandleForReading.readDataToEndOfFile() }
        let stderrTask = Task.detached { errPipe.fileHandleForReading.readDataToEndOfFile() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                // Close write ends so the drain tasks unblock on run failure.
                outPipe.fileHandleForWriting.closeFile()
                errPipe.fileHandleForWriting.closeFile()
                continuation.resume(throwing: error)
            }
        }

        let stdoutData = await stdoutTask.value
        let stderrData = await stderrTask.value
        return ProcessExecutionResult(
            terminationStatus: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}
