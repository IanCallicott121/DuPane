import Foundation
import XCTest

/// Writes a machine-readable line per test into `.test-results/latest.log` at the repo
/// root, so a run's outcome — including failure text — can be read from a shell instead
/// of scraped out of Xcode's UI. The path is derived from `#filePath`, so it works
/// wherever the bundle happens to be built.
///
/// Format, one line per test:
///   PASS <ClassName.testName>
///   FAIL <ClassName.testName> :: <issue description>
enum TestResultLog {
    private static let lock = NSLock()
    private static var didTruncate = false

    /// One file per test bundle. A scheme runs several bundles in the same session and
    /// they would otherwise share a path, so whichever finished last truncated the rest.
    static var fileURL: URL {
        var root = URL(fileURLWithPath: #filePath)
        // <repo>/<TargetDir>/<Suite>/TestResultLog.swift
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let bundle = Bundle(for: DuPaneTestCase.self)
            .bundleURL.deletingPathExtension().lastPathComponent
        return root.appendingPathComponent(".test-results/\(bundle).log")
    }

    static func append(name: String, failures: [String], skipped: Bool) {
        let line: String
        if !failures.isEmpty {
            line = failures.map { "FAIL \(name) :: \($0.replacingOccurrences(of: "\n", with: " ⏎ "))\n" }.joined()
        } else if skipped {
            line = "SKIP \(name)\n"
        } else {
            line = "PASS \(name)\n"
        }

        lock.lock()
        defer { lock.unlock() }

        let url = fileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if !didTruncate {
            didTruncate = true
            try? Data().write(to: url)
        }
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}

/// Base class that routes every failure through `TestResultLog`. Test classes inherit
/// from this instead of `XCTestCase` directly.
///
/// The hook is `invokeTest`, not `tearDown`: several suites override `tearDown()` — some
/// as `async throws`, many on `@MainActor` classes — and a base-class `tearDown` would be
/// shadowed by those or clash on isolation. `invokeTest` wraps the whole test, is
/// overridden nowhere in this project, and is non-isolated.
class DuPaneTestCase: XCTestCase {
    private var recordedFailures: [String] = []

    override func record(_ issue: XCTIssue) {
        recordedFailures.append(issue.compactDescription)
        super.record(issue)
    }

    override func invokeTest() {
        recordedFailures = []
        super.invokeTest()
        TestResultLog.append(
            name: name,
            failures: recordedFailures,
            skipped: (testRun?.skipCount ?? 0) > 0
        )
    }
}
