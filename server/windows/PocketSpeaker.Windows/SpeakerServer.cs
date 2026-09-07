using NAudio.CoreAudioApi;
using NAudio.Wave;
using System.Net;
using System.Net.Sockets;
namespace PocketSpeaker;
internal sealed class SpeakerServer {
    public bool Running { get; private set; } public bool Connected { get; private set; }
    public event Action? StateChanged; public event Action<double>? LevelChanged;
    private TcpListener? listener; private CancellationTokenSource? cancellation; private WasapiLoopbackCapture? capture; private NetworkStream? client; private int sequence; private readonly SemaphoreSlim sendLock = new(1, 1);
    public Task StartAsync(int port) { cancellation = new(); listener = new TcpListener(IPAddress.Any, port); listener.Start(); Running = true; StateChanged?.Invoke(); _ = AcceptLoop(cancellation.Token); return Task.CompletedTask; }
    public async Task StopAsync() { cancellation?.Cancel(); capture?.StopRecording(); capture?.Dispose(); capture = null; client?.Dispose(); client = null; listener?.Stop(); listener = null; Connected = false; Running = false; StateChanged?.Invoke(); await Task.CompletedTask; }
    private async Task AcceptLoop(CancellationToken token) {
        while (!token.IsCancellationRequested) try { var socket = await listener!.AcceptTcpClientAsync(token); client?.Dispose(); client = socket.GetStream(); if (await Handshake(client, token)) { Connected = true; StateChanged?.Invoke(); StartCapture(); } } catch (OperationCanceledException) { break; } catch { if (!token.IsCancellationRequested) await Task.Delay(500, token); }
    }
    private static async Task<bool> Handshake(NetworkStream stream, CancellationToken token) {
        var hello = new byte[12]; if (!await ReadExact(stream, hello, token) || System.Text.Encoding.UTF8.GetString(hello) != "MicYouCheck1") return false;
        await stream.WriteAsync(System.Text.Encoding.UTF8.GetBytes("MicYouCheck2"), token); var header = new byte[8]; if (!await ReadExact(stream, header, token)) return false;
        var length = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(header.AsSpan(4)); if (length <= 0 || length > 65536) return false; var payload = new byte[length]; return await ReadExact(stream, payload, token) && SpeakerProtocol.IsSpeakerConnect(payload);
    }
    private void StartCapture() { capture?.StopRecording(); capture?.Dispose(); capture = new WasapiLoopbackCapture(); capture.DataAvailable += (_, e) => ProcessAudio(e.Buffer.AsSpan(0, e.BytesRecorded), capture.WaveFormat); capture.RecordingStopped += (_, _) => { Connected = false; StateChanged?.Invoke(); }; capture.StartRecording(); }
    private void ProcessAudio(ReadOnlySpan<byte> data, WaveFormat format) {
        var channels = format.Channels; var inputRate = format.SampleRate; var count = data.Length / 4 / channels; if (count < 2 || format.Encoding != WaveFormatEncoding.IeeeFloat) return;
        var mono = new float[count]; for (var frame = 0; frame < count; frame++) { float sum = 0; for (var ch = 0; ch < channels; ch++) sum += BitConverter.ToSingle(data.Slice((frame * channels + ch) * 4, 4)); mono[frame] = float.IsFinite(sum) ? sum / channels : 0; }
        var outCount = Math.Max(1, (int)Math.Round(count * 48000.0 / inputRate)); var pcm = new byte[outCount * 2]; double peak = 0;
        for (var i = 0; i < outCount; i++) { var pos = i * (inputRate / 48000.0); var lo = Math.Min((int)pos, count - 1); var hi = Math.Min(lo + 1, count - 1); var sample = Math.Clamp(mono[lo] + (mono[hi] - mono[lo]) * (float)(pos - lo), -1, 1); peak = Math.Max(peak, Math.Abs(sample)); BitConverter.TryWriteBytes(pcm.AsSpan(i * 2, 2), (short)(sample * short.MaxValue)); }
        LevelChanged?.Invoke(peak); _ = SendAsync(SpeakerProtocol.Audio(pcm, sequence++));
    }
    private async Task SendAsync(byte[] frame) { var stream = client; if (stream == null) return; await sendLock.WaitAsync(); try { await stream.WriteAsync(frame); } catch { Connected = false; StateChanged?.Invoke(); } finally { sendLock.Release(); } }
    private static async Task<bool> ReadExact(Stream stream, byte[] buffer, CancellationToken token) { var offset = 0; while (offset < buffer.Length) { var read = await stream.ReadAsync(buffer.AsMemory(offset), token); if (read == 0) return false; offset += read; } return true; }
}
