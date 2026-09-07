import Foundation
import XCTest
@testable import DuPane

// Tests that document and pin down the bugs found in the Build 381 codebase analysis.
// Tests marked [must] expose incorrect behaviour and will FAIL until the bug is fixed.
// Tests marked [optional] are slow (async wait) or test internal detail.

// MARK: - Bug 10: FolderCompareService treats directories with different kind strings as .different — 3 tests [must]

final class FolderCompareDirectoryKindTests: XCTestCase {
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
final class TabbedPaneStateFallbackMetadataTests: XCTestCase {
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
final class PaneStateDuplicateSilentNoOpTests: XCTestCase {
    func testDuplicateAtComputerRootIsNoOpAndSetsNoError() {
        let pane = PaneState(initialURL: nil) // nil = virtual Computer root
        XCTAssertNil(pane.currentURL)
        pane.duplicate()
        // Currently returns silently with no error message and no user feedback.
        // The test pins this behaviour; a future fix should show a toast instead.
        XCTAssertNil(pane.errorMessage,
                     "duplicate() at Computer root returns early — no error is currently surfaced to the user")
    }
}

// MARK: - Bug 2: SortPreference writes a distinct UserDefaults key per folder URL — unbounded growth — 1 test [must]

@MainActor
final class SortPreferenceGrowthTests: XCTestCase {
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

// MARK: - Bug 19: SmartMetadataService.lineCount overcounts lines for files ending with a newline — 2 tests [optional]

@MainActor
final class SmartMetadataLineCountTests: XCTestCase {
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
