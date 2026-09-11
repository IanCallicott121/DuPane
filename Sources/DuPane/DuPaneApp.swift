import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
            NSWorkspace.shared.open(url)
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

    private var keyEventMonitor: Any?

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
            guard event.keyCode == 49 else { return event } // 49 = space
            if let fr = NSApp.keyWindow?.firstResponder, fr is NSTextView { return event }
            NotificationCenter.default.post(name: .quickLookRequested, object: nil)
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
