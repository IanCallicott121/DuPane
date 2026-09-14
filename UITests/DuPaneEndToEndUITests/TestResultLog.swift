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

    private var negativeValidationEnabled: Bool {
        ProcessInfo.processInfo.environment["DUPANE_E2E_NEGATIVE_VALIDATION"] == "1"
            || FileManager.default.fileExists(atPath: "/tmp/DuPane-e2e-negative-validation")
    }

    override func record(_ issue: XCTIssue) {
        if issue.severity.rawValue >= XCTIssue.Severity.error.rawValue {
            recordedFailures.append(issue.compactDescription)
        }
        super.record(issue)
    }

    override func setUpWithError() throws {
        recordedFailures = []
        try super.setUpWithError()
        if negativeValidationEnabled {
            XCTFail("Negative E2E validation: intentional failure for an otherwise-passing test")
        }
    }

    override func tearDownWithError() throws {
        let testWasSkipped = (testRun?.skipCount ?? 0) > 0
        let finalTestRunHasFailures = (testRun?.failureCount ?? 0) > 0
            || (testRun?.unexpectedExceptionCount ?? 0) > 0
        TestResultLog.append(
            name: name,
            failures: finalTestRunHasFailures && recordedFailures.isEmpty
                ? ["XCTest reported a failure that was not intercepted by record(_:)" ]
                : recordedFailures,
            skipped: testWasSkipped
        )
        try super.tearDownWithError()
    }
}
