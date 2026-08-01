import SwiftUI
import AppKit

struct FileRowView: View {
    static let minimumHitHeight: CGFloat = 28
    static let minimumNameWidth: CGFloat = 140

    let item: FileItem
    let accentColor: Color
    var isSelected: Bool = false
    var extraInfo: String? = nil

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            iconView.frame(width: 20)
            Text(displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: Self.minimumNameWidth, alignment: .leading)
            if !item.tags.isEmpty {
                tagDots
            }
            Spacer(minLength: 8)
            if !settings.hiddenColumns.contains("Size") {
                Text(item.isDirectory ? "—" : Self.formatSize(item.size))
                    .frame(width: 74, alignment: .trailing)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if !settings.hiddenColumns.contains("Kind") {
                Text(item.kind)
                    .frame(width: 120, alignment: .leading)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if !settings.hiddenColumns.contains("Modified") {
                Text(Self.formatDate(item.modified))
                    .frame(width: 92, alignment: .leading)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if !settings.hiddenColumns.contains("Info") {
                Text(extraInfo ?? "")
                    .frame(width: 80, alignment: .trailing)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: Self.minimumHitHeight, alignment: .leading)
        .background(isSelected ? accentColor.opacity(0.16) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: - Display name

    private var displayName: String {
        guard !settings.showFileExtensions,
              !item.isDirectory,
              !item.fileExtension.isEmpty else {
            return item.name
        }
        return item.url.deletingPathExtension().lastPathComponent
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconView: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: 16, height: 16)
            .overlay(alignment: .bottomTrailing) {
                if item.isRestricted {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(1.5)
                        .background(Circle().fill(Color.red))
                        .offset(x: 3, y: 3)
                }
            }
    }

    // MARK: - Tag dots

    private var tagDots: some View {
        HStack(spacing: 2) {
            ForEach(item.tags.prefix(4), id: \.self) { tag in
                Circle()
                    .fill(Self.finderTagColor(tag))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel(item.tags.prefix(4).joined(separator: ", "))
    }

    // MARK: - Helpers

    private static func finderTagColor(_ name: String) -> Color {
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

    static func formatSize(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
