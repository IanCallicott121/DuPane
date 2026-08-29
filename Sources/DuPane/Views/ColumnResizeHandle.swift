import SwiftUI
import AppKit

final class ColumnResizeNSView: NSView {
    private static var anyIsDragging = false
    private(set) var isDragging = false
    var columnWidth: CGFloat = 74
    var resizesFromLeadingEdge = false
    var onWidthChange: (CGFloat) -> Void = { _ in }

    private var dragStartWindowX: CGFloat = 0
    private var dragStartWidth: CGFloat = 0
    private var lastSentWidth: CGFloat = 0
    private var thresholdMet = false
    private var dragCursor: NSCursor?
    private var dragCursorMonitor: Any?
    private var didPushDragCursor = false
    private weak var cursorRectsDisabledWindow: NSWindow?

    private static let dragThreshold: CGFloat = 3

    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(rect: CGRect(
            x: (bounds.width - 1) / 2,
            y: (bounds.height - 14) / 2,
            width: 1,
            height: 14
        )).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .enabledDuringMouseDrag, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func resetCursorRects() {
        discardCursorRects()
        guard !isDragging else { return }
        addCursorRect(bounds, cursor: appropriateCursor)
    }

    override func mouseEntered(with event: NSEvent) {
        activeCursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        guard !ColumnResizeNSView.anyIsDragging else { return }
        NSCursor.arrow.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        activeCursor.set()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        ColumnResizeNSView.anyIsDragging = true
        thresholdMet = false
        dragStartWindowX = event.locationInWindow.x
        dragStartWidth = columnWidth
        lastSentWidth = columnWidth.rounded()

        let cursor = appropriateCursor
        dragCursor = cursor
        cursorRectsDisabledWindow = window
        window?.disableCursorRects()
        cursor.push()
        didPushDragCursor = true
        cursor.set()

        dragCursorMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .cursorUpdate]) { [weak self] e in
            self?.dragCursor?.set()
            return e
        }
    }

    override func mouseDragged(with event: NSEvent) {
        defer { dragCursor?.set() }

        let delta = event.locationInWindow.x - dragStartWindowX
        guard thresholdMet || abs(delta) >= Self.dragThreshold else { return }
        thresholdMet = true
        let directionalDelta = resizesFromLeadingEdge ? -delta : delta
        let newWidth = (dragStartWidth + directionalDelta)
            .clamped(to: FileColumnLayout.minWidth...FileColumnLayout.maxWidth)
            .rounded()
        guard abs(newWidth - lastSentWidth) >= 1 else { return }
        lastSentWidth = newWidth
        onWidthChange(newWidth)
    }

    override func mouseUp(with event: NSEvent) {
        finishDragging()
    }

    deinit {
        finishDragging()
    }

    private func finishDragging() {
        guard isDragging else { return }

        isDragging = false
        ColumnResizeNSView.anyIsDragging = false
        thresholdMet = false
        if let monitor = dragCursorMonitor {
            NSEvent.removeMonitor(monitor)
            dragCursorMonitor = nil
        }
        if didPushDragCursor {
            NSCursor.pop()
            didPushDragCursor = false
        }

        let disabledWindow = cursorRectsDisabledWindow ?? window
        disabledWindow?.enableCursorRects()
        if let window = disabledWindow {
            window.invalidateCursorRects(for: self)
            let mouseInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            let mouseInView = convert(mouseInWindow, from: nil)
            if bounds.contains(mouseInView) {
                appropriateCursor.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        cursorRectsDisabledWindow = nil
        dragCursor = nil
    }

    private var activeCursor: NSCursor {
        dragCursor ?? appropriateCursor
    }

    private var appropriateCursor: NSCursor {
        let atMin = columnWidth <= FileColumnLayout.minWidth + 1
        let atMax = columnWidth >= FileColumnLayout.maxWidth - 1
        if atMin && !atMax {
            return resizesFromLeadingEdge ? .resizeLeft : .resizeRight
        } else if atMax && !atMin {
            return resizesFromLeadingEdge ? .resizeRight : .resizeLeft
        } else {
            return .resizeLeftRight
        }
    }
}

struct ColumnResizeHandle: NSViewRepresentable {
    let currentWidth: CGFloat
    let resizesFromLeadingEdge: Bool
    let onResize: (CGFloat) -> Void

    init(
        currentWidth: CGFloat,
        resizesFromLeadingEdge: Bool = false,
        onResize: @escaping (CGFloat) -> Void
    ) {
        self.currentWidth = currentWidth
        self.resizesFromLeadingEdge = resizesFromLeadingEdge
        self.onResize = onResize
    }

    func makeNSView(context: Context) -> ColumnResizeNSView {
        let view = ColumnResizeNSView()
        view.columnWidth = currentWidth
        view.resizesFromLeadingEdge = resizesFromLeadingEdge
        view.onWidthChange = onResize
        return view
    }

    func updateNSView(_ nsView: ColumnResizeNSView, context: Context) {
        nsView.onWidthChange = onResize
        nsView.resizesFromLeadingEdge = resizesFromLeadingEdge
        if !nsView.isDragging {
            nsView.columnWidth = currentWidth
            nsView.window?.invalidateCursorRects(for: nsView)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
