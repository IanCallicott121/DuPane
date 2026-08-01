import AppKit
import SwiftUI

enum RowMouseEventAction: Equatable {
    case select
    case open
}

enum RowMouseEventPolicy {
    static func actions(clickCount: Int, buttonNumber: Int) -> [RowMouseEventAction] {
        guard buttonNumber == 0 else { return [] }
        if clickCount == 1 {
            return [.select]
        } else {
            return [.select, .open]
        }
    }
}

struct RowMouseEventView: NSViewRepresentable {
    let onSelect: () -> Void
    let onOpen: () -> Void
    var isSelected: Bool = false
    var getDragItems: (() -> [FileItem])? = nil

    func makeNSView(context: Context) -> RowMouseEventNSView {
        let view = RowMouseEventNSView()
        view.onSelect = onSelect
        view.onOpen = onOpen
        view.isSelected = isSelected
        view.getDragItems = getDragItems
        return view
    }

    func updateNSView(_ nsView: RowMouseEventNSView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onOpen = onOpen
        nsView.isSelected = isSelected
        nsView.getDragItems = getDragItems
    }
}

final class RowMouseEventNSView: NSView {
    var onSelect: (() -> Void)?
    var onOpen: (() -> Void)?
    var isSelected: Bool = false
    var getDragItems: (() -> [FileItem])? = nil

    private var mouseDownEvent: NSEvent?
    // When mouseDown lands on an already-selected item, defer onSelect to mouseUp
    // so that a drag can read the full multi-selection instead of a reset selection.
    private var mouseDownOnSelected: Bool = false

    // Drag session state
    private var activeDraggingSession: NSDraggingSession?
    private var activeDragURLs: [URL] = []
    private var lastDragCopyState: Bool = false
    private var flagsMonitor: Any? = nil

    // MARK: - Badge image

    private static let moveBadgeImage: NSImage = {
        let size = NSSize(width: 14, height: 14)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 14, height: 14)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 3, y: 5.5, width: 8, height: 3)).fill()
        img.unlockFocus()
        return img
    }()

    // Compose badge onto icon within a 32×32 canvas.
    private func dragImage(url: URL, showsMoveBadge: Bool) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let composite = NSImage(size: NSSize(width: 32, height: 32))
        composite.lockFocus()
        icon.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32))
        if showsMoveBadge {
            Self.moveBadgeImage.draw(in: NSRect(x: 18, y: 18, width: 14, height: 14))
        }
        composite.unlockFocus()
        return composite
    }

    // Update drag image badge when Option key state changes mid-drag.
    private func updateDragBadge(isCopy: Bool) {
        guard isCopy != lastDragCopyState else { return }
        lastDragCopyState = isCopy
        updateLiveDraggingImages(isCopy: isCopy)
    }

    private func updateLiveDraggingImages(isCopy: Bool) {
        guard let session = activeDraggingSession else { return }
        let leaderIndex = session.draggingLeaderIndex
        session.enumerateDraggingItems(
            options: [],
            for: nil,
            classes: [NSURL.self],
            searchOptions: [:]
        ) { [weak self] dragItem, index, _ in
            guard let self, index < activeDragURLs.count else { return }
            let showsMoveBadge = !isCopy && index == leaderIndex
            let image = dragImage(url: activeDragURLs[index], showsMoveBadge: showsMoveBadge)
            dragItem.setDraggingFrame(dragItem.draggingFrame, contents: image)
        }
    }

    // MARK: - Hit test

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard window?.currentEvent?.type == .leftMouseDown else { return nil }
        return super.hitTest(point)
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event

        if isSelected {
            // Defer selection change: the item is already selected, so a drag should
            // carry the full multi-selection. Fire onSelect in mouseUp instead.
            mouseDownOnSelected = true
        } else {
            for action in RowMouseEventPolicy.actions(clickCount: event.clickCount, buttonNumber: event.buttonNumber) {
                switch action {
                case .select: onSelect?()
                case .open:   onOpen?()
                }
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownOnSelected {
            // No drag occurred — apply the deferred selection/open now.
            for action in RowMouseEventPolicy.actions(clickCount: event.clickCount, buttonNumber: event.buttonNumber) {
                switch action {
                case .select: onSelect?()
                case .open:   onOpen?()
                }
            }
        }
        mouseDownOnSelected = false
        mouseDownEvent = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downEvent = mouseDownEvent,
              let items = getDragItems?(), !items.isEmpty else { return }

        let start = downEvent.locationInWindow
        let current = event.locationInWindow
        guard hypot(current.x - start.x, current.y - start.y) > 4 else { return }

        mouseDownOnSelected = false
        mouseDownEvent = nil

        DragSession.shared.items = items
        DragSession.shared.sourceDirectoryURL = items.first?.url.deletingLastPathComponent()

        let isCopy = currentCopyIntent(from: event)
        lastDragCopyState = isCopy
        DragSession.shared.copyIntentDidChange = { [weak self] isCopy in
            self?.updateDragBadge(isCopy: isCopy)
        }
        DragSession.shared.setCopyIntent(isCopy)
        activeDragURLs = items.prefix(10).map(\.url)

        let viewPoint = convert(event.locationInWindow, from: nil)
        let dragItems = items.prefix(10).enumerated().map { i, fileItem in
            let dragItem = NSDraggingItem(pasteboardWriter: fileItem.url as NSURL)
            let offset = CGFloat(i) * 2
            let frame = NSRect(x: viewPoint.x - 16 + offset, y: viewPoint.y - 16 - offset, width: 32, height: 32)
            let image = dragImage(url: fileItem.url, showsMoveBadge: !isCopy && i == 0)
            dragItem.setDraggingFrame(frame, contents: image)
            return dragItem
        }

        // Monitor Option key presses to swap the badge while dragging.
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateDragBadge(isCopy: DragSession.isOptionKeyPressed)
            return event
        }

        let session = beginDraggingSession(with: dragItems, event: event, source: self)
        session.draggingLeaderIndex = 0
        activeDraggingSession = session
    }
}

// MARK: - NSDraggingSource

extension RowMouseEventNSView: NSDraggingSource {
    private func currentCopyIntent(from event: NSEvent? = nil) -> Bool {
        let eventFlags = event?.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if eventFlags?.contains(.option) == true { return true }

        let currentFlags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if currentFlags?.contains(.option) == true { return true }

        return DragSession.isOptionKeyPressed
    }

    private func syncDragOperationFromModifierFlags() -> NSDragOperation {
        let isCopy = currentCopyIntent() || DragSession.shared.isCopy
        if isCopy != lastDragCopyState {
            updateDragBadge(isCopy: isCopy)
        } else {
            DragSession.shared.setCopyIntent(isCopy)
        }
        return isCopy ? .copy : .move
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        _ = syncDragOperationFromModifierFlags()
        return [.copy, .move]
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        _ = syncDragOperationFromModifierFlags()
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        activeDraggingSession = nil
        activeDragURLs = []
        lastDragCopyState = false

        // Reload source pane if files were accepted as a move by an external app.
        if operation == .move, let srcURL = DragSession.shared.sourceDirectoryURL {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .paneContentsChanged, object: nil,
                    userInfo: ["url": srcURL]
                )
            }
        }
        DragSession.shared.clear()
    }
}
