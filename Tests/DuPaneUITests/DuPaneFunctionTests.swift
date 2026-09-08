import Foundation
import XCTest
@testable import DuPane
// All tests [must] unless marked [optional]. See Build268Tests.swift for tagging convention.

final class DuPaneFunctionTests: DuPaneTestCase {
    private var fixture: FilePaneFixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        fixture = try FilePaneFixture()
    }

    override func tearDownWithError() throws {
        try fixture?.tearDown()
        fixture = nil
        try super.tearDownWithError()
    }

    func testLaunchConfigurationDefaultsToDownloadsAndComputerRoot() {
        let configuration = AppLaunchConfiguration.current(arguments: ["DuPane"])

        XCTAssertEqual(configuration.leftPaneURL, FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
        XCTAssertNil(configuration.rightPaneURL)
    }

    func testLaunchConfigurationUsesExplicitPaneURLs() {
        let configuration = AppLaunchConfiguration.current(arguments: [
            "DuPane",
            "--left-pane-url", fixture.leftPaneURL.path,
            "--right-pane-url", fixture.rightPaneURL.path
        ])

        XCTAssertEqual(configuration.leftPaneURL, fixture.leftPaneURL)
        XCTAssertEqual(configuration.rightPaneURL, fixture.rightPaneURL)
    }

    @MainActor
    func testLoadFolderReadsFilesAndFolders() throws {
        try fixture.createFolder(named: "Nested", in: .left)

        let names = try fixture.itemNames(in: .left)

        XCTAssertEqual(names, ["Nested", "alpha.txt", "beta.txt", "gamma.txt"])
    }

    @MainActor
    func testComputerRootLoadsMountedVolumes() async {
        let pane = PaneState()

        pane.start()
        await pane.loadingTask?.value

        XCTAssertNil(pane.currentURL)
        XCTAssertFalse(pane.items.isEmpty)
        XCTAssertTrue(pane.items.allSatisfy { $0.isVolume && $0.isDirectory })
    }

    @MainActor
    func testStartLoadsInitialFolder() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        pane.start()
        await pane.loadingTask?.value

        XCTAssertEqual(Set(pane.items.map(\.name)), Set(fixture.leftFileNames))
        XCTAssertNil(pane.errorMessage)
    }

    @MainActor
    func testBreadcrumbsStartAtComputerAndEndAtCurrentFolder() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        let labels = pane.breadcrumbs.map(\.label)

        XCTAssertEqual(labels.first, "Computer")
        XCTAssertEqual(labels.last, "left-pane")
    }

    @MainActor
    func testNavigateClearsSelectionAndFilter() throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        pane.selection = [try fixture.fileItem(named: "alpha.txt", in: .left).url]
        pane.filterText = "alpha"

        pane.navigate(to: fixture.rightPaneURL)

        XCTAssertEqual(pane.currentURL, fixture.rightPaneURL)
        XCTAssertTrue(pane.selection.isEmpty)
        XCTAssertTrue(pane.filterText.isEmpty)
    }

    @MainActor
    func testBackAndForwardNavigationUseHistory() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        pane.navigate(to: fixture.rightPaneURL)
        pane.goBack()

        XCTAssertEqual(pane.currentURL, fixture.leftPaneURL)
        XCTAssertTrue(pane.canGoForward)

        pane.goForward()

        XCTAssertEqual(pane.currentURL, fixture.rightPaneURL)
    }

    @MainActor
    func testGoUpMovesToParentFolder() throws {
        let childURL = try fixture.createFolder(named: "Child", in: .left)
        let pane = PaneState(initialURL: childURL)

        pane.goUp()

        XCTAssertEqual(pane.currentURL, fixture.leftPaneURL)
    }

    @MainActor
    func testGoUpFromVolumesReturnsToComputerRoot() {
        let pane = PaneState(initialURL: URL(fileURLWithPath: "/Volumes", isDirectory: true))

        pane.goUp()

        XCTAssertNil(pane.currentURL)
    }

    @MainActor
    func testSetSortChangesKeyAndTogglesDirection() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        pane.setSort(.size)
        XCTAssertEqual(pane.sortKey, .size)
        XCTAssertTrue(pane.sortAscending)

        pane.setSort(.size)
        XCTAssertFalse(pane.sortAscending)
    }

    @MainActor
    func testDisplayedItemsFiltersCaseInsensitively() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        pane.filterText = "ALPHA"

        XCTAssertEqual(pane.displayedItems.map(\.name), ["alpha.txt"])
    }

    @MainActor
    func testDisplayedItemsFiltersByActiveFinderTag() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = [
            makeItem(name: "alpha.txt", tags: ["Red"]),
            makeItem(name: "beta.txt", tags: ["Blue"]),
            makeItem(name: "gamma.txt", tags: ["red\n6"])
        ]
        pane.activeTagFilters = ["red"]

        XCTAssertEqual(pane.displayedItems.map(\.name), ["alpha.txt", "gamma.txt"])
    }

    @MainActor
    func testDisplayedItemsFiltersByMultipleFinderTags() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = [
            makeItem(name: "alpha.txt", tags: ["Red"]),
            makeItem(name: "beta.txt", tags: ["Blue"]),
            makeItem(name: "gamma.txt", tags: ["Green"])
        ]
        pane.activeTagFilters = ["red", "blue"]

        XCTAssertEqual(pane.displayedItems.map(\.name), ["alpha.txt", "beta.txt"])
    }

    // [optional] — tests internal string normalization, not user-visible output
    func testFinderTagSummariesNormalizeSpotlightValues() {
        let tags = FinderTagMetadata.summaries(from: [
            (value: "Red\n6", count: 2),
            (value: ["Blue\n4", "red"], count: 1),
            (value: "   ", count: 5)
        ])

        XCTAssertEqual(tags.map(\.name), ["Blue", "Red"])
        XCTAssertEqual(tags.first(where: { $0.name == "Blue" })?.count, 1)
        XCTAssertEqual(tags.first(where: { $0.name == "Red" })?.count, 3)
    }

    // [optional] — tests internal NSPredicate string format, not user-visible
    func testFinderTagDiscoveryPredicateUsesWildcardString() {
        let predicate = FinderTagMetadata.tagDiscoveryPredicate()

        XCTAssertTrue(predicate.predicateFormat.contains(FinderTagMetadata.userTagsAttribute))
        XCTAssertTrue(predicate.predicateFormat.contains("\"*\""))
        XCTAssertFalse(predicate.predicateFormat.contains("nil"))
    }

    @MainActor
    func testSidebarModelPublishesTagsFromPaneItems() {
        let model = SidebarModel()
        model.updatePaneTags(from: [
            makeItem(name: "alpha.txt", tags: ["Red"]),
            makeItem(name: "beta.txt", tags: ["Blue"]),
            makeItem(name: "gamma.txt", tags: ["red\n6"])
        ])

        XCTAssertEqual(model.tags.map(\.name), ["Blue", "Red"])
        XCTAssertEqual(model.tags.first(where: { $0.name == "Blue" })?.count, 1)
        XCTAssertEqual(model.tags.first(where: { $0.name == "Red" })?.count, 2)
    }

    @MainActor
    func testDisplayedItemsSortsDirectoriesFirstThenName() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = [
            makeItem(name: "zeta.txt", isDirectory: false),
            makeItem(name: "Archive", isDirectory: true),
            makeItem(name: "alpha.txt", isDirectory: false)
        ]

        XCTAssertEqual(pane.displayedItems.map(\.name), ["Archive", "alpha.txt", "zeta.txt"])
    }

    @MainActor
    func testDisplayedItemsSortsBySize() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        pane.setSort(.size)

        XCTAssertEqual(pane.displayedItems.map(\.name), ["beta.txt", "gamma.txt", "alpha.txt"])
    }

    @MainActor
    func testDisplayedItemsSortsByKind() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        pane.setSort(.kind)

        XCTAssertEqual(pane.displayedItems.map(\.name), ["gamma.txt", "alpha.txt", "beta.txt"])
    }

    @MainActor
    func testDisplayedItemsSortsByModifiedDate() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        pane.setSort(.modified)

        XCTAssertEqual(pane.displayedItems.map(\.name), ["beta.txt", "alpha.txt", "gamma.txt"])
    }

    @MainActor
    func testSelectedFileItemsReturnsSelectedFilesOnly() {
        let selectedFile = makeItem(name: "alpha.txt", isDirectory: false)
        let selectedFolder = makeItem(name: "Folder", isDirectory: true)
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = [selectedFile, selectedFolder]
        pane.selection = [selectedFile.url, selectedFolder.url]

        XCTAssertEqual(pane.selectedFileItems, [selectedFile])
    }

    @MainActor
    func testRenameTrimsNameReloadsFolderAndSelectsRenamedItem() async throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)
        let renamedURL = fixture.fileURL(named: "renamed.txt", in: .left)

        await pane.rename(item: item, to: "  renamed.txt  ")?.value
        await pane.loadingTask?.value

        XCTAssertFalse(fixture.exists(item.url))
        XCTAssertTrue(fixture.exists(renamedURL))
        XCTAssertEqual(pane.selection, [renamedURL])
        XCTAssertTrue(pane.items.contains { $0.name == "renamed.txt" })
    }

    func testCreateFolderCreatesFolderInDocumentsFixture() throws {
        let folderURL = try FileOperationService.createFolder(named: "  Created Folder  ", in: fixture.leftPaneURL)

        XCTAssertEqual(folderURL.path, fixture.folderURL(named: "Created Folder", in: .left).path)
        XCTAssertTrue(fixture.exists(folderURL))
    }

    func testCreateFileCreatesEmptyFileInDirectory() throws {
        let fileURL = try FileOperationService.createFile(named: "newfile.txt", in: fixture.leftPaneURL)

        XCTAssertTrue(fixture.exists(fileURL))
        XCTAssertEqual(fileURL.lastPathComponent, "newfile.txt")
        let data = try Data(contentsOf: fileURL)
        XCTAssertTrue(data.isEmpty, "newly created file should be empty")
    }

    func testCreateFileTrimsWhitespaceFromName() throws {
        let fileURL = try FileOperationService.createFile(named: "  spaced.txt  ", in: fixture.leftPaneURL)

        XCTAssertEqual(fileURL.lastPathComponent, "spaced.txt")
        XCTAssertTrue(fixture.exists(fileURL))
    }

    func testCreateFileFailsWhenFileAlreadyExists() throws {
        _ = try FileOperationService.createFile(named: "dup.txt", in: fixture.leftPaneURL)

        XCTAssertThrowsError(try FileOperationService.createFile(named: "dup.txt", in: fixture.leftPaneURL))
    }

    func testDeletePermanentlyRemovesFileWithNoTrash() throws {
        let url = try fixture.writeFile(named: "perm-delete.txt", in: .left)

        let result = FileOperationService.delete(urls: [url])

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(fixture.exists(url), "file should be gone from filesystem")
    }

    func testDeletePermanentlyRemovesMultipleFiles() throws {
        let url1 = try fixture.writeFile(named: "perm-1.txt", in: .left)
        let url2 = try fixture.writeFile(named: "perm-2.txt", in: .left)

        let result = FileOperationService.delete(urls: [url1, url2])

        XCTAssertEqual(result.succeeded, 2)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(fixture.exists(url1))
        XCTAssertFalse(fixture.exists(url2))
    }

    func testAppSettingsDeleteConfirmDefaultsAreFalse() {
        // Verify fresh UserDefaults has false for both delete-confirm toggles.
        let domain = "test-defaults-\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: domain)!
        XCTAssertFalse(ud.bool(forKey: "fileDeleteNoConfirm"))
        XCTAssertFalse(ud.bool(forKey: "directoryDeleteNoConfirm"))
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }

    func testStartupFolderModeDefaultParsing() {
        // Empty/missing raw value should fall back to .default
        XCTAssertEqual(StartupFolderMode(rawValue: "") ?? .default, .default)
        XCTAssertEqual(StartupFolderMode(rawValue: "rememberLast"), .rememberLast)
        XCTAssertEqual(StartupFolderMode(rawValue: "fixed"), .fixed)
    }

    @MainActor
    func testMoveOrCopySelfIntoSubfolderIsRejected() throws {
        let folderURL = try fixture.createFolder(named: "FolderA", in: .left)
        let folderItem = try fixture.fileItem(named: "FolderA", in: .left)

        // Trying to copy FolderA into itself should fail before touching the filesystem
        let result = FileOperationService.moveOrCopy(
            files: [folderItem], to: folderURL, isMove: false
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].contains("itself"))
    }

    @MainActor
    func testPaneStateShowHiddenFilesDefaultsFalse() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        XCTAssertFalse(pane.showHiddenFiles)
    }

    @MainActor
    func testCopySelectedFilesCopiesIntoOtherPane() throws {
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)

        let result = FileOperationService.moveOrCopy(files: [item], to: fixture.rightPaneURL, isMove: false)

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(fixture.exists(item.url))
        XCTAssertTrue(fixture.exists(fixture.fileURL(named: "alpha.txt", in: .right)))
    }

    @MainActor
    func testMoveSelectedFilesMovesIntoOtherPane() throws {
        let item = try fixture.fileItem(named: "beta.txt", in: .left)

        let result = FileOperationService.moveOrCopy(files: [item], to: fixture.rightPaneURL, isMove: true)

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(fixture.exists(item.url))
        XCTAssertTrue(fixture.exists(fixture.fileURL(named: "beta.txt", in: .right)))
    }

    @MainActor
    func testMoveReplacesExistingDestinationAndDeletesSource() throws {
        try fixture.writeFile(named: "alpha.txt", contents: "right-copy", in: .right)
        let source = try fixture.fileItem(named: "alpha.txt", in: .left)

        let result = FileOperationService.moveOrCopy(files: [source], to: fixture.rightPaneURL, isMove: true)

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(fixture.exists(source.url), "source should be deleted after move")
        XCTAssertTrue(fixture.exists(fixture.fileURL(named: "alpha.txt", in: .right)))
    }

    @MainActor
    func testCopyConflictOverwriteReplacesDestinationAndLeavesSource() throws {
        let sourceURL = try fixture.writeFile(named: "replace.txt", contents: "source", in: .left)
        let destinationURL = try fixture.writeFile(named: "replace.txt", contents: "destination", in: .right)
        let source = try fixture.fileItem(named: "replace.txt", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [source],
            to: fixture.rightPaneURL,
            isMove: false,
            conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "source")
    }

    @MainActor
    func testCopyConflictSkipLeavesExistingDestination() throws {
        let sourceURL = try fixture.writeFile(named: "skip.txt", contents: "source", in: .left)
        let destinationURL = try fixture.writeFile(named: "skip.txt", contents: "destination", in: .right)
        let source = try fixture.fileItem(named: "skip.txt", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [source],
            to: fixture.rightPaneURL,
            isMove: false,
            conflictResolution: .skip
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "destination")
    }

    @MainActor
    func testCopyConflictRenameKeepsBothFiles() throws {
        let sourceURL = try fixture.writeFile(named: "keep.txt", contents: "source", in: .left)
        let destinationURL = try fixture.writeFile(named: "keep.txt", contents: "destination", in: .right)
        let renamedDestinationURL = fixture.fileURL(named: "keep 2.txt", in: .right)
        let source = try fixture.fileItem(named: "keep.txt", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [source],
            to: fixture.rightPaneURL,
            isMove: false,
            conflictResolution: .rename
        )

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "destination")
        XCTAssertEqual(try String(contentsOf: renamedDestinationURL, encoding: .utf8), "source")
    }

    @MainActor
    func testCopyOverwriteSameFolderDoesNotDeleteSource() throws {
        let sourceURL = try fixture.writeFile(named: "same-copy.txt", contents: "source", in: .left)
        let source = try fixture.fileItem(named: "same-copy.txt", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [source],
            to: fixture.leftPaneURL,
            isMove: false,
            conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), "source")
    }

    @MainActor
    func testMoveOverwriteSameFolderDoesNotDeleteSource() throws {
        let sourceURL = try fixture.writeFile(named: "same-move.txt", contents: "source", in: .left)
        let source = try fixture.fileItem(named: "same-move.txt", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [source],
            to: fixture.leftPaneURL,
            isMove: true,
            conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), "source")
    }

    @MainActor
    func testMoveOrCopyReportsDestinationConflict() throws {
        let item = try fixture.fileItem(named: "target.txt", in: .right)
        try fixture.writeFile(named: "target.txt", contents: "existing", in: .left)

        let result = FileOperationService.moveOrCopy(files: [item], to: fixture.leftPaneURL, isMove: false)

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testTrashMovesItemsOutOfDocumentsFixtureAndReturnsCleanupURL() throws {
        let url = try fixture.writeFile(named: "delete-me.txt", in: .left)
        let trashURL = fixture.rootURL.appendingPathComponent("test-trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)

        let result = FileOperationService.trash(urls: [url], trashHandler: moveToTestTrash(in: trashURL))

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(fixture.exists(url))
        XCTAssertEqual(result.resultingURLs, [trashURL.appendingPathComponent("delete-me.txt")])
    }

    @MainActor
    func testPaneSelectionReplaceSelectsOneItem() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        let item = pane.items[0]

        pane.select(item, from: pane.displayedItems, mode: .replace)

        XCTAssertEqual(pane.selection, [item.url])
    }

    @MainActor
    func testPaneSelectionToggleAddsAndRemovesItem() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        let item = pane.items[0]

        pane.select(item, from: pane.displayedItems, mode: .toggle)
        XCTAssertEqual(pane.selection, [item.url])

        pane.select(item, from: pane.displayedItems, mode: .toggle)
        XCTAssertTrue(pane.selection.isEmpty)
    }

    @MainActor
    func testPaneSelectionRangeUsesSelectionAnchor() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        let displayedItems = pane.displayedItems

        pane.select(displayedItems[0], from: displayedItems, mode: .replace)
        pane.select(displayedItems[2], from: displayedItems, mode: .range)

        XCTAssertEqual(pane.selection, Set(displayedItems.map(\.url)))
    }

    func testFileRowsExposeUsableMinimumHitHeight() {
        XCTAssertGreaterThanOrEqual(FileRowView.minimumHitHeight, 28)
    }

    func testRowMouseEventSingleClickSelectsOnly() {
        XCTAssertEqual(
            RowMouseEventPolicy.actions(clickCount: 1, buttonNumber: 0),
            [.select]
        )
    }

    func testRowMouseEventDoubleClickSelectsThenOpens() {
        XCTAssertEqual(
            RowMouseEventPolicy.actions(clickCount: 2, buttonNumber: 0),
            [.select, .open]
        )
    }

    func testRowMouseEventRightClickLeavesContextMenuAvailable() {
        XCTAssertTrue(RowMouseEventPolicy.actions(clickCount: 1, buttonNumber: 1).isEmpty)
    }

    func testStatusFormatterShowsItemCountOnly() {
        XCTAssertEqual(PaneStatusFormatter.text(itemCount: 1, selectedCount: 0, selectedBytes: 0), "1 item")
        XCTAssertEqual(PaneStatusFormatter.text(itemCount: 3, selectedCount: 0, selectedBytes: 0), "3 items")
    }

    func testStatusFormatterIncludesSelectionCountAndSize() {
        let text = PaneStatusFormatter.text(itemCount: 3, selectedCount: 2, selectedBytes: 1024)

        XCTAssertTrue(text.hasPrefix("3 items, 2 selected"))
        XCTAssertTrue(text.contains("1 KB") || text.contains("1 kB"))
    }

    @MainActor
    func testDoubleClickFolderRoutesToNavigation() throws {
        let folderURL = try fixture.createFolder(named: "Open Folder", in: .left)
        let folder = try fixture.fileItem(named: "Open Folder", in: .left)
        let harness = ItemActionHarness()

        harness.open(folder)

        XCTAssertEqual(harness.navigatedURL, folderURL)
        XCTAssertNil(harness.openedURL)
    }

    @MainActor
    func testDoubleClickFileRoutesToExternalOpen() throws {
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)
        let harness = ItemActionHarness()

        harness.open(item)

        XCTAssertEqual(harness.openedURL, item.url)
        XCTAssertNil(harness.navigatedURL)
    }

    @MainActor
    func testRevealInFinderRoutesSelectedItemURL() throws {
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)
        let harness = ItemActionHarness()

        harness.reveal(item)

        XCTAssertEqual(harness.revealedURL, item.url)
    }

    // MARK: - Missing coverage

    @MainActor
    func testDisplayedItemsIsEmptyWhenFilterMatchesNothing() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = makeSortItems()
        pane.filterText = "zzzz-no-match"

        XCTAssertTrue(pane.displayedItems.isEmpty)
    }

    @MainActor
    func testDescendingSortEqualValuesTieBreakByName() {
        // Input: beta and alpha both have size 20, gamma has size 10.
        // A correct descending-by-size sort must break ties alphabetically.
        // The current sort has no tiebreaker, so equal-size items retain input
        // order (beta before alpha), violating Swift's strict-weak-ordering
        // contract. This test pins the desired behaviour and is expected to
        // fail until a name tiebreaker is added.
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.items = [
            makeItem(name: "beta.txt", size: 20),
            makeItem(name: "alpha.txt", size: 20),
            makeItem(name: "gamma.txt", size: 10)
        ]
        pane.sortKey = .size
        pane.sortAscending = false

        XCTAssertEqual(pane.displayedItems.map(\.name), ["alpha.txt", "beta.txt", "gamma.txt"])
    }

    @MainActor
    func testRenameToExistingNameSetsErrorMessageAndLeavesOriginalIntact() async throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)

        await pane.rename(item: item, to: "beta.txt")?.value

        XCTAssertNotNil(pane.errorMessage)
        XCTAssertTrue(fixture.exists(item.url))
    }

    @MainActor
    func testMoveOrCopyReportsAllConflictsForMultipleFiles() throws {
        try fixture.writeFile(named: "alpha.txt", contents: "right-alpha", in: .right)
        try fixture.writeFile(named: "beta.txt", contents: "right-beta", in: .right)
        let alpha = try fixture.fileItem(named: "alpha.txt", in: .left)
        let beta = try fixture.fileItem(named: "beta.txt", in: .left)

        let result = FileOperationService.moveOrCopy(files: [alpha, beta], to: fixture.rightPaneURL, isMove: false)

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.errors.count, 2)
    }

    func testTrashMultipleFilesReportsAllSuccesses() throws {
        let url1 = try fixture.writeFile(named: "del-1.txt", in: .left)
        let url2 = try fixture.writeFile(named: "del-2.txt", in: .left)
        let url3 = try fixture.writeFile(named: "del-3.txt", in: .left)
        let trashURL = fixture.rootURL.appendingPathComponent("test-trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)

        let result = FileOperationService.trash(
            urls: [url1, url2, url3],
            trashHandler: moveToTestTrash(in: trashURL)
        )

        XCTAssertEqual(result.succeeded, 3)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(fixture.exists(url1))
        XCTAssertFalse(fixture.exists(url2))
        XCTAssertFalse(fixture.exists(url3))
        XCTAssertEqual(
            Set(result.resultingURLs.map(\.lastPathComponent)),
            ["del-1.txt", "del-2.txt", "del-3.txt"]
        )
    }

    func testTrashReportsFailuresAndContinues() throws {
        let url1 = try fixture.writeFile(named: "trash-ok.txt", in: .left)
        let url2 = try fixture.writeFile(named: "trash-fails.txt", in: .left)
        let trashURL = fixture.rootURL.appendingPathComponent("test-trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)

        let result = FileOperationService.trash(urls: [url1, url2]) { url in
            guard url.lastPathComponent != "trash-fails.txt" else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try moveToTestTrash(in: trashURL)(url)
        }

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertFalse(fixture.exists(url1))
        XCTAssertTrue(fixture.exists(url2))
        XCTAssertEqual(result.resultingURLs, [trashURL.appendingPathComponent("trash-ok.txt")])
    }

    private func moveToTestTrash(in trashURL: URL) -> FileOperationService.TrashHandler {
        { url in
            let destinationURL = trashURL.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: url, to: destinationURL)
            return destinationURL
        }
    }

    private func makeSortItems() -> [FileItem] {
        [
            makeItem(name: "alpha.txt", size: 30, kind: "Text", modified: Date(timeIntervalSince1970: 20)),
            makeItem(name: "beta.txt", size: 10, kind: "Video", modified: Date(timeIntervalSince1970: 10)),
            makeItem(name: "gamma.txt", size: 20, kind: "Archive", modified: Date(timeIntervalSince1970: 30))
        ]
    }

    private func makeItem(
        name: String,
        isDirectory: Bool = false,
        size: Int64? = nil,
        kind: String = "Text",
        modified: Date? = nil,
        tags: [String] = []
    ) -> FileItem {
        let url = fixture.leftPaneURL.appendingPathComponent(name, isDirectory: isDirectory)
        return FileItem(
            id: url,
            name: name,
            url: url,
            isDirectory: isDirectory,
            isVolume: false,
            isRemovable: false,
            size: isDirectory ? nil : size,
            kind: isDirectory ? "Folder" : kind,
            modified: modified,
            tags: tags
        )
    }
}

// MARK: - TabbedPaneState Tests

@MainActor
final class TabbedPaneStateTests: DuPaneTestCase {

    func testInitialStateHasOneTab() {
        let state = TabbedPaneState(initialURL: nil)
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.activeTabIndex, 0)
    }

    func testOpenTabAddsTabAndActivatesIt() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()
        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.activeTabIndex, 1)
    }

    func testOpenTabInheritsCurrentURL() {
        let url = FileManager.default.homeDirectoryForCurrentUser
        let state = TabbedPaneState(initialURL: url)
        state.tabs[0].pane.currentURL = url
        state.openTab()
        XCTAssertEqual(state.tabs[1].pane.currentURL, url)
    }

    func testTagFiltersPropagateToExistingAndNewTabs() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()

        state.activeTagFilters = ["Red", "Blue"]

        XCTAssertEqual(state.tabs[0].pane.activeTagFilters, ["Red", "Blue"])
        XCTAssertEqual(state.tabs[1].pane.activeTagFilters, ["Red", "Blue"])

        state.openTab()
        XCTAssertEqual(state.tabs[2].pane.activeTagFilters, ["Red", "Blue"])
    }

    func testCloseTabCannotRemoveLastTab() {
        let state = TabbedPaneState(initialURL: nil)
        state.closeTab(at: 0)
        XCTAssertEqual(state.tabs.count, 1)
    }

    func testPinnedTabCannotBeClosedUntilUnpinned() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()
        state.setTabPinned(true, at: 1)

        state.closeTab(at: 1)

        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertTrue(state.tabs[1].isPinned)

        state.setTabPinned(false, at: 1)
        state.closeTab(at: 1)

        XCTAssertEqual(state.tabs.count, 1)
    }

    func testCloseLastTabMovesActiveIndexLeft() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()
        XCTAssertEqual(state.activeTabIndex, 1)
        state.closeTab(at: 1)
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.activeTabIndex, 0)
    }

    func testCloseTabBeforeActiveShiftsIndexLeft() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()
        state.openTab()
        let activePaneID = ObjectIdentifier(state.activePaneState)
        state.closeTab(at: 0)
        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.activeTabIndex, 1)
        XCTAssertEqual(ObjectIdentifier(state.activePaneState), activePaneID)
    }

    func testCloseActiveTabFromMiddle() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()
        state.openTab()
        state.switchTab(to: 1)
        let nextPaneID = ObjectIdentifier(state.tabs[2].pane)
        state.closeTab(at: 1)
        XCTAssertEqual(state.tabs.count, 2)
        XCTAssertEqual(state.activeTabIndex, 1)
        XCTAssertEqual(ObjectIdentifier(state.activePaneState), nextPaneID)
    }

    func testSwitchTab() {
        let state = TabbedPaneState(initialURL: nil)
        state.openTab()
        state.switchTab(to: 0)
        XCTAssertEqual(state.activeTabIndex, 0)
    }

    func testSwitchTabOutOfBoundsIsNoOp() {
        let state = TabbedPaneState(initialURL: nil)
        state.switchTab(to: 99)
        XCTAssertEqual(state.activeTabIndex, 0)
    }

    func testMoveTabReordersTabs() throws {
        let firstURL = try temporaryDirectory(named: "tab-reorder-first")
        let secondURL = try temporaryDirectory(named: "tab-reorder-second")
        let thirdURL = try temporaryDirectory(named: "tab-reorder-third")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: thirdURL)
        }

        let state = TabbedPaneState(initialURLs: [firstURL, secondURL, thirdURL])
        state.moveTab(from: 0, to: 3)

        XCTAssertEqual(state.tabs.map { $0.pane.currentURL }, [secondURL, thirdURL, firstURL])
    }

    func testMoveTabPreservesActiveTabIdentity() throws {
        let firstURL = try temporaryDirectory(named: "tab-active-first")
        let secondURL = try temporaryDirectory(named: "tab-active-second")
        let thirdURL = try temporaryDirectory(named: "tab-active-third")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: thirdURL)
        }

        let state = TabbedPaneState(initialURLs: [firstURL, secondURL, thirdURL])
        state.switchTab(to: 1)
        let activePaneID = ObjectIdentifier(state.activePaneState)

        state.moveTab(from: 1, to: 3)

        XCTAssertEqual(state.activeTabIndex, 2)
        XCTAssertEqual(ObjectIdentifier(state.activePaneState), activePaneID)
        XCTAssertEqual(state.activePaneState.currentURL, secondURL)
    }

    func testMoveTabPersistsReorderedMetadata() throws {
        let key = "test_tab_reorder_\(UUID().uuidString)"
        defer { removeTabPersistence(forKey: key) }
        let firstURL = try temporaryDirectory(named: "tab-persist-first")
        let secondURL = try temporaryDirectory(named: "tab-persist-second")
        let thirdURL = try temporaryDirectory(named: "tab-persist-third")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: thirdURL)
        }

        let state = TabbedPaneState(initialURLs: [firstURL, secondURL, thirdURL], tabsKey: key)
        state.setTabLabel("Pinned Second", at: 1)
        state.setTabPinned(true, at: 1)
        state.moveTab(from: 1, to: 0)

        XCTAssertEqual(TabPersistence.paths(forKey: key), [secondURL.path, firstURL.path, thirdURL.path])
        XCTAssertEqual(TabPersistence.labels(forKey: key), ["Pinned Second", nil, nil])
        XCTAssertEqual(TabPersistence.pins(forKey: key), [true, false, false])
        XCTAssertEqual(TabPersistence.pinnedPaths(forKey: key), [secondURL.path, nil, nil])
    }

    func testPinnedTabStateAndCustomNamePersist() throws {
        let key = "test_tab_pin_\(UUID().uuidString)"
        defer { removeTabPersistence(forKey: key) }
        let url = try temporaryDirectory(named: "pinned-tab")
        defer { try? FileManager.default.removeItem(at: url) }

        let state = TabbedPaneState(initialURLs: [url], tabsKey: key)
        state.setTabLabel("Reference", at: 0)
        state.setTabPinned(true, at: 0)

        let restored = TabbedPaneState(initialURLs: [url], tabsKey: key)

        XCTAssertEqual(restored.tabs[0].customLabel, "Reference")
        XCTAssertTrue(restored.tabs[0].isPinned)
    }

    func testActivatingPinnedTabRestoresPinnedFolderAfterNavigation() throws {
        let pinnedURL = try temporaryDirectory(named: "pinned-recall-source")
        let otherURL = try temporaryDirectory(named: "pinned-recall-other")
        defer {
            try? FileManager.default.removeItem(at: pinnedURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let state = TabbedPaneState(initialURLs: [pinnedURL])
        state.setTabPinned(true, at: 0)
        state.tabs[0].pane.navigate(to: otherURL)

        XCTAssertEqual(state.tabs[0].pane.currentURL, otherURL)

        state.activateTab(at: 0)

        XCTAssertEqual(state.tabs[0].pane.currentURL, pinnedURL)
    }

    func testPinnedTabOriginalFolderPersistsAfterNavigation() throws {
        let key = "test_tab_pinned_recall_\(UUID().uuidString)"
        defer { removeTabPersistence(forKey: key) }
        let pinnedURL = try temporaryDirectory(named: "pinned-persist-source")
        let otherURL = try temporaryDirectory(named: "pinned-persist-other")
        defer {
            try? FileManager.default.removeItem(at: pinnedURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let state = TabbedPaneState(initialURLs: [pinnedURL], tabsKey: key)
        state.setTabPinned(true, at: 0)
        state.tabs[0].pane.navigate(to: otherURL)

        let restored = TabbedPaneState(initialURLs: [otherURL], tabsKey: key)

        XCTAssertTrue(restored.tabs[0].isPinned)
        XCTAssertEqual(restored.tabs[0].pane.currentURL, otherURL)

        restored.activateTab(at: 0)

        XCTAssertEqual(restored.tabs[0].pane.currentURL, pinnedURL)
    }

    func testLaunchConfigurationRestoresPinnedTabsOutsideRememberLastMode() throws {
        let keys = [
            "leftTabState",
            "leftTabState_labels",
            "leftTabState_pins",
            "leftTabState_pinnedPaths",
            "leftStartupMode",
            "lastLeftURL"
        ]
        let snapshot = snapshotDefaults(forKeys: keys)
        defer { restoreDefaults(snapshot) }
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        let unpinnedURL = try temporaryDirectory(named: "unpinned-startup-tab")
        let pinnedURL = try temporaryDirectory(named: "pinned-startup-tab")
        defer {
            try? FileManager.default.removeItem(at: unpinnedURL)
            try? FileManager.default.removeItem(at: pinnedURL)
        }
        UserDefaults.standard.set(StartupFolderMode.default.rawValue, forKey: "leftStartupMode")

        let tabs = TabbedPaneState(initialURLs: [unpinnedURL], tabsKey: "leftTabState")
        tabs.openTab(url: pinnedURL)
        tabs.setTabLabel("Pinned Startup", at: 1)
        tabs.setTabPinned(true, at: 1)

        let configuration = AppLaunchConfiguration.current(arguments: ["DuPane"])

        XCTAssertTrue(configuration.leftTabURLs.contains { $0 == pinnedURL })
        XCTAssertFalse(configuration.leftTabURLs.contains { $0 == unpinnedURL })

        let restored = TabbedPaneState(initialURLs: configuration.leftTabURLs, tabsKey: "leftTabState")
        let restoredPinnedTab = restored.tabs.first { $0.pane.currentURL == pinnedURL }
        XCTAssertEqual(restoredPinnedTab?.customLabel, "Pinned Startup")
        XCTAssertEqual(restoredPinnedTab?.isPinned, true)
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func removeTabPersistence(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + TabPersistence.labelsSuffix)
        UserDefaults.standard.removeObject(forKey: key + TabPersistence.pinsSuffix)
        UserDefaults.standard.removeObject(forKey: key + TabPersistence.pinnedPathsSuffix)
    }

    private func snapshotDefaults(forKeys keys: [String]) -> [(key: String, value: Any?)] {
        keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
    }

    private func restoreDefaults(_ snapshot: [(key: String, value: Any?)]) {
        for entry in snapshot {
            if let value = entry.value {
                UserDefaults.standard.set(value, forKey: entry.key)
            } else {
                UserDefaults.standard.removeObject(forKey: entry.key)
            }
        }
    }
}

// MARK: - SidebarModel Tests

@MainActor
final class SidebarModelTests: DuPaneTestCase {

    // [optional] — environment check; fails only if system folders are missing
    func testSystemLocationsAreNonEmpty() {
        let model = SidebarModel()
        XCTAssertFalse(model.systemLocations.isEmpty)
        XCTAssertTrue(model.systemLocations.contains { $0.name == "Home" })
        XCTAssertTrue(model.systemLocations.contains { $0.name == "Downloads" })
    }

    func testAddBookmark() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.addBookmark(url)
        XCTAssertTrue(model.isBookmarked(url))
        model.removeBookmark(url) // cleanup
    }

    func testRemoveBookmark() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.addBookmark(url)
        model.removeBookmark(url)
        XCTAssertFalse(model.isBookmarked(url))
    }

    func testNoDuplicateBookmarks() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.addBookmark(url)
        model.addBookmark(url)
        let count = model.bookmarks.filter { $0 == url }.count
        XCTAssertEqual(count, 1)
        model.removeBookmark(url) // cleanup
    }

    func testAddFolderBookmarksIgnoresFilesAndAddsFolders() throws {
        let fixture = try FilePaneFixture()
        defer { try? fixture.tearDown() }

        let model = SidebarModel()
        let folderURL = try fixture.createFolder(named: "Bookmarkable Folder", in: .left)
        let fileURL = try fixture.writeFile(named: "not-a-folder.txt", in: .left)

        let addedCount = model.addFolderBookmarks([fileURL, folderURL, folderURL])

        XCTAssertEqual(addedCount, 1)
        XCTAssertTrue(model.isBookmarked(folderURL))
        XCTAssertFalse(model.isBookmarked(fileURL))
        XCTAssertEqual(model.bookmarks.filter { $0 == folderURL }.count, 1)
        model.removeBookmark(folderURL)
    }

    func testToggleBookmark() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.toggleBookmark(url)
        XCTAssertTrue(model.isBookmarked(url))
        model.toggleBookmark(url)
        XCTAssertFalse(model.isBookmarked(url))
    }
}

// MARK: - PaneState Enhanced Tests

@MainActor
final class PaneStateEnhancedTests: DuPaneTestCase {
    var fixture: FilePaneFixture!

    override func setUp() async throws {
        fixture = try FilePaneFixture()
    }

    override func tearDown() async throws {
        try? fixture.tearDown()
    }

    func testRenameRejectsSlash() async throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        guard let item = pane.items.first(where: { $0.name == "alpha.txt" }) else {
            return XCTFail("alpha.txt not found")
        }

        pane.rename(item: item, to: "folder/name.txt")
        XCTAssertNotNil(pane.errorMessage, "Expected error for name containing '/'")
        XCTAssertTrue(pane.items.contains { $0.name == "alpha.txt" }, "File should be unchanged")
    }

    // [optional] — verifies isLoading flag timing; tested implicitly by all async load tests
    func testIsLoadingTransition() async throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        XCTAssertFalse(pane.isLoading)
        pane.load()
        XCTAssertTrue(pane.isLoading)
        await pane.loadingTask?.value
        XCTAssertFalse(pane.isLoading)
    }

    func testSortPreferencePersistedAcrossNavigation() async throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        // Set size descending
        pane.setSort(.size)
        pane.setSort(.size) // toggles to descending
        XCTAssertEqual(pane.sortKey, .size)
        XCTAssertFalse(pane.sortAscending)

        // A second pane navigating to the same URL should restore the preference
        let pane2 = PaneState(initialURL: nil)
        pane2.navigate(to: fixture.leftPaneURL)
        await pane2.loadingTask?.value

        XCTAssertEqual(pane2.sortKey, .size)
        XCTAssertFalse(pane2.sortAscending)
    }

    // [optional] — checks tags array is never nil; trivial structural assertion
    func testTagsLoadedForFiles() async throws {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        // All items should have a tags array (possibly empty since test files have no tags)
        for item in pane.items {
            XCTAssertNotNil(item.tags, "tags should never be nil")
        }
    }
}

// MARK: - ProcessRunnerTests

@MainActor
final class ProcessRunnerTests: DuPaneTestCase {
    // [optional] — slow I/O stress test; run periodically, not on every build
    func testProcessRunnerHandlesLargeOutputWithoutDeadlock() async throws {
        let result = try await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "i=0; while [ $i -lt 20000 ]; do echo line; i=$((i + 1)); done"]
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertGreaterThan(result.stdout.count, 80_000)
    }

    // [optional] — slow shell process invocation; run periodically
    func testProcessRunnerCapturesNonzeroStatusAndStderr() async throws {
        let result = try await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo failure >&2; exit 7"]
        )

        XCTAssertEqual(result.terminationStatus, 7)
        XCTAssertEqual(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines), "failure")
    }
}

// MARK: - SmartMetadataServiceTests

@MainActor
final class SmartMetadataServiceTests: DuPaneTestCase {
    // [optional] — slow (500ms sleep); metadata correctness covered by Build42BugFixTests
    func testLineCountForSwiftFile() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).swift")
        try "line1\nline2\nline3\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = SmartMetadataService.shared
        let item = makeItem(url: tmp, ext: "swift")
        service.loadIfNeeded(for: [item])

        // Wait briefly for background task
        try await Task.sleep(nanoseconds: 500_000_000)
        let info = service.info(for: item)
        XCTAssertTrue(info?.contains("line") == true, "Expected line count, got: \(info ?? "nil")")
    }

    // [optional] — slow (500ms sleep); tests SmartMetadataService background path
    func testImageDimensionsForPNG() async throws {
        // Create a minimal 1x1 PNG (89 bytes)
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
            0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
            0x44, 0xAE, 0x42, 0x60, 0x82
        ])
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).png")
        try pngData.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = SmartMetadataService.shared
        let item = makeItem(url: tmp, ext: "png")
        service.loadIfNeeded(for: [item])
        try await Task.sleep(nanoseconds: 500_000_000)
        let info = service.info(for: item)
        XCTAssertTrue(info?.contains("px") == true, "Expected pixel dimensions, got: \(info ?? "nil")")
    }

    private func makeItem(url: URL, ext: String) -> FileItem {
        FileItem(id: url, name: url.lastPathComponent, url: url,
                 isDirectory: false, isVolume: false, isRemovable: false,
                 size: nil, kind: "Test", modified: nil, tags: [])
    }
}

// MARK: - FolderSizeViewModelTests

@MainActor
final class FolderSizeViewModelTests: DuPaneTestCase {
    // [optional] — slow folder scan; FolderSizeViewModel edge cases in FrontendCoverageTests
    func testScanCountsSubitems() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsvmtest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for i in 0..<5 {
            let f = dir.appendingPathComponent("file\(i).txt")
            try Data(repeating: UInt8(i), count: 1024).write(to: f)
        }

        let vm = FolderSizeViewModel()
        vm.scan(url: dir)

        var waited = 0
        while vm.isLoading && waited < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }

        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.entries.count, 5)
        XCTAssertGreaterThan(vm.totalBytes, 0)
    }

    // [optional] — slow folder scan; correctness covered by testScanCountsSubitems
    func testScanSortsLargestFirst() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsvmsort-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data(repeating: 0, count: 100).write(to: dir.appendingPathComponent("small.txt"))
        try Data(repeating: 0, count: 10000).write(to: dir.appendingPathComponent("large.txt"))

        let vm = FolderSizeViewModel()
        vm.scan(url: dir)

        var waited = 0
        while vm.isLoading && waited < 50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }

        XCTAssertEqual(vm.entries.first?.name, "large.txt")
    }

    // [optional] — trivial enum-case existence check; compiler catches removal anyway
    func testSortKeyInfoCaseExists() {
        XCTAssertTrue(SortKey.allCases.contains(.info))
        XCTAssertEqual(SortKey.info.rawValue, "Info")
    }

    // [optional] — trivial default; struct initialiser ensures this unless explicitly set
    func testFileItemIsRestrictedDefaultsFalse() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FileItem(
            id: url, name: "test", url: url,
            isDirectory: false, isVolume: false, isRemovable: false,
            size: nil, kind: "File", modified: nil, tags: []
        )
        XCTAssertFalse(item.isRestricted)
    }

    func testAppSettingsToggleColumnAddsAndRemoves() {
        let settings = AppSettings()
        XCTAssertFalse(settings.hiddenColumns.contains("Size"))
        settings.toggleColumn("Size")
        XCTAssertTrue(settings.hiddenColumns.contains("Size"))
        settings.toggleColumn("Size")
        XCTAssertFalse(settings.hiddenColumns.contains("Size"))
        // Clean up
        UserDefaults.standard.removeObject(forKey: "hiddenColumns")
    }

    func testAppSettingsHiddenColumnsMultiple() {
        UserDefaults.standard.removeObject(forKey: "hiddenColumns")
        let settings = AppSettings()
        settings.hiddenColumns = []  // reset to empty before toggling
        settings.toggleColumn("Kind")
        settings.toggleColumn("Modified")
        XCTAssertTrue(settings.hiddenColumns.contains("Kind"))
        XCTAssertTrue(settings.hiddenColumns.contains("Modified"))
        XCTAssertFalse(settings.hiddenColumns.contains("Size"))
        UserDefaults.standard.removeObject(forKey: "hiddenColumns")
    }

    func testAppSettingsColumnOrderDefaultContainsAllColumns() {
        UserDefaults.standard.removeObject(forKey: "columnOrder")
        let settings = AppSettings()
        XCTAssertEqual(settings.columnOrder, ["Size", "Kind", "Modified", "Info"])
        UserDefaults.standard.removeObject(forKey: "columnOrder")
    }

    func testAppSettingsColumnOrderIsPersisted() {
        UserDefaults.standard.removeObject(forKey: "columnOrder")
        let settings = AppSettings()
        settings.columnOrder = ["Info", "Modified", "Kind", "Size"]
        let settings2 = AppSettings()
        XCTAssertEqual(settings2.columnOrder, ["Info", "Modified", "Kind", "Size"])
        UserDefaults.standard.removeObject(forKey: "columnOrder")
    }

    func testAppSettingsColumnWidthsDefaults() {
        UserDefaults.standard.removeObject(forKey: "leftColumnWidths")
        let settings = AppSettings()
        XCTAssertEqual(settings.columnWidths(for: .left)["Size"], 80)
        XCTAssertEqual(settings.columnWidths(for: .left)["Kind"], 120)
        XCTAssertEqual(settings.columnWidths(for: .left)["Modified"], 150)
        XCTAssertEqual(settings.columnWidths(for: .left)["Info"], 80)
        UserDefaults.standard.removeObject(forKey: "leftColumnWidths")
    }

    func testAppSettingsColumnWidthsArePersisted() {
        UserDefaults.standard.removeObject(forKey: "leftColumnWidths")
        let settings = AppSettings()
        settings.setColumnWidths(["Kind": 200], for: .left)
        let settings2 = AppSettings()
        XCTAssertEqual(settings2.columnWidths(for: .left)["Kind"], 200)
        UserDefaults.standard.removeObject(forKey: "leftColumnWidths")
    }

    func testPaneStateShowCommandRunnerDefaultsFalse() {
        let pane = PaneState()
        XCTAssertFalse(pane.showCommandRunner)
    }

    func testTabbedPaneShowHiddenFilesPropagatesToAllTabs() {
        let tabs = TabbedPaneState()
        tabs.openTab()
        tabs.showHiddenFiles = true
        for tab in tabs.tabs {
            XCTAssertTrue(tab.pane.showHiddenFiles)
        }
        tabs.showHiddenFiles = false
        for tab in tabs.tabs {
            XCTAssertFalse(tab.pane.showHiddenFiles)
        }
    }

    func testTabbedPaneShowHiddenFilesNoOpWhenValueUnchanged() {
        let tabs = TabbedPaneState()
        tabs.showHiddenFiles = false
        tabs.showHiddenFiles = true
        tabs.showHiddenFiles = true
        XCTAssertTrue(tabs.activePaneState.showHiddenFiles)
    }

    func testTabbedPaneStateInitWithMultipleURLsCreatesMultipleTabs() {
        let url1 = FileManager.default.homeDirectoryForCurrentUser
        let url2 = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let tabs = TabbedPaneState(initialURLs: [url1, url2], tabsKey: nil)
        XCTAssertEqual(tabs.tabs.count, 2)
        XCTAssertEqual(tabs.tabs[0].pane.currentURL, url1)
        XCTAssertEqual(tabs.tabs[1].pane.currentURL, url2)
    }

    func testTabbedPaneStateInitEmptyURLsFallsBackToSingleNilTab() {
        let tabs = TabbedPaneState(initialURLs: [], tabsKey: nil)
        XCTAssertEqual(tabs.tabs.count, 1)
        XCTAssertNil(tabs.tabs[0].pane.currentURL)
    }

    func testTabbedPaneStateSavesTabsToUserDefaults() {
        let key = "test_tab_save_\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let url = FileManager.default.homeDirectoryForCurrentUser
        let tabs = TabbedPaneState(initialURLs: [url], tabsKey: key)
        tabs.openTab(url: url)
        let data = UserDefaults.standard.data(forKey: key)
        XCTAssertNotNil(data)
    }

    func testPaneStateRequestRenameDefaultsFalse() {
        let pane = PaneState()
        XCTAssertFalse(pane.requestRename)
    }

    func testAppLaunchConfigurationLeftTabURLsContainsFirstURL() {
        let configuration = AppLaunchConfiguration.current(arguments: ["DuPane"])
        XCTAssertFalse(configuration.leftTabURLs.isEmpty)
        XCTAssertEqual(configuration.leftPaneURL, configuration.leftTabURLs.first ?? nil)
    }

    // [optional] — hits real home directory; selectAll logic covered by testSelectAllWithActiveFilterOnlySelectsVisibleSubset
    func testPaneStateSelectAllSelectsDisplayedItems() async throws {
        let pane = PaneState(initialURL: FileManager.default.homeDirectoryForCurrentUser)
        pane.start()
        await pane.loadingTask?.value
        guard !pane.displayedItems.isEmpty else { return }
        pane.selectAll()
        let allURLs = Set(pane.displayedItems.map { $0.url })
        XCTAssertEqual(pane.selection, allURLs)
    }

    func testSidebarModelMoveBookmarkReorders() {
        let model = SidebarModel()
        let url1 = URL(fileURLWithPath: "/tmp")
        let url2 = URL(fileURLWithPath: "/private/tmp")
        model.addBookmark(url1)
        model.addBookmark(url2)
        model.moveBookmark(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(model.bookmarks.last, url1)
        model.removeBookmark(url1)
        model.removeBookmark(url2)
    }

    func testSidebarModelRenameBookmarkStoresCustomName() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.addBookmark(url)
        model.renameBookmark(url, to: "My Temp")
        XCTAssertEqual(model.displayName(for: url), "My Temp")
        model.renameBookmark(url, to: "")
        XCTAssertEqual(model.displayName(for: url), url.lastPathComponent)
        model.removeBookmark(url)
    }

    func testSidebarModelRemoveBookmarkClearsCustomName() {
        let model = SidebarModel()
        let url = URL(fileURLWithPath: "/tmp")
        model.addBookmark(url)
        model.renameBookmark(url, to: "Custom")
        model.removeBookmark(url)
        XCTAssertEqual(model.displayName(for: url), url.lastPathComponent)
    }
}
