import Foundation

struct FileOperationResult {
    let succeeded: Int
    let errors: [String]
    let resultingURLs: [URL]

    var hasSucceeded: Bool { succeeded > 0 }
    var lastError: String? { errors.last }
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
        // Guard: refuse to copy/move a folder into its own subtree
        let dstPath = destinationFolder.standardizedFileURL.resolvingSymlinksInPath().path
        for file in files where file.isDirectory {
            let srcPath = file.url.standardizedFileURL.resolvingSymlinksInPath().path
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

        for (index, file) in files.enumerated() {
            defer { onProgress?(index + 1, files.count) }
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

        for url in urls {
            do {
                let resultingURL = try trashHandler(url)
                succeeded += 1
                if let resultingURL {
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

        try process.run()
        let stdoutTask = Task.detached {
            outPipe.fileHandleForReading.readDataToEndOfFile()
        }
        let stderrTask = Task.detached {
            errPipe.fileHandleForReading.readDataToEndOfFile()
        }
        process.waitUntilExit()

        let stdoutData = await stdoutTask.value
        let stderrData = await stderrTask.value
        return ProcessExecutionResult(
            terminationStatus: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}
