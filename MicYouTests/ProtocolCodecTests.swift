import XCTest
@testable import MicYou

final class ProtocolCodecTests: XCTestCase {
    func testTCPFrameUsesBigEndianHeader() {
        let frame = MicYouProtocol.tcpFrame(Data([1, 2, 3]))
        XCTAssertEqual(Array(frame.prefix(8)), [0x4d, 0x69, 0x63, 0x59, 0, 0, 0, 3])
    }

    func testControlMessagesDecode() {
        XCTAssertEqual(MicYouProtocol.controlMessage(Data([0x1a, 0x02, 0x08, 0x01])).muted, true)
        XCTAssertEqual(MicYouProtocol.controlMessage(Data([0x2a, 0x03, 0x08, 0xac, 0x02])).ping, 300)
    }

    func testAudioDatagramStaysBelowMTU() {
        let payload = MicYouProtocol.audio(sequence: 1, timestamp: 2, sessionID: 3,
                                           pcm: Data(repeating: 0, count: 960), sampleRate: 48_000)
        XCTAssertLessThanOrEqual(MicYouProtocol.udpFrame(payload).count, 1472)
    }
}

