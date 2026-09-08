import Foundation
import XCTest
@testable import DuPane

// Tests that document and pin down the bugs found in the Build 381 codebase analysis.
// Tests marked [must] expose incorrect behaviour and will FAIL until the bug is fixed.
// Tests marked [optional] are slow (async wait) or test internal detail.

// MARK: - Bug 10: FolderCompareService treats directories with different kind strings as .different — 3 tests [must]

final class FolderCompareDirectoryKindTests: DuPaneTestCase {
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

    func testDirectoriesWithDifferentKindStringsButSameDatesCompareAsSame() {
        // iCloud Drive can report "iCloud Folder" instead of "Folder" — same directory, different kind
        let date = Date(timeIntervalSince1970: 1000)
        let left  = makeDir(name: "Documents", kind: "Folder",        date: date, pane: .left)
        let right = makeDir(name: "Documents", kind: "iCloud Folder", date: date, pane: .right)
        let snapshot = FolderCompareService.compare(leftItems: [left], rightItems: [right])
        XCTAssertEqual(snapshot.entries.first?.status, .same,
                       "Directories that differ only in localizedTypeDescription should compare as .same")
        XCTAssertEqual(snapshot.summary.different, 0)
    }

    func testDirectoriesWithDifferentKindStringsNewerOnLeftCompareAsNewerLeft() {
        let now  = Date(timeIntervalSince1970: 2000)
        let past = Date(timeIntervalSince1970: 1000)
        let left  = makeDir(name: "Movies", kind: "Folder",        date: now,  pane: .left)
        let right = makeDir(name: "Movies", kind: "iCloud Folder", date: past, pane: .right)
        let snapshot = FolderCompareService.compare(leftItems: [left], rightItems: [right])
        XCTAssertEqual(snapshot.entries.first?.status, .newerLeft,
                       "Directory pair where left is newer should be .newerLeft regardless of kind string")
        XCTAssertEqual(snapshot.summary.newerLeft, 1)
        XCTAssertEqual(snapshot.summary.different, 0)
    }

    func testDirectoriesWithSameKindStringCompareAsSame() {
        let date = Date(timeIntervalSince1970: 1000)
        let left  = makeDir(name: "Downloads", kind: "Folder", date: date, pane: .left)
        let right = makeDir(name: "Downloads", kind: "Folder", date: date, pane: .right)
        let snapshot = FolderCompareService.compare(leftItems: [left], rightItems: [right])
        XCTAssertEqual(snapshot.entries.first?.status, .same)
    }

    private func makeDir(name: String, kind: String, date: Date, pane: TestPane) -> FileItem {
        let url = fixture.paneURL(pane).appendingPathComponent(name, isDirectory: true)
        return FileItem(id: url, name: name, url: url,
                        isDirectory: true, isVolume: false, isRemovable: false,
                        size: nil, kind: kind, modified: date, tags: [])
    }
}

// MARK: - Bug 22: TabbedPaneState.fallbackMetadataIndex OR guard applies metadata when only label count matches tabs count — 1 test [must]

@MainActor
final class TabbedPaneStateFallbackMetadataTests: DuPaneTestCase {
    private var testKey: String!

    override func setUp() {
        super.setUp()
        testKey = "test_tabs_\(UUID().uuidString)"
    }

    override func tearDown() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: testKey)
        ud.removeObject(forKey: testKey + TabPersistence.labelsSuffix)
        ud.removeObject(forKey: testKey + TabPersistence.pinsSuffix)
        ud.removeObject(forKey: testKey + TabPersistence.pinnedPathsSuffix)
        ud.removeObject(forKey: testKey + TabPersistence.tintsSuffix)
        super.tearDown()
    }

    func testFallbackDoesNotApplyLabelsWhenOnlyLabelCountMatchesTabCount() throws {
        // Manufacture mismatched state: 2 savedPaths but 3 savedLabels.
        // This can't arise in normal use but exposes the OR condition in fallbackMetadataIndex.
        let ud = UserDefaults.standard
        ud.set(try JSONEncoder().encode(["/tmp/a", "/tmp/b"] as [String?]),       forKey: testKey)
        ud.set(try JSONEncoder().encode(["Alpha", "Beta", "Gamma"] as [String?]), forKey: testKey + TabPersistence.labelsSuffix)

        // 3 tabs — savedLabels.count (3) == tabs.count (3) trips the buggy OR condition
        let state = TabbedPaneState(initialURLs: [nil, nil, nil], tabsKey: testKey)

        // savedPaths.count (2) ≠ tabs.count (3), so fallback should not apply any metadata.
        // With the bug: labels ["Alpha", "Beta", "Gamma"] get stamped onto the three tabs.
        XCTAssertNil(state.tabs[0].customLabel,
                     "Labels must not be applied when savedPaths.count ≠ tabs.count")
        XCTAssertNil(state.tabs[1].customLabel)
        XCTAssertNil(state.tabs[2].customLabel)
    }
}

// MARK: - Bug 26: PaneState.duplicate() with nil currentURL is a silent no-op — 1 test [must]

@MainActor
final class PaneStateDuplicateSilentNoOpTests: DuPaneTestCase {
    func testDuplicateAtComputerRootSetsErrorMessage() {
        let pane = PaneState(initialURL: nil) // nil = virtual Computer root
        XCTAssertNil(pane.currentURL)
        pane.duplicate()
        XCTAssertNotNil(pane.errorMessage,
                        "duplicate() at Computer root should surface an error message to the user")
    }
}

// MARK: - Bug 2: SortPreference writes a distinct UserDefaults key per folder URL — unbounded growth — 1 test [must]

@MainActor
final class SortPreferenceGrowthTests: DuPaneTestCase {
    private var writtenPaths: [String] = []

    override func tearDown() {
        for path in writtenPaths {
            UserDefaults.standard.removeObject(forKey: "sortPref_\(path)")
        }
        writtenPaths = []
        super.tearDown()
    }

    func testSetSortWritesSeparateUserDefaultsKeyPerVisitedFolder() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("sortpref-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        var dirs: [URL] = []
        for i in 1...5 {
            let d = root.appendingPathComponent("dir\(i)", isDirectory: true)
            try fm.createDirectory(at: d, withIntermediateDirectories: false)
            dirs.append(d)
            writtenPaths.append(d.path)
        }

        let pane = PaneState()
        for dir in dirs {
            pane.navigate(to: dir)
            await pane.loadingTask?.value
            pane.setSort(.kind)
        }

        let ours = writtenPaths.filter {
            UserDefaults.standard.object(forKey: "sortPref_\($0)") != nil
        }
        // Each folder writes its own key — demonstrates the unbounded growth problem.
        XCTAssertEqual(ours.count, 5,
                       "5 distinct folder visits should have written 5 separate UserDefaults keys")
    }
}

// MARK: - FileOperationService.moveOrCopy subtree guard skips only the offending item — 2 tests [must]

final class FileOperationSubtreeGuardTests: DuPaneTestCase {
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

    func testSubtreeSelfCopySkipsOffendingFolderButCopiesOtherItems() throws {
        // Batch: one folder copying into itself (invalid) + one regular file (valid).
        // Bug: the guard returned early, abandoning the entire batch.
        // Fix: only the self-referential folder should be skipped.
        let validFile = try fixture.writeFile(named: "valid.txt", contents: "hello", in: .left)
        let selfFolder = try fixture.createFolder(named: "self", in: .left)
        // Destination is the selfFolder itself — a subtree violation.
        let selfItem = FileItem(
            id: selfFolder, name: "self", url: selfFolder,
            isDirectory: true, isVolume: false, isRemovable: false,
            size: nil, kind: "Folder", modified: nil, tags: []
        )
        let fileItem = FileItem(
            id: validFile, name: "valid.txt", url: validFile,
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 5, kind: "Text", modified: nil, tags: []
        )

        let result = FileOperationService.moveOrCopy(
            files: [selfItem, fileItem],
            to: selfFolder,
            isMove: false
        )

        XCTAssertEqual(result.succeeded, 1, "valid.txt must be copied even though the folder item is invalid")
        XCTAssertEqual(result.errors.count, 1, "exactly one error for the self-referential folder")
        XCTAssertTrue(FileManager.default.fileExists(atPath: selfFolder.appendingPathComponent("valid.txt").path),
                      "valid.txt must appear inside the destination folder")
    }

    func testSubtreeSelfCopyOnlyItemReturnsOneError() throws {
        let selfFolder = try fixture.createFolder(named: "loop", in: .left)
        let selfItem = FileItem(
            id: selfFolder, name: "loop", url: selfFolder,
            isDirectory: true, isVolume: false, isRemovable: false,
            size: nil, kind: "Folder", modified: nil, tags: []
        )

        let result = FileOperationService.moveOrCopy(
            files: [selfItem],
            to: selfFolder,
            isMove: false
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.errors.count, 1)
    }
}

// MARK: - ArchiveExtractionSafety.conflicts detects intermediate-component conflicts — 3 tests [must]

final class ArchiveExtractionSafetyConflictTests: DuPaneTestCase {
    private var destDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-conflict-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: destDir)
        destDir = nil
        try super.tearDownWithError()
    }

    func testTopLevelFileConflictDetected() throws {
        // Archive entry "readme.txt" conflicts with existing file at destination root.
        try "existing".write(to: destDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        let conflicts = ArchiveExtractionSafety.conflicts(for: ["readme.txt"], in: destDir)
        XCTAssertEqual(conflicts, ["readme.txt"])
    }

    func testNoConflictWhenPathIsFree() {
        let conflicts = ArchiveExtractionSafety.conflicts(for: ["newfile.txt"], in: destDir)
        XCTAssertTrue(conflicts.isEmpty, "no conflict for a path that does not exist")
    }

    func testSubdirectoryFileConflictWhenIntermediateIsAFile() throws {
        // "subdir" exists as a FILE — extracting "subdir/data.txt" would fail because
        // the intermediate component is not a directory. The bug: fileExists on the
        // leaf path returned false, missing the conflict entirely.
        try "I am a file".write(to: destDir.appendingPathComponent("subdir"), atomically: true, encoding: .utf8)
        let conflicts = ArchiveExtractionSafety.conflicts(for: ["subdir/data.txt"], in: destDir)
        XCTAssertEqual(conflicts, ["subdir/data.txt"],
                       "intermediate component 'subdir' is a file, not a directory — must be flagged as a conflict")
    }
}

// MARK: - Bug 19: SmartMetadataService.lineCount overcounts lines for files ending with a newline — 2 tests [optional]

@MainActor
final class SmartMetadataLineCountTests: DuPaneTestCase {
    private var tmpFiles: [URL] = []

    override func tearDown() async throws {
        for url in tmpFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tmpFiles = []
        try await super.tearDown()
    }

    func testLineCountFileWithTrailingNewlineReportsActualLineCount() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lc-\(UUID().uuidString).swift")
        // 3 lines with a trailing newline — correct answer: "3 lines"
        // Bug: count += newlines (=3), total = count + 1 = 4 → reports "4 lines"
        try "line1\nline2\nline3\n".write(to: url, atomically: true, encoding: .utf8)
        tmpFiles.append(url)

        let item = FileItem(id: url, name: url.lastPathComponent, url: url,
                            isDirectory: false, isVolume: false, isRemovable: false,
                            size: nil, kind: "Swift Source File", modified: nil, tags: [])
        SmartMetadataService.shared.loadIfNeeded(for: [item])

        let deadline = Date().addingTimeInterval(5)
        while SmartMetadataService.shared.cache[url] == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(SmartMetadataService.shared.cache[url], "3 lines",
                       "File with trailing newline should report 3 lines, not 4")
    }

    func testLineCountFileWithoutTrailingNewlineReportsCorrectCount() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lc-\(UUID().uuidString).swift")
        // 3 lines, no trailing newline — count += newlines (=2), total = 3 (currently correct)
        try "line1\nline2\nline3".write(to: url, atomically: true, encoding: .utf8)
        tmpFiles.append(url)

        let item = FileItem(id: url, name: url.lastPathComponent, url: url,
                            isDirectory: false, isVolume: false, isRemovable: false,
                            size: nil, kind: "Swift Source File", modified: nil, tags: [])
        SmartMetadataService.shared.loadIfNeeded(for: [item])

        let deadline = Date().addingTimeInterval(5)
        while SmartMetadataService.shared.cache[url] == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(SmartMetadataService.shared.cache[url], "3 lines")
    }
}
