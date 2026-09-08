import Foundation
import XCTest
@testable import DuPane

// Tests for bugs fixed in Build 379.

// MARK: - Bug: Duplicate scan cancellation is unresponsive [must]
// The scan's blocking read loops (fnv1a64, filesHaveSameContents) ignored
// Task.isCancelled, so hitting Cancel during a long scan did nothing until the
// scan finished on its own — and the completion path then flipped phase back to
// .done, discarding the cancel. After the fix, cancel() transitions to .idle and
// the guarded completion path must not overwrite it.

@MainActor
final class DuplicateFinderCancellationTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dupe-cancel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
        try super.tearDownWithError()
    }

    func testCancelSetsPhaseToIdle() throws {
        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)
        vm.cancel()
        XCTAssertEqual(vm.phase, .idle, "cancel() must transition phase to .idle immediately")
    }

    // [optional] — writes several megabytes of duplicate data so hashing takes
    // long enough for cancellation to land mid-scan.
    func testCancelledScanDoesNotCompleteToDone() async throws {
        // Six identical 2 MB files: same size forces hashing + byte-for-byte
        // content verification, which is where the blocking loops live.
        let blob = Data(repeating: 0xAB, count: 2 * 1024 * 1024)
        for i in 0..<6 {
            try blob.write(to: dir.appendingPathComponent("copy\(i).bin"))
        }

        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)
        // Let the scan get into the hashing loop, then cancel.
        try await Task.sleep(nanoseconds: 30_000_000) // 30 ms
        vm.cancel()
        XCTAssertEqual(vm.phase, .idle, "cancel() must set phase to .idle")

        // Give the detached scan task ample time to run to its natural end.
        // If cancellation were ignored, the completion path would flip phase
        // back to .done here.
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s
        XCTAssertEqual(vm.phase, .idle,
                       "a cancelled scan must not resurrect phase to .done")
        XCTAssertTrue(vm.groups.isEmpty,
                      "a cancelled scan must not publish results")
    }

    func testCompletedScanReachesDoneWhenNotCancelled() async throws {
        let a = dir.appendingPathComponent("a.txt")
        let b = dir.appendingPathComponent("b.txt")
        try "identical".write(to: a, atomically: true, encoding: .utf8)
        try "identical".write(to: b, atomically: true, encoding: .utf8)

        let vm = DuplicateFinderViewModel()
        vm.startScan(at: dir)

        // Poll for completion rather than sleeping a fixed duration.
        let deadline = Date().addingTimeInterval(5)
        while vm.phase != .done, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(vm.phase, .done, "an uncancelled scan must reach .done")
        XCTAssertEqual(vm.groups.count, 1, "the two identical files form one group")
        XCTAssertEqual(vm.groups.first?.count, 2)
    }
}
