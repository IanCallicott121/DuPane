import XCTest

final class DOpusMacEndToEndUITests: XCTestCase {
    private var fixture: EndToEndFixture!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        // XCUIApplication requires DOpusMac.app to be built and placed next to
        // this test bundle in the build products directory. When running the
        // package test plan without the app scheme, the bundle won't exist and
        // the test host reports "No target application path specified". Skip
        // cleanly instead of failing.
        let productsDir = Bundle(for: DOpusMacEndToEndUITests.self).bundleURL
            .deletingLastPathComponent()
        let appExists = FileManager.default.fileExists(
            atPath: productsDir.appendingPathComponent("DOpusMac.app").path
        )
        try XCTSkipUnless(appExists, "Build DOpusMac.app first — run via Xcode with the app scheme")
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

        alphaRow.click()

        waitForStatus(in: "left", containing: "1 selected")
    }

    @MainActor
    func testDoubleClickFolderOpensFolderInRealApp() throws {
        let folderURL = try fixture.createFolder(named: "Open Folder", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "inside.txt", contents: "inside", in: folderURL)
        launchApp()
        let folderRow = row(named: "Open Folder", in: "left")
        XCTAssertTrue(folderRow.waitForExistence(timeout: 5))

        folderRow.doubleClick()

        XCTAssertTrue(row(named: "inside.txt", in: "left").waitForExistence(timeout: 5))
    }

    @MainActor
    func testCommandClickAddsSecondRowToSelection() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        let betaRow = row(named: "beta.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        alphaRow.click()
        XCUIElement.perform(withKeyModifiers: .command) {
            betaRow.click()
        }

        waitForStatus(in: "left", containing: "2 selected")
    }

    @MainActor
    func testShiftClickExtendsSelectionToRange() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        let gammaRow = row(named: "gamma.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        alphaRow.click()
        XCUIElement.perform(withKeyModifiers: .shift) {
            gammaRow.click()
        }

        waitForStatus(in: "left", containing: "3 selected")
    }

    @MainActor
    func testRightClickShowsContextMenu() throws {
        launchApp()
        let alphaRow = row(named: "alpha.txt", in: "left")
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 5))

        alphaRow.rightClick()

        XCTAssertTrue(app.menuItems["Open"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["Rename…"].exists)
        XCTAssertTrue(app.menuItems["Reveal in Finder"].exists)
    }

    @MainActor
    private func launchApp() {
        app.launchArguments = [
            "--left-pane-url", fixture.leftPaneURL.path,
            "--right-pane-url", fixture.rightPaneURL.path
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    private func row(named name: String, in pane: String) -> XCUIElement {
        app.descendants(matching: .any)["\(pane)-file-row-\(name)"]
    }

    @MainActor
    private func waitForStatus(in pane: String, containing text: String) {
        let status = app.staticTexts["\(pane)-pane-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        expectation(for: predicate, evaluatedWith: status)
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
            .appendingPathComponent("DOpusMacEndToEndUITests-\(UUID().uuidString)", isDirectory: true)
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
        let fileURL = folderURL.appendingPathComponent(name)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    @discardableResult
    func createFolder(named name: String, in folderURL: URL) throws -> URL {
        let url = folderURL.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
}
