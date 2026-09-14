import SwiftUI

struct TextPromptSheet: View {
    let title: String
    @Binding var text: String
    var confirmLabel: String = "OK"
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            TextField("Name", text: $text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("text-prompt-name-field")
                .onSubmit(onConfirm)
                .onPasteCommand(of: [.text]) { providers in
                    guard let provider = providers.first else { return }
                    provider.loadObject(ofClass: NSString.self) { value, _ in
                        guard let value = value as? NSString else { return }
                        DispatchQueue.main.async { text = value as String }
                    }
                }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .accessibilityIdentifier("text-prompt-cancel-button")
                Button(confirmLabel, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("text-prompt-confirm-button")
            }
        }
        .padding(20)
        .frame(width: 300)
        .onExitCommand(perform: onCancel)
    }
}
