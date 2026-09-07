import XCTest

final class DuPaneEndToEndUITests: XCTestCase {
    private var fixture: EndToEndFixture!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        #if SWIFT_PACKAGE
        // XCUIApplication requires DuPane.app to be built and placed next to
        // this test bundle in the build products directory. When running the
        // package test plan without the app scheme, the bundle won't exist and
        // the test host reports "No target application path specified". Skip
        // cleanly instead of failing.
        let productsDir = Bundle(for: DuPaneEndToEndUITests.self).bundleURL
            .deletingLastPathComponent()
        let appExists = FileManager.default.fileExists(
            atPath: productsDir.appendingPathComponent("DuPane.app").path
        )
        try XCTSkipUnless(appExists, "Build DuPane.app first — run via Xcode with the app scheme")
        #endif
        fixture = try EndToEndFixture()
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        try fixture?.tearDown()
        fixture = nil
        try super.tearDownWithError()
    }

    // Critical UI tag: method names beginning with testCritical are the
    // post-build subset for functional, broad, or explicitly full test runs.
    @MainActor
    func testCriticalRenameFileThroughToolbarSheet() throws {
        launchApp()
        let originalRow = waitForRow(named: "alpha.txt", in: "left")

        clickRow(originalRow)
        waitForSelection(originalRow)
        clickToolbarButton("toolbar-rename-button")

        let nameField = app.textFields["text-prompt-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("renamed-alpha.txt")
        clickToolbarButton("text-prompt-confirm-button")

        XCTAssertTrue(row(named: "renamed-alpha.txt", in: "left").waitForExistence(timeout: 5))
        waitForMissingRow(named: "alpha.txt", in: "left")
        XCTAssertFalse(fixture.exists(fixture.fileURL(named: "alpha.txt", in: fixture.leftPaneURL)))
        XCTAssertEqual(
            try fixture.fileContents(named: "renamed-alpha.txt", in: fixture.leftPaneURL),
            "alpha"
        )
    }

    @MainActor
    func testCriticalCopySelectedFileBetweenPanes() throws {
        let sourceURL = try fixture.writeFile(named: "copy-me.txt", contents: "copy source", in: fixture.leftPaneURL)
        launchApp()

        let sourceRow = waitForRow(named: "copy-me.txt", in: "left")
        clickRow(sourceRow)
        waitForSelection(sourceRow)
        clickToolbarButton("toolbar-copy-button")

        XCTAssertTrue(row(named: "copy-me.txt", in: "right").waitForExistence(timeout: 5))
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try fixture.fileContents(named: "copy-me.txt", in: fixture.rightPaneURL), "copy source")
    }

    @MainActor
    func testCriticalMoveSelectedFileBetweenPanes() throws {
        let sourceURL = try fixture.writeFile(named: "move-me.txt", contents: "move source", in: fixture.leftPaneURL)
        launchApp()

        let sourceRow = waitForRow(named: "move-me.txt", in: "left")
        clickRow(sourceRow)
        waitForSelection(sourceRow)
        clickToolbarButton("toolbar-move-button")

        XCTAssertTrue(row(named: "move-me.txt", in: "right").waitForExistence(timeout: 5))
        waitForMissingRow(named: "move-me.txt", in: "left")
        XCTAssertFalse(fixture.exists(sourceURL))
        XCTAssertEqual(try fixture.fileContents(named: "move-me.txt", in: fixture.rightPaneURL), "move source")
    }

    @MainActor
    func testCriticalCopyConflictDialogResolvesOverwriteSkipAndKeepBoth() throws {
        try fixture.writeFile(named: "overwrite-conflict.txt", contents: "incoming overwrite", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "overwrite-conflict.txt", contents: "existing overwrite", in: fixture.rightPaneURL)
        try fixture.writeFile(named: "skip-conflict.txt", contents: "incoming skip", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "skip-conflict.txt", contents: "existing skip", in: fixture.rightPaneURL)
        try fixture.writeFile(named: "keep-conflict.txt", contents: "incoming keep", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "keep-conflict.txt", contents: "existing keep", in: fixture.rightPaneURL)
        launchApp()

        copyConflictingFile(named: "overwrite-conflict.txt", choosing: "Overwrite")
        XCTAssertEqual(
            try fixture.fileContents(named: "overwrite-conflict.txt", in: fixture.rightPaneURL),
            "incoming overwrite"
        )

        copyConflictingFile(named: "skip-conflict.txt", choosing: "Skip")
        XCTAssertEqual(
            try fixture.fileContents(named: "skip-conflict.txt", in: fixture.rightPaneURL),
            "existing skip"
        )
        XCTAssertFalse(fixture.exists(fixture.fileURL(named: "skip-conflict 2.txt", in: fixture.rightPaneURL)))

        copyConflictingFile(named: "keep-conflict.txt", choosing: "Keep Both")
        XCTAssertEqual(
            try fixture.fileContents(named: "keep-conflict.txt", in: fixture.rightPaneURL),
            "existing keep"
        )
        XCTAssertTrue(row(named: "keep-conflict 2.txt", in: "right").waitForExistence(timeout: 5))
        XCTAssertEqual(
            try fixture.fileContents(named: "keep-conflict 2.txt", in: fixture.rightPaneURL),
            "incoming keep"
        )
    }

    @MainActor
    func testLaunchShowsFixtureRows() throws {
        launchApp()

        XCTAssertTrue(row(named: "alpha.txt", in: "left").waitForExistence(timeout: 5))
        XCTAssertTrue(row(named: "target.txt", in: "right").waitForExistence(timeout: 5))
    }

    @MainActor
    func testSingleClickSelectsRowInRealApp() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        clickRow(alphaRow)

        waitForSelection(alphaRow)
    }

    @MainActor
    func testDoubleClickFolderOpensFolderInRealApp() throws {
        let folderURL = try fixture.createFolder(named: "Open Folder", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "inside.txt", contents: "inside", in: folderURL)
        launchApp()
        let folderRow = row(named: "Open Folder", in: "left")
        XCTAssertTrue(folderRow.waitForExistence(timeout: 5))

        doubleClickRow(folderRow)

        XCTAssertTrue(row(named: "inside.txt", in: "left").waitForExistence(timeout: 5))
    }

    @MainActor
    func testCommandClickAddsSecondRowToSelection() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        let betaRow = row(named: "beta.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        clickRow(alphaRow)
        waitForSelection(alphaRow)
        XCUIElement.perform(withKeyModifiers: .command) {
            clickRow(betaRow)
        }

        waitForSelection(alphaRow)
        waitForSelection(betaRow)
    }

    @MainActor
    func testShiftClickExtendsSelectionToRange() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        let betaRow = row(named: "beta.txt", in: "left")
        let gammaRow = row(named: "gamma.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        clickRow(alphaRow)
        waitForSelection(alphaRow)
        XCUIElement.perform(withKeyModifiers: .shift) {
            clickRow(gammaRow)
        }

        waitForSelection(alphaRow)
        waitForSelection(betaRow)
        waitForSelection(gammaRow)
    }

    @MainActor
    func testRightClickShowsContextMenu() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        rightClickRow(alphaRow)

        XCTAssertTrue(app.menuItems["Open"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["Rename…"].exists)
        XCTAssertTrue(app.menuItems["Reveal in Finder"].exists)
    }

    @MainActor
    private func launchApp() {
        app.launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            "--left-pane-url", fixture.leftPaneURL.path,
            "--right-pane-url", fixture.rightPaneURL.path
        ]
        app.launch()
        app.activate()
        XCTAssertTrue(
            app.descendants(matching: .any)["left-pane"].waitForExistence(timeout: 10),
            "Expected the main DuPane UI to be accessible after launch. App state: \(app.state.rawValue)\n\(app.debugDescription)"
        )
    }

    @MainActor
    private func row(named name: String, in pane: String) -> XCUIElement {
        app.descendants(matching: .any)["\(pane)-file-row-\(name)"]
    }

    @MainActor
    @discardableResult
    private func waitForRow(named name: String, in pane: String) -> XCUIElement {
        let element = row(named: name, in: pane)
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        return element
    }

    @MainActor
    private func waitForMissingRow(named name: String, in pane: String) {
        let element = row(named: name, in: pane)
        let predicate = NSPredicate(format: "exists == false")
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func clickToolbarButton(_ identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.click()
    }

    @MainActor
    private func copyConflictingFile(named name: String, choosing buttonTitle: String) {
        let sourceRow = waitForRow(named: name, in: "left")
        clickRow(sourceRow)
        waitForSelection(sourceRow)
        clickToolbarButton("toolbar-copy-button")

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let button = sheet.buttons[buttonTitle]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.click()

        let predicate = NSPredicate(format: "exists == false")
        expectation(for: predicate, evaluatedWith: sheet)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func clickRow(_ row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    @MainActor
    private func doubleClickRow(_ row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
    }

    @MainActor
    private func rightClickRow(_ row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
    }

    @MainActor
    private func waitForSelection(_ row: XCUIElement) {
        let predicate = NSPredicate(format: "value == %@", "selected")
        expectation(for: predicate, evaluatedWith: row)
        waitForExpectations(timeout: 2)
    }
}

private final class EndToEndFixture {
    let rootURL: URL
    let leftPaneURL: URL
    let rightPaneURL: URL

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("DuPaneEndToEndUITests-\(UUID().uuidString)", isDirectory: true)
        leftPaneURL = rootURL.appendingPathComponent("left-pane", isDirectory: true)
        rightPaneURL = rootURL.appendingPathComponent("right-pane", isDirectory: true)

        try fileManager.createDirectory(at: leftPaneURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: rightPaneURL, withIntermediateDirectories: true)
        try writeFile(named: "alpha.txt", contents: "alpha", in: leftPaneURL)
        try writeFile(named: "beta.txt", contents: "beta", in: leftPaneURL)
        try writeFile(named: "gamma.txt", contents: "gamma", in: leftPaneURL)
        try writeFile(named: "target.txt", contents: "target", in: rightPaneURL)
    }

    func tearDown() throws {
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
    }

    @discardableResult
    func writeFile(named name: String, contents: String, in folderURL: URL) throws -> URL {
        let fileURL = fileURL(named: name, in: folderURL)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    @discardableResult
    func createFolder(named name: String, in folderURL: URL) throws -> URL {
        let url = folderURL.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    func fileURL(named name: String, in folderURL: URL) -> URL {
        folderURL.appendingPathComponent(name)
    }

    func fileContents(named name: String, in folderURL: URL) throws -> String {
        try String(contentsOf: fileURL(named: name, in: folderURL), encoding: .utf8)
    }

    func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
