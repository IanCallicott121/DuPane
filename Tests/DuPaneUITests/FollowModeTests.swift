import Foundation
import XCTest
@testable import DuPane

final class FollowModeTests: XCTestCase {
    func testFollowSynchronizesFolderToComputer() {
        let folder = URL(fileURLWithPath: "/tmp/source", isDirectory: true)

        XCTAssertTrue(ContentView.shouldSynchronizeFollowedPane(
            isFollowMode: true,
            activePane: .left,
            sourcePane: .left,
            sourceURL: folder,
            targetURL: nil
        ))
    }

    func testFollowSynchronizesComputerToFolder() {
        let folder = URL(fileURLWithPath: "/tmp/target", isDirectory: true)

        XCTAssertTrue(ContentView.shouldSynchronizeFollowedPane(
            isFollowMode: true,
            activePane: .right,
            sourcePane: .right,
            sourceURL: nil,
            targetURL: folder
        ))
    }

    func testFollowDoesNotSynchronizeWhenLocationsMatch() {
        let folder = URL(fileURLWithPath: "/tmp/shared", isDirectory: true)

        XCTAssertFalse(ContentView.shouldSynchronizeFollowedPane(
            isFollowMode: true,
            activePane: .left,
            sourcePane: .left,
            sourceURL: folder,
            targetURL: folder
        ))
    }

    func testFollowDoesNotSynchronizeInactivePaneChanges() {
        let folder = URL(fileURLWithPath: "/tmp/source", isDirectory: true)

        XCTAssertFalse(ContentView.shouldSynchronizeFollowedPane(
            isFollowMode: true,
            activePane: .right,
            sourcePane: .left,
            sourceURL: folder,
            targetURL: nil
        ))
    }
}
