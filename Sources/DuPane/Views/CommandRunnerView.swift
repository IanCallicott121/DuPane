import SwiftUI

/// Retractable panel at the bottom of a pane for running shell commands.
struct CommandRunnerView: View {
    @Binding var isVisible: Bool
    let workingDirectory: URL?
    @EnvironmentObject private var settings: AppSettings
    @State private var command = ""
    @State private var output = ""
    @State private var isRunning = false
    @State private var pendingCommand: PendingShellCommand?
    @State private var runTask: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    private struct PendingShellCommand: Identifiable {
        let id = UUID()
        let command: String
        let workingDirectory: URL?
    }

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
                    .accessibilityIdentifier("command-runner-field")
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
                    .accessibilityIdentifier("command-runner-run-button")
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
        .onDisappear { runTask?.cancel() }
        .alert("Run Shell Command?", isPresented: Binding(
            get: { pendingCommand != nil },
            set: { if !$0 { pendingCommand = nil } }
        ), presenting: pendingCommand) { pending in
            Button("Run") { execute(pending) }
            Button("Don't Show Again") {
                settings.showCustomShellCommandNotice = false
                execute(pending)
            }
            Button("Cancel", role: .cancel) { pendingCommand = nil }
        } message: { _ in
            Text("Commands run through your login shell in the active folder. They can modify, move, or delete files, so only run commands you trust.")
        }
    }

    private var promptLabel: String {
        if let dir = workingDirectory { return "\(dir.lastPathComponent) $ " }
        return "$ "
    }

    private func run() {
        let cmd = command.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty, !isRunning else { return }
        let pending = PendingShellCommand(command: cmd, workingDirectory: workingDirectory)
        if settings.showCustomShellCommandNotice {
            pendingCommand = pending
        } else {
            execute(pending)
        }
    }

    private func execute(_ pending: PendingShellCommand) {
        pendingCommand = nil
        isRunning = true
        output = ""
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let wd = pending.workingDirectory
        let cmd = pending.command

        runTask?.cancel()
        runTask = Task(priority: .userInitiated) {
            do {
                let result = try await ProcessRunner.run(
                    executableURL: URL(fileURLWithPath: shell),
                    arguments: ["-l", "-c", cmd],
                    currentDirectoryURL: wd
                )
                let combined = result.trimmedCombinedOutput
                let displayOutput: String
                if result.terminationStatus == 0 {
                    displayOutput = combined.isEmpty ? "(no output)" : combined
                } else if combined.isEmpty {
                    displayOutput = "Command exited with status \(result.terminationStatus)"
                } else {
                    displayOutput = "\(combined)\n(exit \(result.terminationStatus))"
                }
                try Task.checkCancellation()
                output = displayOutput
                isRunning = false
            } catch is CancellationError {
                isRunning = false
            } catch {
                output = "Error: \(error.localizedDescription)"
                isRunning = false
            }
        }
    }
}
