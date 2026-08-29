import Foundation

enum PaneStatusFormatter {
    static func text(itemCount: Int, selectedCount: Int, selectedBytes: Int64, isFiltered: Bool = false) -> String {
        var text = "\(itemCount) item\(itemCount == 1 ? "" : "s")"
        if isFiltered { text += " (filtered)" }
        if selectedCount > 0 {
            text += ", \(selectedCount) selected"
            if selectedBytes > 0 {
                text += " (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))"
            }
        }
        return text
    }
}
