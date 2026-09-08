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
    typealias VolumeScan = (Set<String>) -> (network: [NetworkVolume], external: [NetworkVolume])

    @Published var mountedVolumes: [NetworkVolume] = []
    @Published var externalVolumes: [NetworkVolume] = []
    @Published var bonjourServers: [BonjourServer] = []

    private static let suppressedPathsKey = "suppressedNetworkPaths"
    @Published private(set) var suppressedPaths: Set<String> = Set(UserDefaults.standard.stringArray(forKey: suppressedPathsKey) ?? [])
    private var mountToken: Any?
    private var unmountToken: Any?
    private var smbBrowser: NetServiceBrowser?
    private var afpBrowser: NetServiceBrowser?
    private var smbDelegate: BonjourBrowserDelegate?
    private var afpDelegate: BonjourBrowserDelegate?
    private let unmountAndEject: (URL) throws -> Void
    private let volumeScan: VolumeScan
    private let refreshQueue = DispatchQueue(label: "DuPane.NetworkVolumeMonitor.refresh", qos: .utility)
    private var refreshGeneration = 0

    init(unmountAndEject: @escaping (URL) throws -> Void = {
        try NSWorkspace.shared.unmountAndEjectDevice(at: $0)
    }, volumeScan: @escaping VolumeScan = NetworkVolumeMonitor.scanVolumes) {
        self.unmountAndEject = unmountAndEject
        self.volumeScan = volumeScan
    }

    func startMonitoring(autoReconnect: Bool = false, pinnedURLs: [String] = []) {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        mountToken = nc.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        unmountToken = nc.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        if autoReconnect { reconnectPinned(pinnedURLs) }
    }

    func stopMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter
        if let t = mountToken { nc.removeObserver(t); mountToken = nil }
        if let t = unmountToken { nc.removeObserver(t); unmountToken = nil }
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

    private static let networkFSTypes: Set<String> = ["smbfs", "afpfs", "nfs", "nfs4", "webdav", "ftpfs"]
    private static let externalFSTypes: Set<String> = ["apfs", "hfs", "msdos", "exfat", "ntfs", "ufsd_NTFS", "ufsd_ExtFS", "udf", "cd9660"]

    func refresh() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.refresh() }
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        let suppressedPaths = suppressedPaths
        let volumeScan = volumeScan
        refreshQueue.async { [weak self] in
            let result = volumeScan(suppressedPaths)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.refreshGeneration == generation else { return }
                self.mountedVolumes = result.network
                self.externalVolumes = result.external
            }
        }
    }

    private static func scanVolumes(suppressedPaths: Set<String>) -> (network: [NetworkVolume], external: [NetworkVolume]) {
        let opts: FileManager.VolumeEnumerationOptions = [.skipHiddenVolumes]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: opts) ?? []
        var network: [NetworkVolume] = []
        var external: [NetworkVolume] = []
        for url in urls {
            var stat = statfs()
            guard statfs(url.path, &stat) == 0 else { continue }
            let fsType = withUnsafeBytes(of: stat.f_fstypename) { raw in
                String(bytes: raw.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            if Self.networkFSTypes.contains(fsType) {
                guard !suppressedPaths.contains(url.path) else { continue }
                network.append(NetworkVolume(url: url))
            } else if Self.externalFSTypes.contains(fsType), url.path.hasPrefix("/Volumes/") {
                external.append(NetworkVolume(url: url))
            }
        }
        return (network, external)
    }

    func ejectExternal(_ volume: NetworkVolume) {
        try? unmountAndEject(volume.url)
    }

    func ejectAndRemove(_ volume: NetworkVolume) {
        guard (try? unmountAndEject(volume.url)) != nil else { return }
        suppressedPaths.insert(volume.url.path)
        UserDefaults.standard.set(Array(suppressedPaths), forKey: Self.suppressedPathsKey)
        mountedVolumes.removeAll { $0.id == volume.id }
    }

    func clearSuppressedPaths() {
        suppressedPaths = []
        UserDefaults.standard.removeObject(forKey: Self.suppressedPathsKey)
        refresh()
    }

    func mountedVolume(for pinnedURLString: String) -> NetworkVolume? {
        guard let pinned = URL(string: pinnedURLString) else { return nil }
        let share = pinned.lastPathComponent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !share.isEmpty else { return nil }
        return mountedVolumes.first { $0.name.caseInsensitiveCompare(share) == .orderedSame }
    }

    func reconnectPinned(_ pinnedURLs: [String]) {
        for raw in pinnedURLs {
            guard let url = URL(string: raw),
                  let scheme = url.scheme, !scheme.isEmpty,
                  url.host != nil else { continue }
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
            self?.receiveBonjourServers(servers, scheme: scheme)
        }
        let browser = NetServiceBrowser()
        browser.delegate = del
        browser.searchForServices(ofType: type, inDomain: "local.")
        store(browser)
        return del
    }

    func receiveBonjourServers(_ servers: [BonjourServer], scheme: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.receiveBonjourServers(servers, scheme: scheme)
            }
            return
        }
        let others = bonjourServers.filter { $0.scheme != scheme }
        bonjourServers = others + servers
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        if let t = mountToken { nc.removeObserver(t) }
        if let t = unmountToken { nc.removeObserver(t) }
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
