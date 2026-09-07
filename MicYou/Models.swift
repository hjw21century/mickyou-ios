import Foundation

struct DiscoveredServer: Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let port: UInt16
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case chinese, english
    var id: String { rawValue }
    var title: String { self == .chinese ? "简体中文" : "English" }
}

struct ConnectionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let host: String
    let port: UInt16
    let date: Date
}

enum StreamState: Equatable {
    case idle, connecting, streaming, failed(String)

    var title: String {
        switch self {
        case .idle: "未连接"
        case .connecting: "正在连接…"
        case .streaming: "播放中"
        case .failed: "连接失败"
        }
    }
}
