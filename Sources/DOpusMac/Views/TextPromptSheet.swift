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
                .onSubmit(onConfirm)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button(confirmLabel, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
