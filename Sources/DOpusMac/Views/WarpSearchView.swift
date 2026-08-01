import SwiftUI

struct WarpSearchView: View {
    @ObservedObject var viewModel: WarpSearchViewModel
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                warpTextField
                if !viewModel.query.isEmpty {
                    Button { viewModel.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if !viewModel.results.isEmpty {
                Divider().opacity(0.5)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { idx, result in
                                resultRow(result, idx: idx)
                                    .id(idx)
                                    .onTapGesture { onSelect(result.url) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 330)
                    .onChange(of: viewModel.selectedIndex, perform: { idx in
                        withAnimation(.none) { proxy.scrollTo(idx, anchor: .center) }
                    })
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 28, y: 10)
        .frame(width: 500)
        .onAppear {
            // Delay one run-loop cycle so the view is in the window hierarchy before
            // requesting focus — @FocusState can silently fail if set synchronously
            // in a ZStack overlay before the host view is fully committed.
            DispatchQueue.main.async { fieldFocused = true }
        }
        .background {
            // Arrow key navigation and confirmation via hidden buttons
            Group {
                Button("Down") { viewModel.moveSelection(by: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Up") { viewModel.moveSelection(by: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("Escape") { onDismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var warpTextField: some View {
        TextField("Jump to folder…", text: $viewModel.query)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .focused($fieldFocused)
            .onSubmit {
                if let r = viewModel.selectedResult { onSelect(r.url) }
            }
    }

    private func resultRow(_ result: WarpSearchViewModel.WarpResult, idx: Int) -> some View {
        let isSelected = idx == viewModel.selectedIndex
        return HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color.primary)
                    .lineLimit(1)
                Text(result.subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }
}
