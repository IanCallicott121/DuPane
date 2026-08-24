import SwiftUI

struct CustomActionsSettingsView: View {
    @ObservedObject var model: CustomActionsModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID? = nil
    @State private var editName = ""
    @State private var editCommand = ""
    @State private var isEditingExisting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actions")
                        .font(.headline)
                    Text("Actions appear in the right-click context menu. Use **$@** for selected file paths, **$PWD** for the current folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // +/- toolbar (above the list)
                HStack(spacing: 0) {
                    Button {
                        selectedID = nil
                        isEditingExisting = false
                        editName = ""
                        editCommand = ""
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("New action")

                    Divider().frame(height: 14)

                    Button {
                        guard let id = selectedID,
                              let index = model.actions.firstIndex(where: { $0.id == id })
                        else { return }
                        model.remove(at: IndexSet(integer: index))
                        selectedID = nil
                        isEditingExisting = false
                        editName = ""
                        editCommand = ""
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedID == nil)
                    .help("Remove selected action")

                    Spacer()
                }
                .frame(height: 24)
                .background(Color(nsColor: .underPageBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                // Action list
                List(model.actions, id: \.id, selection: $selectedID) { action in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(action.command)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                    .tag(action.id)
                }
                .listStyle(.bordered)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .onChange(of: selectedID, perform: { id in
                    if let id, let action = model.actions.first(where: { $0.id == id }) {
                        editName = action.name
                        editCommand = action.command
                        isEditingExisting = true
                    } else {
                        isEditingExisting = false
                    }
                })

                // Add / Edit form
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditingExisting ? "Edit Action" : "New Action")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        TextField("Name", text: $editName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        TextField("Shell command  (e.g. open -a BBEdit \"$@\")", text: $editCommand)
                            .textFieldStyle(.roundedBorder)

                        if isEditingExisting {
                            Button("Save") {
                                guard let id = selectedID else { return }
                                let n = editName.trimmingCharacters(in: .whitespaces)
                                let c = editCommand.trimmingCharacters(in: .whitespaces)
                                guard !n.isEmpty, !c.isEmpty else { return }
                                model.update(id: id, name: n, command: c)
                                selectedID = nil
                                editName = ""
                                editCommand = ""
                            }
                            .disabled(
                                editName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                editCommand.trimmingCharacters(in: .whitespaces).isEmpty
                            )

                            Button("Cancel") {
                                selectedID = nil
                                isEditingExisting = false
                                editName = ""
                                editCommand = ""
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        } else {
                            Button("Add") {
                                let n = editName.trimmingCharacters(in: .whitespaces)
                                let c = editCommand.trimmingCharacters(in: .whitespaces)
                                guard !n.isEmpty, !c.isEmpty else { return }
                                model.add(name: n, command: c)
                                editName = ""
                                editCommand = ""
                            }
                            .disabled(
                                editName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                editCommand.trimmingCharacters(in: .whitespaces).isEmpty
                            )
                        }
                    }
                }
            }
            .padding(16)

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 580, height: 380)
    }
}
