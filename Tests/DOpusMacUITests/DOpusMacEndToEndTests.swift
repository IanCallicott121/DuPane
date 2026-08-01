import XCTest

final class DOpusMacEndToEndTests: XCTestCase {
    // Requires an Xcode-built executable in DerivedData.
    // Passes silently via `swift test` (no binary); runs fully via ⌘U in Xcode.
    func testAppBundleCanBeCreatedFromBuiltExecutable() {
        guard let appBundleURL = try? TestAppBundleBuilder.makeAppBundle(
            testBundle: Bundle(for: DOpusMacEndToEndTests.self)
        ) else { return }

        let executableURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("DOpusMac")
        let infoPlistURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")

        XCTAssertTrue(FileManager.default.fileExists(atPath: appBundleURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executableURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPlistURL.path))
    }
}
