import Foundation
import Network

final class ServerDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private var browser: NetServiceBrowser?
    private var resolving: [NetService] = []
    private var serversByID: [String: DiscoveredServer] = [:]
    var onChange: (([DiscoveredServer]) -> Void)?

    func start() {
        stop()
        serversByID.removeAll()
        onChange?([])
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: "_micyou._tcp.", inDomain: "local.")
        self.browser = browser
    }

    func stop() {
        browser?.stop()
        resolving.forEach { $0.stop() }
        resolving.removeAll()
        browser = nil
    }

    func endpoint(for server: DiscoveredServer) -> NWEndpoint {
        .hostPort(host: NWEndpoint.Host(server.host), port: NWEndpoint.Port(rawValue: server.port)!)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolving.append(service)
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        serversByID.removeValue(forKey: serviceKey(service))
        publish()
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        defer { resolving.removeAll { $0 === sender } }
        guard let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              sender.port > 0, sender.port <= Int(UInt16.max) else { return }
        let id = serviceKey(sender)
        serversByID[id] = DiscoveredServer(id: id, name: sender.name, host: host, port: UInt16(sender.port))
        publish()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolving.removeAll { $0 === sender }
    }

    private func serviceKey(_ service: NetService) -> String { "\(service.name).\(service.type)\(service.domain)" }
    private func publish() { onChange?(serversByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }
}

