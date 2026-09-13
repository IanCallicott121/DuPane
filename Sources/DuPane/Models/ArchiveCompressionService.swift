import Foundation
import ZIPFoundation

enum ArchiveCompressionError: LocalizedError {
    case noItems
    case destinationExists(String)
    case duplicateEntry(String)
    case reservedEntryPath(String)

    var errorDescription: String? {
        switch self {
        case .noItems:
            return "No items were selected for compression."
        case .destinationExists(let name):
            return "An archive named '\(name)' already exists."
        case .duplicateEntry(let path):
            return "The archive would contain more than one item named '\(path)'."
        case .reservedEntryPath(let path):
            return "The item '\(path)' uses a reserved archive metadata path."
        }
    }
}

enum ArchiveCompressionService {
    static func compress(
        items: [URL],
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard !items.isEmpty else { throw ArchiveCompressionError.noItems }
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ArchiveCompressionError.destinationExists(destinationURL.lastPathComponent)
        }

        let temporaryURL = destinationURL.deletingLastPathComponent().appendingPathComponent(
            ".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp"
        )

        do {
            let archive = try Archive(url: temporaryURL, accessMode: .create)
            var entryPaths: Set<String> = []
            var extendedAttributes: [ArchiveExtendedAttributeRecord] = []
            for item in items {
                try addItem(
                    at: item,
                    archivePath: item.lastPathComponent,
                    to: archive,
                    entryPaths: &entryPaths,
                    extendedAttributes: &extendedAttributes,
                    fileManager: fileManager
                )
            }
            if !extendedAttributes.isEmpty {
                try addMetadataManifest(
                    extendedAttributes,
                    to: archive,
                    entryPaths: &entryPaths
                )
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func addItem(
        at sourceURL: URL,
        archivePath: String,
        to archive: Archive,
        entryPaths: inout Set<String>,
        extendedAttributes: inout [ArchiveExtendedAttributeRecord],
        fileManager: FileManager
    ) throws {
        guard archivePath != ArchiveExtractionService.metadataPath,
              !archivePath.hasPrefix("__DUPANE_METADATA__/") else {
            throw ArchiveCompressionError.reservedEntryPath(archivePath)
        }
        guard entryPaths.insert(archivePath).inserted else {
            throw ArchiveCompressionError.duplicateEntry(archivePath)
        }

        extendedAttributes.append(contentsOf: try ArchiveExtendedAttributeStore.records(
            for: sourceURL,
            archivePath: archivePath
        ))

        let values = try sourceURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let compressionMethod: CompressionMethod = values.isDirectory == true ? .none : .deflate
        try archive.addEntry(
            with: archivePath,
            fileURL: sourceURL,
            compressionMethod: compressionMethod
        )

        guard values.isDirectory == true, values.isSymbolicLink != true else { return }
        let children = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        for child in children {
            try addItem(
                at: child,
                archivePath: archivePath + "/" + child.lastPathComponent,
                to: archive,
                entryPaths: &entryPaths,
                extendedAttributes: &extendedAttributes,
                fileManager: fileManager
            )
        }
    }

    private static func addMetadataManifest(
        _ extendedAttributes: [ArchiveExtendedAttributeRecord],
        to archive: Archive,
        entryPaths: inout Set<String>
    ) throws {
        guard entryPaths.insert(ArchiveExtractionService.metadataPath).inserted else {
            throw ArchiveCompressionError.duplicateEntry(ArchiveExtractionService.metadataPath)
        }
        let manifest = ArchiveMetadataManifest(
            version: ArchiveMetadataManifest.version,
            extendedAttributes: extendedAttributes
        )
        let data = try JSONEncoder().encode(manifest)
        try archive.addEntry(
            with: ArchiveExtractionService.metadataPath,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            let start = Int(position)
            guard start < data.count else { return Data() }
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }
}
