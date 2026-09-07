using System.Buffers.Binary;
namespace PocketSpeaker;
internal static class SpeakerProtocol {
    private const uint Magic = 0x4D696359;
    public static byte[] Audio(byte[] pcm, int sequence) {
        var packet = Bytes(1, pcm).Concat(UInt(2, 48000)).Concat(UInt(3, 1)).Concat(UInt(4, 2)).ToArray();
        var ordered = UInt(1, (ulong)sequence).Concat(Bytes(2, packet)).Concat(UInt(3, (ulong)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds())).ToArray();
        var payload = Bytes(1, ordered); var frame = new byte[payload.Length + 8]; BinaryPrimitives.WriteUInt32BigEndian(frame, Magic); BinaryPrimitives.WriteInt32BigEndian(frame.AsSpan(4), payload.Length); payload.CopyTo(frame, 8); return frame;
    }
    public static bool IsSpeakerConnect(byte[] data) { for (var i = 0; i + 1 < data.Length; i++) if (data[i] == 0x10 && data[i + 1] == 1) return true; return false; }
    private static byte[] UInt(ulong field, ulong value) => Varint(field << 3).Concat(Varint(value)).ToArray();
    private static byte[] Bytes(ulong field, byte[] value) => Varint((field << 3) | 2).Concat(Varint((ulong)value.Length)).Concat(value).ToArray();
    private static byte[] Varint(ulong value) { var result = new List<byte>(); do { var b = (byte)(value & 127); value >>= 7; if (value != 0) b |= 128; result.Add(b); } while (value != 0); return result.ToArray(); }
}
