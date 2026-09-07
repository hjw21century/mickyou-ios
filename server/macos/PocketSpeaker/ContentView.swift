import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var server: SpeakerServer
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.04, blue: 0.12), Color(red: 0.08, green: 0.06, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.indigo.opacity(0.3)).frame(width: 300).blur(radius: 70).offset(x: 220, y: -180)
            VStack(spacing: 28) {
                HStack { Image(systemName: "wave.3.right.circle.fill").foregroundStyle(.cyan, .indigo); Text("Pocket Speaker").font(.title2.bold()); Spacer(); Text("DESKTOP").font(.caption2.bold()).foregroundStyle(.cyan) }
                ZStack {
                    Circle().stroke(.white.opacity(0.09)).frame(width: 190, height: 190)
                    Circle().fill((server.connected ? Color.cyan : .indigo).opacity(0.14)).frame(width: 150, height: 150)
                    Image(systemName: server.connected ? "iphone.radiowaves.left.and.right" : "hifispeaker.2.fill").font(.system(size: 54)).foregroundStyle(.white)
                }
                Text(server.connected ? "手机已连接" : server.running ? "等待手机连接" : "准备就绪").font(.title.bold())
                Text(server.running ? "\(server.address):\(server.port)" : "将电脑声音无线播放到手机").foregroundStyle(.secondary)
                HStack(spacing: 8) { ForEach(0..<18, id: \.self) { i in Capsule().fill(Double(i) / 18 < server.level ? AnyShapeStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .bottom, endPoint: .top)) : AnyShapeStyle(.white.opacity(0.08))).frame(width: 10, height: CGFloat(12 + (i % 5) * 5)) } }
                Button { server.running ? server.stop() : server.start() } label: { Label(server.running ? "停止服务" : "开始共享声音", systemImage: server.running ? "stop.fill" : "play.fill").frame(width: 220).padding(.vertical, 8) }
                    .buttonStyle(.borderedProminent).tint(server.running ? .red.opacity(0.8) : .indigo)
                if let error = server.error { Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center) }
            }.padding(34)
        }.frame(width: 520, height: 600).preferredColorScheme(.dark)
    }
}
