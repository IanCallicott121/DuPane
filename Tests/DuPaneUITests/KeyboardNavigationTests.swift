import Foundation
import XCTest
@testable import DuPane

@MainActor
final class KeyboardNavigationTests: XCTestCase {
    func testDownArrowSelectsFirstItemWhenNothingIsSelected() {
        let items = makeItems(names: ["a", "b", "c"])
        let pane = PaneState()

        XCTAssertEqual(pane.moveSelection(by: 1, in: items)?.name, "a")
        XCTAssertEqual(pane.selection, [items[0].url])
    }

    func testArrowMovementChangesTheSelectedItem() {
        let items = makeItems(names: ["a", "b", "c"])
        let pane = PaneState()
        pane.selection = [items[1].url]

        XCTAssertEqual(pane.moveSelection(by: -1, in: items)?.name, "a")
        XCTAssertEqual(pane.moveSelection(by: 1, in: items)?.name, "b")
    }

    func testArrowMovementStopsAtListBoundaries() {
        let items = makeItems(names: ["a", "b", "c"])
        let pane = PaneState()
        pane.select(items[2], from: items, mode: .replace)
        XCTAssertEqual(pane.selection, [items[2].url])

        XCTAssertEqual(pane.moveSelection(by: 1, in: items)?.name, "c")
        XCTAssertEqual(pane.moveSelection(by: -1, in: items)?.name, "b")
    }

    private func makeItems(names: [String]) -> [FileItem] {
        let root = URL(fileURLWithPath: "/tmp/keyboard-\(UUID().uuidString)")
        return names.map { name in
            let url = root.appendingPathComponent(name)
            return FileItem(
                id: url,
                name: name,
                url: url,
                isDirectory: false,
                isVolume: false,
                isRemovable: false,
                size: 1,
                kind: "File",
                modified: nil,
                tags: []
            )
        }
    }
}
