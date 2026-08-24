import SwiftUI
import AppKit

@main
struct DOpusMacApp: App {
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
                Button("Open DuPane User Guide") {
                    openUserGuide()
                }
                .keyboardShortcut("?", modifiers: .command)

                Button("Open DuPane FAQs") {
                    openFAQs()
                }
            }
            CommandGroup(replacing: .windowArrangement) {}
        }

        Settings {
            SettingsView(settings: settings)
        }
    }

    private func openDoc(_ filename: String) {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs")
        let candidates: [URL] = [
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(filename),
            Bundle.main.resourceURL?.appendingPathComponent(filename),
            root.appendingPathComponent(filename)
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
            return
        }
    }

    private func openUserGuide() { openDoc("UserGuide.html") }
    private func openFAQs() { openDoc("FAQs.html") }
}

/// Ensures normal app behaviour (Dock icon, frontmost window) when running
/// as a plain Swift Package executable without a signed .app bundle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false
        for window in NSApp.windows {
            window.titleVisibility = .hidden
            window.tabbingMode = .disallowed
            if let frameStr = UserDefaults.standard.string(forKey: "mainWindowFrame") {
                window.setFrame(NSRectFromString(frameStr), display: true)
            } else if let screen = NSScreen.main {
                window.setFrame(screen.visibleFrame, display: true)
            }
            window.makeKeyAndOrderFront(nil)
        }

        // Space bar → Quick Look for the active pane's selection.
        // Skipped when a text field has keyboard focus.
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
}
