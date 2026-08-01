import Foundation
import AVFoundation
import ImageIO

/// Asynchronously loads type-aware metadata (dimensions, duration, line count) for files.
/// Results are cached in-memory and keyed by URL.
@MainActor
final class SmartMetadataService: ObservableObject {
    static let shared = SmartMetadataService()
    private init() {}

    @Published private(set) var cache: [URL: String] = [:]
    private var pending: Set<URL> = []

    func info(for item: FileItem) -> String? { cache[item.url] }

    func loadIfNeeded(for items: [FileItem]) {
        for item in items where !item.isDirectory {
            guard cache[item.url] == nil, !pending.contains(item.url) else { continue }
            pending.insert(item.url)
            let url = item.url
            let ext = item.fileExtension
            Task.detached(priority: .background) {
                let result = await Self.compute(url: url, ext: ext)
                await MainActor.run {
                    self.pending.remove(url)
                    if let result { self.cache[url] = result }
                }
            }
        }
    }

    private static func compute(url: URL, ext: String) async -> String? {
        switch ext {
        case "jpg", "jpeg", "png", "heic", "gif", "bmp", "tiff", "tif", "webp", "avif":
            return imageDimensions(url: url)
        case "mp4", "mov", "m4v", "avi", "mkv", "mp3", "m4a", "aac", "flac", "wav", "aiff", "opus":
            return await mediaDuration(url: url)
        case "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "hpp", "java", "kt",
             "rb", "sh", "bash", "zsh", "fish", "css", "html", "xml", "json", "yaml", "yml", "toml":
            return lineCount(url: url)
        default:
            return nil
        }
    }

    private static func imageDimensions(url: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return "\(w) × \(h) px"
    }

    private static func mediaDuration(url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let dur = try? await asset.load(.duration) else { return nil }
        let s = CMTimeGetSeconds(dur)
        guard s.isFinite && s > 0 else { return nil }
        let t = Int(s)
        if t >= 3600 { return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60) }
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private static func lineCount(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let n = data.filter { $0 == UInt8(ascii: "\n") }.count + 1
        return "\(n) line\(n == 1 ? "" : "s")"
    }
}
