import Foundation
import XCTest
@testable import DOpusMac

final class DeepSearchTests: XCTestCase {
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

    // MARK: - Initial State

    @MainActor
    func testDeepSearchInitiallyInactive() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        XCTAssertFalse(pane.isInSearchMode)
        XCTAssertFalse(pane.isSearching)
        XCTAssertNil(pane.searchResults)
    }

    // MARK: - beginDeepSearch

    @MainActor
    func testBeginDeepSearchDoesNothingWhenCurrentURLIsNil() {
        let pane = PaneState()

        pane.beginDeepSearch(query: "test")

        XCTAssertFalse(pane.isInSearchMode)
        XCTAssertFalse(pane.isSearching)
    }

    @MainActor
    func testBeginDeepSearchSetsIsSearchingAndIsInSearchMode() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        pane.beginDeepSearch(query: "alpha")

        XCTAssertTrue(pane.isSearching)
        XCTAssertTrue(pane.isInSearchMode)

        pane.endDeepSearch()
    }

    @MainActor
    func testBeginDeepSearchClearsSearchResultsWhileGathering() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        let fakeItem = FileItem(
            id: fixture.leftPaneURL.appendingPathComponent("fake.txt"),
            name: "fake.txt", url: fixture.leftPaneURL.appendingPathComponent("fake.txt"),
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 0, kind: "Text File", modified: nil, tags: [], isRestricted: false
        )
        pane._setSearchResults([fakeItem])

        pane.beginDeepSearch(query: "something")

        XCTAssertNil(pane.searchResults, "searchResults should be nil while gathering starts")
        XCTAssertTrue(pane.isSearching)

        pane.endDeepSearch()
    }

    // MARK: - endDeepSearch

    @MainActor
    func testEndDeepSearchResetsAllSearchState() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.beginDeepSearch(query: "gamma")

        pane.endDeepSearch()

        XCTAssertFalse(pane.isSearching)
        XCTAssertFalse(pane.isInSearchMode)
        XCTAssertNil(pane.searchResults)
    }

    @MainActor
    func testEndDeepSearchIsNoOpWhenNotSearching() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        // Should not crash and state should remain clean
        pane.endDeepSearch()

        XCTAssertFalse(pane.isInSearchMode)
        XCTAssertNil(pane.searchResults)
    }

    @MainActor
    func testBeginDeepSearchCancelsExistingSearch() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.beginDeepSearch(query: "alpha")
        XCTAssertTrue(pane.isSearching)

        // Second begin should cancel the first without crashing
        pane.beginDeepSearch(query: "beta")
        XCTAssertTrue(pane.isSearching)
        XCTAssertTrue(pane.isInSearchMode)

        pane.endDeepSearch()
    }

    // MARK: - displayedItems with searchResults

    @MainActor
    func testDisplayedItemsUsesSearchResultsWhenNonNil() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        let searchItem = FileItem(
            id: fixture.leftPaneURL.appendingPathComponent("sub/alpha.txt"),
            name: "alpha.txt",
            url: fixture.leftPaneURL.appendingPathComponent("sub/alpha.txt"),
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 100, kind: "Text File", modified: nil, tags: [], isRestricted: false
        )
        pane._setSearchResults([searchItem])

        XCTAssertEqual(pane.displayedItems.count, 1)
        XCTAssertEqual(pane.displayedItems.first?.name, "alpha.txt")
    }

    @MainActor
    func testDisplayedItemsBypassesTextFilterInSearchMode() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        pane.filterText = "alpha"
        let filteredCount = pane.displayedItems.count // only alpha.txt matches

        let searchItem = FileItem(
            id: fixture.leftPaneURL.appendingPathComponent("sub/beta.txt"),
            name: "beta.txt",
            url: fixture.leftPaneURL.appendingPathComponent("sub/beta.txt"),
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 50, kind: "Text File", modified: nil, tags: [], isRestricted: false
        )
        pane._setSearchResults([searchItem])

        // In search mode, filterText "alpha" should NOT filter the search results
        XCTAssertEqual(pane.displayedItems.count, 1)
        XCTAssertEqual(pane.displayedItems.first?.name, "beta.txt",
            "Search results should be returned as-is, not filtered by filterText")
        XCTAssertLessThan(filteredCount, pane.items.count,
            "Sanity check: filterText was actually filtering before search mode")
    }

    @MainActor
    func testDisplayedItemsResumesNormalBehaviorAfterEndSearch() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        pane.filterText = "alpha"
        let searchItem = FileItem(
            id: fixture.leftPaneURL.appendingPathComponent("sub/beta.txt"),
            name: "beta.txt",
            url: fixture.leftPaneURL.appendingPathComponent("sub/beta.txt"),
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 50, kind: "Text File", modified: nil, tags: [], isRestricted: false
        )
        pane._setSearchResults([searchItem])
        pane.endDeepSearch()

        // Back to normal: filterText "alpha" should filter items
        let names = pane.displayedItems.map(\.name)
        XCTAssertTrue(names.contains("alpha.txt"))
        XCTAssertFalse(names.contains("beta.txt"))
    }

    // MARK: - selectedItems with searchResults

    @MainActor
    func testSelectedItemsReadsFromSearchResultsWhenNonNil() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        let subURL = fixture.leftPaneURL.appendingPathComponent("sub/deep.txt")
        let searchItem = FileItem(
            id: subURL, name: "deep.txt", url: subURL,
            isDirectory: false, isVolume: false, isRemovable: false,
            size: 10, kind: "Text File", modified: nil, tags: [], isRestricted: false
        )
        pane._setSearchResults([searchItem])
        pane.selection = [subURL]

        XCTAssertEqual(pane.selectedItems.count, 1)
        XCTAssertEqual(pane.selectedItems.first?.name, "deep.txt")
    }

    @MainActor
    func testSelectedItemsReturnsEmptyWhenSearchResultsExcludeSelection() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.start()
        await pane.loadingTask?.value

        let normalURL = fixture.leftPaneURL.appendingPathComponent("alpha.txt")
        pane.selection = [normalURL]
        // Search results don't include the normally-selected item
        pane._setSearchResults([])

        XCTAssertEqual(pane.selectedItems.count, 0,
            "Selection of an item not in searchResults should yield empty selectedItems")
    }

    // MARK: - Navigation exits search mode

    @MainActor
    func testNavigateToURLExitsSearchMode() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.beginDeepSearch(query: "txt")
        XCTAssertTrue(pane.isInSearchMode)

        pane.navigate(to: fixture.rightPaneURL)
        await pane.loadingTask?.value

        XCTAssertFalse(pane.isInSearchMode)
        XCTAssertFalse(pane.isSearching)
        XCTAssertNil(pane.searchResults)
    }

    @MainActor
    func testGoBackExitsSearchMode() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.navigate(to: fixture.rightPaneURL)
        await pane.loadingTask?.value
        pane.beginDeepSearch(query: "txt")
        XCTAssertTrue(pane.isInSearchMode)

        pane.goBack()
        await pane.loadingTask?.value

        XCTAssertFalse(pane.isInSearchMode)
    }

    @MainActor
    func testGoForwardExitsSearchMode() async {
        let pane = PaneState(initialURL: fixture.leftPaneURL)
        pane.navigate(to: fixture.rightPaneURL)
        await pane.loadingTask?.value
        pane.goBack()
        await pane.loadingTask?.value
        pane.beginDeepSearch(query: "txt")
        XCTAssertTrue(pane.isInSearchMode)

        pane.goForward()
        await pane.loadingTask?.value

        XCTAssertFalse(pane.isInSearchMode)
    }

    // MARK: - isInSearchMode reflects both states

    @MainActor
    func testIsInSearchModeTrueWhenSearching() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        pane.beginDeepSearch(query: "x")

        // isSearching = true → isInSearchMode = true (even with nil searchResults)
        XCTAssertTrue(pane.isInSearchMode)
        XCTAssertTrue(pane.isSearching)

        pane.endDeepSearch()
    }

    @MainActor
    func testIsInSearchModeTrueWhenResultsAreSet() {
        let pane = PaneState(initialURL: fixture.leftPaneURL)

        pane._setSearchResults([])

        // searchResults is non-nil (empty) → isInSearchMode = true even though isSearching = false
        XCTAssertTrue(pane.isInSearchMode)
        XCTAssertFalse(pane.isSearching)
    }
}
