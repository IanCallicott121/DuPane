import SwiftUI
import AppKit

struct SidebarView: View {
    static let width: CGFloat = 180

    @ObservedObject var model: SidebarModel
    let onNavigate: (URL) -> Void
    @State private var hoveredBookmark: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.bookmarks.isEmpty {
                sectionHeader("Bookmarks")
                List {
                    ForEach(model.bookmarks, id: \.self) { url in
                        bookmarkRow(url: url)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { from, to in
                        model.moveBookmark(from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(model.bookmarks.count) * 28)
                .background(Color.clear)
            }
            Spacer()
        }
        .frame(width: Self.width)
        .background(Color(NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.18, alpha: 1)
                : NSColor(white: 0.955, alpha: 1)
        })))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func bookmarkRow(url: URL) -> some View {
        let name = url.lastPathComponent
        return HStack(spacing: 6) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(Color.accentColor.opacity(0.7))
            Text(name)
                .lineLimit(1)
            Spacer(minLength: 2)
            // Remove × button — appears on hover
            Button {
                model.removeBookmark(url)
                if hoveredBookmark == url { hoveredBookmark = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .opacity(hoveredBookmark == url ? 1 : 0)
            .animation(.easeInOut(duration: 0.12), value: hoveredBookmark == url)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            let resolved = (try? URL(resolvingAliasFileAt: url)) ?? url
            let isDir = (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            if isDir {
                onNavigate(resolved)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        .onHover { isHovering in
            hoveredBookmark = isHovering ? url : nil
        }
        .contextMenu {
            Button("Remove Bookmark") { model.removeBookmark(url) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
    }
}
