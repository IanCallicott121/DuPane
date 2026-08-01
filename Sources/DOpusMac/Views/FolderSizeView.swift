import SwiftUI

struct FolderSizeView: View {
    @StateObject private var viewModel = FolderSizeViewModel()
    let folderURL: URL
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Folder Sizes")
                        .font(.headline)
                    Text(folderURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if viewModel.totalBytes > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: viewModel.totalBytes, countStyle: .file))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
                Button("Done", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            if viewModel.isLoading && viewModel.entries.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Scanning…").foregroundStyle(.secondary).font(.callout)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if viewModel.entries.isEmpty {
                Spacer()
                Text("Folder is empty")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let maxBytes = viewModel.entries.first?.bytes ?? 1
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(viewModel.entries) { entry in
                            SizeRow(entry: entry, maxBytes: maxBytes, totalBytes: viewModel.totalBytes)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 480, height: 380)
        .onAppear { viewModel.scan(url: folderURL) }
        .onDisappear { viewModel.cancel() }
    }
}

private struct SizeRow: View {
    let entry: FolderSizeViewModel.Entry
    let maxBytes: Int64
    let totalBytes: Int64

    var fraction: CGFloat {
        maxBytes > 0 ? CGFloat(entry.bytes) / CGFloat(maxBytes) : 0
    }
    var percent: String {
        guard totalBytes > 0 else { return "" }
        let pct = Int((Double(entry.bytes) / Double(totalBytes)) * 100)
        return "\(pct)%"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 11))
                .foregroundStyle(entry.isDirectory ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: 14)
            Text(entry.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(width: 148, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.65))
                        .frame(width: max(3, geo.size.width * fraction))
                }
            }
            .frame(height: 14)
            Text(percent)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            Text(ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}
