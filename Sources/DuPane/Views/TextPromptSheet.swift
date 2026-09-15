import SwiftUI

struct TextPromptSheet: View {
    let title: String
    @Binding var text: String
    @FocusState private var nameFieldFocused: Bool
    var confirmLabel: String = "OK"
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            TextField("Name", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($nameFieldFocused)
                .accessibilityIdentifier("text-prompt-name-field")
                .onChange(of: nameFieldFocused) { focused in
                    if focused { TextFieldFocusSupport.selectAllCurrentEditor() }
                }
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
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                nameFieldFocused = true
            }
        }
    }
}
