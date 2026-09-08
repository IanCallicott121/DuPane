import Foundation
import XCTest
@testable import DuPane

// Tests for bugs fixed in Build 404.

@MainActor
final class DuplicateFinderScanGenerationTests: DuPaneTestCase {
    func testSupersededScanCannotPublishProgressOrCompletionIntoNewScan() {
        let viewModel = DuplicateFinderViewModel()

        viewModel.startScan(at: URL(fileURLWithPath: "/nonexistent/first-scan"))
        let staleGeneration = viewModel.scanGeneration
        viewModel.startScan(at: URL(fileURLWithPath: "/nonexistent/second-scan"))
        let currentGeneration = viewModel.scanGeneration

        XCTAssertNotEqual(staleGeneration, currentGeneration)

        viewModel.recordScannedFiles(90, generation: staleGeneration)
        viewModel.recordHashStart(total: 80, generation: staleGeneration)
        viewModel.recordHashProgress(70, generation: staleGeneration)
        viewModel.completeScan(
            groups: [[URL(fileURLWithPath: "/stale/a"), URL(fileURLWithPath: "/stale/b")]],
            wastedBytes: 60,
            generation: staleGeneration
        )

        XCTAssertEqual(viewModel.phase, .scanning)
        XCTAssertEqual(viewModel.scannedFiles, 0)
        XCTAssertEqual(viewModel.filesToHash, 0)
        XCTAssertEqual(viewModel.hashedFiles, 0)
        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertEqual(viewModel.totalWastedBytes, 0)

        viewModel.recordScannedFiles(9, generation: currentGeneration)
        viewModel.recordHashStart(total: 8, generation: currentGeneration)
        viewModel.recordHashProgress(7, generation: currentGeneration)

        XCTAssertEqual(viewModel.scannedFiles, 9)
        XCTAssertEqual(viewModel.filesToHash, 8)
        XCTAssertEqual(viewModel.hashedFiles, 7)

        viewModel.cancel()
    }
}
