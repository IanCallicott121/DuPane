import Foundation
import XCTest
@testable import DuPane

// Test tagging convention used across the test suite:
// All tests are [must] unless individually marked [optional].
// [must]     = tests core, user-visible behaviour; must pass before any ship.
// [optional] = slow, env-specific, or covers internal details — run periodically.

// MARK: - PaneState.duplicate() — 4 tests [must]

@MainActor
final class PaneStateDuplicateTests: DuPaneTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
        dir = nil
        try super.tearDownWithError()
    }

    func testDuplicateCreatesNameCopyWithExtension() async throws {
        try "data".write(to: dir.appendingPathComponent("photo.jpg"), atomically: true, encoding: .utf8)
        let pane = PaneState(initialURL: dir)
        pane.start()
        await pane.loadingTask?.value
        let item = try XCTUnwrap(pane.items.first { $0.name == "photo.jpg" })
        pane.selection = [item.url]
        pane.duplicate()
        try await waitForFile(dir.appendingPathComponent("photo copy.jpg"))
    }

    func testDuplicateCreatesNameCopyWithoutExtension() async throws {
        try "data".write(to: dir.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)
        let pane = PaneState(initialURL: dir)
        pane.start()
        await pane.loadingTask?.value
        let item = try XCTUnwrap(pane.items.first { $0.name == "Makefile" })
        pane.selection = [item.url]
        pane.duplicate()
        try await waitForFile(dir.appendingPathComponent("Makefile copy"))
    }

    func testDuplicateAutoIncrementsWhenCopyNameAlreadyExists() async throws {
        try "a".write(to: dir.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: dir.appendingPathComponent("note copy.txt"), atomically: true, encoding: .utf8)
        let pane = PaneState(initialURL: dir)
        pane.start()
        await pane.loadingTask?.value
        let item = try XCTUnwrap(pane.items.first { $0.name == "note.txt" })
        pane.selection = [item.url]
        pane.duplicate()
        try await waitForFile(dir.appendingPathComponent("note copy 2.txt"))
    }

    func testDuplicateMultipleSelectedItemsCreatesAllCopies() async throws {
        try "a".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let pane = PaneState(initialURL: dir)
        pane.start()
        await pane.loadingTask?.value
        pane.selection = Set(pane.items.map { $0.url })
        pane.duplicate()
        try await waitForFile(dir.appendingPathComponent("a copy.txt"))
        try await waitForFile(dir.appendingPathComponent("b copy.txt"))
    }

    private func waitForFile(_ url: URL, timeout: TimeInterval = 3.0) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !FileManager.default.fileExists(atPath: url.path), Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "Expected '\(url.lastPathComponent)' to appear within \(timeout)s")
    }
}

// MARK: - SidebarModel recents — 4 tests [must]

@MainActor
final class SidebarModelRecentsTests: DuPaneTestCase {
    private let recentsKey = "sidebar.recentURLs"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: recentsKey)
        super.tearDown()
    }

    func testRecordVisitAddsURLToFrontOfList() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.recordVisit(url)
        XCTAssertEqual(model.recentURLs.first, url)
    }

    func testRecordVisitDeduplicatesRepeatedURL() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.recordVisit(url)
        model.recordVisit(url)
        XCTAssertEqual(model.recentURLs.filter { $0 == url }.count, 1,
                       "Revisiting the same URL must not create duplicates")
    }

    func testRecordVisitCapsListAtTwelveEntries() {
        let model = SidebarModel()
        let candidates = [
            "/tmp", "/private/tmp", "/var", "/etc", "/usr",
            "/bin", "/sbin", "/private/var", "/private/etc",
            "/Library", "/Users", "/Applications", "/System"
        ].map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        for dir in candidates { model.recordVisit(dir) }
        XCTAssertLessThanOrEqual(model.recentURLs.count, 12,
                                 "Recent list must not exceed 12 entries")
    }

    func testClearRecentsEmptiesTheList() {
        let model = SidebarModel()
        model.recordVisit(URL(fileURLWithPath: "/tmp"))
        model.clearRecents()
        XCTAssertTrue(model.recentURLs.isEmpty)
    }
}

// MARK: - FileRowView.formatDate(showTime:) — 6 tests [must]

final class FileRowViewFormatDateTests: DuPaneTestCase {
    private let fixedDate: Date = {
        var c = DateComponents()
        c.year = 2025; c.month = 12; c.day = 31; c.hour = 14; c.minute = 30; c.second = 0
        return Calendar.current.date(from: c)!
    }()

    func testNilDateReturnsPlaceholder() {
        XCTAssertEqual(FileRowView.formatDate(nil), "—")
    }

    func testMediumStyleOmitsTimeWhenStyleNone() {
        let result = FileRowView.formatDate(fixedDate, style: .medium, timeStyle: .none)
        XCTAssertFalse(result.contains(":"), "Date-only medium format must not contain ':' — got '\(result)'")
        XCTAssertTrue(result.contains("2025"))
    }

    func testMediumStyleIncludesTimeWhen24Hour() {
        let result = FileRowView.formatDate(fixedDate, style: .medium, timeStyle: .twentyFour)
        XCTAssertTrue(result.contains("14:30"), "Medium+24h format must contain '14:30' — got '\(result)'")
    }

    func testISOStyleDateOnlyFormat() {
        let result = FileRowView.formatDate(fixedDate, style: .iso, timeStyle: .none)
        XCTAssertEqual(result, "2025-12-31")
    }

    func testISOStyleDateAndTimeFormat() {
        let result = FileRowView.formatDate(fixedDate, style: .iso, timeStyle: .twentyFour)
        XCTAssertEqual(result, "2025-12-31 14:30")
    }

    func testRelativeStyleTodayWithTimeContainsColon() {
        let todayWithTime = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let result = FileRowView.formatDate(todayWithTime, style: .relative, timeStyle: .twentyFour)
        XCTAssertTrue(result.hasPrefix("Today"), "Expected 'Today' prefix — got '\(result)'")
        XCTAssertTrue(result.contains(":"), "Expected time separator in '\(result)'")
    }
}

// MARK: - PaneState.foldersFirst = false — 2 tests [must]

@MainActor
final class PaneStateFoldersFirstTests: DuPaneTestCase {
    func testFoldersFirstFalseInterleavesFoldersAndFilesByName() {
        let pane = PaneState()
        pane.foldersFirst = false
        pane.items = [
            makeItem(name: "a.txt", isDirectory: false),
            makeItem(name: "ZFolder", isDirectory: true),
            makeItem(name: "m.txt", isDirectory: false),
        ]
        // Pure name sort: a.txt < m.txt < ZFolder (localizedStandardCompare is case-insensitive)
        XCTAssertEqual(pane.displayedItems.map(\.name), ["a.txt", "m.txt", "ZFolder"],
                       "foldersFirst=false must not elevate folders above earlier-sorting files")
    }

    func testFoldersFirstTrueKeepsFoldersAboveAlphabeticallyPriorFiles() {
        let pane = PaneState()
        pane.foldersFirst = true
        pane.items = [
            makeItem(name: "a.txt", isDirectory: false),
            makeItem(name: "ZFolder", isDirectory: true),
        ]
        XCTAssertEqual(pane.displayedItems.first?.name, "ZFolder",
                       "foldersFirst=true must keep ZFolder above a.txt despite Z > a by name")
    }

    private func makeItem(name: String, isDirectory: Bool) -> FileItem {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        return FileItem(id: url, name: name, url: url, isDirectory: isDirectory,
                        isVolume: false, isRemovable: false, size: nil,
                        kind: isDirectory ? "Folder" : "File", modified: nil, tags: [])
    }
}

// MARK: - TabbedPaneState.foldersFirst propagation — 2 tests [must]

@MainActor
final class TabbedPaneStateFoldersFirstTests: DuPaneTestCase {
    func testFoldersFirstPropagatesToAllExistingTabs() {
        let tabs = TabbedPaneState()
        tabs.openTab()
        tabs.foldersFirst = false
        for tab in tabs.tabs {
            XCTAssertFalse(tab.pane.foldersFirst, "All tabs must reflect foldersFirst=false")
        }
        tabs.foldersFirst = true
        for tab in tabs.tabs {
            XCTAssertTrue(tab.pane.foldersFirst, "All tabs must reflect foldersFirst=true")
        }
    }

    func testNewTabInheritsCurrentFoldersFirstValue() {
        let tabs = TabbedPaneState()
        tabs.foldersFirst = false
        tabs.openTab()
        XCTAssertFalse(tabs.tabs.last!.pane.foldersFirst,
                       "New tab must inherit current foldersFirst=false")
    }
}

// MARK: - AppSettings new defaults — 1 test [must]

final class AppSettingsNewDefaultsTests: DuPaneTestCase {
    func testNewBoolSettingsDefaultToTrue() {
        let keys = [
            "showSidebarPlaces",
            "showSidebarRecents",
            "foldersFirst",
            "timeFormatStyle",
            "showCustomShellCommandNotice"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }

        let settings = AppSettings()
        XCTAssertTrue(settings.showSidebarPlaces, "showSidebarPlaces must default true")
        XCTAssertTrue(settings.showSidebarRecents, "showSidebarRecents must default true")
        XCTAssertTrue(settings.foldersFirst, "foldersFirst must default true")
        XCTAssertNotEqual(settings.timeFormatStyle, .none, "time in date must be enabled by default")
        XCTAssertTrue(settings.showCustomShellCommandNotice, "showCustomShellCommandNotice must default true")
    }
}

// MARK: - PaneState new flag defaults — 2 tests [must]

@MainActor
final class PaneStateNewFlagDefaultsTests: DuPaneTestCase {
    func testRequestGetInfoDefaultsFalse() {
        XCTAssertFalse(PaneState().requestGetInfo)
    }

    func testRequestFocusFilterDefaultsFalse() {
        XCTAssertFalse(PaneState().requestFocusFilter)
    }
}
