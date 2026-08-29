import Darwin
import Foundation
import XCTest
@testable import DuPane

enum TestPane: String {
    case left, right

    var other: TestPane { self == .left ? .right : .left }
}

enum ClickVariant {
    case plain
    case command
    case shift

    var title: String {
        switch self {
        case .plain: return "Single-click"
        case .command: return "Command-click"
        case .shift: return "Shift-click"
        }
    }
}

enum ClickSelectionError: Error, Equatable {
    case missingRow(String, TestPane)
}

final class ClickSelectionHarness {
    private let rowsByPane: [TestPane: [String]]
    private var selections: [TestPane: Set<String>] = [.left: [], .right: []]
    private var openedRowsByPane: [TestPane: [String]] = [.left: [], .right: []]
    private var anchorRows: [TestPane: String] = [:]

    private(set) var activePane: TestPane = .left

    var destinationPane: TestPane {
        activePane.other
    }

    init(leftRows: [String], rightRows: [String]) {
        rowsByPane = [
            .left: leftRows,
            .right: rightRows
        ]
    }

    func click(_ variant: ClickVariant, rowNamed name: String, in pane: TestPane) throws {
        guard let rows = rowsByPane[pane], rows.contains(name) else {
            throw ClickSelectionError.missingRow(name, pane)
        }

        activePane = pane
        switch variant {
        case .plain:
            selectRow(named: name, in: pane)
        case .command:
            toggleSelection(named: name, in: pane)
            anchorRows[pane] = name
        case .shift:
            extendSelection(to: name, in: pane, rows: rows)
        }
    }

    func doubleClick(rowNamed name: String, in pane: TestPane) throws {
        guard rowsByPane[pane, default: []].contains(name) else {
            throw ClickSelectionError.missingRow(name, pane)
        }

        activePane = pane
        for action in RowMouseEventPolicy.actions(clickCount: 2, buttonNumber: 0) {
            switch action {
            case .select:
                selectRow(named: name, in: pane)
            case .open:
                openedRowsByPane[pane, default: []].append(name)
            }
        }
    }

    func selectionCount(in pane: TestPane) -> Int {
        selections[pane, default: []].count
    }

    func isSelected(_ name: String, in pane: TestPane) -> Bool {
        selections[pane, default: []].contains(name)
    }

    func selection(in pane: TestPane) -> [String] {
        let selected = selections[pane, default: []]
        return rowsByPane[pane, default: []].filter { selected.contains($0) }
    }

    func openedRows(in pane: TestPane) -> [String] {
        openedRowsByPane[pane, default: []]
    }

    private func selectRow(named name: String, in pane: TestPane) {
        selections[pane] = [name]
        anchorRows[pane] = name
    }

    private func toggleSelection(named name: String, in pane: TestPane) {
        var selection = selections[pane, default: []]
        if selection.contains(name) {
            selection.remove(name)
        } else {
            selection.insert(name)
        }
        selections[pane] = selection
    }

    private func extendSelection(to name: String, in pane: TestPane, rows: [String]) {
        guard
            let anchor = anchorRows[pane],
            let anchorIndex = rows.firstIndex(of: anchor),
            let targetIndex = rows.firstIndex(of: name)
        else {
            selections[pane] = [name]
            anchorRows[pane] = name
            return
        }

        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selections[pane] = Set(rows[range])
    }
}

enum TestAppBundleBuilderError: Error, CustomStringConvertible {
    case executableNotFound([String])
    case invalidInfoPlist

    var description: String {
        switch self {
        case .executableNotFound(let paths):
            return "Unable to find the built DuPane executable. Checked: \(paths.joined(separator: ", "))"
        case .invalidInfoPlist:
            return "Unable to create the generated test app Info.plist."
        }
    }
}

struct TestAppBundleBuilder {
    private static let executableName = "DuPane"
    private static let bundleIdentifier = "local.DuPane.UITests"

    static func makeAppBundle(testBundle: Bundle, fileManager: FileManager = .default) throws -> URL {
        let executableURL = try findExecutable(testBundle: testBundle, fileManager: fileManager)
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("DuPaneUITests", isDirectory: true)
        let appURL = rootURL.appendingPathComponent("\(executableName).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let bundledExecutableURL = macOSURL.appendingPathComponent(executableName)

        if fileManager.fileExists(atPath: appURL.path) {
            try fileManager.removeItem(at: appURL)
        }

        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: executableURL, to: bundledExecutableURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundledExecutableURL.path)

        guard let infoPlistData = infoPlist.data(using: .utf8) else {
            throw TestAppBundleBuilderError.invalidInfoPlist
        }
        try infoPlistData.write(to: contentsURL.appendingPathComponent("Info.plist"), options: .atomic)

        return appURL
    }

    private static func findExecutable(testBundle: Bundle, fileManager: FileManager) throws -> URL {
        let candidates = executableCandidates(testBundle: testBundle, fileManager: fileManager)
        if let executableURL = candidates.first(where: { isExecutableFile($0, fileManager: fileManager) }) {
            return executableURL
        }
        throw TestAppBundleBuilderError.executableNotFound(candidates.map(\.path))
    }

    private static func executableCandidates(testBundle: Bundle, fileManager: FileManager) -> [URL] {
        let productDirectory = testBundle.bundleURL.deletingLastPathComponent()
        let packageRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildRootURL = packageRootURL.appendingPathComponent(".build", isDirectory: true)

        return unique([
            productDirectory.appendingPathComponent(executableName),
            packageRootURL.appendingPathComponent(".build/debug/\(executableName)"),
            packageRootURL.appendingPathComponent(".build/arm64-apple-macosx/debug/\(executableName)"),
            packageRootURL.appendingPathComponent(".build/x86_64-apple-macosx/debug/\(executableName)")
        ] + swiftBuildCandidates(in: buildRootURL, fileManager: fileManager))
    }

    private static func swiftBuildCandidates(in buildRootURL: URL, fileManager: FileManager) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: buildRootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var candidates: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent == executableName {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true else {
                continue
            }
            candidates.append(url)
            if candidates.count >= 20 { break }
        }
        return candidates
    }

    private static func isExecutableFile(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue && fileManager.isExecutableFile(atPath: url.path)
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seenPaths: Set<String> = []
        return urls.filter { url in
            seenPaths.insert(url.standardizedFileURL.path).inserted
        }
    }

    private static var infoPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDisplayName</key>
            <string>DuPane</string>
            <key>CFBundleExecutable</key>
            <string>\(executableName)</string>
            <key>CFBundleIdentifier</key>
            <string>\(bundleIdentifier)</string>
            <key>CFBundleName</key>
            <string>DuPane</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSMinimumSystemVersion</key>
            <string>13.0</string>
            <key>NSHighResolutionCapable</key>
            <true/>
        </dict>
        </plist>
        """
    }
}

final class ItemActionHarness {
    private(set) var navigatedURL: URL?
    private(set) var openedURL: URL?
    private(set) var revealedURL: URL?

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigatedURL = item.url
        } else {
            openedURL = item.url
        }
    }

    func reveal(_ item: FileItem) {
        revealedURL = item.url
    }
}

enum FilePaneFixtureError: Error, Equatable {
    case missingItem(String, TestPane)
}

final class FilePaneFixture {
    let rootURL: URL
    let leftPaneURL: URL
    let rightPaneURL: URL
    let leftFileNames = ["alpha.txt", "beta.txt", "gamma.txt"]
    let rightFileNames = ["target.txt"]

    private let fileManager: FileManager

    init(
        fileManager: FileManager = .default,
        rootName: String = "DuPaneFunctionTests-\(UUID().uuidString)",
        baseURL: URL? = nil
    ) throws {
        self.fileManager = fileManager
        let parentURL: URL
        if let baseURL {
            parentURL = baseURL
        } else {
            parentURL = Self.canonicalTemporaryDirectory(fileManager: fileManager)
        }

        rootURL = parentURL.appendingPathComponent(rootName, isDirectory: true)
        leftPaneURL = rootURL.appendingPathComponent("left-pane", isDirectory: true)
        rightPaneURL = rootURL.appendingPathComponent("right-pane", isDirectory: true)

        try fileManager.createDirectory(at: leftPaneURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: rightPaneURL, withIntermediateDirectories: true)

        for fileName in leftFileNames {
            try writeFile(named: fileName, in: .left)
        }
        for fileName in rightFileNames {
            try writeFile(named: fileName, in: .right)
        }
    }

    func tearDown() throws {
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
    }

    func paneURL(_ pane: TestPane) -> URL {
        pane == .left ? leftPaneURL : rightPaneURL
    }

    func fileURL(named name: String, in pane: TestPane) -> URL {
        paneURL(pane).appendingPathComponent(name)
    }

    func folderURL(named name: String, in pane: TestPane) -> URL {
        paneURL(pane).appendingPathComponent(name, isDirectory: true)
    }

    @discardableResult
    func writeFile(named name: String, contents: String? = nil, in pane: TestPane) throws -> URL {
        let fileURL = fileURL(named: name, in: pane)
        try (contents ?? name).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    @discardableResult
    func createFolder(named name: String, in pane: TestPane) throws -> URL {
        let url = folderURL(named: name, in: pane)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    @MainActor
    func itemNames(in pane: TestPane) throws -> [String] {
        try PaneState.loadFolder(paneURL(pane)).map(\.name).sorted()
    }

    @MainActor
    func fileItem(named name: String, in pane: TestPane) throws -> FileItem {
        guard let item = try PaneState.loadFolder(paneURL(pane)).first(where: { $0.name == name }) else {
            throw FilePaneFixtureError.missingItem(name, pane)
        }
        return item
    }

    func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func removeIfExists(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func canonicalTemporaryDirectory(fileManager: FileManager) -> URL {
        let url = fileManager.temporaryDirectory
        guard let path = realpath(url.path, nil) else { return url }
        defer { free(path) }
        return URL(fileURLWithFileSystemRepresentation: path, isDirectory: true, relativeTo: nil)
    }
}
