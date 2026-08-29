import Foundation
import XCTest
@testable import DuPane

final class FolderCompareServiceTests: XCTestCase {
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

    func testCompareMarksMissingAndSameItems() {
        let date = Date(timeIntervalSince1970: 100)
        let leftItems = [
            makeItem(name: "same.txt", pane: .left, size: 4, modified: date),
            makeItem(name: "left-only.txt", pane: .left, size: 1, modified: date)
        ]
        let rightItems = [
            makeItem(name: "same.txt", pane: .right, size: 4, modified: date),
            makeItem(name: "right-only.txt", pane: .right, size: 1, modified: date)
        ]

        let snapshot = FolderCompareService.compare(leftItems: leftItems, rightItems: rightItems)

        XCTAssertEqual(snapshot.summary.same, 1)
        XCTAssertEqual(snapshot.summary.onlyLeft, 1)
        XCTAssertEqual(snapshot.summary.onlyRight, 1)
        XCTAssertEqual(snapshot.leftStatuses[leftItems[1].url], .onlyLeft)
        XCTAssertEqual(snapshot.rightStatuses[rightItems[1].url], .onlyRight)
        XCTAssertNil(snapshot.leftStatuses[leftItems[0].url])
    }

    func testCompareMarksNewerSideWhenSizeMatches() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let left = makeItem(name: "shared.txt", pane: .left, size: 12, modified: newer)
        let right = makeItem(name: "shared.txt", pane: .right, size: 12, modified: older)

        let snapshot = FolderCompareService.compare(leftItems: [left], rightItems: [right])

        XCTAssertEqual(snapshot.summary.newerLeft, 1)
        XCTAssertEqual(snapshot.leftStatuses[left.url], .newerLeft)
        XCTAssertEqual(snapshot.rightStatuses[right.url], .newerLeft)
    }

    func testCompareMarksDifferentForSizeKindAndDateAmbiguity() {
        let leftItems = [
            makeItem(name: "size.txt", pane: .left, size: 10),
            makeItem(name: "kind.txt", pane: .left, size: 1, kind: "Text"),
            makeItem(name: "date.txt", pane: .left, size: 1, modified: Date(timeIntervalSince1970: 1))
        ]
        let rightItems = [
            makeItem(name: "size.txt", pane: .right, size: 12),
            makeItem(name: "kind.txt", pane: .right, size: 1, kind: "PDF"),
            makeItem(name: "date.txt", pane: .right, size: 1, modified: nil)
        ]

        let snapshot = FolderCompareService.compare(leftItems: leftItems, rightItems: rightItems)

        XCTAssertEqual(snapshot.summary.different, 3)
        XCTAssertTrue(leftItems.allSatisfy { snapshot.leftStatuses[$0.url] == .different })
        XCTAssertTrue(rightItems.allSatisfy { snapshot.rightStatuses[$0.url] == .different })
    }

    func testSyncPlanLeftToRightCopiesMissingAndOverwritesOnlyEligibleSourceDifferences() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let leftItems = [
            makeItem(name: "left-only.txt", pane: .left, size: 1, modified: older),
            makeItem(name: "left-newer.txt", pane: .left, size: 2, modified: newer),
            makeItem(name: "right-newer.txt", pane: .left, size: 2, modified: older),
            makeItem(name: "different.txt", pane: .left, size: 5, modified: newer)
        ]
        let rightItems = [
            makeItem(name: "left-newer.txt", pane: .right, size: 2, modified: older),
            makeItem(name: "right-newer.txt", pane: .right, size: 2, modified: newer),
            makeItem(name: "different.txt", pane: .right, size: 7, modified: newer),
            makeItem(name: "right-only.txt", pane: .right, size: 1, modified: older)
        ]
        let snapshot = FolderCompareService.compare(leftItems: leftItems, rightItems: rightItems)

        let plan = FolderCompareService.syncPlan(
            from: snapshot,
            direction: .leftToRight,
            leftFolder: fixture.leftPaneURL,
            rightFolder: fixture.rightPaneURL
        )

        XCTAssertEqual(Set(plan.entries.map { $0.source.name }), ["left-only.txt", "left-newer.txt", "different.txt"])
        XCTAssertEqual(plan.copyMissingCount, 1)
        XCTAssertEqual(plan.overwriteOlderCount, 1)
        XCTAssertEqual(plan.overwriteDifferentCount, 1)
        XCTAssertFalse(plan.entries.contains { $0.source.name == "right-newer.txt" })
        XCTAssertFalse(plan.entries.contains { $0.source.name == "right-only.txt" })
    }

    func testSyncPlanDoesNotDeleteDestinationOnlyItems() {
        let rightOnly = makeItem(name: "right-only.txt", pane: .right, size: 1)
        let snapshot = FolderCompareService.compare(leftItems: [], rightItems: [rightOnly])

        let plan = FolderCompareService.syncPlan(
            from: snapshot,
            direction: .leftToRight,
            leftFolder: fixture.leftPaneURL,
            rightFolder: fixture.rightPaneURL
        )

        XCTAssertTrue(plan.entries.isEmpty)
        XCTAssertEqual(plan.confirmationMessage, "Sync Left to Right? This will make no filesystem changes. Destination-only items will not be deleted.")
    }

    func testSyncPlanSkipsExistingFolderOverwrites() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let leftFolder = makeItem(name: "Shared", pane: .left, isDirectory: true, modified: newer)
        let rightFolder = makeItem(name: "Shared", pane: .right, isDirectory: true, modified: older)
        let snapshot = FolderCompareService.compare(leftItems: [leftFolder], rightItems: [rightFolder])

        let plan = FolderCompareService.syncPlan(
            from: snapshot,
            direction: .leftToRight,
            leftFolder: fixture.leftPaneURL,
            rightFolder: fixture.rightPaneURL
        )

        XCTAssertTrue(plan.entries.isEmpty)
        XCTAssertEqual(plan.skippedExistingFolderOverwrites, 1)
    }

    func testExecutingSyncPlanCopiesMissingAndOverwritesDifferentFileWithoutDeletingDestinationOnlyFile() throws {
        for name in fixture.leftFileNames {
            try fixture.removeIfExists(fixture.fileURL(named: name, in: .left))
        }
        for name in fixture.rightFileNames {
            try fixture.removeIfExists(fixture.fileURL(named: name, in: .right))
        }

        _ = try fixture.writeFile(named: "common.txt", contents: "source", in: .left)
        let rightCommon = try fixture.writeFile(named: "common.txt", contents: "destination", in: .right)
        _ = try fixture.writeFile(named: "missing.txt", contents: "copy", in: .left)
        let rightOnly = try fixture.writeFile(named: "right-only.txt", contents: "keep", in: .right)

        let snapshot = FolderCompareService.compare(
            leftItems: [
                makeItem(name: "common.txt", pane: .left, size: 6),
                makeItem(name: "missing.txt", pane: .left, size: 4)
            ],
            rightItems: [
                makeItem(name: "common.txt", pane: .right, size: 11),
                makeItem(name: "right-only.txt", pane: .right, size: 4)
            ]
        )
        let plan = FolderCompareService.syncPlan(
            from: snapshot,
            direction: .leftToRight,
            leftFolder: fixture.leftPaneURL,
            rightFolder: fixture.rightPaneURL
        )

        let result = FileOperationService.moveOrCopy(
            files: plan.entries.map(\.source),
            to: plan.destinationFolder,
            isMove: false,
            conflictResolution: .overwrite
        )

        XCTAssertEqual(result.succeeded, 2)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(try String(contentsOf: rightCommon, encoding: .utf8), "source")
        XCTAssertTrue(fixture.exists(fixture.fileURL(named: "missing.txt", in: .right)))
        XCTAssertTrue(fixture.exists(rightOnly))
    }

    private func makeItem(
        name: String,
        pane: TestPane,
        isDirectory: Bool = false,
        size: Int64? = nil,
        kind: String = "Text",
        modified: Date? = Date(timeIntervalSince1970: 100)
    ) -> FileItem {
        let url = fixture.paneURL(pane).appendingPathComponent(name, isDirectory: isDirectory)
        return FileItem(
            id: url,
            name: name,
            url: url,
            isDirectory: isDirectory,
            isVolume: false,
            isRemovable: false,
            size: isDirectory ? nil : size,
            kind: isDirectory ? "Folder" : kind,
            modified: modified,
            tags: []
        )
    }
}
