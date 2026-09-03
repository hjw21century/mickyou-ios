import Foundation

enum MicYouProtocol {
    static let tcpMagic: UInt32 = 0x4D696359
    static let udpMagic: UInt32 = 0x4D696355

    static func connect(sessionID: UInt64) -> Data {
        wrapper(field: 2, payload: fieldVarint(1, sessionID))
    }

    static func pong(timestamp: UInt64) -> Data {
        wrapper(field: 6, payload: fieldVarint(1, timestamp))
    }

    static func audio(sequence: UInt32, timestamp: UInt64, sessionID: UInt64,
                      pcm: Data, sampleRate: UInt32, channels: UInt32 = 1) -> Data {
        var packet = Data()
        packet += fieldBytes(1, pcm)
        packet += fieldVarint(2, UInt64(sampleRate))
        packet += fieldVarint(3, UInt64(channels))
        packet += fieldVarint(4, 2) // Android ENCODING_PCM_16BIT

        var ordered = Data()
        ordered += fieldVarint(1, UInt64(sequence))
        ordered += fieldBytes(2, packet)
        ordered += fieldVarint(3, timestamp)
        ordered += fieldVarint(6, sessionID)
        return wrapper(field: 1, payload: ordered)
    }

    static func tcpFrame(_ payload: Data) -> Data {
        var result = Data()
        result.appendBigEndian(tcpMagic)
        result.appendBigEndian(UInt32(payload.count))
        result += payload
        return result
    }

    static func udpFrame(_ payload: Data) -> Data {
        var result = Data()
        result.appendBigEndian(udpMagic)
        result.appendBigEndian(UInt32(payload.count))
        result += payload
        return result
    }

    static func controlMessage(_ data: Data) -> (muted: Bool?, ping: UInt64?) {
        var reader = ProtoReader(data)
        var muted: Bool?
        var ping: UInt64?
        while let (field, wire) = reader.nextTag() {
            guard wire == 2, let nested = reader.readBytes() else { reader.skip(wire); continue }
            if field == 3 { muted = ProtoReader.firstVarint(nested, field: 1).map { $0 != 0 } }
            if field == 5 { ping = ProtoReader.firstVarint(nested, field: 1) }
        }
        return (muted, ping)
    }

    private static func wrapper(field: UInt64, payload: Data) -> Data { fieldBytes(field, payload) }
    private static func fieldVarint(_ field: UInt64, _ value: UInt64) -> Data {
        var data = varint((field << 3) | 0); data += varint(value); return data
    }
    private static func fieldBytes(_ field: UInt64, _ value: Data) -> Data {
        var data = varint((field << 3) | 2); data += varint(UInt64(value.count)); data += value; return data
    }
    private static func varint(_ value: UInt64) -> Data {
        var value = value, data = Data()
        repeat {
            var byte = UInt8(value & 0x7f); value >>= 7
            if value != 0 { byte |= 0x80 }
            data.append(byte)
        } while value != 0
        return data
    }
}

private struct ProtoReader {
    let data: Data
    var index = 0
    init(_ data: Data) { self.data = data }
    mutating func readVarint() -> UInt64? {
        var value: UInt64 = 0, shift: UInt64 = 0
        while index < data.count && shift < 64 {
            let byte = data[index]; index += 1
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
        }
        return nil
    }
    mutating func nextTag() -> (UInt64, UInt64)? { readVarint().map { ($0 >> 3, $0 & 7) } }
    mutating func readBytes() -> Data? {
        guard let length = readVarint(), length <= UInt64(data.count - index) else { return nil }
        let end = index + Int(length), value = data[index..<end]; index = end
        return Data(value)
    }
    mutating func skip(_ wire: UInt64) {
        if wire == 0 { _ = readVarint() }
        else if wire == 2, let size = readVarint() { index = min(data.count, index + Int(size)) }
        else { index = data.count }
    }
    static func firstVarint(_ data: Data, field wanted: UInt64) -> UInt64? {
        var reader = ProtoReader(data)
        while let (field, wire) = reader.nextTag() {
            if field == wanted, wire == 0 { return reader.readVarint() }
            reader.skip(wire)
        }
        return nil
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        var value = value.bigEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}

