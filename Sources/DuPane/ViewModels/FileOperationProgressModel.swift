import Foundation

/// Tracks in-flight file operations for the progress overlay.
///
/// Operations were previously written into a single set of `@State` slots in
/// `ContentView`, so two running at once clobbered each other: whichever finished
/// first tore down the overlay, and the one still running had no progress display
/// for the rest of its life. Every mutation here is addressed by the token issued
/// at `begin`, so a finished operation can only ever retire itself.
@MainActor
final class FileOperationProgressModel: ObservableObject {
    struct Info: Equatable {
        let label: String
        let completed: Int
        let total: Int
    }

    /// The operation currently on display: the most recently started one still running.
    @Published private(set) var info: Info?
    @Published private(set) var isVisible: Bool = false

    private var inFlight: [UUID] = []
    private var infos: [UUID: Info] = [:]

    var activeOperationCount: Int { inFlight.count }

    func begin(label: String, total: Int) -> UUID {
        let token = UUID()
        inFlight.append(token)
        let started = Info(label: label, completed: 0, total: total)
        infos[token] = started
        info = started
        return token
    }

    /// Shown on a delay so brief operations never flash the overlay.
    func reveal(_ token: UUID) {
        guard inFlight.contains(token) else { return }
        isVisible = true
    }

    func update(_ token: UUID, completed: Int) {
        guard let existing = infos[token] else { return }
        let updated = Info(label: existing.label, completed: completed, total: existing.total)
        infos[token] = updated
        if inFlight.last == token { info = updated }
    }

    func finish(_ token: UUID) {
        guard let index = inFlight.firstIndex(of: token) else { return }
        inFlight.remove(at: index)
        infos[token] = nil
        if let current = inFlight.last {
            info = infos[current]
        } else {
            info = nil
            isVisible = false
        }
    }
}
