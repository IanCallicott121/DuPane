import SwiftUI
import AppKit

struct PropertiesView: View {
    let item: FileItem
    let onDismiss: () -> Void

    @State private var createdDate: Date? = nil
    @State private var fileSize: Int64? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — icon + name
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Text(item.isDirectory ? "Folder" : item.kind)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 12)

            // Metadata rows
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Path", item.url.path)
                if !item.isDirectory {
                    let sizeValue = fileSize ?? item.size
                    infoRow("Size", sizeValue.map { FileRowView.formatSize($0) } ?? "—")
                }
                infoRow("Modified", item.modified.map { Self.formatDateTime($0) } ?? "—")
                if let created = createdDate {
                    infoRow("Created", Self.formatDateTime(created))
                }
                if !item.tags.isEmpty {
                    tagRow
                }
            }

            Spacer(minLength: 20)

            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { loadMetadata() }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(4)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private var tagRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Tags")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .trailing)
            HStack(spacing: 6) {
                ForEach(item.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(finderTagColor(tag))
                            .frame(width: 9, height: 9)
                        Text(tag)
                            .font(.system(size: 12))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func loadMetadata() {
        let url = item.url
        Task.detached {
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey, .totalFileSizeKey])
            let created = values?.creationDate
            let size = values?.fileSize.map { Int64($0) } ?? values?.totalFileSize.map { Int64($0) }
            await MainActor.run {
                createdDate = created
                if let size { fileSize = size }
            }
        }
    }

    private static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func finderTagColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "red":           return .red
        case "orange":        return .orange
        case "yellow":        return .yellow
        case "green":         return .green
        case "blue":          return .blue
        case "purple":        return .purple
        case "gray", "grey":  return .gray
        default:              return .accentColor
        }
    }
}
