import Foundation

struct AppLaunchConfiguration {
    let leftTabURLs: [URL?]
    let rightTabURLs: [URL?]

    var leftPaneURL: URL? { leftTabURLs.first ?? nil }
    var rightPaneURL: URL? { rightTabURLs.first ?? nil }

    // Used by tests that create configurations with explicit single URLs
    init(leftPaneURL: URL?, rightPaneURL: URL?) {
        self.leftTabURLs = [leftPaneURL]
        self.rightTabURLs = [rightPaneURL]
    }

    init(leftTabURLs: [URL?], rightTabURLs: [URL?]) {
        self.leftTabURLs = leftTabURLs.isEmpty ? [nil] : leftTabURLs
        self.rightTabURLs = rightTabURLs.isEmpty ? [nil] : rightTabURLs
    }

    static func current(processInfo: ProcessInfo = .processInfo) -> AppLaunchConfiguration {
        current(arguments: processInfo.arguments)
    }

    static func current(arguments: [String]) -> AppLaunchConfiguration {
        // Explicit command-line flags take priority over all other settings
        let leftArgURL  = url(for: "--left-pane-url",  in: arguments)
        let rightArgURL = url(for: "--right-pane-url", in: arguments)

        let leftMode  = StartupFolderMode(rawValue: UserDefaults.standard.string(forKey: "leftStartupMode") ?? "") ?? .default
        let rightMode = StartupFolderMode(rawValue: UserDefaults.standard.string(forKey: "rightStartupMode") ?? "") ?? .default

        let leftFirst  = leftArgURL  ?? startupURL(pane: "left",  defaultURL: defaultLeftPaneURL)
        let rightFirst = rightArgURL ?? startupURL(pane: "right", defaultURL: nil)

        let leftTabs  = restoredTabURLs(argURL: leftArgURL,  firstURL: leftFirst,  mode: leftMode,  key: "leftTabState")
        let rightTabs = restoredTabURLs(argURL: rightArgURL, firstURL: rightFirst, mode: rightMode, key: "rightTabState")

        return AppLaunchConfiguration(leftTabURLs: leftTabs, rightTabURLs: rightTabs)
    }

    // MARK: - Private helpers

    private static var defaultLeftPaneURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    private static func restoredTabURLs(argURL: URL?, firstURL: URL?, mode: StartupFolderMode, key: String) -> [URL?] {
        guard argURL == nil else { return [argURL] }

        // Restore all saved tabs only in rememberLast mode with no explicit command-line URL
        if mode == .rememberLast,
           let data = UserDefaults.standard.data(forKey: key),
           let paths = try? JSONDecoder().decode([String?].self, from: data),
           !paths.isEmpty {
            return paths.map { path -> URL? in
                guard let path else { return nil }
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                return URL(fileURLWithPath: path)
            }
        }

        let pinnedURLs = TabPersistence.pinnedStartupURLs(forKey: key, excluding: firstURL)
        guard !pinnedURLs.isEmpty else { return [firstURL] }
        return [firstURL] + pinnedURLs
    }

    private static func startupURL(pane: String, defaultURL: URL?) -> URL? {
        let modeKey  = "\(pane)StartupMode"
        let fixedKey = "\(pane)FixedPath"
        let lastKey  = "last\(pane.prefix(1).uppercased() + pane.dropFirst())URL"

        let mode = StartupFolderMode(
            rawValue: UserDefaults.standard.string(forKey: modeKey) ?? ""
        ) ?? .default

        switch mode {
        case .default:
            return defaultURL
        case .rememberLast:
            if let path = UserDefaults.standard.string(forKey: lastKey),
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
            return defaultURL
        case .fixed:
            if let path = UserDefaults.standard.string(forKey: fixedKey),
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
            return defaultURL
        }
    }

    private static func url(for option: String, in arguments: [String]) -> URL? {
        guard let idx = arguments.firstIndex(of: option) else { return nil }
        let valueIdx = arguments.index(after: idx)
        guard valueIdx < arguments.endIndex else { return nil }
        return URL(fileURLWithPath: arguments[valueIdx], isDirectory: true)
    }
}
