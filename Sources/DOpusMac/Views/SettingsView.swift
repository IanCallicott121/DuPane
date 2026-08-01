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
                Toggle("Show file name extensions", isOn: $settings.showFileExtensions)
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
