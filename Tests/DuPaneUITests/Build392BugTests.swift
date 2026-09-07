import Foundation
import XCTest
@testable import DuPane

// Tests for bugs fixed in Build 392.
// Each test class is named after the bug it covers.

// MARK: - SortPreference pruning (Critical: PaneState sortPref UserDefaults leak)

final class SortPreferenceKeyPruningTests: XCTestCase {
    private let ud = UserDefaults(suiteName: "SortPrefPruningTests-\(UUID().uuidString)")!

    override func tearDownWithError() throws {
        ud.removePersistentDomain(forName: ud.description)
        try super.tearDownWithError()
    }

    @MainActor
    func testSortPreferenceCapAt200Keys() async throws {
        // Write 201 distinct URLs and verify only 200 remain in UserDefaults.
        let base = URL(fileURLWithPath: "/tmp/sortpref-\(UUID().uuidString)")
        for i in 0..<201 {
            let url = base.appendingPathComponent("dir\(i)")
            SortPreference.save(url: url, key: .name, ascending: true, userDefaults: ud)
        }
        let order = ud.stringArray(forKey: SortPreference.orderKey) ?? []
        XCTAssertEqual(order.count, 200, "Order list should be capped at 200")
        // The first entry (dir0) should have been evicted.
        let evictedKey = "sortPref_\(base.appendingPathComponent("dir0").path)"
        XCTAssertNil(ud.object(forKey: evictedKey), "Oldest key should be removed from UserDefaults")
        // The last entry (dir200) should be present.
        let keptKey = "sortPref_\(base.appendingPathComponent("dir200").path)"
        XCTAssertNotNil(ud.object(forKey: keptKey), "Newest key should still be present")
    }

    @MainActor
    func testSortPreferenceUpdatingExistingKeyDoesNotGrowList() async throws {
        let url = URL(fileURLWithPath: "/tmp/sortpref-stable-\(UUID().uuidString)")
        for _ in 0..<10 {
            SortPreference.save(url: url, key: .name, ascending: true, userDefaults: ud)
        }
        let order = ud.stringArray(forKey: SortPreference.orderKey) ?? []
        XCTAssertEqual(order.count, 1, "Repeated saves to same URL should not grow the list")
    }
}

// MARK: - AppLaunchConfiguration non-existent path (Low: url() no existence check)

final class AppLaunchConfigurationURLExistenceTests: XCTestCase {
    func testNonExistentPathIsIgnoredAndFallsBackToDefault() {
        let nonExistentPath = "/tmp/dupane-nonexistent-\(UUID().uuidString)/some/folder"
        let config = AppLaunchConfiguration.current(arguments: ["DuPane", "--left-pane-url", nonExistentPath])
        // Non-existent arg is rejected; config falls back to ~/Downloads.
        XCTAssertNotEqual(config.leftPaneURL?.path, nonExistentPath,
                          "Non-existent path should not be used as left pane URL")
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        XCTAssertEqual(config.leftPaneURL?.standardizedFileURL, downloads.standardizedFileURL,
                       "Non-existent path should fall back to ~/Downloads default")
    }

    func testExistingDirectoryProducesURL() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("dupane-exist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let config = AppLaunchConfiguration.current(arguments: ["DuPane", "--left-pane-url", tmp.path])
        XCTAssertEqual(config.leftPaneURL?.standardizedFileURL, tmp.standardizedFileURL)
        XCTAssertTrue(config.leftPaneURL?.hasDirectoryPath == true)
    }

    func testExistingFileProducesNonDirectoryURL() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("dupane-file-\(UUID().uuidString).txt")
        try "hello".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let config = AppLaunchConfiguration.current(arguments: ["DuPane", "--left-pane-url", tmp.path])
        XCTAssertNotNil(config.leftPaneURL)
        XCTAssertFalse(config.leftPaneURL?.hasDirectoryPath == true)
    }
}

// MARK: - PaneState duplicate at Computer root (Low: duplicate() silent fail)

final class PaneStateDuplicateAtRootTests: XCTestCase {
    @MainActor
    func testDuplicateAtComputerRootSetsErrorMessage() async {
        let pane = PaneState(initialURL: nil)
        XCTAssertNil(pane.currentURL, "Precondition: pane should be at Computer root")
        pane.duplicate()
        XCTAssertNotNil(pane.errorMessage, "duplicate() at Computer root should set errorMessage")
    }

    @MainActor
    func testDuplicateInFolderWithNoSelectionDoesNotSetError() async {
        let pane = PaneState(initialURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertNotNil(pane.currentURL)
        XCTAssertTrue(pane.selectedItems.isEmpty)
        pane.duplicate()
        XCTAssertNil(pane.errorMessage, "duplicate() with no selection should not set errorMessage")
    }
}

// MARK: - TabbedPaneState pinned-path migration guard (Low: diverged savedPinnedPaths)

final class TabbedPinMigrationTests: XCTestCase {
    private let key = "TabbedPinMigrationTests-\(UUID().uuidString)"
    private let ud = UserDefaults.standard

    override func tearDownWithError() throws {
        ud.removeObject(forKey: key)
        ud.removeObject(forKey: key + TabPersistence.labelsSuffix)
        ud.removeObject(forKey: key + TabPersistence.pinsSuffix)
        ud.removeObject(forKey: key + TabPersistence.pinnedPathsSuffix)
        ud.removeObject(forKey: key + TabPersistence.tintsSuffix)
        try super.tearDownWithError()
    }

    @MainActor
    func testDivergedPinnedPathsFallsBackToSavedPaths() async throws {
        // Simulate a crash mid-save: savedPaths has 2 entries, savedPinnedPaths has only 1.
        // The tab at index 0 is pinned; its pinnedURL should come from savedPaths[0], not the
        // mismatched savedPinnedPaths[0] which belongs to a different session.
        let pathA = "/tmp/pinned-a"
        let pathB = "/tmp/pinned-b"
        let stalePinnedPath = "/tmp/stale-pinned"

        TabPersistence.save(
            paths: [pathA, pathB],
            labels: [nil, nil],
            pins: [true, false],
            pinnedPaths: [stalePinnedPath],   // only 1 entry — count mismatch
            tints: [nil, nil],
            forKey: key
        )

        let state = TabbedPaneState(
            initialURLs: [URL(fileURLWithPath: pathA), URL(fileURLWithPath: pathB)],
            tabsKey: key
        )

        let pinnedTab = state.tabs.first(where: { $0.isPinned })
        XCTAssertNotNil(pinnedTab, "Tab at index 0 should be pinned")
        // pinnedURL must NOT be the stale path — it should fall back to savedPaths[0].
        XCTAssertNotEqual(
            pinnedTab?.pinnedURL?.path, stalePinnedPath,
            "Diverged savedPinnedPaths should not be used; should fall back to savedPaths"
        )
        XCTAssertEqual(
            pinnedTab?.pinnedURL?.path, pathA,
            "pinnedURL should fall back to savedPaths[0] when savedPinnedPaths count diverges"
        )
    }

    @MainActor
    func testConsistentPinnedPathsAreUsed() async throws {
        let pathA = "/tmp/consistent-a"
        let pathB = "/tmp/consistent-b"
        let pinnedPath = "/tmp/consistent-pinned"

        TabPersistence.save(
            paths: [pathA, pathB],
            labels: [nil, nil],
            pins: [true, false],
            pinnedPaths: [pinnedPath, nil],  // count matches savedPaths
            tints: [nil, nil],
            forKey: key
        )

        let state = TabbedPaneState(
            initialURLs: [URL(fileURLWithPath: pathA), URL(fileURLWithPath: pathB)],
            tabsKey: key
        )

        let pinnedTab = state.tabs.first(where: { $0.isPinned })
        XCTAssertEqual(
            pinnedTab?.pinnedURL?.path, pinnedPath,
            "Consistent savedPinnedPaths should be used as pinnedURL"
        )
    }
}
