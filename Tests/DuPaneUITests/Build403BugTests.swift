import Combine
import Foundation
import XCTest
@testable import DuPane

final class NetworkVolumeThreadingTests: DuPaneTestCase {
    func testRefreshDoesNotBlockItsCallerWhileVolumeScanRuns() {
        let monitor = NetworkVolumeMonitor(volumeScan: { _ in
            Thread.sleep(forTimeInterval: 0.15)
            return ([], [])
        })

        let started = Date()
        monitor.refresh()

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.05)
    }

    func testBonjourPublicationArrivesOnMainThread() {
        let monitor = NetworkVolumeMonitor()
        let published = expectation(description: "Bonjour update published")
        var wasMainThread = false
        let observation = monitor.$bonjourServers.dropFirst().sink { _ in
            wasMainThread = Thread.isMainThread
            published.fulfill()
        }

        DispatchQueue.global().async {
            monitor.receiveBonjourServers(
                [BonjourServer(name: "Share", hostName: "share.local", scheme: "smb")],
                scheme: "smb"
            )
        }

        wait(for: [published], timeout: 1)
        withExtendedLifetime(observation) {}
        XCTAssertTrue(wasMainThread)
    }
}
