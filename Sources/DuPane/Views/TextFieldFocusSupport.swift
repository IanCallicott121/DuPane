import AppKit

@MainActor
enum TextFieldFocusSupport {
    static func selectAllCurrentEditor() {
        DispatchQueue.main.async {
            guard let responder = NSApp.keyWindow?.firstResponder else { return }

            if let editor = responder as? NSTextView {
                editor.selectAll(nil)
            } else if let textField = responder as? NSTextField {
                textField.currentEditor()?.selectAll(nil)
            }
        }
    }
}
