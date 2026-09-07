import AVFoundation
import CoreMedia
import ScreenCaptureKit

final class SystemAudioCapture: NSObject, SCStreamOutput {
    private let callback: (Data, Double) -> Void; private var stream: SCStream?; private var pending = [Int16](); private let queue = DispatchQueue(label: "PocketSpeaker.capture")
    init(callback: @escaping (Data, Double) -> Void) { self.callback = callback }
    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw CaptureError.noDisplay }
        let config = SCStreamConfiguration(); config.capturesAudio = true; config.excludesCurrentProcessAudio = true; config.sampleRate = 48_000; config.channelCount = 1; config.width = 2; config.height = 2; config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue); self.stream = stream; try await stream.startCapture()
    }
    func stop() { let current = stream; stream = nil; Task { try? await current?.stopCapture() }; pending.removeAll() }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)); var block: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: nil, bufferListOut: &list, bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment), blockBufferOut: &block)
        guard status == noErr, let data = list.mBuffers.mData else { return }
        let count = Int(list.mBuffers.mDataByteSize) / MemoryLayout<Float>.size; let floats = data.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count { let s = floats[i].isFinite ? max(-1, min(1, floats[i])) : 0; pending.append(Int16(s * Float(Int16.max))) }
        while pending.count >= 960 { let frame = Array(pending.prefix(960)); var data = Data(capacity: 1920); for var s in frame { s = s.littleEndian; Swift.withUnsafeBytes(of: &s) { data.append(contentsOf: $0) } }; let peak = frame.map { abs(Double($0) / 32768) }.max() ?? 0; pending.removeFirst(960); callback(data, peak) }
    }
    enum CaptureError: LocalizedError { case noDisplay; var errorDescription: String? { "无法访问系统音频，请允许屏幕录制权限" } }
}
