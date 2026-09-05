import Foundation
import SwiftUI

enum AppColorScheme: String, CaseIterable {
    case system  = "system"
    case ocean   = "ocean"
    case country = "country"
    case earth   = "earth"
    case fire    = "fire"
    case vivid   = "vivid"

    var label: String {
        switch self {
        case .system:  return "System"
        case .ocean:   return "Ocean"
        case .country: return "Country"
        case .earth:   return "Earth"
        case .fire:    return "Fire"
        case .vivid:   return "Vivid"
        }
    }

    var accentColor: Color? {
        switch self {
        case .system:  return nil
        case .ocean:   return Color(red: 0.00, green: 0.88, blue: 1.00)
        case .country: return Color(red: 0.15, green: 0.78, blue: 0.08)
        case .earth:   return Color(red: 0.90, green: 0.38, blue: 0.00)
        case .fire:    return Color(red: 1.00, green: 0.20, blue: 0.00)
        case .vivid:   return Color(red: 0.82, green: 0.00, blue: 1.00)
        }
    }

    var panelBackground: Color? {
        switch self {
        case .system: return nil
        case .ocean:
            return Color(NSColor(name: nil, dynamicProvider: { a in
                a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.05, green: 0.09, blue: 0.20, alpha: 1)
                    : NSColor(red: 0.87, green: 0.93, blue: 0.98, alpha: 1)
            }))
        case .country:
            return Color(NSColor(name: nil, dynamicProvider: { a in
                a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.07, green: 0.14, blue: 0.05, alpha: 1)
                    : NSColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1)
            }))
        case .earth:
            return Color(NSColor(name: nil, dynamicProvider: { a in
                a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.14, green: 0.09, blue: 0.05, alpha: 1)
                    : NSColor(red: 0.90, green: 0.85, blue: 0.74, alpha: 1)
            }))
        case .fire:
            return Color(NSColor(name: nil, dynamicProvider: { a in
                a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.12, green: 0.06, blue: 0.04, alpha: 1)
                    : NSColor(red: 0.97, green: 0.91, blue: 0.85, alpha: 1)
            }))
        case .vivid:
            return Color(NSColor(name: nil, dynamicProvider: { a in
                a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.09, green: 0.05, blue: 0.17, alpha: 1)
                    : NSColor(red: 0.96, green: 0.94, blue: 1.00, alpha: 1)
            }))
        }
    }
}

enum AppColorMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum DateFormatStyle: String, CaseIterable {
    case short    = "short"
    case medium   = "medium"
    case long     = "long"
    case iso      = "iso"
    case relative = "relative"

    var label: String {
        switch self {
        case .short:    return "Short  (31/12/25)"
        case .medium:   return "Medium (31 Dec 2025)"
        case .long:     return "Long  (December 31, 2025)"
        case .iso:      return "ISO   (2025-12-31)"
        case .relative: return "Relative (Today, Yesterday…)"
        }
    }
}

enum TimeFormatStyle: String, CaseIterable {
    case none                = "none"
    case twelve              = "12h"
    case twelveWithSeconds   = "12hSec"
    case twentyFour          = "24h"
    case withSeconds         = "24hSec"

    var label: String {
        switch self {
        case .none:              return "None"
        case .twelve:            return "12-hour  (2:35 PM)"
        case .twelveWithSeconds: return "12-hour + seconds  (2:35:22 PM)"
        case .twentyFour:        return "24-hour  (14:35)"
        case .withSeconds:       return "24-hour + seconds  (14:35:22)"
        }
    }

    var formatString: String? {
        switch self {
        case .none:              return nil
        case .twelve:            return "h:mm a"
        case .twelveWithSeconds: return "h:mm:ss a"
        case .twentyFour:        return "HH:mm"
        case .withSeconds:       return "HH:mm:ss"
        }
    }

    // Force POSIX locale so macOS 12/24h system preference doesn't override the format string.
    var usesPOSIXLocale: Bool {
        switch self {
        case .none, .twelve, .twelveWithSeconds: return false
        case .twentyFour, .withSeconds: return true
        }
    }
}

enum StartupFolderMode: String, CaseIterable {
    case `default` = "default"
    case rememberLast = "rememberLast"
    case fixed = "fixed"

    var label: String {
        switch self {
        case .default: return "Default"
        case .rememberLast: return "Remember last folder"
        case .fixed: return "Fixed folder…"
        }
    }
}

enum FileColumnLayout {
    static let defaultWidths: [String: CGFloat] = ["Size": 80, "Kind": 120, "Modified": 150, "Info": 80]
    static let minWidth: CGFloat = 50
    static let maxWidth: CGFloat = 400
    static let headerHeight: CGFloat = 28
    static let horizontalPadding: CGFloat = 8
    static let nameLeadingPadding: CGFloat = 28
    static let nameColumnGap: CGFloat = 8
    static let contentLeadingInset: CGFloat = 6
    static let resizeHandleWidth: CGFloat = 16
    static let resizeHandleHeight: CGFloat = 20

    static func defaultWidth(for column: String) -> CGFloat {
        defaultWidths[column, default: 80]
    }

    static func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minWidth), maxWidth)
    }
}

final class AppSettings: ObservableObject {
    // Delete behaviour
    @Published var fileDeleteNoConfirm: Bool {
        didSet { UserDefaults.standard.set(fileDeleteNoConfirm, forKey: "fileDeleteNoConfirm") }
    }
    @Published var directoryDeleteNoConfirm: Bool {
        didSet { UserDefaults.standard.set(directoryDeleteNoConfirm, forKey: "directoryDeleteNoConfirm") }
    }
    @Published var showCustomShellCommandNotice: Bool {
        didSet { UserDefaults.standard.set(showCustomShellCommandNotice, forKey: "showCustomShellCommandNotice") }
    }
    // Display
    @Published var showHiddenFiles: Bool {
        didSet { UserDefaults.standard.set(showHiddenFiles, forKey: "showHiddenFiles") }
    }
    @Published var showHiddenFolders: Bool {
        didSet { UserDefaults.standard.set(showHiddenFolders, forKey: "showHiddenFolders") }
    }
    @Published var showFileExtensions: Bool {
        didSet { UserDefaults.standard.set(showFileExtensions, forKey: "showFileExtensions") }
    }
    // Toolbar
    @Published var showToolbarLabels: Bool {
        didSet { UserDefaults.standard.set(showToolbarLabels, forKey: "showToolbarLabels") }
    }
    // Appearance
    @Published var appColorScheme: AppColorScheme {
        didSet { UserDefaults.standard.set(appColorScheme.rawValue, forKey: "appColorScheme") }
    }
    @Published var appColorMode: AppColorMode {
        didSet { UserDefaults.standard.set(appColorMode.rawValue, forKey: "appColorMode") }
    }
    @Published var listFontSize: Int {
        didSet { UserDefaults.standard.set(listFontSize, forKey: "listFontSize") }
    }
    @Published var dateFormatStyle: DateFormatStyle {
        didSet { UserDefaults.standard.set(dateFormatStyle.rawValue, forKey: "dateFormatStyle") }
    }
    // Column visibility — comma-separated list of hidden column names
    @Published var hiddenColumnsRaw: String {
        didSet { UserDefaults.standard.set(hiddenColumnsRaw, forKey: "hiddenColumns") }
    }
    // Column order — display order of the reorderable columns
    @Published var columnOrder: [String] {
        didSet { UserDefaults.standard.set(columnOrder, forKey: "columnOrder") }
    }
    // Column widths are kept per pane so resizing one side doesn't move the other.
    @Published var leftColumnWidths: [String: CGFloat] {
        didSet { Self.saveColumnWidths(leftColumnWidths, forKey: "leftColumnWidths") }
    }
    @Published var rightColumnWidths: [String: CGFloat] {
        didSet { Self.saveColumnWidths(rightColumnWidths, forKey: "rightColumnWidths") }
    }
    // Startup folders
    @Published var leftStartupMode: StartupFolderMode {
        didSet { UserDefaults.standard.set(leftStartupMode.rawValue, forKey: "leftStartupMode") }
    }
    @Published var leftFixedPath: String {
        didSet { UserDefaults.standard.set(leftFixedPath, forKey: "leftFixedPath") }
    }
    @Published var rightStartupMode: StartupFolderMode {
        didSet { UserDefaults.standard.set(rightStartupMode.rawValue, forKey: "rightStartupMode") }
    }
    @Published var rightFixedPath: String {
        didSet { UserDefaults.standard.set(rightFixedPath, forKey: "rightFixedPath") }
    }
    // Sidebar Places — set of location names to show in the Places section
    @Published var enabledPlaces: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledPlaces), forKey: "enabledPlaces")
        }
    }
    // Sidebar section visibility
    @Published var showSidebarPlaces: Bool {
        didSet { UserDefaults.standard.set(showSidebarPlaces, forKey: "showSidebarPlaces") }
    }
    @Published var showSidebarRecents: Bool {
        didSet { UserDefaults.standard.set(showSidebarRecents, forKey: "showSidebarRecents") }
    }
    // Sort behaviour
    @Published var foldersFirst: Bool {
        didSet { UserDefaults.standard.set(foldersFirst, forKey: "foldersFirst") }
    }
    // Date display
    @Published var timeFormatStyle: TimeFormatStyle {
        didSet { UserDefaults.standard.set(timeFormatStyle.rawValue, forKey: "timeFormatStyle") }
    }
    // Network section in sidebar
    @Published var showNetworkSection: Bool {
        didSet { UserDefaults.standard.set(showNetworkSection, forKey: "showNetworkSection") }
    }
    // Network sub-features (each individually toggleable)
    @Published var networkShowMountedVolumes: Bool {
        didSet { UserDefaults.standard.set(networkShowMountedVolumes, forKey: "networkShowMountedVolumes") }
    }
    @Published var networkBonjourDiscovery: Bool {
        didSet { UserDefaults.standard.set(networkBonjourDiscovery, forKey: "networkBonjourDiscovery") }
    }
    @Published var networkPinnedLocations: Bool {
        didSet { UserDefaults.standard.set(networkPinnedLocations, forKey: "networkPinnedLocations") }
    }
    @Published var networkAutoReconnect: Bool {
        didSet { UserDefaults.standard.set(networkAutoReconnect, forKey: "networkAutoReconnect") }
    }
    @Published var networkStatusIndicator: Bool {
        didSet { UserDefaults.standard.set(networkStatusIndicator, forKey: "networkStatusIndicator") }
    }
    @Published var pinnedNetworkURLs: [String] {
        didSet { UserDefaults.standard.set(pinnedNetworkURLs, forKey: "pinnedNetworkURLs") }
    }
    @Published var pinnedNetworkNames: [String: String] {
        didSet { UserDefaults.standard.set(pinnedNetworkNames, forKey: "pinnedNetworkNames") }
    }

    init() {
        fileDeleteNoConfirm = UserDefaults.standard.bool(forKey: "fileDeleteNoConfirm")
        directoryDeleteNoConfirm = UserDefaults.standard.bool(forKey: "directoryDeleteNoConfirm")
        showCustomShellCommandNotice = UserDefaults.standard.object(forKey: "showCustomShellCommandNotice").map {
            ($0 as? Bool) ?? true
        } ?? true
        showHiddenFiles = UserDefaults.standard.bool(forKey: "showHiddenFiles")
        showHiddenFolders = UserDefaults.standard.bool(forKey: "showHiddenFolders")
        // Default true: show extensions (matches pre-existing behaviour)
        showFileExtensions = UserDefaults.standard.object(forKey: "showFileExtensions").map {
            ($0 as? Bool) ?? true
        } ?? true
        // Default true: show toolbar labels
        showToolbarLabels = UserDefaults.standard.object(forKey: "showToolbarLabels").map {
            ($0 as? Bool) ?? true
        } ?? true
        appColorScheme = AppColorScheme(
            rawValue: UserDefaults.standard.string(forKey: "appColorScheme") ?? ""
        ) ?? .system
        appColorMode = AppColorMode(
            rawValue: UserDefaults.standard.string(forKey: "appColorMode") ?? ""
        ) ?? .system
        listFontSize = UserDefaults.standard.object(forKey: "listFontSize").map {
            ($0 as? Int) ?? 14
        } ?? 14
        dateFormatStyle = DateFormatStyle(
            rawValue: UserDefaults.standard.string(forKey: "dateFormatStyle") ?? ""
        ) ?? .medium
        // Default: hide Kind and Info so only Name, Size, Modified show
        hiddenColumnsRaw = UserDefaults.standard.object(forKey: "hiddenColumns").map {
            ($0 as? String) ?? "Info,Kind"
        } ?? "Info,Kind"
        columnOrder = UserDefaults.standard.stringArray(forKey: "columnOrder") ?? ["Size", "Kind", "Modified", "Info"]
        let legacyColumnWidths = Self.loadColumnWidths(forKey: "columnWidths") ?? FileColumnLayout.defaultWidths
        leftColumnWidths = Self.loadColumnWidths(forKey: "leftColumnWidths") ?? legacyColumnWidths
        rightColumnWidths = Self.loadColumnWidths(forKey: "rightColumnWidths") ?? legacyColumnWidths
        leftStartupMode = StartupFolderMode(
            rawValue: UserDefaults.standard.string(forKey: "leftStartupMode") ?? ""
        ) ?? .default
        leftFixedPath = UserDefaults.standard.string(forKey: "leftFixedPath") ?? ""
        rightStartupMode = StartupFolderMode(
            rawValue: UserDefaults.standard.string(forKey: "rightStartupMode") ?? ""
        ) ?? .default
        rightFixedPath = UserDefaults.standard.string(forKey: "rightFixedPath") ?? ""
        if let saved = UserDefaults.standard.array(forKey: "enabledPlaces") as? [String] {
            enabledPlaces = Set(saved)
        } else {
            enabledPlaces = ["Home", "Applications", "Desktop", "Documents", "Downloads", "iCloud Drive", "OneDrive"]
        }
        showSidebarPlaces = UserDefaults.standard.object(forKey: "showSidebarPlaces").map { ($0 as? Bool) ?? true } ?? true
        showSidebarRecents = UserDefaults.standard.object(forKey: "showSidebarRecents").map { ($0 as? Bool) ?? true } ?? true
        foldersFirst = UserDefaults.standard.object(forKey: "foldersFirst").map { ($0 as? Bool) ?? true } ?? true
        if let raw = UserDefaults.standard.string(forKey: "timeFormatStyle"),
           let parsed = TimeFormatStyle(rawValue: raw) {
            timeFormatStyle = parsed
        } else {
            // Migrate from old showTimeInDate bool: true → 24h, false → none, absent → 24h
            let legacy = UserDefaults.standard.object(forKey: "showTimeInDate")
            timeFormatStyle = ((legacy as? Bool) == false) ? .none : .twentyFour
        }
        showNetworkSection = UserDefaults.standard.object(forKey: "showNetworkSection").map { ($0 as? Bool) ?? true } ?? true
        networkShowMountedVolumes = UserDefaults.standard.object(forKey: "networkShowMountedVolumes").map { ($0 as? Bool) ?? true } ?? true
        networkBonjourDiscovery = UserDefaults.standard.object(forKey: "networkBonjourDiscovery").map { ($0 as? Bool) ?? true } ?? true
        networkPinnedLocations = UserDefaults.standard.object(forKey: "networkPinnedLocations").map { ($0 as? Bool) ?? true } ?? true
        networkAutoReconnect = UserDefaults.standard.object(forKey: "networkAutoReconnect").map { ($0 as? Bool) ?? false } ?? false
        networkStatusIndicator = UserDefaults.standard.object(forKey: "networkStatusIndicator").map { ($0 as? Bool) ?? true } ?? true
        pinnedNetworkURLs = UserDefaults.standard.stringArray(forKey: "pinnedNetworkURLs") ?? []
        pinnedNetworkNames = (UserDefaults.standard.dictionary(forKey: "pinnedNetworkNames") as? [String: String]) ?? [:]
    }

    var hiddenColumns: Set<String> {
        get { Set(hiddenColumnsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }) }
        set { hiddenColumnsRaw = newValue.sorted().joined(separator: ",") }
    }

    func toggleColumn(_ name: String) {
        var cols = hiddenColumns
        if cols.contains(name) { cols.remove(name) } else { cols.insert(name) }
        hiddenColumns = cols
    }

    func columnWidth(for name: String, in side: PaneSide) -> CGFloat {
        columnWidths(for: side)[name, default: FileColumnLayout.defaultWidth(for: name)]
    }

    func setColumnWidths(_ widths: [String: CGFloat], for side: PaneSide) {
        let clampedWidths = widths.mapValues { FileColumnLayout.clampedWidth($0) }
        switch side {
        case .left:
            leftColumnWidths = leftColumnWidths.merging(clampedWidths) { _, new in new }
        case .right:
            rightColumnWidths = rightColumnWidths.merging(clampedWidths) { _, new in new }
        }
    }

    func columnWidths(for side: PaneSide) -> [String: CGFloat] {
        switch side {
        case .left: return leftColumnWidths
        case .right: return rightColumnWidths
        }
    }

    func resetColumnWidths(for side: PaneSide) {
        switch side {
        case .left:
            leftColumnWidths = FileColumnLayout.defaultWidths
        case .right:
            rightColumnWidths = FileColumnLayout.defaultWidths
        }
    }

    func resetColumnWidths() {
        leftColumnWidths = FileColumnLayout.defaultWidths
        rightColumnWidths = FileColumnLayout.defaultWidths
    }

    private static func loadColumnWidths(forKey key: String) -> [String: CGFloat]? {
        guard let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] else {
            return nil
        }

        let clamped = saved.mapValues { FileColumnLayout.clampedWidth(CGFloat($0)) }
        return FileColumnLayout.defaultWidths.merging(clamped) { _, saved in saved }
    }

    private static func saveColumnWidths(_ widths: [String: CGFloat], forKey key: String) {
        UserDefaults.standard.set(widths.mapValues { Double($0) }, forKey: key)
    }

    func exportedData() -> Data? {
        let keys = [
            "fileDeleteNoConfirm", "directoryDeleteNoConfirm", "showCustomShellCommandNotice",
            "showHiddenFiles", "showHiddenFolders", "showFileExtensions", "showToolbarLabels",
            "appColorScheme", "appColorMode", "listFontSize", "dateFormatStyle",
            "hiddenColumns", "columnOrder", "leftColumnWidths", "rightColumnWidths",
            "leftStartupMode", "leftFixedPath", "rightStartupMode", "rightFixedPath",
            "enabledPlaces", "showSidebarPlaces", "showSidebarRecents",
            "foldersFirst", "timeFormatStyle", "showNetworkSection",
            "networkShowMountedVolumes", "networkBonjourDiscovery", "networkPinnedLocations",
            "networkAutoReconnect", "networkStatusIndicator", "pinnedNetworkURLs", "pinnedNetworkNames"
        ]
        var dict: [String: Any] = [:]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                dict[key] = value
            }
        }
        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }

    func applyImport(from data: Data) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let v = dict["fileDeleteNoConfirm"] as? Bool { fileDeleteNoConfirm = v }
        if let v = dict["directoryDeleteNoConfirm"] as? Bool { directoryDeleteNoConfirm = v }
        if let v = dict["showCustomShellCommandNotice"] as? Bool { showCustomShellCommandNotice = v }
        if let v = dict["showHiddenFiles"] as? Bool { showHiddenFiles = v }
        if let v = dict["showHiddenFolders"] as? Bool { showHiddenFolders = v }
        if let v = dict["showFileExtensions"] as? Bool { showFileExtensions = v }
        if let v = dict["showToolbarLabels"] as? Bool { showToolbarLabels = v }
        if let v = dict["appColorScheme"] as? String, let e = AppColorScheme(rawValue: v) { appColorScheme = e }
        if let v = dict["appColorMode"] as? String, let e = AppColorMode(rawValue: v) { appColorMode = e }
        if let v = dict["listFontSize"] as? Int { listFontSize = v }
        if let v = dict["dateFormatStyle"] as? String, let e = DateFormatStyle(rawValue: v) { dateFormatStyle = e }
        if let v = dict["hiddenColumns"] as? String { hiddenColumnsRaw = v }
        if let v = dict["columnOrder"] as? [String] { columnOrder = v }
        if let v = dict["leftColumnWidths"] as? [String: Double] { leftColumnWidths = v.mapValues { CGFloat($0) } }
        if let v = dict["rightColumnWidths"] as? [String: Double] { rightColumnWidths = v.mapValues { CGFloat($0) } }
        if let v = dict["leftStartupMode"] as? String, let e = StartupFolderMode(rawValue: v) { leftStartupMode = e }
        if let v = dict["leftFixedPath"] as? String { leftFixedPath = v }
        if let v = dict["rightStartupMode"] as? String, let e = StartupFolderMode(rawValue: v) { rightStartupMode = e }
        if let v = dict["rightFixedPath"] as? String { rightFixedPath = v }
        if let v = dict["enabledPlaces"] as? [String] { enabledPlaces = Set(v) }
        if let v = dict["showSidebarPlaces"] as? Bool { showSidebarPlaces = v }
        if let v = dict["showSidebarRecents"] as? Bool { showSidebarRecents = v }
        if let v = dict["foldersFirst"] as? Bool { foldersFirst = v }
        if let v = dict["timeFormatStyle"] as? String, let e = TimeFormatStyle(rawValue: v) { timeFormatStyle = e }
        if let v = dict["showNetworkSection"] as? Bool { showNetworkSection = v }
        if let v = dict["networkShowMountedVolumes"] as? Bool { networkShowMountedVolumes = v }
        if let v = dict["networkBonjourDiscovery"] as? Bool { networkBonjourDiscovery = v }
        if let v = dict["networkPinnedLocations"] as? Bool { networkPinnedLocations = v }
        if let v = dict["networkAutoReconnect"] as? Bool { networkAutoReconnect = v }
        if let v = dict["networkStatusIndicator"] as? Bool { networkStatusIndicator = v }
        if let v = dict["pinnedNetworkURLs"] as? [String] { pinnedNetworkURLs = v }
        if let v = dict["pinnedNetworkNames"] as? [String: String] { pinnedNetworkNames = v }
    }
}
