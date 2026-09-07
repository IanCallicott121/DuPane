import Foundation
import SwiftUI

@MainActor
final class DuplicateFinderViewModel: ObservableObject {
    enum Phase { case idle, scanning, done }

    @Published var phase: Phase = .idle
    @Published var groups: [[URL]] = []
    @Published var scannedFiles: Int = 0
    @Published var hashedFiles: Int = 0
    @Published var filesToHash: Int = 0
    @Published var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private let trash: ([URL]) -> FileOperationResult

    var totalDuplicateCount: Int { groups.reduce(0) { $0 + $1.count - 1 } }
    var totalWastedBytes: Int64 = 0

    init(trash: @escaping ([URL]) -> FileOperationResult = { FileOperationService.trash(urls: $0) }) {
        self.trash = trash
    }

    func startScan(at rootURL: URL) {
        scanTask?.cancel()
        phase = .scanning
        groups = []
        scannedFiles = 0
        hashedFiles = 0
        filesToHash = 0
        totalWastedBytes = 0
        errorMessage = nil

        let vm = self
        scanTask = Task.detached(priority: .userInitiated) {
            let result = await DuplicateFinderViewModel.scan(
                rootURL: rootURL,
                onScanProgress: { count in
                    Task { @MainActor in vm.scannedFiles = count }
                },
                onHashStart: { total in
                    Task { @MainActor in vm.filesToHash = total; vm.hashedFiles = 0 }
                },
                onHashProgress: { count in
                    Task { @MainActor in vm.hashedFiles = count }
                }
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                vm.groups = result.groups
                vm.totalWastedBytes = result.wastedBytes
                vm.phase = .done
            }
        }
    }

    func moveToTrash(_ url: URL) {
        let result = trash([url])
        guard result.hasSucceeded else {
            errorMessage = result.lastError ?? "Couldn't move \(url.lastPathComponent) to Trash."
            return
        }
        groups = groups.compactMap { group in
            let remaining = group.filter { $0 != url }
            return remaining.count > 1 ? remaining : nil
        }
    }

    func cancel() {
        scanTask?.cancel()
        phase = .idle
    }

    private struct ScanResult {
        var groups: [[URL]]
        var wastedBytes: Int64
    }

    private static func scan(
        rootURL: URL,
        onScanProgress: @escaping (Int) -> Void,
        onHashStart: @escaping (Int) -> Void,
        onHashProgress: @escaping (Int) -> Void
    ) async -> ScanResult {
        var sizeMap: [Int64: [URL]] = [:]
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return ScanResult(groups: [], wastedBytes: 0)
        }

        var visited = 0   // all items (files + dirs) — drives the progress counter
        var scanned = 0   // regular files only — reported as the final count
        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { return ScanResult(groups: [], wastedBytes: 0) }
            visited += 1
            if visited % 100 == 0 { onScanProgress(visited) }
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { continue }
            // Skip symlinks and don't descend into them — prevents /Volumes/MacintoshHD → / cycles
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true, let size = values.fileSize, size > 0 else { continue }
            sizeMap[Int64(size), default: []].append(item)
            scanned += 1
        }
        onScanProgress(scanned)

        // Hash only files that share a size (vastly reduces hashing work).
        // Reads in 1 MB chunks to avoid loading entire large files into memory.
        let candidateURLs = sizeMap.values.filter { $0.count > 1 }.flatMap { $0 }
        onHashStart(candidateURLs.count)

        var hashMap: [String: [URL]] = [:]
        var hashed = 0
        for (_, urls) in sizeMap where urls.count > 1 {
            if Task.isCancelled { return ScanResult(groups: [], wastedBytes: 0) }
            for url in urls {
                guard let hash = fnv1a64(url: url) else { continue }
                hashMap[hash, default: []].append(url)
                hashed += 1
                if hashed % 5 == 0 { onHashProgress(hashed) }
            }
        }
        onHashProgress(hashed)

        var wastedBytes: Int64 = 0

        let allGroups: [[URL]] = hashMap.values.flatMap { urls in
            verifiedDuplicateGroups(for: urls)
        }.map { group in
            let sorted = group.sorted { $0.path < $1.path }
            if let size = try? sorted[0].resourceValues(forKeys: [.fileSizeKey]).fileSize {
                wastedBytes += Int64(size) * Int64(sorted.count - 1)
            }
            return sorted
        }.sorted { $0[0].lastPathComponent < $1[0].lastPathComponent }

        return ScanResult(groups: allGroups, wastedBytes: wastedBytes)
    }

    nonisolated static func verifiedDuplicateGroups(for urls: [URL]) -> [[URL]] {
        let sorted = urls.sorted { $0.path < $1.path }
        var groups: [[URL]] = []

        for url in sorted {
            if let index = groups.firstIndex(where: { filesHaveSameContents(url, $0[0]) }) {
                groups[index].append(url)
            } else {
                groups.append([url])
            }
        }

        return groups.filter { $0.count > 1 }
    }

    nonisolated static func filesHaveSameContents(_ first: URL, _ second: URL) -> Bool {
        guard first != second else { return true }
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        guard let firstSize = try? first.resourceValues(forKeys: keys).fileSize,
              let secondSize = try? second.resourceValues(forKeys: keys).fileSize,
              firstSize == secondSize,
              let firstHandle = try? FileHandle(forReadingFrom: first),
              let secondHandle = try? FileHandle(forReadingFrom: second) else {
            return false
        }
        defer {
            try? firstHandle.close()
            try? secondHandle.close()
        }

        while true {
            if Task.isCancelled { return false }
            let firstChunk = firstHandle.readData(ofLength: 1024 * 1024)
            let secondChunk = secondHandle.readData(ofLength: 1024 * 1024)
            guard firstChunk == secondChunk else { return false }
            if firstChunk.isEmpty { return true }
        }
    }

    // FNV-1a 64-bit hash — reads in 1 MB chunks so large files don't load entirely into RAM.
    private static func fnv1a64(url: URL) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        var hash: UInt64 = 14695981039346656037
        while true {
            if Task.isCancelled { return nil }
            let chunk = fh.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            for byte in chunk {
                hash ^= UInt64(byte)
                hash = hash &* 1099511628211
            }
        }
        return String(hash, radix: 16, uppercase: false)
    }
}
