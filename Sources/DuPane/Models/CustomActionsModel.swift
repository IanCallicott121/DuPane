import Foundation

struct CustomAction: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var command: String

    /// Runs the action in a detached login-shell process.
    /// $@ expands to space-separated shell-quoted selected file paths.
    func run(selectedFiles: [URL], workingDirectory: URL?) {
        let quotedPaths = selectedFiles
            .map { "'\($0.path.replacingOccurrences(of: "'", with: "'\\''"))'" }
            .joined(separator: " ")
        let resolved = command.replacingOccurrences(of: "$@", with: quotedPaths)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", resolved]   // -l = login shell for correct PATH
        if let dir = workingDirectory { process.currentDirectoryURL = dir }
        try? process.run()
    }
}

@MainActor
final class CustomActionsModel: ObservableObject {
    @Published var actions: [CustomAction] = []
    private static let defaultsKey = "customActions.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([CustomAction].self, from: data) {
            actions = decoded
        }
    }

    func add(name: String, command: String) {
        actions.append(CustomAction(name: name, command: command))
        persist()
    }

    func update(id: UUID, name: String, command: String) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index].name = name
        actions[index].command = command
        persist()
    }

    func remove(at offsets: IndexSet) {
        actions.remove(atOffsets: offsets)
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
