import Foundation
import Network

@MainActor final class SpeakerServer: ObservableObject {
    @Published var running = false; @Published var connected = false; @Published var level = 0.0; @Published var error: String?
    let port: UInt16 = 8554
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
        client?.stop(); capture?.stop()
        let client = Client(connection: connection) { [weak self] ready in Task { @MainActor in self?.clientReady(ready) } }
        self.client = client; client.start()
    }
    private func clientReady(_ ready: Bool) {
        connected = ready
        guard ready, let client else { capture?.stop(); capture = nil; return }
        let capture = SystemAudioCapture { [weak self, weak client] pcm, level in client?.send(pcm); Task { @MainActor in self?.level = level } }
        self.capture = capture
        Task { do { try await capture.start() } catch { self.error = error.localizedDescription; connected = false } }
    }
}

private final class Client {
    private let connection: NWConnection; private let queue = DispatchQueue(label: "PocketSpeaker.client"); private var sequence: UInt32 = 0; private let ready: (Bool) -> Void
    init(connection: NWConnection, ready: @escaping (Bool) -> Void) { self.connection = connection; self.ready = ready }
    func start() { connection.start(queue: queue); receiveHandshake() }
    func stop() { connection.cancel(); ready(false) }
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
