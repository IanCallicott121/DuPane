import Foundation
import XCTest
@testable import DuPane

/// Tests covering the Critical and Major bug fixes from Build 42.
final class Build42BugFixTests: XCTestCase {
    private var fixture: FilePaneFixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try FilePaneFixture()
    }

    override func tearDownWithError() throws {
        try fixture?.tearDown()
        fixture = nil
        try super.tearDownWithError()
    }

    // MARK: - Critical: Atomic overwrite in move/copy

    func testCopyWithOverwriteReplacesDestinationContent() throws {
        try fixture.writeFile(named: "shared.txt", contents: "old", in: .right)
        try fixture.writeFile(named: "shared.txt", contents: "new", in: .left)
        let item = makeItem(name: "shared.txt", in: .left, size: 3)

        let result = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 1)
        let destContent = try String(contentsOf: fixture.fileURL(named: "shared.txt", in: .right), encoding: .utf8)
        XCTAssertEqual(destContent, "new")
    }

    func testCopyWithOverwriteLeavesNoHiddenTempFiles() throws {
        try fixture.writeFile(named: "shared.txt", contents: "old", in: .right)
        try fixture.writeFile(named: "shared.txt", contents: "new", in: .left)
        let item = makeItem(name: "shared.txt", in: .left, size: 3)

        _ = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        let contents = try FileManager.default.contentsOfDirectory(
            at: fixture.rightPaneURL, includingPropertiesForKeys: nil
        )
        let tmpFiles = contents.filter { $0.lastPathComponent.hasSuffix(".tmp") }
        XCTAssertTrue(tmpFiles.isEmpty, "Temp backup files should be cleaned up: \(tmpFiles.map(\.lastPathComponent))")
    }

    func testMoveWithOverwriteRemovesSourceAndReplacesDestination() throws {
        let destURL = try fixture.writeFile(named: "shared.txt", contents: "old", in: .right)
        try fixture.writeFile(named: "shared.txt", contents: "new", in: .left)
        let srcURL = fixture.fileURL(named: "shared.txt", in: .left)
        let item = makeItem(name: "shared.txt", in: .left, size: 3)

        let result = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: true, conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: srcURL.path), "Source must be gone after move")
        XCTAssertEqual(try String(contentsOf: destURL, encoding: .utf8), "new")
    }

    /// Verifies the restore path: if the copy fails (source missing after backup is taken),
    /// the original destination content must be atomically restored.
    func testCopyFailureRestoresDestinationFromBackup() throws {
        let destFile = fixture.fileURL(named: "target.txt", in: .right)
        try "original content".write(to: destFile, atomically: true, encoding: .utf8)

        // Source URL points to a file that does not exist — copy will fail.
        let missingURL = fixture.leftPaneURL.appendingPathComponent("target.txt")
        let item = FileItem(
            id: missingURL, name: "target.txt", url: missingURL,
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 7, kind: "Text", modified: nil, tags: []
        )

        let result = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destFile.path), "Destination must be restored after failed copy")
        XCTAssertEqual(try String(contentsOf: destFile, encoding: .utf8), "original content")
    }

    func testCopyFolderOverwriteRestoresDestinationAfterPartialCopyFailure() throws {
        let destination = try fixture.createFolder(named: "Shared", in: .right)
        let original = destination.appendingPathComponent("original.txt")
        try "original".write(to: original, atomically: true, encoding: .utf8)

        let source = try fixture.createFolder(named: "Shared", in: .left)
        try "partial".write(to: source.appendingPathComponent("partial.txt"), atomically: true, encoding: .utf8)
        let blocked = source.appendingPathComponent("blocked.txt")
        try "blocked".write(to: blocked, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: blocked.path) }

        let item = makeItem(name: "Shared", in: .left, isDirectory: true)

        let result = FileOperationService.moveOrCopy(
            files: [item],
            to: fixture.rightPaneURL,
            isMove: false,
            conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path), "Original destination must be restored")
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
    }

    // MARK: - Medium: createFolder validation

    func testCreateFolderRejectsEmptyName() {
        XCTAssertThrowsError(try FileOperationService.createFolder(named: "", in: fixture.leftPaneURL))
    }

    func testCreateFolderRejectsWhitespaceOnlyName() {
        XCTAssertThrowsError(try FileOperationService.createFolder(named: "   ", in: fixture.leftPaneURL))
    }

    func testCreateFolderRejectsNameContainingSlash() {
        XCTAssertThrowsError(try FileOperationService.createFolder(named: "a/b", in: fixture.leftPaneURL))
    }

    func testCreateFileRejectsNameContainingSlash() {
        XCTAssertThrowsError(try FileOperationService.createFile(named: "a/b", in: fixture.leftPaneURL))
    }

    func testCreateFileRejectsParentTraversalName() {
        let escapedURL = fixture.rootURL.appendingPathComponent("escaped.txt")

        XCTAssertThrowsError(try FileOperationService.createFile(named: "../escaped.txt", in: fixture.leftPaneURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: escapedURL.path))
        XCTAssertThrowsError(try FileOperationService.createFile(named: "..", in: fixture.leftPaneURL))
    }

    // MARK: - Medium: archive extraction safety

    func testArchiveExtractionRejectsUnsafePaths() {
        XCTAssertThrowsError(try ArchiveExtractionSafety.validatedFileEntries(from: ["../outside.txt"]))
        XCTAssertThrowsError(try ArchiveExtractionSafety.validatedFileEntries(from: ["/tmp/outside.txt"]))
        XCTAssertThrowsError(try ArchiveExtractionSafety.validatedFileEntries(from: ["safe/../outside.txt"]))
        XCTAssertThrowsError(try ArchiveExtractionSafety.validatedFileEntries(from: ["safe\\outside.txt"]))
    }

    func testArchiveExtractionDetectsSymbolicLinks() {
        let listing = """
        Archive: sample.zip
        ?rw-------  2.0 unx        5 b-        5 stor 26-Aug-29 08:10 plain.txt
        lrwxrwxrwx  2.0 unx        4 b-        4 stor 80-Jan-01 00:00 link target
        2 files, 9 bytes uncompressed, 9 bytes compressed:  0.0%
        """

        XCTAssertEqual(ArchiveExtractionSafety.symbolicLinkEntries(from: listing), ["link target"])
    }

    func testArchiveExtractionConflictsUseValidatedRelativeEntries() throws {
        try fixture.createFolder(named: "nested", in: .right)
        try "existing".write(
            to: fixture.rightPaneURL.appendingPathComponent("nested/existing.txt"),
            atomically: true,
            encoding: .utf8
        )
        let entries = try ArchiveExtractionSafety.validatedFileEntries(
            from: ["nested/", "nested/existing.txt", "nested/new.txt"]
        )

        let conflicts = ArchiveExtractionSafety.conflicts(for: entries, in: fixture.rightPaneURL)

        XCTAssertEqual(conflicts, ["nested/existing.txt"])
    }

    // MARK: - Major: FolderCompareService duplicate filename safety

    func testCompareDoesNotCrashWithDuplicateNamesOnLeft() {
        // Two FileItems with the same .name field — simulates a case-sensitive volume oddity.
        let date = Date(timeIntervalSince1970: 100)
        let url1 = fixture.leftPaneURL.appendingPathComponent("dupe.txt")
        let url2 = fixture.leftPaneURL.appendingPathComponent("DUPE.txt")
        let leftA = FileItem(id: url1, name: "dupe.txt", url: url1, isDirectory: false, isVolume: false, isRemovable: false, size: 4, kind: "Text", modified: date, tags: [])
        let leftB = FileItem(id: url2, name: "dupe.txt", url: url2, isDirectory: false, isVolume: false, isRemovable: false, size: 8, kind: "Text", modified: date, tags: [])
        let rightURL = fixture.rightPaneURL.appendingPathComponent("dupe.txt")
        let rightItem = FileItem(id: rightURL, name: "dupe.txt", url: rightURL, isDirectory: false, isVolume: false, isRemovable: false, size: 4, kind: "Text", modified: date, tags: [])

        // Must not crash; first occurrence (size 4) wins → sizes match → .same
        let snapshot = FolderCompareService.compare(leftItems: [leftA, leftB], rightItems: [rightItem])
        XCTAssertEqual(snapshot.summary.same, 1)
        XCTAssertEqual(snapshot.summary.different, 0)
    }

    func testCompareDoesNotCrashWithDuplicateNamesOnRight() {
        let date = Date(timeIntervalSince1970: 100)
        let leftURL = fixture.leftPaneURL.appendingPathComponent("dupe.txt")
        let leftItem = FileItem(id: leftURL, name: "dupe.txt", url: leftURL, isDirectory: false, isVolume: false, isRemovable: false, size: 4, kind: "Text", modified: date, tags: [])
        let url1 = fixture.rightPaneURL.appendingPathComponent("dupe.txt")
        let url2 = fixture.rightPaneURL.appendingPathComponent("DUPE.txt")
        let rightA = FileItem(id: url1, name: "dupe.txt", url: url1, isDirectory: false, isVolume: false, isRemovable: false, size: 4, kind: "Text", modified: date, tags: [])
        let rightB = FileItem(id: url2, name: "dupe.txt", url: url2, isDirectory: false, isVolume: false, isRemovable: false, size: 8, kind: "Text", modified: date, tags: [])

        // Must not crash; first occurrence on right (size 4) wins → .same
        let snapshot = FolderCompareService.compare(leftItems: [leftItem], rightItems: [rightA, rightB])
        XCTAssertEqual(snapshot.summary.same, 1)
        XCTAssertEqual(snapshot.summary.different, 0)
    }

    func testCompareFirstOccurrenceWinsOnDuplicateLeftName() {
        let date = Date(timeIntervalSince1970: 100)
        let url1 = fixture.leftPaneURL.appendingPathComponent("file.txt")
        let url2 = fixture.leftPaneURL.appendingPathComponent("FILE.txt")
        // First item has size 10; second has size 99. Right has size 10.
        // First should win → same (size 10 == 10), not different (99 != 10).
        let leftFirst = FileItem(id: url1, name: "file.txt", url: url1, isDirectory: false, isVolume: false, isRemovable: false, size: 10, kind: "Text", modified: date, tags: [])
        let leftSecond = FileItem(id: url2, name: "file.txt", url: url2, isDirectory: false, isVolume: false, isRemovable: false, size: 99, kind: "Text", modified: date, tags: [])
        let rightURL = fixture.rightPaneURL.appendingPathComponent("file.txt")
        let rightItem = FileItem(id: rightURL, name: "file.txt", url: rightURL, isDirectory: false, isVolume: false, isRemovable: false, size: 10, kind: "Text", modified: date, tags: [])

        let snapshot = FolderCompareService.compare(leftItems: [leftFirst, leftSecond], rightItems: [rightItem])
        XCTAssertEqual(snapshot.summary.same, 1, "First occurrence (size 10) should win, matching right side (size 10)")
    }

    // MARK: - Major: SmartMetadataService lineCount correctness

    @MainActor
    // [optional] — slow async metadata test; tests background service, not hot path
    func testSmartMetadataLineCountIsAccurateForSwiftFile() async throws {
        // 3 newlines → lineCount returns count + 1 = 4 lines
        let content = "let a = 1\nlet b = 2\nlet c = 3\n"
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("linecount_\(UUID().uuidString).swift")
        try content.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let item = FileItem(
            id: tmpURL, name: tmpURL.lastPathComponent, url: tmpURL,
            isDirectory: false, isVolume: false, isRemovable: false,
            size: Int64(content.utf8.count), kind: "Swift Source", modified: nil, tags: []
        )

        let service = SmartMetadataService.shared
        service.loadIfNeeded(for: [item])

        let deadline = Date().addingTimeInterval(5)
        while service.cache[tmpURL] == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(service.cache[tmpURL], "4 lines")
    }

    @MainActor
    // [optional] — slow async metadata test
    func testSmartMetadataLineCountHandlesSingleLineFile() async throws {
        let content = "no newline at end"
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("singleline_\(UUID().uuidString).swift")
        try content.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let item = FileItem(
            id: tmpURL, name: tmpURL.lastPathComponent, url: tmpURL,
            isDirectory: false, isVolume: false, isRemovable: false,
            size: Int64(content.utf8.count), kind: "Swift Source", modified: nil, tags: []
        )

        let service = SmartMetadataService.shared
        service.loadIfNeeded(for: [item])

        let deadline = Date().addingTimeInterval(5)
        while service.cache[tmpURL] == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(service.cache[tmpURL], "1 line")
    }

    // MARK: - Medium: PaneStatusFormatter filtered indicator

    func testStatusFormatterShowsFilteredIndicator() {
        let text = PaneStatusFormatter.text(itemCount: 3, selectedCount: 0, selectedBytes: 0, isFiltered: true)
        XCTAssertTrue(text.contains("(filtered)"), "Expected '(filtered)' in: \(text)")
    }

    func testStatusFormatterOmitsFilteredIndicatorByDefault() {
        let text = PaneStatusFormatter.text(itemCount: 3, selectedCount: 0, selectedBytes: 0)
        XCTAssertFalse(text.contains("(filtered)"), "Did not expect '(filtered)' in: \(text)")
    }

    func testStatusFormatterFilteredAppearsBeforeSelectionCount() {
        let text = PaneStatusFormatter.text(itemCount: 5, selectedCount: 2, selectedBytes: 512, isFiltered: true)
        XCTAssertTrue(text.contains("(filtered)"))
        XCTAssertTrue(text.contains("2 selected"))
        // "(filtered)" should come before "selected" in the string
        let filteredRange = text.range(of: "(filtered)")!
        let selectedRange = text.range(of: "selected")!
        XCTAssertLessThan(filteredRange.lowerBound, selectedRange.lowerBound)
    }

    // MARK: - Helpers

    private func makeItem(name: String, in pane: TestPane, isDirectory: Bool = false, size: Int64? = nil) -> FileItem {
        let url = fixture.paneURL(pane).appendingPathComponent(name, isDirectory: isDirectory)
        return FileItem(
            id: url, name: name, url: url,
            isDirectory: isDirectory, isVolume: false, isRemovable: false,
            size: isDirectory ? nil : size, kind: isDirectory ? "Folder" : "Text",
            modified: Date(timeIntervalSince1970: 100), tags: []
        )
    }
}
