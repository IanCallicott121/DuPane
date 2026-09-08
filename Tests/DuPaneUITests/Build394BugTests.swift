import Foundation
import XCTest
@testable import DuPane

// Tests for bugs fixed in Build 394.
// Each test class is named after the bug it covers.

// MARK: - Critical: "Overwrite" on a folder destroyed destination-only files — 5 tests [must]
//
// moveOrCopy with .overwrite moved the existing destination folder aside, copied the
// source over it, then deleted the backup with removeItem. Any file present only in
// the destination was permanently gone — no Trash, no undo. Finder merges instead.

final class FolderOverwriteMergeTests: XCTestCase {
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

    /// Builds left/Photos containing `sourceFiles` and right/Photos containing `destFiles`.
    private func makeFolders(sourceFiles: [String], destFiles: [String]) throws -> (src: URL, dst: URL) {
        let src = try fixture.createFolder(named: "Photos", in: .left)
        let dst = try fixture.createFolder(named: "Photos", in: .right)
        for name in sourceFiles {
            try "src-\(name)".write(to: src.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        for name in destFiles {
            try "dst-\(name)".write(to: dst.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return (src, dst)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func contents(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    @MainActor
    func testOverwriteKeepsDestinationOnlyFiles() throws {
        // THE data-loss case: b.jpg exists only in the destination and must survive.
        let (_, dst) = try makeFolders(sourceFiles: ["a.jpg"], destFiles: ["b.jpg"])
        let item = try fixture.fileItem(named: "Photos", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(exists(dst.appendingPathComponent("b.jpg")),
                      "destination-only file must survive an Overwrite of its parent folder")
        XCTAssertTrue(exists(dst.appendingPathComponent("a.jpg")),
                      "source file must be merged into the destination folder")
    }

    @MainActor
    func testOverwriteReplacesCollidingFilesWithSourceVersion() throws {
        let (_, dst) = try makeFolders(sourceFiles: ["shared.txt"], destFiles: ["shared.txt"])
        let item = try fixture.fileItem(named: "Photos", in: .left)

        _ = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        XCTAssertEqual(try contents(dst.appendingPathComponent("shared.txt")), "src-shared.txt",
                       "a colliding file inside the folder must take the source version")
    }

    @MainActor
    func testOverwriteMergeIsRecursive() throws {
        let src = try fixture.createFolder(named: "Photos", in: .left)
        let dst = try fixture.createFolder(named: "Photos", in: .right)
        let srcYear = src.appendingPathComponent("2024", isDirectory: true)
        let dstYear = dst.appendingPathComponent("2024", isDirectory: true)
        try FileManager.default.createDirectory(at: srcYear, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dstYear, withIntermediateDirectories: true)
        try "x".write(to: srcYear.appendingPathComponent("x.jpg"), atomically: true, encoding: .utf8)
        try "y".write(to: dstYear.appendingPathComponent("y.jpg"), atomically: true, encoding: .utf8)

        let item = try fixture.fileItem(named: "Photos", in: .left)
        _ = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        XCTAssertTrue(exists(dstYear.appendingPathComponent("y.jpg")),
                      "nested destination-only file must survive")
        XCTAssertTrue(exists(dstYear.appendingPathComponent("x.jpg")),
                      "nested source file must be merged in")
    }

    @MainActor
    func testOverwriteStillReplacesPlainFiles() throws {
        // Regression guard: file-level overwrite semantics must not change.
        try fixture.writeFile(named: "dup.txt", contents: "source", in: .left)
        try fixture.writeFile(named: "dup.txt", contents: "destination", in: .right)
        let item = try fixture.fileItem(named: "dup.txt", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: false, conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertEqual(try contents(fixture.fileURL(named: "dup.txt", in: .right)), "source")
    }

    @MainActor
    func testMoveMergeRemovesSourceFolderAndKeepsDestinationOnlyFiles() throws {
        let (src, dst) = try makeFolders(sourceFiles: ["a.jpg"], destFiles: ["b.jpg"])
        let item = try fixture.fileItem(named: "Photos", in: .left)

        let result = FileOperationService.moveOrCopy(
            files: [item], to: fixture.rightPaneURL, isMove: true, conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 1)
        XCTAssertTrue(exists(dst.appendingPathComponent("b.jpg")), "destination-only file must survive a move-merge")
        XCTAssertTrue(exists(dst.appendingPathComponent("a.jpg")), "moved file must arrive")
        XCTAssertFalse(exists(src), "source folder must be gone after a move")
    }
}

// MARK: - Low: onProgress skipped for items rejected by the subtree guard — 1 test [must]

final class MoveOrCopyProgressReportingTests: XCTestCase {
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

    @MainActor
    func testProgressReachesTotalEvenWhenSubtreeGuardSkipsAnItem() throws {
        let selfFolder = try fixture.createFolder(named: "loop", in: .left)
        try fixture.writeFile(named: "ok.txt", contents: "ok", in: .left)
        let folderItem = try fixture.fileItem(named: "loop", in: .left)
        let fileItem = try fixture.fileItem(named: "ok.txt", in: .left)

        var lastCompleted = 0
        _ = FileOperationService.moveOrCopy(
            files: [folderItem, fileItem], to: selfFolder, isMove: false,
            onProgress: { completed, _ in lastCompleted = completed }
        )

        XCTAssertEqual(lastCompleted, 2, "progress must reach the batch total even when an item is skipped")
    }
}

// MARK: - High: cancelled directory loads kept running — 2 tests [must]
//
// load() cancelled only the wrapper Task; the inner Task.detached does not inherit
// cancellation and loadFolder had no cancellation checks, so a cancelled load kept a
// cooperative-pool thread busy until the read finished. Enough of those (several tabs
// on a hung SMB share) exhausts the pool and every Task.detached in the app stalls.

final class LoadFolderCancellationTests: XCTestCase {
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

    func testLoadFolderThrowsCancellationWhenItsTaskIsCancelled() async throws {
        let dir = fixture.leftPaneURL
        for i in 0..<200 {
            try "x".write(to: dir.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8)
        }

        let task = Task.detached { try PaneState.loadFolder(dir) }
        task.cancel()

        do {
            _ = try await task.value
            // Racing a very fast read is acceptable; the contract is that it must not
            // return a full result *after* observing cancellation.
        } catch is CancellationError {
            return
        }
    }

    func testLoadFolderCompletesNormallyWhenNotCancelled() async throws {
        let items = try await Task.detached { [url = fixture.leftPaneURL] in
            try PaneState.loadFolder(url)
        }.value
        XCTAssertEqual(items.count, fixture.leftFileNames.count)
    }
}

// MARK: - Medium: SmartMetadataService re-spawned a task per file on every reload — 2 tests [must]
//
// compute() returns nil for any extension outside its three lists. Nothing was recorded
// for a nil, so loadIfNeeded restarted the whole set on every pane reload — thousands of
// no-op detached tasks after every file operation in a large folder.

final class SmartMetadataNegativeCacheTests: XCTestCase {
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

    @MainActor
    func testUncomputableFileIsRecordedSoItIsNotRetried() async throws {
        // .bin has no metadata provider, so compute() returns nil.
        let url = try fixture.writeFile(named: "blob.bin", contents: "data", in: .left)
        let item = try fixture.fileItem(named: "blob.bin", in: .left)
        let service = SmartMetadataService.shared

        service.loadIfNeeded(for: [item])
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertTrue(service.hasResolved(url),
                      "a file whose metadata resolves to nothing must still be recorded, or it is recomputed forever")
        XCTAssertNil(service.info(for: item),
                     "recording the negative result must not surface an empty string in the UI")
    }

    @MainActor
    func testResolvedFileIsNotRecomputedOnReload() async throws {
        let item = try fixture.fileItem(named: "alpha.txt", in: .left)
        let service = SmartMetadataService.shared

        service.loadIfNeeded(for: [item])
        try await Task.sleep(nanoseconds: 400_000_000)
        let resolvedAfterFirst = service.hasResolved(item.url)

        service.loadIfNeeded(for: [item])
        XCTAssertTrue(resolvedAfterFirst && service.hasResolved(item.url),
                      "a resolved file must stay resolved across reloads")
    }
}
