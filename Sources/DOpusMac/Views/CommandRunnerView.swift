import SwiftUI

/// Retractable panel at the bottom of a pane for running shell commands.
struct CommandRunnerView: View {
    @Binding var isVisible: Bool
    let workingDirectory: URL?
    @State private var command = ""
    @State private var output = ""
    @State private var isRunning = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Text(promptLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .padding(.trailing, 4)
                TextField("Command…", text: $command, onCommit: run)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($fieldFocused)
                    .padding(.vertical, 6)
                if isRunning {
                    ProgressView().scaleEffect(0.65).padding(.horizontal, 8)
                } else {
                    Button(action: run) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(command.isEmpty ? Color.secondary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(command.isEmpty)
                    .padding(.horizontal, 8)
                }
                Button { isVisible = false } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .help("Hide command runner (⌥`)")
            }
            .frame(height: 32)
            .background(Color(nsColor: .windowBackgroundColor))

            if !output.isEmpty {
                Divider()
                ScrollView {
                    Text(output)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 130)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .onAppear { fieldFocused = true }
    }

    private var promptLabel: String {
        if let dir = workingDirectory { return "\(dir.lastPathComponent) $ " }
        return "$ "
    }

    private func run() {
        let cmd = command.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty, !isRunning else { return }
        isRunning = true
        output = ""
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let wd = workingDirectory

        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-l", "-c", cmd]
            if let dir = wd { process.currentDirectoryURL = dir }

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()
                let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let combined = (stdout + stderr).trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    output = combined.isEmpty ? "(no output)" : combined
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    output = "Error: \(error.localizedDescription)"
                    isRunning = false
                }
            }
        }
    }
}
