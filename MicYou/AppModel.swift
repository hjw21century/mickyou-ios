import Foundation
import Network

@MainActor
final class AppModel: ObservableObject {
    @Published var servers: [DiscoveredServer] = []
    @Published var state: StreamState = .idle
    @Published var level: Float = 0
    @Published var muted = false
    @Published var language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .chinese {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published var history: [ConnectionRecord] = {
        guard let data = UserDefaults.standard.data(forKey: "connectionHistory") else { return [] }
        return (try? JSONDecoder().decode([ConnectionRecord].self, from: data)) ?? []
    }()
    @Published var host = UserDefaults.standard.string(forKey: "serverHost") ?? ""
    @Published var port: Int = {
        let saved = UserDefaults.standard.integer(forKey: "serverPort")
        return saved == 0 || saved == 8554 ? 8679 : saved
    }()

    private let discovery = ServerDiscovery()
    private let streamer = AudioStreamer()
    private var reconnectTask: Task<Void, Never>?
    private var lastEndpoint: (name: String, host: String, port: UInt16)?
    private var manuallyDisconnected = true
    private var recordedCurrentConnection = false

    init() {
        discovery.onChange = { [weak self] in self?.servers = $0 }
        streamer.onState = { [weak self] value in
            Task { @MainActor in
                self?.state = value
                if case .failed = value { self?.scheduleReconnect() }
                if value == .streaming { self?.reconnectTask?.cancel(); self?.reconnectTask = nil; self?.recordConnectionIfNeeded() }
            }
        }
        streamer.onLevel = { [weak self] in self?.level = $0 }
        streamer.onMuted = { [weak self] in self?.muted = $0 }
        discovery.start()
    }

    func connect(to server: DiscoveredServer? = nil) {
        let targetHost: String
        let targetPort: UInt16
        let targetName: String
        if let server { targetName = server.name; targetHost = server.host; targetPort = server.port }
        else {
            guard !host.isEmpty, (1...65_535).contains(port) else {
                state = .failed(language == .chinese ? "请输入有效的电脑地址和端口" : language == .japanese ? "有効なパソコンのアドレスとポートを入力してください" : "Enter a valid computer address and port"); return
            }
            UserDefaults.standard.set(host, forKey: "serverHost")
            UserDefaults.standard.set(port, forKey: "serverPort")
            targetName = host; targetHost = host; targetPort = UInt16(port)
        }
        manuallyDisconnected = false
        recordedCurrentConnection = false
        lastEndpoint = (targetName, targetHost, targetPort)
        reconnectTask?.cancel(); reconnectTask = nil
        startConnection(host: targetHost, port: targetPort)
    }

    func connect(to record: ConnectionRecord) {
        host = record.host; port = Int(record.port)
        manuallyDisconnected = false; recordedCurrentConnection = false
        lastEndpoint = (record.name, record.host, record.port)
        reconnectTask?.cancel(); reconnectTask = nil
        startConnection(host: record.host, port: record.port)
    }

    func clearHistory() { history.removeAll(); saveHistory() }

    private func recordConnectionIfNeeded() {
        guard !recordedCurrentConnection, let endpoint = lastEndpoint else { return }
        recordedCurrentConnection = true
        history.removeAll { $0.host == endpoint.host && $0.port == endpoint.port }
        history.insert(ConnectionRecord(id: UUID(), name: endpoint.name, host: endpoint.host, port: endpoint.port, date: Date()), at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: "connectionHistory") }
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
