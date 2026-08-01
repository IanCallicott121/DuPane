import Foundation
import CoreGraphics
import AppKit
import Carbon.HIToolbox

// Holds the dragged FileItems for within-app drag-and-drop so the drop target
// doesn't need to re-parse NSItemProviders. Cleared after every session.
final class DragSession {
    static let shared = DragSession()
    private init() {}

    var items: [FileItem] = []
    var sourceDirectoryURL: URL? = nil
    var copyIntentDidChange: ((Bool) -> Void)?
    private(set) var isCopy: Bool = false

    func setCopyIntent(_ isCopy: Bool) {
        guard self.isCopy != isCopy else { return }
        self.isCopy = isCopy
        copyIntentDidChange?(isCopy)
    }

    static var isOptionKeyPressed: Bool {
        let appKitFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if appKitFlags.contains(.option) { return true }

        return CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
            || CGEventSource.flagsState(.hidSystemState).contains(.maskAlternate)
            || (Int(GetCurrentKeyModifiers()) & optionKey) != 0
    }

    func clear() {
        copyIntentDidChange = nil
        items = []
        sourceDirectoryURL = nil
        isCopy = false
    }
}
