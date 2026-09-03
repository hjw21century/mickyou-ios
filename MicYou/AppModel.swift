import Foundation
import Network

@MainActor
final class AppModel: ObservableObject {
    @Published var servers: [DiscoveredServer] = []
    @Published var state: StreamState = .idle
    @Published var level: Float = 0
    @Published var muted = false
    @Published var host = UserDefaults.standard.string(forKey: "serverHost") ?? ""
    @Published var port = UserDefaults.standard.integer(forKey: "serverPort") == 0 ? 8554 : UserDefaults.standard.integer(forKey: "serverPort")

    private let discovery = ServerDiscovery()
    private let streamer = AudioStreamer()

    init() {
        discovery.onChange = { [weak self] in self?.servers = $0 }
        streamer.onState = { [weak self] in self?.state = $0 }
        streamer.onLevel = { [weak self] in self?.level = $0 }
        streamer.onMuted = { [weak self] in self?.muted = $0 }
        discovery.start()
    }

    func connect(to server: DiscoveredServer? = nil) {
        let endpoint: NWEndpoint
        if let server { endpoint = discovery.endpoint(for: server) }
        else {
            guard !host.isEmpty, let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
                state = .failed("请输入有效的电脑地址和端口"); return
            }
            UserDefaults.standard.set(host, forKey: "serverHost")
            UserDefaults.standard.set(port, forKey: "serverPort")
            endpoint = .hostPort(host: NWEndpoint.Host(host), port: nwPort)
        }
        Task {
            do { try await streamer.start(endpoint: endpoint) }
            catch { streamer.stop(); state = .failed(error.localizedDescription) }
        }
    }

    func disconnect() { streamer.stop() }
    func refresh() { discovery.start() }
}
