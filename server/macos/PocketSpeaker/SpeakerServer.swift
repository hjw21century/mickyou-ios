import Foundation
import Network

enum DesktopLanguage: String, CaseIterable, Identifiable, Codable { case chinese, english, japanese; var id: String { rawValue }; var title: String { switch self { case .chinese: "简体中文"; case .english: "English"; case .japanese: "日本語" } } }
struct DesktopConnectionRecord: Identifiable, Codable { let id: UUID; let client: String; let date: Date }

@MainActor final class SpeakerServer: ObservableObject {
    @Published var running = false; @Published var connected = false; @Published var level = 0.0; @Published var error: String?
    @Published var port: UInt16 = 8679
    @Published var language = DesktopLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .chinese { didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") } }
    @Published var history: [DesktopConnectionRecord] = { guard let data = UserDefaults.standard.data(forKey: "history") else { return [] }; return (try? JSONDecoder().decode([DesktopConnectionRecord].self, from: data)) ?? [] }()
    var address: String { Host.current().addresses.first { $0.contains(".") && !$0.hasPrefix("127.") } ?? "localhost" }
    private var listener: NWListener?; private var client: Client?; private var capture: SystemAudioCapture?
    func start() {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.service = NWListener.Service(name: "Pocket Speaker", type: "_pocketspeaker._tcp")
            listener.newConnectionHandler = { [weak self] connection in Task { @MainActor in self?.accept(connection) } }
            listener.stateUpdateHandler = { [weak self] state in if case .failed(let e) = state { Task { @MainActor in self?.error = e.localizedDescription } } }
            listener.start(queue: .global(qos: .userInitiated)); self.listener = listener; running = true; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func stop() { capture?.stop(); capture = nil; client?.stop(); client = nil; listener?.cancel(); listener = nil; running = false; connected = false; level = 0 }
    private func accept(_ connection: NWConnection) {
        client?.stop(notify: false); capture?.stop()
        let remote = String(describing: connection.endpoint)
        let client = Client(connection: connection) { [weak self] ready in Task { @MainActor in self?.clientReady(ready, remote: remote) } }
        self.client = client; client.start()
    }
    private func clientReady(_ ready: Bool, remote: String) {
        connected = ready
        guard ready, let client else { capture?.stop(); capture = nil; return }
        history.insert(DesktopConnectionRecord(id: UUID(), client: remote, date: Date()), at: 0); if history.count > 20 { history = Array(history.prefix(20)) }; saveHistory()
        let capture = SystemAudioCapture { [weak self, weak client] pcm, level in client?.send(pcm); Task { @MainActor in self?.level = level } }
        self.capture = capture
        Task { do { try await capture.start() } catch { self.error = error.localizedDescription; connected = false } }
    }
    func clearHistory() { history.removeAll(); saveHistory() }
    private func saveHistory() { if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: "history") } }
}

private final class Client {
    private let connection: NWConnection; private let queue = DispatchQueue(label: "PocketSpeaker.client"); private var sequence: UInt32 = 0; private let ready: (Bool) -> Void
    init(connection: NWConnection, ready: @escaping (Bool) -> Void) { self.connection = connection; self.ready = ready }
    func start() { connection.start(queue: queue); receiveHandshake() }
    func stop(notify: Bool = true) { connection.cancel(); if notify { ready(false) } }
    func send(_ pcm: Data) { connection.send(content: WireProtocol.audio(pcm, sequence: sequence), completion: .contentProcessed { _ in }); sequence &+= 1 }
    private func receiveHandshake() {
        receiveExactly(12) { [weak self] data in
            guard let self, data == Data("MicYouCheck1".utf8) else { self?.stop(); return }
            self.connection.send(content: Data("MicYouCheck2".utf8), completion: .contentProcessed { error in error == nil ? self.receiveConnect() : self.stop() })
        }
    }
    private func receiveConnect() {
        receiveExactly(8) { [weak self] header in
            guard let self, let header else { self?.stop(); return }
            let bytes = [UInt8](header), length = Int(bytes[4]) << 24 | Int(bytes[5]) << 16 | Int(bytes[6]) << 8 | Int(bytes[7])
            guard bytes[0...3].elementsEqual([0x4d,0x69,0x63,0x59]), length > 0, length <= 65_536 else { self.stop(); return }
            self.receiveExactly(length) { [weak self] payload in
                guard let self, let payload, WireProtocol.isSpeakerConnect(payload) else { self?.stop(); return }
                self.ready(true); self.receiveKeepalive()
            }
        }
    }
    private func receiveExactly(_ count: Int, completion: @escaping (Data?) -> Void) {
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, complete, error in
            guard error == nil, let data, data.count == count else { completion(nil); return }
            completion(data)
        }
    }
    private func receiveKeepalive() { connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] _, _, complete, error in if complete || error != nil { self?.stop() } else { self?.receiveKeepalive() } } }
}
