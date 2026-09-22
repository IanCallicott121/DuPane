import XCTest
import AppKit

final class DuPaneEndToEndUITests: DuPaneTestCase {
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
        nameField.typeKey(.rightArrow, modifierFlags: .command)
        nameField.typeKey(.leftArrow, modifierFlags: [.command, .shift])
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
    func testCriticalRepeatedEscapeDismissesCreationSheets() throws {
        launchApp()

        for identifier in ["toolbar-new-file-button", "toolbar-new-folder-button"] {
            clickToolbarButton(identifier)
            let field = app.textFields["text-prompt-name-field"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            for _ in 0..<20 {
                app.typeKey(.escape, modifierFlags: [])
            }
            waitForCreationPromptToDismiss()
        }

        clickRow(waitForRow(named: "alpha.txt", in: "left"))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let pathField = app.textFields["go-to-path-field"]
        XCTAssertTrue(pathField.waitForExistence(timeout: 5), "Go To Folder field did not appear")
        for _ in 0..<20 {
            app.typeKey(.escape, modifierFlags: [])
        }
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: pathField)
        wait(for: [dismissed], timeout: 5)

        XCTAssertTrue(app.descendants(matching: .any)["left-pane"].exists)
    }

    @MainActor
    func testCriticalCommandVPastesIntoCreationAndGoToFolderFields() throws {
        launchApp()
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        pasteboard.setString("pasted-name.txt", forType: .string)
        clickToolbarButton("toolbar-new-file-button")

        let nameField = app.textFields["text-prompt-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.click()
        nameField.typeKey(.rightArrow, modifierFlags: .command)
        nameField.typeKey(.leftArrow, modifierFlags: [.command, .shift])
        app.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(nameField.value as? String, "pasted-name.txt")
        app.typeKey(.escape, modifierFlags: [])

        let promptDismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: nameField)
        wait(for: [promptDismissed], timeout: 5)

        let path = fixture.leftPaneURL.path
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        app.typeKey("g", modifierFlags: [.command, .shift])

        let pathField = app.textFields["go-to-path-field"]
        XCTAssertTrue(pathField.waitForExistence(timeout: 5))
        pathField.click()
        pathField.typeKey(.rightArrow, modifierFlags: .command)
        pathField.typeKey(.leftArrow, modifierFlags: [.command, .shift])
        app.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(pathField.value as? String, path)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testCriticalDefaultInputTextIsSelectedOnFocus() throws {
        launchApp()

        clickToolbarButton("toolbar-new-folder-button")
        let folderField = app.textFields["text-prompt-name-field"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 5))
        folderField.typeText("f")
        XCTAssertEqual(folderField.value as? String, "f")
        app.typeKey(.escape, modifierFlags: [])
        waitForCreationPromptToDismiss()

        clickToolbarButton("toolbar-new-file-button")
        let fileField = app.textFields["text-prompt-name-field"]
        XCTAssertTrue(fileField.waitForExistence(timeout: 5))
        fileField.typeText("x")
        XCTAssertEqual(fileField.value as? String, "x")
        app.typeKey(.escape, modifierFlags: [])
        waitForCreationPromptToDismiss()

        clickRow(waitForRow(named: "alpha.txt", in: "left"))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let pathField = app.textFields["go-to-path-field"]
        XCTAssertTrue(pathField.waitForExistence(timeout: 5))
        pathField.typeText("p")
        XCTAssertEqual(pathField.value as? String, "p")
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testCriticalDateAddedColumnCanBeShown() throws {
        launchApp(additionalArguments: ["-hiddenColumns", "NONE"])

        XCTAssertTrue(
            app.staticTexts["Date Added"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testMediumColumnPickerListsAllColumnsAndStateAwareActions() throws {
        launchApp(additionalArguments: ["-hiddenColumns", "Kind,Modified,Date Added,Info"])

        let leftPane = app.descendants(matching: .any)["left-pane"]
        let header = leftPane.staticTexts["left-column-Name"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()

        for column in ["Name", "Icon", "Size", "Kind", "Modified", "Date Added", "Info"] {
            XCTAssertTrue(
                app.menuItems[column].waitForExistence(timeout: 2),
                "Missing \(column) column menu"
            )
        }

        app.menuItems["Kind"].click()
        XCTAssertTrue(app.menuItems["Show Kind"].waitForExistence(timeout: 2))
        let kindSubmenu = app.menuItems["Kind"].menus.element(boundBy: 0)
        XCTAssertTrue(kindSubmenu.menuItems["Move Left"].exists)
        XCTAssertTrue(kindSubmenu.menuItems["Move Right"].exists)
        XCTAssertFalse(kindSubmenu.menuItems["Move Left"].isEnabled)
        XCTAssertFalse(kindSubmenu.menuItems["Move Right"].isEnabled)
        XCTAssertTrue(kindSubmenu.menuItems["Minimum Width"].exists)
        XCTAssertTrue(kindSubmenu.menuItems["Maximum Width"].exists)
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
    func testCriticalCommandCopyAndPasteDoNotTransferFilesBetweenPanes() throws {
        let sourceURL = try fixture.writeFile(named: "shortcut-file.txt", contents: "shortcut source", in: fixture.leftPaneURL)
        launchApp()

        let sourceRow = waitForRow(named: "shortcut-file.txt", in: "left")
        clickRow(sourceRow)
        waitForSelection(sourceRow)
        app.typeKey("c", modifierFlags: .command)
        app.typeKey("v", modifierFlags: .command)

        XCTAssertFalse(row(named: "shortcut-file.txt", in: "right").exists)
        XCTAssertTrue(row(named: "shortcut-file.txt", in: "left").exists)
        XCTAssertTrue(fixture.exists(sourceURL))
        XCTAssertEqual(try fixture.fileContents(named: "shortcut-file.txt", in: fixture.leftPaneURL), "shortcut source")
    }

    @MainActor
    func testCriticalCreatesFileAndFolderThroughToolbarSheets() throws {
        launchApp()

        clickToolbarButton("toolbar-new-folder-button")
        let folderField = app.textFields["text-prompt-name-field"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 5))
        folderField.click()
        folderField.typeKey(.rightArrow, modifierFlags: .command)
        folderField.typeKey(.leftArrow, modifierFlags: [.command, .shift])
        folderField.typeText("created-folder")
        clickToolbarButton("text-prompt-confirm-button")
        XCTAssertTrue(row(named: "created-folder", in: "left").waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.fileURL(named: "created-folder", in: fixture.leftPaneURL).path))

        clickToolbarButton("toolbar-new-file-button")
        let fileField = app.textFields["text-prompt-name-field"]
        XCTAssertTrue(fileField.waitForExistence(timeout: 5))
        fileField.click()
        fileField.typeKey(.rightArrow, modifierFlags: .command)
        fileField.typeKey(.leftArrow, modifierFlags: [.command, .shift])
        fileField.typeText("created-file.txt")
        clickToolbarButton("text-prompt-confirm-button")
        XCTAssertTrue(row(named: "created-file.txt", in: "left").waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.fileURL(named: "created-file.txt", in: fixture.leftPaneURL).path))
    }

    @MainActor
    func testCriticalArchiveRoundTripThroughContextMenu() throws {
        let sourceURL = try fixture.writeFile(named: "archive-me.txt", contents: "archive contents", in: fixture.leftPaneURL)
        launchApp()

        rightClickRow(waitForRow(named: "archive-me.txt", in: "left"))
        XCTAssertTrue(app.menuItems["Compress"].waitForExistence(timeout: 2))
        app.menuItems["Compress"].click()

        _ = waitForRow(named: "archive-me.zip", in: "left")
        try FileManager.default.removeItem(at: sourceURL)
        app.typeKey("r", modifierFlags: .command)
        waitForMissingRow(named: "archive-me.txt", in: "left")

        rightClickRow(waitForRow(named: "archive-me.zip", in: "left"))
        XCTAssertTrue(app.menuItems["Uncompress"].waitForExistence(timeout: 2))
        app.menuItems["Uncompress"].click()

        XCTAssertTrue(row(named: "archive-me.txt", in: "left").waitForExistence(timeout: 5))
        XCTAssertEqual(
            try fixture.fileContents(named: "archive-me.txt", in: fixture.leftPaneURL),
            "archive contents"
        )
    }

    @MainActor
    func testCriticalDuplicateFinderScansAndShowsDuplicateGroup() throws {
        try fixture.writeFile(named: "duplicate-a.txt", contents: "same contents", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "duplicate-b.txt", contents: "same contents", in: fixture.leftPaneURL)
        launchApp()

        clickToolbarButton("toolbar-duplicates-button")
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Keep First"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 copies"].exists)
        app.buttons["Done"].click()
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }

    @MainActor
    func testMediumFilterNarrowsVisibleRows() throws {
        launchApp()

        let filter = app.textFields["left-pane"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.click()
        filter.typeText("alpha")

        XCTAssertTrue(row(named: "alpha.txt", in: "left").waitForExistence(timeout: 5))
        waitForMissingRow(named: "beta.txt", in: "left")
    }

    @MainActor
    func testMediumPropertiesAndFolderSizePanelsOpen() throws {
        let folderURL = try fixture.createFolder(named: "sized-folder", in: fixture.leftPaneURL)
        try fixture.writeFile(named: "inside.txt", contents: "inside", in: folderURL)
        launchApp()

        rightClickRow(waitForRow(named: "sized-folder", in: "left"))
        XCTAssertTrue(app.menuItems["Show Folder / File Sizes"].waitForExistence(timeout: 2))
        app.menuItems["Show Folder / File Sizes"].click()
        XCTAssertTrue(app.staticTexts["Folder Sizes"].waitForExistence(timeout: 5))
        app.buttons["Done"].click()

        rightClickRow(waitForRow(named: "alpha.txt", in: "left"))
        XCTAssertTrue(app.menuItems["Get Info…"].waitForExistence(timeout: 2))
        app.menuItems["Get Info…"].click()
        XCTAssertTrue(app.staticTexts["Path"].waitForExistence(timeout: 5))
        app.buttons["Done"].click()
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
    func testCriticalRestrictedFolderOffersPrivacySettingsRecovery() throws {
        let restrictedFolder = try fixture.createFolder(named: "restricted-folder", in: fixture.leftPaneURL)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: restrictedFolder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: restrictedFolder.path) }

        launchApp()
        rightClickRow(waitForRow(named: "restricted-folder", in: "left"))

        XCTAssertTrue(
            app.menuItems["Open Privacy & Security Settings…"].waitForExistence(timeout: 2),
            "restricted folders must offer a macOS privacy-settings recovery action"
        )
    }

    // Critical UI tag: post-build subset for functional, broad, or full test runs.
    // Bug 394-B: view identity was keyed on activeTabIndex, an Int. Closing a tab can
    // leave the index unchanged while it refers to a different tab, so SwiftUI reused
    // the view, onAppear did not re-run, and the type-ahead closure kept writing into
    // the PaneState of the tab that was gone — type-ahead silently dead in that pane.
    @MainActor
    func testCriticalTypeAheadStillWorksAfterClosingTheActiveTab() throws {
        launchApp()
        _ = waitForRow(named: "alpha.txt", in: "left")

        // A second tab on the same folder, so both tabs list the same rows.
        clickToolbarButton("left-new-tab-button")
        goToPath(fixture.leftPaneURL.path, in: "left")
        _ = waitForRow(named: "alpha.txt", in: "left")

        // Close the first tab. activeTabIndex stays 0 while now referring to the second.
        app.buttons["left-tab-0"].click()
        XCTAssertTrue(app.buttons["left-close-tab-0"].waitForExistence(timeout: 5))
        app.buttons["left-close-tab-0"].click()
        let survivor = waitForRow(named: "gamma.txt", in: "left")

        // Type-ahead must act on the pane now on screen.
        clickRow(waitForRow(named: "alpha.txt", in: "left"))
        app.typeText("g")

        XCTAssertTrue(
            survivor.waitForExistence(timeout: 5),
            "the surviving tab's rows must still be listed"
        )
        expectSelected("gamma.txt", in: "left")
    }

    // Bug 394-A: file-operation progress lived in one shared set of @State slots, so a
    // finishing operation tore down the overlay. Extracted to FileOperationProgressModel;
    // this guards the wiring — the overlay must be retired when the operation completes.
    @MainActor
    func testCriticalProgressOverlayIsNotLeftOnScreenAfterACopy() throws {
        launchApp()
        let source = waitForRow(named: "alpha.txt", in: "left")
        clickRow(source)
        waitForSelection(source)

        clickToolbarButton("toolbar-copy-button")

        _ = waitForRow(named: "alpha.txt", in: "right")
        let overlay = app.descendants(matching: .any)["file-op-progress"]
        let predicate = NSPredicate(format: "exists == false")
        expectation(for: predicate, evaluatedWith: overlay)
        waitForExpectations(timeout: 5)
    }

    // Build 397: a partial/complete trash used to be unrecoverable in one step. Delete now
    // offers an Undo affordance that restores the trashed items to their original location.
    @MainActor
    func testCriticalUndoAfterDeleteRestoresTheFile() throws {
        launchApp()
        let alpha = waitForRow(named: "alpha.txt", in: "left")
        clickRow(alpha)
        waitForSelection(alpha)

        clickToolbarButton("toolbar-delete-button")
        waitForMissingRow(named: "alpha.txt", in: "left")

        let undo = app.buttons["toast-undo-button"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "an Undo button must appear after a delete")
        let undoReady = NSPredicate(format: "enabled == true AND hittable == true")
        let undoReadyExpectation = expectation(for: undoReady, evaluatedWith: undo)
        wait(for: [undoReadyExpectation], timeout: 5)
        undo.click()

        XCTAssertTrue(row(named: "alpha.txt", in: "left").waitForExistence(timeout: 10),
                      "the deleted row must return after Undo")
        XCTAssertTrue(fixture.exists(fixture.fileURL(named: "alpha.txt", in: fixture.leftPaneURL)),
                      "the file must be restored to its original location on disk")
    }

    // Build 397: folder sync now goes through the all-or-nothing transactionalCopy. This
    // exercises the happy path end-to-end — Compare, then Sync L→R — and confirms the
    // left-only files are copied into the right pane and land on disk intact.
    @MainActor
    func testCriticalSyncCopiesLeftOnlyFilesToTheRightPane() throws {
        launchApp()
        _ = waitForRow(named: "alpha.txt", in: "left")
        _ = waitForRow(named: "target.txt", in: "right")

        clickToolbarButton("toolbar-compare-button")
        clickToolbarButton("toolbar-sync-left-to-right-button")

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "the sync confirmation must appear")
        sheet.buttons["Sync"].click()

        XCTAssertTrue(row(named: "alpha.txt", in: "right").waitForExistence(timeout: 5),
                      "a left-only file must appear in the right pane after Sync L→R")
        XCTAssertEqual(try fixture.fileContents(named: "alpha.txt", in: fixture.rightPaneURL), "alpha",
                       "the synced file must arrive with its contents intact")
    }

    @MainActor
    private func goToPath(_ path: String, in pane: String) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        let field = app.textFields["go-to-path-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeKey(.rightArrow, modifierFlags: .command)
        field.typeKey(.leftArrow, modifierFlags: [.command, .shift])
        field.typeText(path)
        app.buttons["go-to-path-confirm-button"].click()
    }

    @MainActor
    private func expectSelected(_ name: String, in pane: String) {
        let target = row(named: name, in: pane)
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value CONTAINS[c] %@", "Selected")
        expectation(for: predicate, evaluatedWith: target)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func launchApp(additionalArguments: [String] = []) {
        app.launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            "-fileDeleteNoConfirm",
            "YES",
            "-directoryDeleteNoConfirm",
            "YES",
            "--left-pane-url", fixture.leftPaneURL.path,
            "--right-pane-url", fixture.rightPaneURL.path
        ] + additionalArguments
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
    private func replaceText(in field: XCUIElement, with value: String) {
        field.click()
        field.typeKey(.rightArrow, modifierFlags: .command)
        field.typeKey(.leftArrow, modifierFlags: [.command, .shift])
        field.typeText(value)
    }

    @MainActor
    private func waitForSheetToDismiss(_ sheet: XCUIElement) {
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet)
        wait(for: [dismissed], timeout: 5)
    }

    @MainActor
    private func waitForCreationPromptToDismiss() {
        let overlay = app.otherElements["creation-prompt-overlay"]
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: overlay)
        wait(for: [dismissed], timeout: 5)
    }

    @MainActor
    private func clickToolbarButton(_ identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let ready = NSPredicate(format: "enabled == true AND hittable == true")
        let readyExpectation = expectation(for: ready, evaluatedWith: button)
        wait(for: [readyExpectation], timeout: 5)
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
