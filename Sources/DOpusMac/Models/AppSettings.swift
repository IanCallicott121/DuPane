import Foundation

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

final class AppSettings: ObservableObject {
    // Delete behaviour
    @Published var fileDeleteNoConfirm: Bool {
        didSet { UserDefaults.standard.set(fileDeleteNoConfirm, forKey: "fileDeleteNoConfirm") }
    }
    @Published var directoryDeleteNoConfirm: Bool {
        didSet { UserDefaults.standard.set(directoryDeleteNoConfirm, forKey: "directoryDeleteNoConfirm") }
    }
    // Display
    @Published var showHiddenFiles: Bool {
        didSet { UserDefaults.standard.set(showHiddenFiles, forKey: "showHiddenFiles") }
    }
    @Published var showFileExtensions: Bool {
        didSet { UserDefaults.standard.set(showFileExtensions, forKey: "showFileExtensions") }
    }
    // Column visibility — comma-separated list of hidden column names
    @Published var hiddenColumnsRaw: String {
        didSet { UserDefaults.standard.set(hiddenColumnsRaw, forKey: "hiddenColumns") }
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

    init() {
        fileDeleteNoConfirm = UserDefaults.standard.bool(forKey: "fileDeleteNoConfirm")
        directoryDeleteNoConfirm = UserDefaults.standard.bool(forKey: "directoryDeleteNoConfirm")
        showHiddenFiles = UserDefaults.standard.bool(forKey: "showHiddenFiles")
        // Default true: show extensions (matches pre-existing behaviour)
        showFileExtensions = UserDefaults.standard.object(forKey: "showFileExtensions").map {
            ($0 as? Bool) ?? true
        } ?? true
        hiddenColumnsRaw = UserDefaults.standard.string(forKey: "hiddenColumns") ?? ""
        leftStartupMode = StartupFolderMode(
            rawValue: UserDefaults.standard.string(forKey: "leftStartupMode") ?? ""
        ) ?? .default
        leftFixedPath = UserDefaults.standard.string(forKey: "leftFixedPath") ?? ""
        rightStartupMode = StartupFolderMode(
            rawValue: UserDefaults.standard.string(forKey: "rightStartupMode") ?? ""
        ) ?? .default
        rightFixedPath = UserDefaults.standard.string(forKey: "rightFixedPath") ?? ""
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
}
