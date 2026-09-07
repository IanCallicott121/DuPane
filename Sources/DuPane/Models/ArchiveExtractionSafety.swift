import Foundation

enum ArchiveExtractionSafetyError: LocalizedError, Equatable {
    case unsafeEntry(String)
    case unsupportedSymbolicLink(String)

    var errorDescription: String? {
        switch self {
        case .unsafeEntry(let entry):
            return "Archive contains an unsafe path: \(entry)"
        case .unsupportedSymbolicLink(let entry):
            return "Archive contains a symbolic link, which is not supported: \(entry)"
        }
    }
}

enum ArchiveExtractionSafety {
    static func listedEntryNames(from output: String) -> [String] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func validatedFileEntries(from entries: [String]) throws -> [String] {
        try entries.compactMap { entry in
            try validate(entry)
            return entry.hasSuffix("/") ? nil : entry
        }
    }

    static func symbolicLinkEntries(from zipInfoListing: String) -> [String] {
        zipInfoListing.components(separatedBy: .newlines).compactMap { line in
            guard line.first == "l" else { return nil }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 10 else { return "symbolic link" }
            return parts.dropFirst(9).joined(separator: " ")
        }
    }

    static func conflicts(for fileEntries: [String], in destinationDirectory: URL) -> [String] {
        fileEntries.filter { entry in
            let fullPath = destinationDirectory.appendingPathComponent(entry)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                return true
            }
            // Detect conflicts where an intermediate directory component already exists
            // as a non-directory file. fileExists on the leaf returns false in this case,
            // but extraction would fail trying to create the directory.
            let components = entry.components(separatedBy: "/").dropLast()
            var partial = destinationDirectory
            for component in components where !component.isEmpty {
                partial = partial.appendingPathComponent(component)
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: partial.path, isDirectory: &isDir)
                if exists && !isDir.boolValue {
                    return true
                }
            }
            return false
        }
    }

    private static func validate(_ entry: String) throws {
        guard !entry.hasPrefix("/"),
              !entry.contains("\\"),
              !entry.contains("\0") else {
            throw ArchiveExtractionSafetyError.unsafeEntry(entry)
        }

        let path = entry.hasSuffix("/") ? String(entry.dropLast()) : entry
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ArchiveExtractionSafetyError.unsafeEntry(entry)
        }
    }
}
