import SwiftUI
import AppKit

@main
struct DOpusMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(configuration: .current())
                .frame(minWidth: 960, minHeight: 620)
                .environmentObject(settings)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Open User Guide") {
                    openUserGuide()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsView(settings: settings)
        }
    }

    private func openUserGuide() {
        // Look for the HTML guide next to the app bundle, then in the source tree
        let candidates: [URL] = [
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("UserGuide.html"),
            Bundle.main.resourceURL?
                .appendingPathComponent("UserGuide.html"),
            // Development path relative to project root
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // DOpusMacApp.swift dir
                .deletingLastPathComponent()   // Sources/DOpusMac
                .deletingLastPathComponent()   // Sources
                .deletingLastPathComponent()   // project root
                .appendingPathComponent("Docs/UserGuide.html")
        ].compactMap { $0 }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
            return
        }
    }
}

/// Ensures normal app behaviour (Dock icon, frontmost window) when running
/// as a plain Swift Package executable without a signed .app bundle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.titleVisibility = .hidden
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
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
