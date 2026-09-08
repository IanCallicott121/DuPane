import Foundation
import XCTest
@testable import DuPane

// Tests for bugs fixed in Build 397 — four design-decision fixes:
//   1. Sync plan not atomic       → FileOperationService.transactionalCopy
//   2. Partial trash unrecoverable → trash() reports TrashedItems + restoreFromTrash
//   3. UserDefaults not atomic     → AppSettings.performBatchUpdate
//   4. Metadata cache not Sendable → SmartMetadataService main-actor assertions
// Each test class is named after the bug it covers.

// MARK: - Medium: sync plan not atomic — 4 tests [must]
//
// executeSyncPlan copied with per-item backups that were deleted the instant each item
// succeeded, so a failure partway through left earlier files overwritten with no rollback.
// transactionalCopy keeps every backup until the whole plan succeeds and rolls the batch
// back on any single failure.

final class TransactionalSyncCopyTests: DuPaneTestCase {
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

    private func item(at url: URL) -> FileItem {
        FileItem(
            id: url, name: url.lastPathComponent, url: url, isDirectory: false,
            isVolume: false, isRemovable: false, size: nil, kind: "", modified: nil, tags: []
        )
    }

    private func contents(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func hasTempBackups(in folder: URL) -> Bool {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.contains { $0.hasPrefix(".") && $0.hasSuffix(".tmp") }
    }

    @MainActor
    func testSuccessfulPlanCopiesEveryFileAndLeavesNoBackups() throws {
        try fixture.writeFile(named: "new.txt", contents: "new-src", in: .left)
        try fixture.writeFile(named: "over.txt", contents: "over-src", in: .left)
        try fixture.writeFile(named: "over.txt", contents: "over-dst", in: .right)

        let files = [
            item(at: fixture.fileURL(named: "new.txt", in: .left)),
            item(at: fixture.fileURL(named: "over.txt", in: .left))
        ]

        let result = FileOperationService.transactionalCopy(files: files, to: fixture.rightPaneURL)

        XCTAssertEqual(result.succeeded, 2)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(try contents(fixture.fileURL(named: "new.txt", in: .right)), "new-src")
        XCTAssertEqual(try contents(fixture.fileURL(named: "over.txt", in: .right)), "over-src",
                       "an existing destination file must be replaced with the source version")
        XCTAssertFalse(hasTempBackups(in: fixture.rightPaneURL),
                       "backups must be cleaned up once the whole plan succeeds")
    }

    @MainActor
    func testFailedPlanRestoresAnAlreadyOverwrittenFile() throws {
        // THE data-loss case: the first file is overwritten, then a later file fails.
        // The already-overwritten file must be rolled back to its original contents.
        try fixture.writeFile(named: "over.txt", contents: "over-src", in: .left)
        try fixture.writeFile(named: "over.txt", contents: "over-dst-ORIGINAL", in: .right)

        let ghost = fixture.leftPaneURL.appendingPathComponent("does-not-exist.txt")
        let files = [
            item(at: fixture.fileURL(named: "over.txt", in: .left)),
            item(at: ghost)          // copyItem throws → whole plan rolls back
        ]

        let result = FileOperationService.transactionalCopy(files: files, to: fixture.rightPaneURL)

        XCTAssertEqual(result.succeeded, 0, "an all-or-nothing plan must not report partial success")
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertEqual(try contents(fixture.fileURL(named: "over.txt", in: .right)), "over-dst-ORIGINAL",
                       "the overwritten destination file must be restored on rollback")
        XCTAssertFalse(hasTempBackups(in: fixture.rightPaneURL),
                       "rollback must leave no orphaned backup files behind")
    }

    @MainActor
    func testFailedPlanRemovesFilesItHadAlreadyCreated() throws {
        try fixture.writeFile(named: "new.txt", contents: "new-src", in: .left)

        let ghost = fixture.leftPaneURL.appendingPathComponent("does-not-exist.txt")
        let files = [
            item(at: fixture.fileURL(named: "new.txt", in: .left)),
            item(at: ghost)
        ]

        let result = FileOperationService.transactionalCopy(files: files, to: fixture.rightPaneURL)

        XCTAssertEqual(result.succeeded, 0)
        XCTAssertFalse(fixture.exists(fixture.fileURL(named: "new.txt", in: .right)),
                       "a file created before the failure must be removed by the rollback")
    }

    @MainActor
    func testEmptyPlanSucceedsWithNothingToDo() throws {
        let result = FileOperationService.transactionalCopy(files: [], to: fixture.rightPaneURL)
        XCTAssertEqual(result.succeeded, 0)
        XCTAssertTrue(result.errors.isEmpty)
    }
}

// MARK: - Medium: partial trash failure was unrecoverable — 4 tests [must]
//
// trash() collected errors but could not say which items had been trashed before a
// failure, and gave the caller no way to undo. It now returns TrashedItems pairing each
// original URL with its Trash location, and restoreFromTrash puts them back.

final class TrashUndoTests: DuPaneTestCase {
    private var fixture: FilePaneFixture!
    private var trashDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try FilePaneFixture()
        trashDir = fixture.rootURL.appendingPathComponent("fake-trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try fixture?.tearDown()
        fixture = nil
        trashDir = nil
        try super.tearDownWithError()
    }

    // A trash handler that "trashes" by moving the file into a controlled directory,
    // so tests are deterministic and never touch the real macOS Trash.
    private func movingHandler(failing failNames: Set<String> = []) -> FileOperationService.TrashHandler {
        { [trashDir] url in
            if failNames.contains(url.lastPathComponent) {
                throw CocoaError(.fileNoSuchFile)
            }
            let dest = trashDir!.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: dest)
            return dest
        }
    }

    func testTrashReportsOriginalAndTrashURLForEachItem() throws {
        let a = fixture.fileURL(named: "alpha.txt", in: .left)
        let b = fixture.fileURL(named: "beta.txt", in: .left)

        let result = FileOperationService.trash(urls: [a, b], trashHandler: movingHandler())

        XCTAssertEqual(result.succeeded, 2)
        XCTAssertEqual(result.trashedItems.count, 2)
        XCTAssertEqual(result.trashedItems.map(\.original), [a, b])
        XCTAssertEqual(result.trashedItems[0].trashURL, trashDir.appendingPathComponent("alpha.txt"))
    }

    func testTrashReportsOnlySuccessfullyTrashedItemsWhenOneFails() throws {
        let a = fixture.fileURL(named: "alpha.txt", in: .left)
        let b = fixture.fileURL(named: "beta.txt", in: .left)
        let c = fixture.fileURL(named: "gamma.txt", in: .left)

        let result = FileOperationService.trash(
            urls: [a, b, c], trashHandler: movingHandler(failing: ["beta.txt"])
        )

        XCTAssertEqual(result.succeeded, 2)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.trashedItems.map(\.original), [a, c],
                       "the failed item must not appear among the trashed items")
    }

    func testRestoreFromTrashMovesItemsBackToTheirOriginalLocations() throws {
        let a = fixture.fileURL(named: "alpha.txt", in: .left)
        let trashResult = FileOperationService.trash(urls: [a], trashHandler: movingHandler())
        XCTAssertFalse(fixture.exists(a), "precondition: the file has been trashed")

        let restore = FileOperationService.restoreFromTrash(trashResult.trashedItems)

        XCTAssertEqual(restore.succeeded, 1)
        XCTAssertTrue(fixture.exists(a), "the item must be back at its original location")
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "alpha.txt")
    }

    func testRestoreSkipsAnItemWhoseOriginalPathIsOccupiedAgain() throws {
        let a = fixture.fileURL(named: "alpha.txt", in: .left)
        let trashResult = FileOperationService.trash(urls: [a], trashHandler: movingHandler())
        // Something new now occupies the original path.
        try "new-file".write(to: a, atomically: true, encoding: .utf8)

        let restore = FileOperationService.restoreFromTrash(trashResult.trashedItems)

        XCTAssertEqual(restore.succeeded, 0)
        XCTAssertEqual(restore.errors.count, 1)
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "new-file",
                       "restore must never overwrite a newer file at the original path")
    }
}

// MARK: - Low: UserDefaults writes had no transaction semantics — 3 tests [must]
//
// Each @Published setting wrote to UserDefaults independently in its didSet, so a bulk
// change (Import Settings) could be observed mid-way. performBatchUpdate collects the
// writes and flushes them in one pass after the whole batch is applied.

final class AppSettingsBatchWriteTests: DuPaneTestCase {
    private let key = "foldersFirst"
    private var savedValue: Any?

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedValue = UserDefaults.standard.object(forKey: key)
    }

    override func tearDownWithError() throws {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        try super.tearDownWithError()
    }

    @MainActor
    func testBatchUpdateDoesNotPersistUntilItCommits() {
        let settings = AppSettings()
        settings.foldersFirst = true
        UserDefaults.standard.set(true, forKey: key)   // known persisted starting point

        settings.performBatchUpdate {
            settings.foldersFirst = false
            XCTAssertTrue(UserDefaults.standard.bool(forKey: key),
                          "the store must not change while the batch is still open")
        }

        XCTAssertFalse(UserDefaults.standard.bool(forKey: key),
                       "the batched value must be flushed once the batch closes")
    }

    @MainActor
    func testValuesOutsideABatchStillPersistImmediately() {
        let settings = AppSettings()
        settings.foldersFirst = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
        settings.foldersFirst = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key),
                      "normal single-setting writes must remain immediate")
    }

    @MainActor
    func testApplyImportPersistsEveryImportedValue() throws {
        let settings = AppSettings()
        settings.foldersFirst = true
        let json: [String: Any] = ["foldersFirst": false, "listFontSize": 18]
        let data = try JSONSerialization.data(withJSONObject: json)

        settings.applyImport(from: data)

        XCTAssertFalse(settings.foldersFirst)
        XCTAssertEqual(settings.listFontSize, 18)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key),
                       "an imported value must be persisted after the atomic import")
        UserDefaults.standard.removeObject(forKey: "listFontSize")
    }
}

// MARK: - Low: metadata cache not Sendable-verified — 1 test [must]
//
// The cache is a plain dictionary guarded only by @MainActor. Debug assertions now make
// any off-main access crash loudly instead of racing silently. This guards that the
// assertions do not break the legitimate on-main path.

@MainActor
final class SmartMetadataMainActorAccessTests: DuPaneTestCase {
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

    func testCacheAccessorsWorkOnTheMainActor() async throws {
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)
        let service = SmartMetadataService.shared

        service.loadIfNeeded(for: [item])
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertTrue(service.hasResolved(item.url),
                      "on-main cache access must succeed with the isolation assertions in place")
        _ = service.info(for: item)
    }
}
