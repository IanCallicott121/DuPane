import Foundation
import AppKit
import XCTest
@testable import DuPane

// Tests for bugs fixed in Build 418.

final class ProcessRunnerLifecycleTests: DuPaneTestCase {
    func testStandardInputIsClosed() async throws {
        let result = try await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "if read value; then echo input; else echo eof; fi"],
            timeout: .seconds(1)
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "eof")
    }

    func testTimeoutTerminatesProcess() async {
        do {
            _ = try await ProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "sleep 5"],
                timeout: .milliseconds(50)
            )
            XCTFail("Expected the process to time out")
        } catch ProcessRunnerError.timedOut {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationTerminatesProcess() async {
        let task = Task {
            try await ProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "sleep 5"],
                timeout: .seconds(10)
            )
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class QuickLookToggleDecisionTests: DuPaneTestCase {
    func testVisiblePanelReloadsForDifferentSelection() {
        let old = [URL(fileURLWithPath: "/tmp/old")]
        let new = [URL(fileURLWithPath: "/tmp/new")]

        XCTAssertEqual(
            QuickLookCoordinator.toggleAction(isVisible: true, currentURLs: old, requestedURLs: new),
            .show
        )
    }

    func testVisiblePanelHidesForSameSelection() {
        let urls = [URL(fileURLWithPath: "/tmp/same")]

        XCTAssertEqual(
            QuickLookCoordinator.toggleAction(isVisible: true, currentURLs: urls, requestedURLs: urls),
            .hide
        )
    }
}

@MainActor
final class PaneDerivedStateTests: DuPaneTestCase {
    func testDisplayedItemsIsCachedUntilAnInputChanges() {
        let pane = PaneState()
        pane.items = [makeItem(name: "b"), makeItem(name: "a")]

        _ = pane.displayedItems
        _ = pane.displayedItems
        XCTAssertEqual(pane.displayedItemsComputationCount, 1)

        pane.filterText = "a"
        XCTAssertEqual(pane.displayedItems.map(\.name), ["a"])
        XCTAssertEqual(pane.displayedItemsComputationCount, 2)
    }

    func testClosingSearchingTabStopsItsSpotlightQuery() {
        let tabs = TabbedPaneState(initialURLs: [URL(fileURLWithPath: "/tmp"), URL(fileURLWithPath: "/var")])
        let closingPane = tabs.tabs[1].pane
        closingPane.beginDeepSearch(query: "txt")
        XCTAssertTrue(closingPane.hasActiveSpotlightQuery)

        tabs.closeTab(at: 1)

        XCTAssertFalse(closingPane.hasActiveSpotlightQuery)
        XCTAssertEqual(closingPane.spotlightObserverCount, 0)
    }

    private func makeItem(name: String) -> FileItem {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        return FileItem(
            id: url, name: name, url: url, isDirectory: false,
            isVolume: false, isRemovable: false, size: 1,
            kind: "File", modified: nil, tags: []
        )
    }
}

final class PeerPaneDeleteNavigationTests: DuPaneTestCase {
    func testTargetEscapesEverySuccessfullyDeletedAncestor() {
        let parent = URL(fileURLWithPath: "/tmp/parent", isDirectory: true)
        let child = parent.appendingPathComponent("child", isDirectory: true)
        let peer = child.appendingPathComponent("inside", isDirectory: true)

        XCTAssertEqual(
            FileOperationService.peerNavigationTarget(peerURL: peer, deletedURLs: [child, parent]),
            URL(fileURLWithPath: "/tmp", isDirectory: true)
        )
    }

    func testNoTargetWhenPeerIsOutsideDeletedItems() {
        XCTAssertNil(
            FileOperationService.peerNavigationTarget(
                peerURL: URL(fileURLWithPath: "/tmp/safe"),
                deletedURLs: [URL(fileURLWithPath: "/tmp/other")]
            )
        )
    }
}

@MainActor
final class SidebarValidationTests: DuPaneTestCase {
    func testInitialExistenceValidationRunsOffMainThread() async {
        let checked = expectation(description: "existence check")
        checked.assertForOverFulfill = false
        let model = SidebarModel(pathExists: { _ in
            XCTAssertFalse(Thread.isMainThread)
            checked.fulfill()
            return true
        })

        await model.validationTask?.value
        await fulfillment(of: [checked], timeout: 1)
    }

    func testRecordVisitValidationRunsOffMainThread() async {
        let checked = expectation(description: "existence check")
        checked.assertForOverFulfill = false
        let model = SidebarModel(pathExists: { _ in
            XCTAssertFalse(Thread.isMainThread)
            checked.fulfill()
            return true
        })
        await model.validationTask?.value

        model.recordVisit(URL(fileURLWithPath: "/tmp/visited"))
        await model.validationTask?.value
        await fulfillment(of: [checked], timeout: 1)
    }
}

@MainActor
final class ArchiveConflictOwnershipTests: DuPaneTestCase {
    func testArchiveConflictRequestLivesOnPaneState() {
        let pane = PaneState()
        let url = URL(fileURLWithPath: "/tmp/archive.zip")

        pane.pendingArchiveConflict = ArchiveConflictRequest(url: url, conflicts: ["a.txt"])

        XCTAssertEqual(pane.pendingArchiveConflict?.url, url)
        XCTAssertEqual(pane.pendingArchiveConflict?.conflicts, ["a.txt"])
    }
}

@MainActor
final class ColumnResizeLifecycleTests: DuPaneTestCase {
    func testWindowResignEndsActiveDrag() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let view = ColumnResizeNSView(frame: NSRect(x: 0, y: 0, width: 20, height: 100))
        window.contentView = view
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 10, y: 10),
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        ))

        view.mouseDown(with: event)
        XCTAssertTrue(view.isDragging)
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)

        XCTAssertFalse(view.isDragging)
    }
}
