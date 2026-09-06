import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Files") {
                Toggle("Skip confirmation when deleting files", isOn: $settings.fileDeleteNoConfirm)
            }
            Section("Folders") {
                Toggle("Skip confirmation when deleting folders", isOn: $settings.directoryDeleteNoConfirm)
            }
            Section("Display") {
                Toggle("Show hidden files (dot-files)", isOn: $settings.showHiddenFiles)
                Toggle("Show hidden folders (dot-folders)", isOn: $settings.showHiddenFolders)
                Toggle("Show file name extensions", isOn: $settings.showFileExtensions)
                Toggle("Show toolbar button labels", isOn: $settings.showToolbarLabels)
                Toggle("Sort folders before files", isOn: $settings.foldersFirst)
                Stepper("File list font size: \(settings.listFontSize)pt",
                        value: $settings.listFontSize, in: 11...16)
                Picker("Date format", selection: $settings.dateFormatStyle) {
                    ForEach(DateFormatStyle.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                Picker("Time in date modified", selection: $settings.timeFormatStyle) {
                    ForEach(TimeFormatStyle.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
            }
            Section("Appearance") {
                Picker("Theme", selection: $settings.appColorScheme) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
                .pickerStyle(.menu)
                Picker("Mode", selection: $settings.appColorMode) {
                    ForEach(AppColorMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Sidebar") {
                Toggle("Show Places section", isOn: $settings.showSidebarPlaces)
                Toggle("Show Recents section", isOn: $settings.showSidebarRecents)
                Toggle("Show Network section", isOn: $settings.showNetworkSection)
            }
            if settings.showNetworkSection {
                Section("Network") {
                    Toggle("Show mounted network volumes", isOn: $settings.networkShowMountedVolumes)
                    Toggle("Show status indicator", isOn: $settings.networkStatusIndicator)
                    Toggle("Show pinned servers", isOn: $settings.networkPinnedLocations)
                    Toggle("Bonjour discovery in Connect sheet", isOn: $settings.networkBonjourDiscovery)
                    Toggle("Auto-reconnect pinned servers on launch", isOn: $settings.networkAutoReconnect)
                }
            }
            Section("Sidebar places") {
                placesRow("Home")
                placesRow("Applications")
                placesRow("Desktop")
                placesRow("Documents")
                placesRow("Downloads")
                if FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs") {
                    placesRow("iCloud Drive")
                }
                if FileManager.default.fileExists(atPath: NSHomeDirectory() + "/OneDrive") {
                    placesRow("OneDrive")
                }
            }
            Section("Startup folders") {
                startupRow(label: "Left pane",
                           mode: $settings.leftStartupMode,
                           fixedPath: $settings.leftFixedPath,
                           pane: "left")
                startupRow(label: "Right pane",
                           mode: $settings.rightStartupMode,
                           fixedPath: $settings.rightFixedPath,
                           pane: "right")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
        .background(
            Button("") { NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .allowsHitTesting(false)
        )
    }

    private func placesRow(_ name: String) -> some View {
        Toggle(name, isOn: Binding(
            get: { settings.enabledPlaces.contains(name) },
            set: { enabled in
                if enabled {
                    settings.enabledPlaces.insert(name)
                } else {
                    settings.enabledPlaces.remove(name)
                }
            }
        ))
    }

    @ViewBuilder
    private func startupRow(
        label: String,
        mode: Binding<StartupFolderMode>,
        fixedPath: Binding<String>,
        pane: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Picker("", selection: mode) {
                ForEach(StartupFolderMode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if mode.wrappedValue == .fixed {
                HStack(spacing: 6) {
                    TextField("Path…", text: fixedPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    Button("Browse…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.canCreateDirectories = false
                        panel.title = "Choose \(label) Startup Folder"
                        if panel.runModal() == .OK, let url = panel.url {
                            fixedPath.wrappedValue = url.path
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
