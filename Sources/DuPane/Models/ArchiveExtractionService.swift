import Darwin
import Foundation
import ZIPFoundation

enum ArchiveExtractionServiceError: LocalizedError, Equatable {
    case duplicateEntry(String)
    case conflictingEntries(String)
    case unsafeSymbolicLink(String)
    case invalidMetadata
    case rollbackFailed

    var errorDescription: String? {
        switch self {
        case .duplicateEntry(let path):
            return "The archive contains more than one item named '\(path)'."
        case .conflictingEntries(let path):
            return "The archive contains conflicting entries for '\(path)'."
        case .unsafeSymbolicLink(let path):
            return "The archive contains an unsafe symbolic link: \(path)."
        case .invalidMetadata:
            return "The archive contains invalid DuPane metadata."
        case .rollbackFailed:
            return "The archive could not be extracted and the original files could not be restored."
        }
    }
}

enum ArchiveExtractionService {
    static let metadataPath = "__DUPANE_METADATA__/extended-attributes.json"

    static func entryNames(at archiveURL: URL) throws -> [String] {
        let archive = try Archive(url: archiveURL, accessMode: .read)
        let plan = try makePlan(from: archive)
        return plan.entries.map(\.path)
    }

    static func extract(
        archiveURL: URL,
        to destinationDirectory: URL,
        overwrite: Bool,
        fileManager: FileManager = .default
    ) throws {
        let archive = try Archive(url: archiveURL, accessMode: .read)
        let plan = try makePlan(from: archive)
        let temporaryURL = destinationDirectory.appendingPathComponent(
            ".(archiveURL.deletingPathExtension().lastPathComponent).(UUID().uuidString).tmp",
            isDirectory: true
        )
        let backupURL = destinationDirectory.appendingPathComponent(
            ".(archiveURL.deletingPathExtension().lastPathComponent).(UUID().uuidString).backup",
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
            for entry in plan.entries {
                let entryURL = temporaryURL.appendingPathComponent(entry.path)
                _ = try archive.extract(
                    entry,
                    to: entryURL,
                    allowUncontainedSymlinks: true
                )
            }
            try ArchiveExtendedAttributeStore.apply(plan.extendedAttributes, to: temporaryURL)
            try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

            var transaction = ExtractionTransaction()
            do {
                for topLevelPath in topLevelPaths(from: plan.entries) {
                    let sourceURL = temporaryURL.appendingPathComponent(topLevelPath)
                    let destinationURL = destinationDirectory.appendingPathComponent(topLevelPath)
                    try apply(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        relativePath: topLevelPath,
                        overwrite: overwrite,
                        backupURL: backupURL,
                        transaction: &transaction,
                        fileManager: fileManager
                    )
                }
            } catch {
                do {
                    try rollback(transaction, fileManager: fileManager)
                } catch {
                    throw ArchiveExtractionServiceError.rollbackFailed
                }
                throw error
            }

            try? fileManager.removeItem(at: backupURL)
            try? fileManager.removeItem(at: temporaryURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            removeEmptyDirectories(at: backupURL, fileManager: fileManager)
            throw error
        }
    }

    private struct Plan {
        let entries: [Entry]
        let extendedAttributes: [ArchiveExtendedAttributeRecord]
    }

    private struct ExtractionTransaction {
        var installed: [URL] = []
        var backups: [(original: URL, backup: URL)] = []
    }

    private static func makePlan(from archive: Archive) throws -> Plan {
        var entries: [Entry] = []
        var paths = Set<String>()
        var manifestEntry: Entry?

        for entry in archive {
            let path = entry.path
            if path == metadataPath {
                manifestEntry = entry
                continue
            }
            if path.hasPrefix("__DUPANE_METADATA__/") {
                throw ArchiveExtractionServiceError.invalidMetadata
            }
            try ArchiveExtractionSafety.validateEntryPath(path)
            let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
            guard paths.insert(normalizedPath).inserted else {
                throw ArchiveExtractionServiceError.duplicateEntry(normalizedPath)
            }
            entries.append(entry)
        }

        let filePaths = Set(entries.filter { $0.type != .directory }.map { normalizedPath($0.path) })
        for entry in entries {
            let components = normalizedPath(entry.path).split(separator: "/")
            var parent = ""
            for component in components.dropLast() {
                parent = parent.isEmpty ? String(component) : parent + "/" + component
                if filePaths.contains(parent) {
                    throw ArchiveExtractionServiceError.conflictingEntries(parent)
                }
            }
        }

        let extendedAttributes: [ArchiveExtendedAttributeRecord]
        if let manifestEntry {
            var data = Data()
            _ = try archive.extract(manifestEntry, skipCRC32: false) { data.append($0) }
            let manifest = try JSONDecoder().decode(ArchiveMetadataManifest.self, from: data)
            guard manifest.version == ArchiveMetadataManifest.version,
                  manifest.extendedAttributes.allSatisfy({ paths.contains(normalizedPath($0.path)) })
            else {
                throw ArchiveExtractionServiceError.invalidMetadata
            }
            extendedAttributes = manifest.extendedAttributes
        } else {
            extendedAttributes = []
        }

        for entry in entries where entry.type == .symlink {
            var data = Data()
            _ = try archive.extract(entry, skipCRC32: false) { data.append($0) }
            guard let target = String(data: data, encoding: .utf8), !target.isEmpty else {
                throw ArchiveExtractionServiceError.unsafeSymbolicLink(entry.path)
            }
            guard isContainedSymbolicLink(target, at: normalizedPath(entry.path)) else {
                throw ArchiveExtractionServiceError.unsafeSymbolicLink(entry.path)
            }
        }

        return Plan(entries: entries, extendedAttributes: extendedAttributes)
    }

    private static func apply(
        sourceURL: URL,
        destinationURL: URL,
        relativePath: String,
        overwrite: Bool,
        backupURL: URL,
        transaction: inout ExtractionTransaction,
        fileManager: FileManager
    ) throws {
        guard itemExists(at: sourceURL) else { return }
        let sourceIsDirectory = try isDirectory(at: sourceURL)
        let destinationExists = itemExists(at: destinationURL)

        if sourceIsDirectory, destinationExists, try isDirectory(at: destinationURL) {
            let children = try fileManager.contentsOfDirectory(
                at: sourceURL,
                includingPropertiesForKeys: nil,
                options: []
            )
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                try apply(
                    sourceURL: child,
                    destinationURL: destinationURL.appendingPathComponent(child.lastPathComponent),
                    relativePath: relativePath + "/" + child.lastPathComponent,
                    overwrite: overwrite,
                    backupURL: backupURL,
                    transaction: &transaction,
                    fileManager: fileManager
                )
            }
            return
        }

        if destinationExists {
            guard overwrite else { return }
            let backup = backupURL.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: destinationURL, to: backup)
            transaction.backups.append((destinationURL, backup))
        } else {
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        transaction.installed.append(destinationURL)
    }

    private static func rollback(
        _ transaction: ExtractionTransaction,
        fileManager: FileManager
    ) throws {
        for installedURL in transaction.installed.reversed() where itemExists(at: installedURL) {
            try fileManager.removeItem(at: installedURL)
        }
        for backup in transaction.backups.reversed() {
            guard itemExists(at: backup.backup) else { continue }
            try fileManager.createDirectory(at: backup.original.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: backup.backup, to: backup.original)
        }
    }

    private static func removeEmptyDirectories(at url: URL, fileManager: FileManager) {
        guard let children = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for child in children {
            if let isDirectory = try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               isDirectory == true {
                removeEmptyDirectories(at: child, fileManager: fileManager)
            }
        }

        if let remaining = try? fileManager.contentsOfDirectory(atPath: url.path), remaining.isEmpty {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func topLevelPaths(from entries: [Entry]) -> [String] {
        Set(entries.map { normalizedPath($0.path).split(separator: "/").first.map(String.init) ?? "" })
            .filter { !$0.isEmpty }
            .sorted()
    }

    private static func normalizedPath(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private static func isContainedSymbolicLink(_ target: String, at entryPath: String) -> Bool {
        guard !target.hasPrefix("/"), !target.contains("\0") else { return false }
        var components = normalizedPath(entryPath).split(separator: "/").dropLast().map(String.init)
        for component in target.split(separator: "/", omittingEmptySubsequences: false).map(String.init) {
            switch component {
            case "", ".":
                continue
            case "..":
                guard !components.isEmpty else { return false }
                components.removeLast()
            default:
                components.append(component)
            }
        }
        return true
    }

    private static func itemExists(at url: URL) -> Bool {
        url.path.withCString { path in
            var itemStat = stat()
            return lstat(path, &itemStat) == 0
        }
    }

    private static func isDirectory(at url: URL) throws -> Bool {
        try url.path.withCString { path in
            var itemStat = stat()
            guard lstat(path, &itemStat) == 0 else {
                throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO)
            }
            return (itemStat.st_mode & S_IFMT) == S_IFDIR
        }
    }
}
