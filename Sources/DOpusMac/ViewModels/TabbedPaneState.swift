import Foundation
import Combine

@MainActor
final class TabbedPaneState: ObservableObject {
    struct Tab: Identifiable {
        let id = UUID()
        let pane: PaneState
    }

    private(set) var tabs: [Tab]
    private(set) var activeTabIndex: Int = 0

    var showHiddenFiles: Bool = false {
        didSet {
            guard oldValue != showHiddenFiles else { return }
            tabs.forEach {
                $0.pane.showHiddenFiles = showHiddenFiles
                $0.pane.load()
            }
        }
    }

    private var activeTabCancellable: AnyCancellable?
    private var urlCancellables: Set<AnyCancellable> = []
    private let tabsKey: String?

    convenience init(initialURL: URL? = nil) {
        self.init(initialURLs: [initialURL], tabsKey: nil)
    }

    init(initialURLs: [URL?] = [nil], tabsKey: String? = nil) {
        self.tabsKey = tabsKey
        let urls = initialURLs.isEmpty ? [nil as URL?] : initialURLs
        tabs = urls.map { Tab(pane: PaneState(initialURL: $0)) }
        activeTabIndex = 0
        subscribeToActiveTab()
        subscribeAllTabURLs()
    }

    var activePaneState: PaneState {
        tabs[activeTabIndex].pane
    }

    func start() {
        activePaneState.start()
    }

    func openTab(url: URL? = nil) {
        objectWillChange.send()
        let pane = PaneState(initialURL: url ?? activePaneState.currentURL)
        pane.showHiddenFiles = showHiddenFiles
        tabs.append(Tab(pane: pane))
        activeTabIndex = tabs.count - 1
        subscribeToActiveTab()
        subscribeAllTabURLs()
        pane.start()
        saveTabs()
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        objectWillChange.send()
        let wasActive = index == activeTabIndex
        tabs.remove(at: index)
        if index < activeTabIndex {
            activeTabIndex -= 1
            // Same pane, new index — no need to resubscribe
        } else if wasActive {
            activeTabIndex = min(activeTabIndex, tabs.count - 1)
            subscribeToActiveTab()
        }
        subscribeAllTabURLs()
        saveTabs()
    }

    func switchTab(to index: Int) {
        guard index != activeTabIndex, index < tabs.count else { return }
        objectWillChange.send()
        activeTabIndex = index
        subscribeToActiveTab()
    }

    private func subscribeToActiveTab() {
        guard activeTabIndex < tabs.count else { return }
        activeTabCancellable = tabs[activeTabIndex].pane.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    private func subscribeAllTabURLs() {
        urlCancellables.removeAll()
        for tab in tabs {
            tab.pane.$currentURL
                .dropFirst()
                .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
                .sink { [weak self] _ in self?.saveTabs() }
                .store(in: &urlCancellables)
        }
    }

    private func saveTabs() {
        guard let key = tabsKey else { return }
        let paths = tabs.map { $0.pane.currentURL?.path }
        if let data = try? JSONEncoder().encode(paths) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
