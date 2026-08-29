import Foundation
import XCTest
@testable import DuPane

// MARK: - DuplicateFinderViewModelTests (8 tests)

@MainActor
final class DuplicateFinderViewModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DupeFinder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
        dir = nil
        try super.tearDownWithError()
    }

    func testDuplicateScanPhaseTransitionsIdleScanningDone() async throws {
        let vm = DuplicateFinderViewModel()
        XCTAssertEqual(vm.phase, .idle)

        try "content".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        vm.startScan(at: dir)
        XCTAssertEqual(vm.phase, .scanning)

        let deadline = Date().addingTimeInterval(10)
        while vm.phase != .done, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(vm.phase, .done)
    }

    func testDuplicateScanGroupsIdenticalFilesByContent() async throws {
        let content = "identical content"
        try content.write(to: dir.appendingPathComponent("copy1.txt"), atomically: true, encoding: .utf8)
        try content.write(to: dir.appendingPathComponent("copy2.txt"), atomically: true, encoding: .utf8)

        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)

        try await waitForDone(vm)

        XCTAssertEqual(vm.groups.count, 1, "One duplicate group expected")
        XCTAssertEqual(vm.groups.first?.count, 2)
    }

    func testDuplicateScanDoesNotGroupDistinctFiles() async throws {
        try "aaa".write(to: dir.appendingPathComponent("unique1.txt"), atomically: true, encoding: .utf8)
        try "bbb".write(to: dir.appendingPathComponent("unique2.txt"), atomically: true, encoding: .utf8)
        try "ccc".write(to: dir.appendingPathComponent("unique3.txt"), atomically: true, encoding: .utf8)

        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)

        try await waitForDone(vm)

        XCTAssertTrue(vm.groups.isEmpty, "No groups expected for distinct files")
    }

    func testVerifiedDuplicateGroupsRejectSameLengthDifferentContent() throws {
        let url1 = dir.appendingPathComponent("first.txt")
        let url2 = dir.appendingPathComponent("second.txt")
        let url3 = dir.appendingPathComponent("third.txt")
        try "same bytes".write(to: url1, atomically: true, encoding: .utf8)
        try "same bytes".write(to: url2, atomically: true, encoding: .utf8)
        try "diff bytes".write(to: url3, atomically: true, encoding: .utf8)

        let groups = DuplicateFinderViewModel.verifiedDuplicateGroups(for: [url1, url2, url3])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), [url1, url2])
    }

    func testDuplicateScanSkipsZeroByteFiles() async throws {
        // Two empty files — were false positives before Build 42 fix
        FileManager.default.createFile(atPath: dir.appendingPathComponent("empty1.txt").path, contents: nil)
        FileManager.default.createFile(atPath: dir.appendingPathComponent("empty2.txt").path, contents: nil)

        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)

        try await waitForDone(vm)

        XCTAssertTrue(vm.groups.isEmpty, "Zero-byte files must not be grouped as duplicates")
    }

    func testDuplicateMoveToTrashRemovesURLFromGroup() async throws {
        let content = "shared bytes"
        let url1 = dir.appendingPathComponent("dup1.txt")
        let url2 = dir.appendingPathComponent("dup2.txt")
        try content.write(to: url1, atomically: true, encoding: .utf8)
        try content.write(to: url2, atomically: true, encoding: .utf8)

        let vm = DuplicateFinderViewModel { urls in
            FileOperationResult(succeeded: urls.count, errors: [], resultingURLs: urls)
        }
        vm.startScan(at: dir)
        try await waitForDone(vm)

        guard let group = vm.groups.first, group.count == 2 else {
            return XCTFail("Expected 1 group of 2 before trash")
        }
        let toTrash = group[0]
        vm.moveToTrash(toTrash)

        // One URL removed — group should shrink; if only one left, the group is gone
        let remaining = vm.groups.flatMap { $0 }
        XCTAssertFalse(remaining.contains(toTrash), "Trashed URL must be removed from all groups")
    }

    func testDuplicateMoveToTrashFailureKeepsURLAndReportsError() {
        let missing = dir.appendingPathComponent("missing.txt")
        let existing = dir.appendingPathComponent("existing.txt")
        let vm = DuplicateFinderViewModel { _ in
            FileOperationResult(succeeded: 0, errors: ["Trash failed"], resultingURLs: [])
        }
        vm.groups = [[missing, existing]]

        vm.moveToTrash(missing)

        XCTAssertEqual(vm.groups, [[missing, existing]])
        XCTAssertNotNil(vm.errorMessage)
    }

    func testDuplicateCancelResetsPhaseToIdle() async throws {
        // Write enough files so the scan won't finish instantly
        for i in 0..<20 {
            try "data\(i)".write(to: dir.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8)
        }

        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)
        XCTAssertEqual(vm.phase, .scanning)

        vm.cancel()

        XCTAssertEqual(vm.phase, .idle)
        XCTAssertTrue(vm.groups.isEmpty)
    }

    // MARK: - Helpers

    private func waitForDone(_ vm: DuplicateFinderViewModel, timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while vm.phase != .done, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        if vm.phase != .done {
            XCTFail("DuplicateFinderViewModel did not reach .done within \(timeout)s")
        }
    }
}

// MARK: - PaneState filter + navigation (3 tests)

@MainActor
final class PaneStateFilterNavigationTests: XCTestCase {
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

    func testGoBackClearsFilterText() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.navigate(to: fixture.rightPaneURL)
        pane.filterText = "alpha"

        pane.goBack()

        XCTAssertTrue(pane.filterText.isEmpty, "goBack() must clear the filter from the previous folder")
    }

    func testGoForwardClearsFilterText() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.navigate(to: fixture.rightPaneURL)
        pane.goBack()
        pane.filterText = "beta"

        pane.goForward()

        XCTAssertTrue(pane.filterText.isEmpty, "goForward() must clear the filter from the previous folder")
    }

    func testSelectAllWithActiveFilterOnlySelectsVisibleSubset() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = [
            makeItem(name: "alpha.txt"),
            makeItem(name: "beta.txt"),
            makeItem(name: "gamma.txt")
        ]
        pane.filterText = "alpha"

        pane.selectAll()

        XCTAssertEqual(pane.selection.count, 1, "selectAll() with filter active selects only displayed items")
        XCTAssertTrue(pane.selection.contains { $0.lastPathComponent == "alpha.txt" })
    }

    private func makeItem(name: String) -> FileItem {
        let url = fixture.leftPaneURL.appendingPathComponent(name)
        return FileItem(id: url, name: name, url: url, isDirectory: false, isVolume: false,
                        isRemovable: false, size: nil, kind: "Text", modified: nil, tags: [])
    }
}

// MARK: - Tab tint / colour (3 tests)

@MainActor
final class TabTintTests: XCTestCase {
    func testTabTintDefaultsToNil() {
        let state = TabbedPaneState(initialURL: nil)
        XCTAssertNil(state.tabs[0].tint)
    }

    func testSetTabTintUpdatesTabProperty() {
        let state = TabbedPaneState(initialURL: nil)
        state.setTabTint(.green, at: 0)
        XCTAssertEqual(state.tabs[0].tint, .green)
    }

    func testTabTintPersistsAcrossStateRecreation() {
        let key = "test_tint_\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: key + TabPersistence.tintsSuffix)
            UserDefaults.standard.removeObject(forKey: key + TabPersistence.labelsSuffix)
            UserDefaults.standard.removeObject(forKey: key + TabPersistence.pinsSuffix)
            UserDefaults.standard.removeObject(forKey: key + TabPersistence.pinnedPathsSuffix)
        }

        let state = TabbedPaneState(initialURLs: [nil], tabsKey: key)
        state.setTabTint(.purple, at: 0)

        let restored = TabbedPaneState(initialURLs: [nil], tabsKey: key)
        XCTAssertEqual(restored.tabs[0].tint, .purple)
    }
}

// MARK: - FolderSizeViewModel edge cases (2 tests)

@MainActor
final class FolderSizeViewModelEdgeCaseTests: XCTestCase {
    func testFolderSizeViewModelHandlesEmptyDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsvm-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = FolderSizeViewModel()
        vm.scan(url: dir)

        let deadline = Date().addingTimeInterval(5)
        while vm.isLoading, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertEqual(vm.totalBytes, 0)
    }

    func testFolderSizeViewModelCancelStopsLoading() async throws {
        // Create enough content to make the scan non-instant
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsvm-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for i in 0..<50 {
            let sub = dir.appendingPathComponent("sub\(i)", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data(repeating: UInt8(i % 256), count: 4096).write(to: sub.appendingPathComponent("file.bin"))
        }

        let vm = FolderSizeViewModel()
        vm.scan(url: dir)
        vm.cancel()

        XCTAssertFalse(vm.isLoading, "cancel() must immediately set isLoading to false")
    }
}

// MARK: - AppSettings & PaneState defaults (2 tests)

final class AppSettingsAndPaneDefaultTests: XCTestCase {
    // [optional] — trivial default; covered by the broader new-defaults test in Build268Tests
    func testAppSettingsListFontSizeDefaultIs14() {
        UserDefaults.standard.removeObject(forKey: "listFontSize")
        let settings = AppSettings()
        XCTAssertEqual(settings.listFontSize, 14)
        UserDefaults.standard.removeObject(forKey: "listFontSize")
    }

    @MainActor
    // [optional] — trivial nil default; incidentally verified by all tests that check errorMessage
    func testPaneErrorMessageDefaultsToNil() {
        let pane = PaneState()
        XCTAssertNil(pane.errorMessage)
    }
}
