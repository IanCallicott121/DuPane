import Foundation

@MainActor
final class FolderSizeViewModel: ObservableObject {
    struct Entry: Identifiable {
        let id: URL
        let name: String
        let url: URL
        let bytes: Int64
        let isDirectory: Bool
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var isLoading = false

    private var scanTask: Task<Void, Never>?

    func scan(url: URL) {
        scanTask?.cancel()
        entries = []
        totalBytes = 0
        isLoading = true

        scanTask = Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
            guard let contents = try? fm.contentsOfDirectory(
                at: url, includingPropertiesForKeys: keys, options: []
            ) else {
                await MainActor.run { self.isLoading = false }
                return
            }

            var results: [(URL, Int64, Bool)] = []
            for item in contents {
                guard !Task.isCancelled else { return }
                let vals = try? item.resourceValues(forKeys: Set(keys))
                let isDir = vals?.isDirectory ?? false
                let size: Int64 = isDir
                    ? Self.directorySize(url: item, fm: fm)
                    : Int64(vals?.fileSize ?? 0)
                results.append((item, size, isDir))
            }

            guard !Task.isCancelled else { return }
            let total = results.reduce(0) { $0 + $1.1 }
            let topEntries = results
                .sorted { $0.1 > $1.1 }
                .prefix(15)
                .map { Entry(id: $0.0, name: $0.0.lastPathComponent, url: $0.0, bytes: $0.1, isDirectory: $0.2) }

            await MainActor.run { [weak self] in
                self?.entries = topEntries
                self?.totalBytes = total
                self?.isLoading = false
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        isLoading = false
    }

    private nonisolated static func directorySize(url: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey], options: []
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { return total }
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
