import SwiftUI
import UniformTypeIdentifiers

struct DuplicateFinderView: View {
    @ObservedObject var viewModel: DuplicateFinderViewModel
    let rootURL: URL
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 680, height: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duplicate Finder")
                    .font(.headline)
                Text(rootURL.lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.phase == .scanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    if viewModel.filesToHash > 0 {
                        Text("Hashing \(viewModel.hashedFiles) of \(viewModel.filesToHash) files…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Scanning… \(viewModel.scannedFiles) items")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Cancel") { viewModel.cancel(); onDismiss() }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            Spacer()
        case .scanning:
            if viewModel.groups.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning for duplicates…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                groupList
            }
        case .done:
            if viewModel.groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text("No duplicates found")
                        .font(.headline)
                    Text("Scanned \(viewModel.scannedFiles) files in \(rootURL.lastPathComponent)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                groupList
            }
        }
    }

    // MARK: - Flat row model
    // Flatten groups into a single List so NSTableView can virtualize all rows.
    // Nested ForEach inside LazyVStack materialises every child view when the
    // parent row scrolls into view, causing AttributeGraph to exhaust its node budget.

    private var flatRows: [DuplicateRow] {
        var rows: [DuplicateRow] = []
        for (i, group) in viewModel.groups.enumerated() {
            let isResolved = group.count == 1
            rows.append(.header(groupIndex: i, fileName: group[0].lastPathComponent,
                                count: group.count, isResolved: isResolved))
            for url in group {
                rows.append(.file(groupIndex: i, url: url, isResolved: isResolved))
            }
        }
        return rows
    }

    private var groupList: some View {
        List(flatRows) { row in
            switch row {
            case .header(let gi, let name, let count, let resolved):
                DuplicateHeaderRow(
                    fileName: name, count: count, isResolved: resolved,
                    onKeepFirst: {
                        guard gi < viewModel.groups.count else { return }
                        for url in viewModel.groups[gi].dropFirst() {
                            viewModel.moveToTrash(url)
                        }
                    }
                )
                .listRowBackground(resolved
                    ? Color.green.opacity(0.08)
                    : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                .listRowSeparator(.hidden)

            case .file(_, let url, let resolved):
                DuplicateFileRow(url: url, isResolved: resolved) {
                    viewModel.moveToTrash(url)
                }
                .listRowBackground(Color(nsColor: .controlBackgroundColor))
                .listRowSeparator(.visible, edges: .bottom)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if viewModel.phase == .done, !viewModel.groups.isEmpty {
                Text("\(viewModel.totalDuplicateCount) duplicate\(viewModel.totalDuplicateCount == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: viewModel.totalWastedBytes, countStyle: .file)) wasted")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if viewModel.phase == .done {
                Text("Scan complete — \(viewModel.scannedFiles) files checked")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Row types

private enum DuplicateRow: Identifiable {
    case header(groupIndex: Int, fileName: String, count: Int, isResolved: Bool)
    case file(groupIndex: Int, url: URL, isResolved: Bool)

    var id: String {
        switch self {
        case .header(let i, _, _, _): return "h\(i)"
        case .file(let i, let url, _): return "f\(i)\(url.path)"
        }
    }
}

// MARK: - Row views (separate structs = isolated type-checker contexts)

private struct DuplicateHeaderRow: View {
    let fileName: String
    let count: Int
    let isResolved: Bool
    let onKeepFirst: () -> Void

    var body: some View {
        HStack {
            if isResolved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("kept")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(count) copies")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text("·")
                .foregroundStyle(.secondary)
            Text(fileName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if !isResolved {
                Button("Keep First", action: onKeepFirst)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DuplicateFileRow: View {
    let url: URL
    let isResolved: Bool
    let onTrash: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: fileIcon)
                .resizable()
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if !isResolved {
                Button(action: onTrash) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help("Move to Trash")
            }
        }
        .padding(.vertical, 3)
    }

    // Look up by UTType (extension only) — no filesystem stat, safe to call per-render.
    private var fileIcon: NSImage {
        let utType = UTType(filenameExtension: url.pathExtension) ?? .data
        return NSWorkspace.shared.icon(for: utType)
    }
}
