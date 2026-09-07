import Foundation
import Network

@MainActor
final class AppModel: ObservableObject {
    @Published var servers: [DiscoveredServer] = []
    @Published var state: StreamState = .idle
    @Published var level: Float = 0
    @Published var muted = false
    @Published var host = UserDefaults.standard.string(forKey: "serverHost") ?? ""
    @Published var port: Int = {
        let saved = UserDefaults.standard.integer(forKey: "serverPort")
        return saved == 0 || saved == 8554 ? 8679 : saved
    }()

    private let discovery = ServerDiscovery()
    private let streamer = AudioStreamer()
    private var reconnectTask: Task<Void, Never>?
    private var lastEndpoint: (host: String, port: UInt16)?
    private var manuallyDisconnected = true

    init() {
        discovery.onChange = { [weak self] in self?.servers = $0 }
        streamer.onState = { [weak self] value in
            Task { @MainActor in
                self?.state = value
                if case .failed = value { self?.scheduleReconnect() }
                if value == .streaming { self?.reconnectTask?.cancel(); self?.reconnectTask = nil }
            }
        }
        streamer.onLevel = { [weak self] in self?.level = $0 }
        streamer.onMuted = { [weak self] in self?.muted = $0 }
        discovery.start()
    }

    func connect(to server: DiscoveredServer? = nil) {
        let targetHost: String
        let targetPort: UInt16
        if let server { targetHost = server.host; targetPort = server.port }
        else {
            guard !host.isEmpty, (1...65_535).contains(port) else {
                state = .failed("请输入有效的电脑地址和端口"); return
            }
            UserDefaults.standard.set(host, forKey: "serverHost")
            UserDefaults.standard.set(port, forKey: "serverPort")
            targetHost = host; targetPort = UInt16(port)
        }
        manuallyDisconnected = false
        lastEndpoint = (targetHost, targetPort)
        reconnectTask?.cancel(); reconnectTask = nil
        startConnection(host: targetHost, port: targetPort)
    }

    private func startConnection(host: String, port: UInt16) {
        Task {
            do { try await streamer.start(endpoint: .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)) }
            catch {
                streamer.stop()
                state = .failed(error.localizedDescription)
                scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard !manuallyDisconnected, let endpoint = lastEndpoint else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self, !self.manuallyDisconnected else { return }
            self.startConnection(host: endpoint.host, port: endpoint.port)
        }
    }

    func disconnect() { manuallyDisconnected = true; reconnectTask?.cancel(); reconnectTask = nil; streamer.stop() }
    func refresh() { discovery.start() }
}
