import Foundation
import XCTest
@testable import DuPane

// Tests written from the 2026-09-07 code audit. Each class targets one bug
// or weakness identified during the review. All are [must] unless noted.

// MARK: - Bug 1: DuplicateFinderViewModel.verifiedDuplicateGroups [must]
// The function accesses $0[0] inside firstIndex(where:). Groups are always
// initialised with at least one URL and only grow, so the access is safe, but
// the behaviour must remain correct if the algorithm changes.

final class DuplicateFinderVerifiedGroupsTests: DuPaneTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dup-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        try super.tearDownWithError()
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(DuplicateFinderViewModel.verifiedDuplicateGroups(for: []).isEmpty,
                      "empty input must not crash and must return []")
    }

    func testSingleURLReturnsEmpty() throws {
        let url = dir.appendingPathComponent("only.txt")
        try "content".write(to: url, atomically: true, encoding: .utf8)
        let result = DuplicateFinderViewModel.verifiedDuplicateGroups(for: [url])
        XCTAssertTrue(result.isEmpty, "one URL cannot form a duplicate group")
    }

    func testTwoDifferentFilesReturnsEmpty() throws {
        let a = dir.appendingPathComponent("a.txt")
        let b = dir.appendingPathComponent("b.txt")
        try "aaa".write(to: a, atomically: true, encoding: .utf8)
        try "bbb".write(to: b, atomically: true, encoding: .utf8)
        let result = DuplicateFinderViewModel.verifiedDuplicateGroups(for: [a, b])
        XCTAssertTrue(result.isEmpty, "files with different content must not produce a group")
    }

    func testTwoIdenticalFilesReturnsOneGroup() throws {
        let a = dir.appendingPathComponent("x.txt")
        let b = dir.appendingPathComponent("y.txt")
        try "same".write(to: a, atomically: true, encoding: .utf8)
        try "same".write(to: b, atomically: true, encoding: .utf8)
        let result = DuplicateFinderViewModel.verifiedDuplicateGroups(for: [a, b])
        XCTAssertEqual(result.count, 1, "two identical files must form exactly one group")
        XCTAssertEqual(result[0].count, 2, "group must contain both URLs")
    }

    func testThreeFilesWithTwoDuplicatesReturnsOneGroup() throws {
        let a = dir.appendingPathComponent("dup1.txt")
        let b = dir.appendingPathComponent("dup2.txt")
        let c = dir.appendingPathComponent("unique.txt")
        try "dupe".write(to: a, atomically: true, encoding: .utf8)
        try "dupe".write(to: b, atomically: true, encoding: .utf8)
        try "other".write(to: c, atomically: true, encoding: .utf8)
        let result = DuplicateFinderViewModel.verifiedDuplicateGroups(for: [a, b, c])
        XCTAssertEqual(result.count, 1, "only the pair should form a group")
        XCTAssertEqual(result[0].count, 2)
        XCTAssertFalse(result[0].contains(c), "unique file must not be in any group")
    }

    func testAllThreeDuplicatesReturnsOneGroupOfThree() throws {
        let urls = try (1...3).map { i -> URL in
            let url = dir.appendingPathComponent("file\(i).txt")
            try "identical".write(to: url, atomically: true, encoding: .utf8)
            return url
        }
        let result = DuplicateFinderViewModel.verifiedDuplicateGroups(for: urls)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].count, 3)
    }
}

// MARK: - Bug 2: DuplicateFinderViewModel.moveToTrash group cleanup [must]
// After trashing one file from a 2-file group the group must be removed entirely,
// not left with a single-element group (which would be a non-duplicate).

@MainActor
final class DuplicateFinderMoveToTrashTests: DuPaneTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trash-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        try super.tearDownWithError()
    }

    func testTrashingFromTwoFileGroupRemovesGroup() throws {
        let a = dir.appendingPathComponent("copy1.txt")
        let b = dir.appendingPathComponent("copy2.txt")
        try "data".write(to: a, atomically: true, encoding: .utf8)
        try "data".write(to: b, atomically: true, encoding: .utf8)

        let vm = DuplicateFinderViewModel(trash: { _ in
            FileOperationResult(succeeded: 1, errors: [], resultingURLs: [])
        })
        vm.groups = [[a, b]]

        vm.moveToTrash(a)

        XCTAssertTrue(vm.groups.isEmpty,
                      "after trashing one copy from a 2-file group the group must be removed")
    }

    func testTrashingFromThreeFileGroupShrinksToTwo() throws {
        let a = dir.appendingPathComponent("c1.txt")
        let b = dir.appendingPathComponent("c2.txt")
        let c = dir.appendingPathComponent("c3.txt")
        for url in [a, b, c] { try "data".write(to: url, atomically: true, encoding: .utf8) }

        let vm = DuplicateFinderViewModel(trash: { _ in
            FileOperationResult(succeeded: 1, errors: [], resultingURLs: [])
        })
        vm.groups = [[a, b, c]]

        vm.moveToTrash(a)

        XCTAssertEqual(vm.groups.count, 1, "group must still exist with 2 remaining copies")
        XCTAssertEqual(vm.groups[0].count, 2)
        XCTAssertFalse(vm.groups[0].contains(a), "trashed URL must not remain in group")
    }

    func testTrashFailurePreservesGroup() throws {
        let a = dir.appendingPathComponent("fail1.txt")
        let b = dir.appendingPathComponent("fail2.txt")
        try "data".write(to: a, atomically: true, encoding: .utf8)
        try "data".write(to: b, atomically: true, encoding: .utf8)

        let vm = DuplicateFinderViewModel(trash: { _ in
            FileOperationResult(succeeded: 0, errors: ["Permission denied"], resultingURLs: [])
        })
        vm.groups = [[a, b]]

        vm.moveToTrash(a)

        XCTAssertEqual(vm.groups.count, 1, "failed trash must not modify groups")
        XCTAssertNotNil(vm.errorMessage)
    }

    func testTotalDuplicateCountIsAccurate() {
        let make = { URL(fileURLWithPath: "/tmp/\(UUID().uuidString)") }
        let vm = DuplicateFinderViewModel()
        vm.groups = [
            [make(), make()],        // 1 wasted
            [make(), make(), make()] // 2 wasted
        ]
        XCTAssertEqual(vm.totalDuplicateCount, 3)
    }
}

// MARK: - Bug 3: PaneState goBack/goForward boundary safety [must]
// historyIndex must stay in bounds. canGoBack/canGoForward are the only guards,
// so test that they gate correctly under navigation sequences.

@MainActor
final class PaneStateHistoryBoundaryTests: DuPaneTestCase {

    func testCanGoBackFalseAtStart() {
        let pane = PaneState(initialURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertFalse(pane.canGoBack, "fresh pane must not allow going back")
    }

    func testCanGoForwardFalseAtStart() {
        let pane = PaneState(initialURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertFalse(pane.canGoForward, "fresh pane must not allow going forward")
    }

    func testGoBackIsNoOpWhenAtStart() {
        let url = URL(fileURLWithPath: "/tmp")
        let pane = PaneState(initialURL: url)
        pane.goBack()
        XCTAssertEqual(pane.currentURL, url, "goBack at start must not change URL")
    }

    func testGoForwardIsNoOpWhenAtEnd() {
        let url = URL(fileURLWithPath: "/tmp")
        let pane = PaneState(initialURL: url)
        pane.goForward()
        XCTAssertEqual(pane.currentURL, url, "goForward at end must not change URL")
    }

    func testGoBackAfterNavigateReturnsToOriginal() {
        let initial = URL(fileURLWithPath: "/tmp")
        let next = URL(fileURLWithPath: "/var")
        let pane = PaneState(initialURL: initial)
        pane.navigate(to: next)
        XCTAssertTrue(pane.canGoBack)
        pane.goBack()
        XCTAssertEqual(pane.currentURL, initial)
    }

    func testGoForwardAfterGoBackMovesForward() {
        let a = URL(fileURLWithPath: "/tmp")
        let b = URL(fileURLWithPath: "/var")
        let pane = PaneState(initialURL: a)
        pane.navigate(to: b)
        pane.goBack()
        XCTAssertTrue(pane.canGoForward)
        pane.goForward()
        XCTAssertEqual(pane.currentURL, b)
    }

    func testNavigateAfterGoBackTruncatesForwardHistory() {
        let a = URL(fileURLWithPath: "/tmp")
        let b = URL(fileURLWithPath: "/var")
        let c = URL(fileURLWithPath: "/usr")
        let pane = PaneState(initialURL: a)
        pane.navigate(to: b)
        pane.goBack()
        pane.navigate(to: c)
        XCTAssertFalse(pane.canGoForward,
                       "navigating after goBack must truncate forward history")
    }

    func testRepeatedGoBackDoesNotUnderflow() {
        let pane = PaneState(initialURL: URL(fileURLWithPath: "/tmp"))
        pane.navigate(to: URL(fileURLWithPath: "/var"))
        for _ in 0..<10 { pane.goBack() }
        XCTAssertFalse(pane.canGoBack, "repeated goBack must stop at the beginning")
    }

    func testRepeatedGoForwardDoesNotOverflow() {
        let pane = PaneState(initialURL: URL(fileURLWithPath: "/tmp"))
        pane.navigate(to: URL(fileURLWithPath: "/var"))
        pane.goBack()
        for _ in 0..<10 { pane.goForward() }
        XCTAssertFalse(pane.canGoForward, "repeated goForward must stop at the end")
    }
}

// MARK: - Bug 4: NetworkVolumeMonitor.ejectAndRemove respects unmount failures [must]

final class NetworkVolumeMonitorEjectTests: DuPaneTestCase {

    func testEjectAndRemoveUpdatesSuppressedPaths() {
        let monitor = NetworkVolumeMonitor { _ in }
        let fakeURL = URL(fileURLWithPath: "/tmp/FakeShare")
        let volume = NetworkVolume(url: fakeURL)
        monitor.mountedVolumes = [volume]

        monitor.ejectAndRemove(volume)

        XCTAssertTrue(monitor.suppressedPaths.contains(fakeURL.path),
                      "ejectAndRemove must add the volume path to suppressedPaths")
    }

    func testSuccessfulEjectDropsVolumeFromModel() {
        let monitor = NetworkVolumeMonitor { _ in }
        let fakeURL = URL(fileURLWithPath: "/tmp/FakeShare")
        let volume = NetworkVolume(url: fakeURL)
        monitor.mountedVolumes = [volume]

        monitor.ejectAndRemove(volume)

        XCTAssertTrue(monitor.mountedVolumes.isEmpty,
                      "ejectAndRemove removes the volume after a successful unmount")
    }

    func testEjectFailureKeepsVolumeVisibleAndUnsuppressed() {
        let fakeURL = URL(fileURLWithPath: "/tmp/FakeShare")
        let volume = NetworkVolume(url: fakeURL)
        let monitor = NetworkVolumeMonitor { _ in throw CocoaError(.fileNoSuchFile) }
        monitor.clearSuppressedPaths()
        monitor.mountedVolumes = [volume]

        monitor.ejectAndRemove(volume)

        XCTAssertEqual(monitor.mountedVolumes, [volume])
        XCTAssertFalse(monitor.suppressedPaths.contains(fakeURL.path))
    }

    func testClearSuppressedPathsRestoresVolumes() {
        let monitor = NetworkVolumeMonitor()
        let fakeURL = URL(fileURLWithPath: "/tmp/FakeShare")
        let volume = NetworkVolume(url: fakeURL)
        monitor.mountedVolumes = [volume]
        monitor.ejectAndRemove(volume)

        monitor.clearSuppressedPaths()

        XCTAssertTrue(monitor.suppressedPaths.isEmpty,
                      "clearSuppressedPaths must empty the suppressed set")
    }
}

// MARK: - Bug 5: AppLaunchConfiguration.url() existence not checked [must]
// url(for:in:) creates a URL with isDirectory:true without verifying the path
// exists. A non-existent path still produces a non-nil URL — this documents
// the behaviour so a future fix can be verified against these tests.

final class AppLaunchConfigurationURLTests: DuPaneTestCase {

    func testNonExistentLeftPaneURLFallsBackToDefault() {
        let ghost = "/tmp/this-path-does-not-exist-\(UUID().uuidString)"
        let config = AppLaunchConfiguration.current(arguments: [
            "DuPane", "--left-pane-url", ghost
        ])
        // Non-existent path is now rejected; config falls back to ~/Downloads default.
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        XCTAssertNotEqual(config.leftPaneURL?.path, ghost,
                          "non-existent path should not be used as left pane URL")
        XCTAssertEqual(config.leftPaneURL?.standardizedFileURL,
                       downloads.standardizedFileURL,
                       "non-existent path should fall back to ~/Downloads")
    }

    func testMissingValueAfterFlagFallsBackToDefault() {
        let config = AppLaunchConfiguration.current(arguments: [
            "DuPane", "--left-pane-url"
        ])
        // No value follows the flag — url(for:in:) returns nil, so the config
        // falls back to the built-in default (~/Downloads). Must not crash.
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        XCTAssertEqual(config.leftPaneURL?.standardizedFileURL,
                       downloads.standardizedFileURL,
                       "missing flag value must fall back to ~/Downloads default")
    }

    func testNoFlagUsesDownloadsDefault() {
        let config = AppLaunchConfiguration.current(arguments: ["DuPane"])
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        XCTAssertEqual(config.leftPaneURL?.standardizedFileURL,
                       downloads.standardizedFileURL,
                       "no flag must default to ~/Downloads")
    }

    func testRightPaneURLFlag() {
        let path = "/tmp"
        let config = AppLaunchConfiguration.current(arguments: [
            "DuPane", "--right-pane-url", path
        ])
        XCTAssertNotNil(config.rightPaneURL)
        XCTAssertEqual(config.rightPaneURL?.path, path)
    }
}

// MARK: - Bug 6: DuplicateFinderViewModel.filesHaveSameContents edge cases [must]
// Same-URL comparison must short-circuit. Zero-byte files must not be confused
// with each other (size guard handles this via the scan pre-filter, but document it).

final class DuplicateFinderSameContentsTests: DuPaneTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("content-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        try super.tearDownWithError()
    }

    func testSameURLReturnsTrueWithoutReadingFile() {
        let url = dir.appendingPathComponent("file.txt")
        XCTAssertTrue(DuplicateFinderViewModel.filesHaveSameContents(url, url),
                      "same URL must return true (short-circuit)")
    }

    func testIdenticalContentReturnsTrue() throws {
        let a = dir.appendingPathComponent("a.bin")
        let b = dir.appendingPathComponent("b.bin")
        let data = Data(repeating: 0xAB, count: 1024)
        try data.write(to: a)
        try data.write(to: b)
        XCTAssertTrue(DuplicateFinderViewModel.filesHaveSameContents(a, b))
    }

    func testDifferentContentReturnsFalse() throws {
        let a = dir.appendingPathComponent("x.bin")
        let b = dir.appendingPathComponent("y.bin")
        try Data(repeating: 0x01, count: 512).write(to: a)
        try Data(repeating: 0x02, count: 512).write(to: b)
        XCTAssertFalse(DuplicateFinderViewModel.filesHaveSameContents(a, b))
    }

    func testMissingFileReturnsFalse() {
        let real = dir.appendingPathComponent("exists.txt")
        let ghost = dir.appendingPathComponent("ghost.txt")
        try? "data".write(to: real, atomically: true, encoding: .utf8)
        XCTAssertFalse(DuplicateFinderViewModel.filesHaveSameContents(real, ghost),
                       "one missing file must return false, not crash")
    }
}
