import AVFoundation
import Foundation
import Network

final class AudioStreamer {
    var onState: ((StreamState) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onMuted: ((Bool) -> Void)?

    private let engine = AVAudioEngine()
    private let networkQueue = DispatchQueue(label: "com.lanrhyme.micyou.network")
    private var tcp: NWConnection?
    private var udp: NWConnection?
    private var receiveBuffer = Data()
    private var sequence: UInt32 = 0
    private var sessionID: UInt64 = 0
    private var sampleRate: UInt32 = 48_000
    private var serverMuted = false
    private var running = false
    private var tapInstalled = false

    func start(endpoint: NWEndpoint) async throws {
        guard !running else { return }
        await state(.connecting)
        sequence = 0
        serverMuted = false
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw StreamError.microphoneDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
        guard !session.currentRoute.inputs.isEmpty else {
            throw StreamError.noAudioInput
        }
        sessionID = UInt64(Date().timeIntervalSince1970 * 1000)

        let tcp = NWConnection(to: endpoint, using: .tcp)
        self.tcp = tcp
        try await connect(tcp)
        try await handshake(tcp)

        let udpEndpoint = try udpEndpoint(from: endpoint)
        let udp = NWConnection(to: udpEndpoint, using: .udp)
        self.udp = udp
        udp.start(queue: networkQueue)

        tcp.send(content: MicYouProtocol.tcpFrame(MicYouProtocol.connect(sessionID: sessionID)), completion: .contentProcessed { _ in })
        running = true
        receiveControl()
        try startCapture()
        await state(.streaming)
    }

    func stop() {
        running = false
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        tcp?.cancel(); udp?.cancel(); tcp = nil; udp = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Task { await state(.idle) }
    }

    private func connect(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false
            connection.stateUpdateHandler = { state in
                guard !completed else { return }
                switch state {
                case .ready: completed = true; continuation.resume()
                case .failed(let error): completed = true; continuation.resume(throwing: error)
                default: break
                }
            }
            connection.start(queue: networkQueue)
        }
    }

    private func handshake(_ connection: NWConnection) async throws {
        try await send(Data("MicYouCheck1".utf8), on: connection)
        let response = try await receiveExactly(12, on: connection)
        guard String(data: response, encoding: .utf8) == "MicYouCheck2" else { throw StreamError.handshakeFailed }
    }

    private func startCapture() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw StreamError.invalidAudioFormat
        }
        sampleRate = UInt32(format.sampleRate.rounded())
        // Passing a stale hardware format can trigger an AVAudioEngine Objective-C
        // assertion instead of a catchable Swift error. `nil` lets the input node
        // provide its current native format after the audio session is activated.
        input.installTap(onBus: 0, bufferSize: 480, format: nil) { [weak self] buffer, _ in
            // AVAudioEngine owns and may reuse the tap buffer after this callback returns.
            self?.process(buffer)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard running, !serverMuted, let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength), channelCount = Int(buffer.format.channelCount)
        var pcm = Data(capacity: frames * 2)
        var peak: Float = 0
        for index in 0..<frames {
            var sample: Float = 0
            for channel in 0..<channelCount { sample += channels[channel][index] }
            sample = max(-1, min(1, sample / Float(max(1, channelCount))))
            peak = max(peak, abs(sample))
            var int16 = Int16(sample * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &int16) { pcm.append(contentsOf: $0) }
        }
        let maxBytes = 960
        var offset = 0
        while offset < pcm.count {
            let end = min(offset + maxBytes, pcm.count)
            sendAudio(Data(pcm[offset..<end])); offset = end
        }
        DispatchQueue.main.async { [weak self] in self?.onLevel?(peak) }
    }

    private func sendAudio(_ pcm: Data) {
        guard let udp else { return }
        let payload = MicYouProtocol.audio(sequence: sequence, timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                                           sessionID: sessionID, pcm: pcm, sampleRate: sampleRate)
        sequence &+= 1
        udp.send(content: MicYouProtocol.udpFrame(payload), completion: .contentProcessed { [weak self] error in
            if let error { Task { await self?.state(.failed(error.localizedDescription)) } }
        })
    }

    private func receiveControl() {
        tcp?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            guard let self, self.running else { return }
            if let data { self.receiveBuffer += data; self.consumeFrames() }
            if let error { self.stop(); Task { await self.state(.failed(error.localizedDescription)) }; return }
            if complete { self.stop(); Task { await self.state(.failed(StreamError.connectionClosed.localizedDescription)) }; return }
            self.receiveControl()
        }
    }

    private func consumeFrames() {
        while receiveBuffer.count >= 8 {
            let magic = receiveBuffer.readUInt32BE(at: 0), length = Int(receiveBuffer.readUInt32BE(at: 4))
            guard magic == MicYouProtocol.tcpMagic, length >= 0, length <= 1_048_576 else { stop(); return }
            guard receiveBuffer.count >= 8 + length else { return }
            let payload = Data(receiveBuffer[8..<(8 + length)])
            receiveBuffer.removeFirst(8 + length)
            let control = MicYouProtocol.controlMessage(payload)
            if let muted = control.muted {
                serverMuted = muted
                DispatchQueue.main.async { [weak self] in self?.onMuted?(muted) }
            }
            if let ping = control.ping, let tcp {
                tcp.send(content: MicYouProtocol.tcpFrame(MicYouProtocol.pong(timestamp: ping)), completion: .contentProcessed { _ in })
            }
        }
    }

    private func udpEndpoint(from endpoint: NWEndpoint) throws -> NWEndpoint {
        switch endpoint {
        case let .hostPort(host, port):
            let raw = port.rawValue
            guard raw < UInt16.max, let udpPort = NWEndpoint.Port(rawValue: raw + 1) else { throw StreamError.invalidEndpoint }
            return .hostPort(host: host, port: udpPort)
        default: throw StreamError.invalidEndpoint
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }

    private func receiveExactly(_ count: Int, on connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let error { continuation.resume(throwing: error) }
                else if let data, data.count == count { continuation.resume(returning: data) }
                else { continuation.resume(throwing: StreamError.connectionClosed) }
            }
        }
    }

    @MainActor private func state(_ value: StreamState) { onState?(value) }
}

enum StreamError: LocalizedError {
    case microphoneDenied, noAudioInput, invalidAudioFormat
    case handshakeFailed, invalidEndpoint, connectionClosed
    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "未获得麦克风权限"
        case .noAudioInput: "没有可用的麦克风输入，请检查系统声音输入设置"
        case .invalidAudioFormat: "麦克风返回了无效的音频格式，请重新连接输入设备"
        case .handshakeFailed: "服务端握手失败，请确认版本兼容"
        case .invalidEndpoint: "无法解析服务端地址"
        case .connectionClosed: "服务端已断开连接"
        }
    }
}

private extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        self[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
