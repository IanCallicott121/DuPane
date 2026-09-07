import SwiftUI
import AppKit

struct FileRowView: View {
    static let minimumHitHeight: CGFloat = 28
    static let minimumNameWidth: CGFloat = 140

    let item: FileItem
    let side: PaneSide
    let accentColor: Color
    let columnWidths: [String: CGFloat]
    var isSelected: Bool = false
    var extraInfo: String? = nil
    var compareStatus: FolderCompareStatus? = nil

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let fs = CGFloat(settings.listFontSize)
        let fsMeta = CGFloat(max(10, settings.listFontSize - 1))
        let fsInfo = CGFloat(max(9, settings.listFontSize - 2))
        let rowHeight = max(Self.minimumHitHeight, fs + 16)
        let showIcon = !settings.hiddenColumns.contains("Icon")

        return HStack(spacing: 8) {
            if showIcon {
                iconView.frame(width: 20)
            }
            // Tag dots live inside the name column so metadata columns stay pixel-aligned with the header.
            HStack(spacing: 0) {
                Text(displayName)
                    .font(.system(size: fs))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                if !item.tags.isEmpty {
                    Spacer(minLength: 6)
                    tagDots
                }
                if let compareStatus {
                    Spacer(minLength: 6)
                    compareBadge(for: compareStatus)
                }
            }
            .frame(minWidth: Self.minimumNameWidth, maxWidth: .infinity, alignment: .leading)
            metadataColumns(fsMeta: fsMeta, fsInfo: fsInfo)
        }
        .padding(.horizontal, FileColumnLayout.horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if let compareStatus {
                Rectangle()
                    .fill(compareColor(for: compareStatus))
                    .frame(width: 3)
                    .padding(.vertical, 3)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            accentColor.opacity(0.16)
        } else if let compareStatus {
            compareColor(for: compareStatus).opacity(0.11)
        } else {
            Color.clear
        }
    }

    private func metadataColumns(fsMeta: CGFloat, fsInfo: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(visibleColumns, id: \.self) { col in
                Color.clear
                    .frame(width: FileColumnLayout.resizeHandleWidth, height: 1)
                columnContent(col, fsMeta: fsMeta, fsInfo: fsInfo)
            }
        }
    }

    @ViewBuilder
    private func columnContent(_ name: String, fsMeta: CGFloat, fsInfo: CGFloat) -> some View {
        switch name {
        case "Size":
            columnCell(name, alignment: .trailing) {
                Text(item.isDirectory ? "—" : Self.formatSize(item.size))
                    .font(.system(size: fsMeta, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "Kind":
            columnCell(name, alignment: .leading) {
                Text(item.kind)
                    .font(.system(size: fsMeta, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        case "Modified":
            columnCell(name, alignment: .leading) {
                Text(Self.formatDate(item.modified, style: settings.dateFormatStyle, timeStyle: settings.timeFormatStyle))
                    .font(.system(size: fsMeta, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "Info":
            columnCell(name, alignment: .trailing) {
                Text(extraInfo ?? "")
                    .font(.system(size: fsInfo, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
            }
        default:
            EmptyView()
        }
    }

    private func columnCell<Content: View>(
        _ name: String,
        alignment: Alignment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.leading, FileColumnLayout.contentLeadingInset)
            .frame(width: columnWidth(for: name), alignment: alignment)
            .clipped()
    }

    private func columnWidth(for name: String) -> CGFloat {
        columnWidths[name, default: FileColumnLayout.defaultWidth(for: name)]
    }

    private var visibleColumns: [String] {
        settings.columnOrder.filter { !settings.hiddenColumns.contains($0) }
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
            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0.5)
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

    private func compareBadge(for status: FolderCompareStatus) -> some View {
        Text(compareLabel(for: status))
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(compareColor(for: status))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(compareColor(for: status).opacity(0.14), in: Capsule())
            .lineLimit(1)
    }

    private func compareLabel(for status: FolderCompareStatus) -> String {
        switch status {
        case .same:
            return "same"
        case .onlyLeft, .onlyRight:
            return "only here"
        case .newerLeft:
            return side == .left ? "newer" : "older"
        case .newerRight:
            return side == .right ? "newer" : "older"
        case .different:
            return "different"
        }
    }

    private func compareColor(for status: FolderCompareStatus) -> Color {
        switch status {
        case .same:
            return .secondary
        case .onlyLeft, .onlyRight:
            return .orange
        case .newerLeft:
            return side == .left ? .green : .red
        case .newerRight:
            return side == .right ? .green : .red
        case .different:
            return .purple
        }
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

    private static let dateFormatterShort: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yy"; return f
    }()
    private static let dateFormatterMedium: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }()
    private static let dateFormatterLong: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none; return f
    }()
    private static let dateFormatterISO: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let timeFormatter12h: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
    private static let timeFormatter12hSec: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm:ss a"; return f
    }()
    private static let timeFormatter24h: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let timeFormatter24hSec: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func formatDate(_ date: Date?, style: DateFormatStyle = .medium, timeStyle: TimeFormatStyle = .none) -> String {
        guard let date else { return "—" }
        let timeSuffix: String = {
            switch timeStyle {
            case .none: return ""
            case .twelve: return " " + timeFormatter12h.string(from: date)
            case .twelveWithSeconds: return " " + timeFormatter12hSec.string(from: date)
            case .twentyFour: return " " + timeFormatter24h.string(from: date)
            case .withSeconds: return " " + timeFormatter24hSec.string(from: date)
            }
        }()
        switch style {
        case .short:
            return dateFormatterShort.string(from: date) + timeSuffix
        case .medium:
            return dateFormatterMedium.string(from: date) + timeSuffix
        case .long:
            return dateFormatterLong.string(from: date) + timeSuffix
        case .iso:
            return dateFormatterISO.string(from: date) + timeSuffix
        case .relative:
            let cal = Calendar.current
            if cal.isDateInToday(date) { return "Today\(timeSuffix)" }
            if cal.isDateInYesterday(date) { return "Yesterday\(timeSuffix)" }
            let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days < 7 { return "\(days)d ago" }
            if days < 30 { return "\(days / 7)w ago" }
            let months = cal.dateComponents([.month], from: date, to: Date()).month ?? 0
            if months < 12 { return "\(months)mo ago" }
            return "\(months / 12)y ago"
        }
    }
}
