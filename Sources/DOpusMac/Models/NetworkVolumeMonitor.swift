import Foundation
import AppKit

struct NetworkVolume: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

struct BonjourServer: Identifiable, Equatable {
    let name: String
    let hostName: String
    let scheme: String
    var id: String { "\(scheme)://\(hostName)" }
    var connectURL: URL? { URL(string: "\(scheme)://\(hostName)/") }
}

final class NetworkVolumeMonitor: ObservableObject {
    @Published var mountedVolumes: [NetworkVolume] = []
    @Published var bonjourServers: [BonjourServer] = []

    private var mountToken: Any?
    private var unmountToken: Any?
    private var smbBrowser: NetServiceBrowser?
    private var afpBrowser: NetServiceBrowser?
    private var smbDelegate: BonjourBrowserDelegate?
    private var afpDelegate: BonjourBrowserDelegate?

    func startMonitoring(autoReconnect: Bool = false, pinnedURLs: [String] = []) {
        refresh()
        mountToken = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        unmountToken = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        if autoReconnect { reconnectPinned(pinnedURLs) }
    }

    func stopMonitoring() {
        if let t = mountToken { NotificationCenter.default.removeObserver(t); mountToken = nil }
        if let t = unmountToken { NotificationCenter.default.removeObserver(t); unmountToken = nil }
    }

    func startBonjourBrowsing() {
        smbDelegate = makeBrowser(type: "_smb._tcp.", scheme: "smb", store: { [weak self] b in self?.smbBrowser = b })
        afpDelegate = makeBrowser(type: "_afpovertcp._tcp.", scheme: "afp", store: { [weak self] b in self?.afpBrowser = b })
    }

    func stopBonjourBrowsing() {
        smbBrowser?.stop(); smbBrowser = nil; smbDelegate = nil
        afpBrowser?.stop(); afpBrowser = nil; afpDelegate = nil
        bonjourServers = []
    }

    func refresh() {
        let opts: FileManager.VolumeEnumerationOptions = [.skipHiddenVolumes]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: opts) ?? []
        mountedVolumes = urls.compactMap { url in
            var stat = statfs()
            guard statfs(url.path, &stat) == 0 else { return nil }
            guard (stat.f_flags & UInt32(MNT_LOCAL)) == 0 else { return nil }
            return NetworkVolume(url: url)
        }
    }

    func eject(_ volume: NetworkVolume) {
        let url = volume.url
        Task.detached { try? NSWorkspace.shared.unmountAndEjectDevice(at: url) }
    }

    func reconnectPinned(_ pinnedURLs: [String]) {
        for raw in pinnedURLs {
            guard let url = URL(string: raw), url.scheme != nil else { continue }
            NSWorkspace.shared.open(url)
        }
    }

    func isMounted(_ pinnedURLString: String) -> Bool {
        guard let pinned = URL(string: pinnedURLString) else { return false }
        let pinnedHost = pinned.host?.lowercased() ?? ""
        let pinnedPath = pinned.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return mountedVolumes.contains { vol in
            let volName = vol.name.lowercased()
            return !pinnedPath.isEmpty && volName == pinnedPath.components(separatedBy: "/").last
                || (!pinnedHost.isEmpty && volName.contains(pinnedHost))
        }
    }

    @discardableResult
    private func makeBrowser(type: String, scheme: String, store: @escaping (NetServiceBrowser) -> Void) -> BonjourBrowserDelegate {
        let del = BonjourBrowserDelegate(scheme: scheme) { [weak self] servers in
            guard let self else { return }
            let others = self.bonjourServers.filter { $0.scheme != scheme }
            self.bonjourServers = others + servers
        }
        let browser = NetServiceBrowser()
        browser.delegate = del
        browser.searchForServices(ofType: type, inDomain: "local.")
        store(browser)
        return del
    }

    deinit {
        if let t = mountToken { NotificationCenter.default.removeObserver(t) }
        if let t = unmountToken { NotificationCenter.default.removeObserver(t) }
    }
}

private final class BonjourBrowserDelegate: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let scheme: String
    private let onUpdate: ([BonjourServer]) -> Void
    private var services: [NetService] = []

    init(scheme: String, onUpdate: @escaping ([BonjourServer]) -> Void) {
        self.scheme = scheme
        self.onUpdate = onUpdate
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service)
        service.resolve(withTimeout: 5)
        if !moreComing { publish() }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 === service }
        if !moreComing { publish() }
    }

    func netServiceDidResolveAddress(_ sender: NetService) { publish() }

    private func publish() {
        let scheme = self.scheme
        let servers: [BonjourServer] = services.compactMap { svc in
            let host = svc.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                ?? "\(svc.name).local"
            return BonjourServer(name: svc.name, hostName: host, scheme: scheme)
        }
        onUpdate(servers)
    }
}
