import XCTest

final class DuPaneClickTests: XCTestCase {
    private var fixture: FilePaneFixture!
    private var harness: ClickSelectionHarness!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        fixture = try FilePaneFixture()
        harness = ClickSelectionHarness(
            leftRows: fixture.leftFileNames,
            rightRows: fixture.rightFileNames
        )
    }

    override func tearDownWithError() throws {
        try fixture?.tearDown()
        fixture = nil
        harness = nil
        try super.tearDownWithError()
    }

    func testSingleClickSelectsOneRow() {
        click(.plain, rowNamed: "alpha.txt", in: .left)

        XCTAssertEqual(harness.selectionCount(in: .left), 1)
        XCTAssertTrue(harness.isSelected("alpha.txt", in: .left))
    }

    func testSingleClickReplacesExistingSelection() {
        click(.plain, rowNamed: "alpha.txt", in: .left)
        click(.plain, rowNamed: "beta.txt", in: .left)

        XCTAssertEqual(harness.selection(in: .left), ["beta.txt"])
    }

    func testDoubleClickSelectsAndOpensRow() {
        doubleClick(rowNamed: "alpha.txt", in: .left)

        XCTAssertEqual(harness.selection(in: .left), ["alpha.txt"])
        XCTAssertEqual(harness.openedRows(in: .left), ["alpha.txt"])
    }

    func testCommandClickAddsToSelection() {
        click(.plain, rowNamed: "alpha.txt", in: .left)
        click(.command, rowNamed: "beta.txt", in: .left)

        XCTAssertEqual(harness.selection(in: .left), ["alpha.txt", "beta.txt"])
    }

    func testShiftClickExtendsSelectionRange() {
        click(.plain, rowNamed: "alpha.txt", in: .left)
        click(.shift, rowNamed: "gamma.txt", in: .left)

        XCTAssertEqual(harness.selection(in: .left), ["alpha.txt", "beta.txt", "gamma.txt"])
    }

    func testShiftClickWithNoPriorAnchorSelectsOnlyThatRow() {
        // No prior click means no anchor — extendSelection falls back to
        // selecting just the clicked row and establishing it as the new anchor.
        click(.shift, rowNamed: "beta.txt", in: .left)

        XCTAssertEqual(harness.selection(in: .left), ["beta.txt"])
    }

    func testShiftClickBackwardExtendsSelectionTowardFirstRow() {
        click(.plain, rowNamed: "gamma.txt", in: .left)
        click(.shift, rowNamed: "alpha.txt", in: .left)

        XCTAssertEqual(harness.selection(in: .left), ["alpha.txt", "beta.txt", "gamma.txt"])
    }

    func testSingleClickInInactivePaneUsesThatPaneAsSelectionContext() {
        click(.plain, rowNamed: "target.txt", in: .right)

        XCTAssertEqual(harness.activePane, .right)
        XCTAssertEqual(harness.selection(in: .right), ["target.txt"])
        XCTAssertEqual(harness.destinationPane, .left)
    }

    private func click(_ variant: ClickVariant, rowNamed name: String, in pane: TestPane) {
        XCTAssertNoThrow(
            try XCTContext.runActivity(named: "\(variant.title) \(name)") { _ in
                try harness.click(variant, rowNamed: name, in: pane)
            }
        )
    }

    private func doubleClick(rowNamed name: String, in pane: TestPane) {
        XCTAssertNoThrow(
            try XCTContext.runActivity(named: "Double-click \(name)") { _ in
                try harness.doubleClick(rowNamed: name, in: pane)
            }
        )
    }
}
