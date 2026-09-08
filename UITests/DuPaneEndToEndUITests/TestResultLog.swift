import Foundation
import XCTest

/// Emits a machine-readable line per test. `Scripts/run-e2e.sh` extracts the marker
/// from xcodebuild output into `.test-results/DuPaneEndToEndUITests.log`; the UI-test
/// sandbox cannot write directly into the source checkout.
///
/// Format, one line per test:
///   PASS <ClassName.testName>
///   FAIL <ClassName.testName> :: <issue description>
enum TestResultLog {
    static func append(name: String, failures: [String], skipped: Bool) {
        let line: String
        if !failures.isEmpty {
            line = failures.map { "FAIL \(name) :: \($0.replacingOccurrences(of: "\n", with: " ⏎ "))\n" }.joined()
        } else if skipped {
            line = "SKIP \(name)\n"
        } else {
            line = "PASS \(name)\n"
        }

        for resultLine in line.split(separator: "\n", omittingEmptySubsequences: true) {
            print("DUPANE_TEST_RESULT \(resultLine)")
        }
    }
}

/// Base class that routes every failure through `TestResultLog`. UI test classes call
/// `super.tearDownWithError()`, which is reliable under both Xcode and SwiftPM runners.
class DuPaneTestCase: XCTestCase {
    private var recordedFailures: [String] = []

    override func record(_ issue: XCTIssue) {
        recordedFailures.append(issue.compactDescription)
        super.record(issue)
    }

    override func setUpWithError() throws {
        recordedFailures = []
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        TestResultLog.append(
            name: name,
            failures: recordedFailures,
            skipped: (testRun?.skipCount ?? 0) > 0
        )
        try super.tearDownWithError()
    }
}
