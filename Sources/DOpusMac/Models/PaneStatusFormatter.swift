import Foundation

enum PaneStatusFormatter {
    static func text(itemCount: Int, selectedCount: Int, selectedBytes: Int64) -> String {
        var text = "\(itemCount) item\(itemCount == 1 ? "" : "s")"
        if selectedCount > 0 {
            text += ", \(selectedCount) selected"
            if selectedBytes > 0 {
                text += " (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))"
            }
        }
        return text
    }
}
