import AppKit
import QuickLookUI

/// Manages the Quick Look panel as its data source.
/// All public methods must be called from the main thread.
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookCoordinator()
    private override init() { super.init() }

    // Written from main thread (show/toggle), read from QL panel callbacks (also main thread).
    var previewURLs: [URL] = []

    @MainActor
    func show(urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        previewURLs = urls
        panel.dataSource = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor
    func toggle(urls: [URL]) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show(urls: urls)
        }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        previewURLs[index] as NSURL
    }
}
