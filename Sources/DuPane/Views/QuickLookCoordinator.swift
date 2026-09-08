import AppKit
import QuickLookUI

/// Manages the Quick Look panel as its data source.
/// All public methods must be called from the main thread.
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource {
    enum ToggleAction: Equatable { case hide, show }

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
        if Self.toggleAction(
            isVisible: panel.isVisible,
            currentURLs: previewURLs,
            requestedURLs: urls
        ) == .hide {
            panel.orderOut(nil)
        } else {
            show(urls: urls)
        }
    }

    static func toggleAction(
        isVisible: Bool,
        currentURLs: [URL],
        requestedURLs: [URL]
    ) -> ToggleAction {
        isVisible && currentURLs == requestedURLs ? .hide : .show
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard index < previewURLs.count else { return nil }
        return previewURLs[index] as NSURL
    }
}
