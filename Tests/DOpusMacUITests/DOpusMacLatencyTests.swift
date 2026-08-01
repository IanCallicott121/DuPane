import XCTest
@testable import DOpusMac

final class DOpusMacLatencyTests: XCTestCase {

    // 1 000 clicks must complete in under 10 ms (10 µs / click).
    // Pure in-memory set/array work lands well under 1 ms; this budget exists
    // to catch accidents — file I/O, network calls, or heavy observers
    // accidentally wired into the selection path.
    private static let clickBudget: Duration = .milliseconds(10)
    private static let iterations = 1_000

    private let rows = (0..<20).map { "file\($0).txt" }

    func testPlainClickLatency() {
        let harness = makeHarness()
        let elapsed = ContinuousClock().measure {
            for i in 0..<Self.iterations {
                try? harness.click(.plain, rowNamed: rows[i % rows.count], in: .left)
            }
        }
        XCTAssertLessThan(elapsed, Self.clickBudget,
            "\(Self.iterations) plain clicks took \(elapsed), exceeded budget of \(Self.clickBudget)")
    }

    func testCommandClickLatency() {
        let harness = makeHarness()
        let elapsed = ContinuousClock().measure {
            for i in 0..<Self.iterations {
                try? harness.click(.command, rowNamed: rows[i % rows.count], in: .left)
            }
        }
        XCTAssertLessThan(elapsed, Self.clickBudget,
            "\(Self.iterations) command-clicks took \(elapsed), exceeded budget of \(Self.clickBudget)")
    }

    func testShiftClickLatency() {
        let harness = makeHarness()
        try? harness.click(.plain, rowNamed: rows[0], in: .left)
        let elapsed = ContinuousClock().measure {
            for i in 0..<Self.iterations {
                try? harness.click(.shift, rowNamed: rows[i % rows.count], in: .left)
            }
        }
        XCTAssertLessThan(elapsed, Self.clickBudget,
            "\(Self.iterations) shift-clicks took \(elapsed), exceeded budget of \(Self.clickBudget)")
    }

    // MARK: - Sort and filter latency

    // displayedItems is recomputed on every access (no caching). With 10 000
    // items it must still return in under 100 ms to keep the UI frame-rate
    // budget intact on an M-series Mac.
    private static let sortBudget: Duration = .milliseconds(100)
    private static let largeItemCount = 10_000

    @MainActor
    func testSortLatencyOnLargeList() {
        let pane = PaneState()
        pane.items = makeLargeItemList(count: Self.largeItemCount)

        let elapsed = ContinuousClock().measure {
            _ = pane.displayedItems
        }

        XCTAssertLessThan(elapsed, Self.sortBudget,
            "Sorting \(Self.largeItemCount) items took \(elapsed), exceeded budget of \(Self.sortBudget)")
    }

    @MainActor
    func testFilterLatencyOnLargeList() {
        let pane = PaneState()
        pane.items = makeLargeItemList(count: Self.largeItemCount)
        pane.filterText = "file_5"

        let elapsed = ContinuousClock().measure {
            _ = pane.displayedItems
        }

        XCTAssertLessThan(elapsed, Self.sortBudget,
            "Filtering \(Self.largeItemCount) items took \(elapsed), exceeded budget of \(Self.sortBudget)")
    }

    // MARK: - Folder load latency

    // A local folder with 500 files must load in under 500 ms. Remote volumes
    // are excluded — they have their own latency budget and are non-blocking
    // by design (async load).
    func testFolderLoadLatencyFor500Files() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DOpusMacLatency-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for i in 0..<500 {
            let fileURL = tempDir.appendingPathComponent("file-\(i).txt")
            try Data("x".utf8).write(to: fileURL)
        }

        let start = ContinuousClock().now
        let items = try PaneState.loadFolder(tempDir)
        let elapsed = ContinuousClock().now - start

        XCTAssertEqual(items.count, 500)
        XCTAssertLessThan(elapsed, .milliseconds(500),
            "Loading 500 local files took \(elapsed), exceeded 500 ms budget")
    }

    // MARK: - Helpers

    private func makeHarness() -> ClickSelectionHarness {
        ClickSelectionHarness(leftRows: rows, rightRows: [])
    }

    private func makeLargeItemList(count: Int) -> [FileItem] {
        let base = URL(fileURLWithPath: "/tmp/perf-test")
        return (0..<count).map { i in
            let url = base.appendingPathComponent("file_\(i).txt")
            return FileItem(
                id: url,
                name: "file_\(i).txt",
                url: url,
                isDirectory: false,
                isVolume: false,
                isRemovable: false,
                size: Int64(i * 100),
                kind: i % 3 == 0 ? "Text" : (i % 3 == 1 ? "Image" : "Video"),
                modified: Date(timeIntervalSince1970: Double(i)),
                tags: []
            )
        }
    }
}
