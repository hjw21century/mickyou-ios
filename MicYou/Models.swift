import Foundation

struct DiscoveredServer: Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let port: UInt16
}

enum StreamState: Equatable {
    case idle, connecting, streaming, failed(String)

    var title: String {
        switch self {
        case .idle: "未连接"
        case .connecting: "正在连接…"
        case .streaming: "传输中"
        case .failed: "连接失败"
        }
    }
}

