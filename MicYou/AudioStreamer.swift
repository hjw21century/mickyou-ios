import AVFoundation
import Foundation
import Network

final class AudioStreamer {
    var onState: ((StreamState) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onMuted: ((Bool) -> Void)?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let networkQueue = DispatchQueue(label: "com.lanrhyme.micyou.network")
    private var tcp: NWConnection?
    private var receiveBuffer = Data()
    private var sessionID: UInt64 = 0
    private var serverMuted = false
    private var running = false

    func start(endpoint: NWEndpoint) async throws {
        guard !running else { return }
        await state(.connecting)
        serverMuted = false

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
        try startPlayback()
        sessionID = UInt64(Date().timeIntervalSince1970 * 1000)

        let tcp = NWConnection(to: endpoint, using: .tcp)
        self.tcp = tcp
        try await connect(tcp)
        try await handshake(tcp)

        tcp.send(content: MicYouProtocol.tcpFrame(MicYouProtocol.connect(sessionID: sessionID)), completion: .contentProcessed { _ in })
        running = true
        receiveControl()
        await state(.streaming)
    }

    func stop() {
        running = false
        player.stop()
        engine.stop()
        tcp?.cancel(); tcp = nil
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

    private func startPlayback() throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 48_000,
                                         channels: 1,
                                         interleaved: false) else {
            throw StreamError.invalidAudioFormat
        }
        if !engine.attachedNodes.contains(player) { engine.attach(player) }
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        player.play()
    }

    private func play(_ packet: SpeakerAudioPacket) {
        guard running, !serverMuted, packet.sampleRate == 48_000, packet.channels == 1,
              packet.pcm.count >= 2, packet.pcm.count.isMultiple(of: 2),
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 48_000,
                                         channels: 1,
                                         interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(packet.pcm.count / 2)),
              let output = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        let bytes = [UInt8](packet.pcm)
        var peak: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            let byteOffset = frame * 2
            let raw = UInt16(bytes[byteOffset]) | (UInt16(bytes[byteOffset + 1]) << 8)
            let sample = Float(Int16(bitPattern: raw)) / 32_768
            output[frame] = sample
            peak = max(peak, abs(sample))
        }
        player.scheduleBuffer(buffer)
        DispatchQueue.main.async { [weak self] in self?.onLevel?(peak) }
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
            let payloadStart = receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 8)
            let payloadEnd = receiveBuffer.index(payloadStart, offsetBy: length)
            let payload = Data(receiveBuffer[payloadStart..<payloadEnd])
            receiveBuffer.removeFirst(8 + length)
            let control = MicYouProtocol.controlMessage(payload)
            if let muted = control.muted {
                serverMuted = muted
                DispatchQueue.main.async { [weak self] in self?.onMuted?(muted) }
            }
            if let ping = control.ping, let tcp {
                tcp.send(content: MicYouProtocol.tcpFrame(MicYouProtocol.pong(timestamp: ping)), completion: .contentProcessed { _ in })
            }
            if let audio = control.audio { play(audio) }
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
    case invalidAudioFormat, handshakeFailed, invalidEndpoint, connectionClosed
    var errorDescription: String? {
        switch self {
        case .invalidAudioFormat: "无法创建扬声器播放格式"
        case .handshakeFailed: "服务端握手失败，请确认版本兼容"
        case .invalidEndpoint: "无法解析服务端地址"
        case .connectionClosed: "服务端已断开连接"
        }
    }
}

extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        precondition(offset >= 0 && count >= offset + 4)
        let fieldStart = index(startIndex, offsetBy: offset)
        let fieldEnd = index(fieldStart, offsetBy: 4)
        return self[fieldStart..<fieldEnd].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
