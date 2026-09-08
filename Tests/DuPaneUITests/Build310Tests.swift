import Foundation
import XCTest
@testable import DuPane

// MARK: - NetworkVolume (5 tests)

final class NetworkVolumeTests: DuPaneTestCase {
    func testNetworkVolumeNameDerivedFromLastPathComponent() {
        let url = URL(fileURLWithPath: "/Volumes/WorkShare")
        let vol = NetworkVolume(url: url)
        XCTAssertEqual(vol.name, "WorkShare")
    }

    func testNetworkVolumeIdIsURL() {
        let url = URL(fileURLWithPath: "/Volumes/Backup")
        let vol = NetworkVolume(url: url)
        XCTAssertEqual(vol.id, url)
    }

    func testNetworkVolumeEqualityByURL() {
        let url = URL(fileURLWithPath: "/Volumes/Shared")
        XCTAssertEqual(NetworkVolume(url: url), NetworkVolume(url: url))
    }

    func testNetworkVolumeInequalityForDifferentURLs() {
        let a = NetworkVolume(url: URL(fileURLWithPath: "/Volumes/A"))
        let b = NetworkVolume(url: URL(fileURLWithPath: "/Volumes/B"))
        XCTAssertNotEqual(a, b)
    }

    func testNetworkVolumeNameWithSpaces() {
        let url = URL(fileURLWithPath: "/Volumes/My Network Drive")
        let vol = NetworkVolume(url: url)
        XCTAssertEqual(vol.name, "My Network Drive")
    }
}

// MARK: - BonjourServer (5 tests)

final class BonjourServerTests: DuPaneTestCase {
    func testBonjourServerIdCombinesSchemeAndHost() {
        let s = BonjourServer(name: "MyServer", hostName: "myserver.local", scheme: "smb")
        XCTAssertEqual(s.id, "smb://myserver.local")
    }

    func testBonjourServerConnectURLSMB() {
        let s = BonjourServer(name: "NAS", hostName: "nas.local", scheme: "smb")
        XCTAssertEqual(s.connectURL, URL(string: "smb://nas.local/"))
    }

    func testBonjourServerConnectURLAFP() {
        let s = BonjourServer(name: "TimeCapsule", hostName: "tc.local", scheme: "afp")
        XCTAssertEqual(s.connectURL, URL(string: "afp://tc.local/"))
    }

    func testBonjourServerEqualityBySchemAndHost() {
        let a = BonjourServer(name: "A", hostName: "host.local", scheme: "smb")
        let b = BonjourServer(name: "B", hostName: "host.local", scheme: "smb")
        // id matches: same scheme+host
        XCTAssertEqual(a.id, b.id)
    }

    func testBonjourServerDifferentSchemesAreNotEqual() {
        let smb = BonjourServer(name: "S", hostName: "host.local", scheme: "smb")
        let afp = BonjourServer(name: "S", hostName: "host.local", scheme: "afp")
        XCTAssertNotEqual(smb.id, afp.id)
    }
}

// MARK: - AppSettings network defaults (7 tests)

final class AppSettingsNetworkDefaultTests: DuPaneTestCase {
    private static let networkKeys = [
        "networkShowMountedVolumes", "networkBonjourDiscovery", "networkPinnedLocations",
        "networkAutoReconnect", "networkStatusIndicator", "pinnedNetworkURLs"
    ]

    override func setUp() {
        super.setUp()
        for key in Self.networkKeys { UserDefaults.standard.removeObject(forKey: key) }
    }

    override func tearDown() {
        for key in Self.networkKeys { UserDefaults.standard.removeObject(forKey: key) }
        super.tearDown()
    }

    func testNetworkShowMountedVolumesDefaultTrue() {
        XCTAssertTrue(AppSettings().networkShowMountedVolumes)
    }

    func testNetworkBonjourDiscoveryDefaultTrue() {
        XCTAssertTrue(AppSettings().networkBonjourDiscovery)
    }

    func testNetworkPinnedLocationsDefaultTrue() {
        XCTAssertTrue(AppSettings().networkPinnedLocations)
    }

    func testNetworkAutoReconnectDefaultFalse() {
        XCTAssertFalse(AppSettings().networkAutoReconnect)
    }

    func testNetworkStatusIndicatorDefaultTrue() {
        XCTAssertTrue(AppSettings().networkStatusIndicator)
    }

    func testPinnedNetworkURLsDefaultEmpty() {
        XCTAssertTrue(AppSettings().pinnedNetworkURLs.isEmpty)
    }

    func testPinnedNetworkURLsPersistAcrossInstances() {
        let s = AppSettings()
        s.pinnedNetworkURLs = ["smb://server/share", "afp://other/"]
        let s2 = AppSettings()
        XCTAssertEqual(s2.pinnedNetworkURLs, ["smb://server/share", "afp://other/"])
    }
}

// MARK: - NetworkVolumeMonitor unit (3 tests)

@MainActor
final class NetworkVolumeMonitorTests: DuPaneTestCase {
    func testRefreshProducesNoVolumesOnRootFileSystem() {
        // The root filesystem ("/") is always local — refresh should not include it
        let monitor = NetworkVolumeMonitor()
        monitor.refresh()
        let rootIncluded = monitor.mountedVolumes.contains { $0.url.path == "/" }
        XCTAssertFalse(rootIncluded, "Root filesystem is local; must not appear in network volumes")
    }

    func testReconnectPinnedSkipsInvalidURLs() {
        // All of these must be rejected by the scheme+host guard — no NSWorkspace calls
        let monitor = NetworkVolumeMonitor()
        monitor.reconnectPinned(["not a url", "", "relative/path", "missinghost://"])
        // no assertion — just verifying no crash and no system dialog
    }

    func testIsMountedReturnsFalseForUnknownPinnedURL() {
        let monitor = NetworkVolumeMonitor()
        monitor.refresh()
        XCTAssertFalse(monitor.isMounted("smb://nonexistent.local/share"))
    }
}
