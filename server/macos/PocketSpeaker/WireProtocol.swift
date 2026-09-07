import Foundation

enum WireProtocol {
    static let magic: UInt32 = 0x4D696359
    static func audio(_ pcm: Data, sequence: UInt32) -> Data {
        var packet = bytes(1, pcm); packet += uint(2, 48_000); packet += uint(3, 1); packet += uint(4, 2)
        var ordered = uint(1, UInt64(sequence)); ordered += bytes(2, packet); ordered += uint(3, UInt64(Date().timeIntervalSince1970 * 1000))
        let payload = bytes(1, ordered)
        var framed = Data(); framed.be(magic); framed.be(UInt32(payload.count)); framed += payload
        return framed
    }
    static func isSpeakerConnect(_ data: Data) -> Bool { data.windows(of: [0x10, 0x01]).first != nil }
    private static func uint(_ n: UInt64, _ value: UInt64) -> Data { var d = varint(n << 3); d += varint(value); return d }
    private static func bytes(_ n: UInt64, _ value: Data) -> Data { var d = varint((n << 3) | 2); d += varint(UInt64(value.count)); d += value; return d }
    private static func varint(_ input: UInt64) -> Data { var v = input, d = Data(); repeat { var b = UInt8(v & 127); v >>= 7; if v > 0 { b |= 128 }; d.append(b) } while v > 0; return d }
}
private extension Data { mutating func be(_ x: UInt32) { var v = x.bigEndian; Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) } } }
