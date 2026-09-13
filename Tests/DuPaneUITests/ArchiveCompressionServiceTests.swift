import Darwin
import Foundation
import XCTest
import ZIPFoundation
@testable import DuPane

final class ArchiveCompressionServiceTests: DuPaneTestCase {
    func testOptionLikeFilenameDoesNotDeleteSelectedSources() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DuPaneArchiveCompressionTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let optionLikeFile = root.appendingPathComponent("-m")
        let ordinaryFile = root.appendingPathComponent("victim.txt")
        let archiveURL = root.appendingPathComponent("Archive.zip")
        try "option".write(to: optionLikeFile, atomically: true, encoding: .utf8)
        try "original".write(to: ordinaryFile, atomically: true, encoding: .utf8)

        try ArchiveCompressionService.compress(
            items: [optionLikeFile, ordinaryFile],
            to: archiveURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: optionLikeFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordinaryFile.path))
        XCTAssertEqual(try String(contentsOf: ordinaryFile, encoding: .utf8), "original")

        let archive = try Archive(url: archiveURL, accessMode: .read)
        XCTAssertEqual(
            Set(archive.map(\.path).filter { $0 != ArchiveExtractionService.metadataPath }),
            ["-m", "victim.txt"]
        )
    }

    func testFailedCompressionDoesNotLeavePartialDestinationArchive() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DuPaneArchiveCompressionTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let missingFile = root.appendingPathComponent("missing.txt")
        let archiveURL = root.appendingPathComponent("Archive.zip")

        XCTAssertThrowsError(
            try ArchiveCompressionService.compress(items: [missingFile], to: archiveURL)
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: archiveURL.path))
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
                $0.hasPrefix(".Archive.zip.") && $0.hasSuffix(".tmp")
            }
        )
    }

    func testCompressionAndExtractionPreserveSymlinksAndExtendedAttributes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DuPaneArchiveFidelityTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceFile = root.appendingPathComponent("target.txt")
        let sourceLink = root.appendingPathComponent("target-link")
        let archiveURL = root.appendingPathComponent("Archive.zip")
        let destination = root.appendingPathComponent("Extracted", isDirectory: true)
        try "payload".write(to: sourceFile, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            atPath: sourceLink.path,
            withDestinationPath: "target.txt"
        )
        try setExtendedAttribute("audit-value", named: "com.example.DuPaneArchiveTest", at: sourceFile)

        try ArchiveCompressionService.compress(items: [sourceFile, sourceLink], to: archiveURL)

        let archive = try Archive(url: archiveURL, accessMode: .read)
        XCTAssertEqual(archive.first(where: { $0.path == "target-link" })?.type, .symlink)

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try ArchiveExtractionService.extract(archiveURL: archiveURL, to: destination, overwrite: true)

        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(atPath: destination.appendingPathComponent("target-link").path),
            "target.txt"
        )
        XCTAssertEqual(
            try extendedAttribute(named: "com.example.DuPaneArchiveTest", at: destination.appendingPathComponent("target.txt")),
            Data("audit-value".utf8)
        )
    }

    func testFailedExtractionLeavesDestinationUnchangedAndCleansTemporaryState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DuPaneArchiveExtractionTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceFile = root.appendingPathComponent("replacement.txt")
        let archiveURL = root.appendingPathComponent("Archive.zip")
        let destination = root.appendingPathComponent("Destination", isDirectory: true)
        let existingFile = destination.appendingPathComponent("existing.txt")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "original".write(to: existingFile, atomically: true, encoding: .utf8)
        try "replacement".write(to: sourceFile, atomically: true, encoding: .utf8)

        let archive = try Archive(url: archiveURL, accessMode: .create)
        try archive.addEntry(with: "existing.txt", fileURL: sourceFile)
        try archive.addEntry(with: "existing.txt/child.txt", fileURL: sourceFile)

        XCTAssertThrowsError(
            try ArchiveExtractionService.extract(
                archiveURL: archiveURL,
                to: destination,
                overwrite: true
            )
        )
        XCTAssertEqual(try String(contentsOf: existingFile, encoding: .utf8), "original")
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
                $0.hasPrefix(".Archive.")
            }
        )
    }

    private func setExtendedAttribute(_ value: String, named name: String, at url: URL) throws {
        let data = Data(value.utf8)
        let result = data.withUnsafeBytes { buffer in
            url.path.withCString { path in
                name.withCString { attributeName in
                    setxattr(path, attributeName, buffer.baseAddress, data.count, 0, XATTR_NOFOLLOW)
                }
            }
        }
        guard result == 0 else { throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO) }
    }

    private func extendedAttribute(named name: String, at url: URL) throws -> Data {
        let size = try url.path.withCString { path in
            try name.withCString { attributeName in
                let result = getxattr(path, attributeName, nil, 0, 0, XATTR_NOFOLLOW)
                guard result >= 0 else { throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO) }
                return result
            }
        }
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { buffer in
            url.path.withCString { path in
                name.withCString { attributeName in
                    getxattr(path, attributeName, buffer.baseAddress, size, 0, XATTR_NOFOLLOW)
                }
            }
        }
        guard result >= 0 else { throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO) }
        data.count = result
        return data
    }
}
