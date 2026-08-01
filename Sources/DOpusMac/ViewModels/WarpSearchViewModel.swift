import Foundation

@MainActor
final class WarpSearchViewModel: ObservableObject {
    struct WarpResult: Identifiable {
        let id = UUID()
        let url: URL
        let displayName: String
        let subtitle: String
        var score: Int
    }

    @Published var query: String = "" { didSet { filter() } }
    @Published var results: [WarpResult] = []
    @Published var selectedIndex: Int = 0

    private var allCandidates: [WarpResult] = []

    var selectedResult: WarpResult? {
        guard !results.isEmpty, selectedIndex < results.count else { return nil }
        return results[selectedIndex]
    }

    func configure(
        systemLocations: [(name: String, url: URL, icon: String)],
        bookmarks: [URL],
        openURLs: [URL]
    ) {
        var seen = Set<URL>()
        var candidates: [WarpResult] = []

        for loc in systemLocations where !seen.contains(loc.url) {
            seen.insert(loc.url)
            candidates.append(WarpResult(url: loc.url, displayName: loc.name, subtitle: loc.url.path, score: 100))
        }
        for url in bookmarks where !seen.contains(url) {
            seen.insert(url)
            candidates.append(WarpResult(url: url, displayName: url.lastPathComponent, subtitle: url.path, score: 80))
        }
        for url in openURLs.reversed() where !seen.contains(url) {
            seen.insert(url)
            candidates.append(WarpResult(url: url, displayName: url.lastPathComponent, subtitle: url.path, score: 60))
        }

        allCandidates = candidates
        filter()
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    private func filter() {
        selectedIndex = 0
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            results = Array(allCandidates.prefix(12))
            return
        }
        results = allCandidates.compactMap { candidate in
            let nameScore = subsequenceScore(q, in: candidate.displayName.lowercased())
            let pathScore = subsequenceScore(q, in: candidate.subtitle.lowercased())
            let best = max(nameScore ?? 0, pathScore.map { $0 / 2 } ?? 0)
            guard best > 0 else { return nil }
            let bonus = candidate.displayName.lowercased().hasPrefix(q) ? 50 : 0
            var r = candidate
            r.score = best + bonus
            return r
        }
        .sorted { $0.score > $1.score }
        .prefix(12)
        .map { $0 }
    }

    private func subsequenceScore(_ query: String, in text: String) -> Int? {
        var score = 0
        var qi = query.startIndex
        var ti = text.startIndex
        var consecutive = 0
        while qi < query.endIndex && ti < text.endIndex {
            if query[qi] == text[ti] {
                score += 10 + consecutive * 8
                consecutive += 1
                qi = query.index(after: qi)
            } else {
                consecutive = 0
            }
            ti = text.index(after: ti)
        }
        return qi == query.endIndex ? score : nil
    }
}
