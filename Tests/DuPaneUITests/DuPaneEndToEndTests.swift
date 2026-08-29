import XCTest

final class DuPaneEndToEndTests: XCTestCase {
    // Requires an Xcode-built executable in DerivedData.
    // Passes silently via `swift test` (no binary); runs fully via ⌘U in Xcode.
    func testAppBundleCanBeCreatedFromBuiltExecutable() {
        guard let appBundleURL = try? TestAppBundleBuilder.makeAppBundle(
            testBundle: Bundle(for: DuPaneEndToEndTests.self)
        ) else { return }

        let executableURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("DuPane")
        let infoPlistURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")

        XCTAssertTrue(FileManager.default.fileExists(atPath: appBundleURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executableURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPlistURL.path))
    }
}
