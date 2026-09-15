import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

enum InternalTestBuildMarker {
    static let value = "421.6"
}

@main
struct DuPaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView(configuration: .current())
                .frame(minWidth: 960, minHeight: 620)
                .environmentObject(settings)
                .preferredColorScheme(settings.appColorMode.preferredColorScheme)
                .accentColor(settings.appColorScheme.accentColor)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Open User Guide") {
                    openUserGuide()
                }
                .keyboardShortcut("?", modifiers: .command)

                Button("Open FAQs") {
                    openFAQs()
                }

                Button("Internal Test Build \(InternalTestBuildMarker.value)") {}
                    .disabled(true)
            }
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(replacing: .appSettings) {
                Button("Export Settings…") { exportSettings() }
                Button("Import Settings…") { importSettings() }
            }
        }

        Settings {
            SettingsView(settings: settings)
        }
    }

    private func openDoc(_ filename: String) {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let candidates: [URL] = [
            Bundle.main.url(forResource: name, withExtension: ext),
            Bundle.main.resourceURL?.appendingPathComponent(filename),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Docs")
                .appendingPathComponent(filename)
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            let title = filename == "FAQs.html" ? "DuPane — FAQs" : "DuPane — User Guide"
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.openDocumentation(url: url, title: title)
            } else {
                NSWorkspace.shared.open(url)
            }
            return
        }
    }

    private func openUserGuide() { openDoc("UserGuide.html") }
    private func openFAQs() { openDoc("FAQs.html") }

    private func exportSettings() {
        guard let data = settings.exportedData() else { return }
        let panel = NSSavePanel()
        panel.title = "Export DuPane Settings"
        panel.nameFieldStringValue = "DuPane Settings"
        panel.allowedContentTypes = [.json]
        panel.isExtensionHidden = false
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import DuPane Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            settings.applyImport(from: data)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum WindowRestore {
        static let minimumSize = NSSize(width: 640, height: 400)
        static let minimumVisibleSize = NSSize(width: 160, height: 120)
    }

    private enum OperationShortcut: String {
        case copy
        case move
        case newFolder
        case delete
    }

    private var keyEventMonitor: Any?
    private var documentationWindows: [String: DocumentationWindowController] = [:]

    func openDocumentation(url: URL, title: String) {
        if let existing = documentationWindows[url.lastPathComponent] {
            existing.showFullWidth()
            return
        }

        let controller = DocumentationWindowController(url: url, title: title)
        documentationWindows[url.lastPathComponent] = controller
        controller.showFullWidth()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false

        if let mainMenu = NSApp.mainMenu {
            for title in ["Edit", "View", "Window"] {
                if let item = mainMenu.item(withTitle: title) {
                    mainMenu.removeItem(item)
                }
            }
        }

        for window in NSApp.windows {
            window.titleVisibility = .hidden
            window.tabbingMode = .disallowed
            if let frameStr = UserDefaults.standard.string(forKey: "mainWindowFrame"),
               let restoredFrame = usableRestoredWindowFrame(from: frameStr) {
                window.setFrame(restoredFrame, display: true)
            } else if let screen = NSScreen.main {
                window.setFrame(screen.visibleFrame, display: true)
            }
            window.makeKeyAndOrderFront(nil)
        }

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let responder = NSApp.keyWindow?.firstResponder
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let navigationModifiers = modifiers.intersection([.command, .control, .option, .shift])
            if event.keyCode == 53 {
                NotificationCenter.default.post(name: .creationPromptEscapeRequested, object: nil)
                return event
            }
            if event.charactersIgnoringModifiers?.lowercased() == "g",
               navigationModifiers == [.command, .shift] {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .goToPathShortcutRequested, object: nil)
                }
                return nil
            }
            if responder is NSTextView || responder is NSTextField {
                if event.charactersIgnoringModifiers?.lowercased() == "v",
                   navigationModifiers == [.command] {
                    let editor: NSText?
                    if let textView = responder as? NSTextView {
                        editor = textView
                    } else if let textField = responder as? NSTextField {
                        editor = textField.currentEditor()
                    } else {
                        editor = nil
                    }
                    if let editor,
                       let pastedText = NSPasteboard.general.string(forType: .string) {
                        editor.replaceCharacters(in: editor.selectedRange, with: pastedText)
                        return nil
                    }
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: responder, from: nil)
                    return nil
                }
                return event
            }

            if navigationModifiers.isEmpty {
                let navigationOffset: Int?
                switch event.keyCode {
                case 126: navigationOffset = -1
                case 125: navigationOffset = 1
                case 116: navigationOffset = -10
                case 121: navigationOffset = 10
                default: navigationOffset = nil
                }
                if let navigationOffset {
                    NotificationCenter.default.post(
                        name: .paneNavigationRequested,
                        object: nil,
                        userInfo: ["offset": navigationOffset]
                    )
                    return nil
                }
            }

            if event.keyCode == 49 {
                NotificationCenter.default.post(name: .quickLookRequested, object: nil)
                return nil
            }

            let shortcut: OperationShortcut?
            switch event.keyCode {
            case 96: shortcut = .copy  // F5
            case 97: shortcut = .move  // F6
            case 98: shortcut = .newFolder  // F7
            case 100: shortcut = .delete  // F8
            default: shortcut = nil
            }
            guard let shortcut,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  !(responder is NSTextView || responder is NSTextField)
            else { return event }
            NotificationCenter.default.post(
                name: .operationShortcutRequested,
                object: nil,
                userInfo: ["operation": shortcut.rawValue]
            )
            return nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = keyEventMonitor { NSEvent.removeMonitor(monitor) }
        for window in NSApp.windows {
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "mainWindowFrame")
        }
    }

    private func usableRestoredWindowFrame(from frameString: String) -> NSRect? {
        let frame = NSRectFromString(frameString)
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.width >= WindowRestore.minimumSize.width,
              frame.height >= WindowRestore.minimumSize.height
        else {
            return nil
        }

        for screen in NSScreen.screens {
            let visibleArea = frame.intersection(screen.visibleFrame)
            if visibleArea.width >= WindowRestore.minimumVisibleSize.width,
               visibleArea.height >= WindowRestore.minimumVisibleSize.height {
                return frame
            }
        }

        return nil
    }
}

final class DocumentationWindowController: NSWindowController {
    private let webView: WKWebView

    init(url: URL, title: String) {
        webView = WKWebView(frame: .zero)
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(width: 900, height: 600)
        window.contentView = webView
        super.init(window: window)
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showFullWidth() {
        if let screen = NSScreen.main {
            window?.setFrame(screen.visibleFrame, display: true)
        } else {
            window?.setContentSize(NSSize(width: 1200, height: 800))
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
