import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var server: SpeakerServer
    @State private var showingHistory = false
    @State private var showingSettings = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.04, blue: 0.12), Color(red: 0.08, green: 0.06, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.indigo.opacity(0.3)).frame(width: 300).blur(radius: 70).offset(x: 220, y: -180)
            VStack(spacing: 28) {
                HStack { Image(systemName: "wave.3.right.circle.fill").foregroundStyle(.cyan, .indigo); Text("Pocket Speaker").font(.title2.bold()); Spacer(); Button { showingHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }; Button { showingSettings = true } label: { Image(systemName: "gearshape.fill") }; Text("DESKTOP").font(.caption2.bold()).foregroundStyle(.cyan) }
                ZStack {
                    Circle().stroke(.white.opacity(0.09)).frame(width: 190, height: 190)
                    Circle().fill((server.connected ? Color.cyan : .indigo).opacity(0.14)).frame(width: 150, height: 150)
                    Image(systemName: server.connected ? "iphone.radiowaves.left.and.right" : "hifispeaker.2.fill").font(.system(size: 54)).foregroundStyle(.white)
                }
                Text(server.connected ? t("手机已连接", "Phone connected", "スマートフォン接続済み") : server.running ? t("等待手机连接", "Waiting for phone", "スマートフォンを待機中") : t("准备就绪", "Ready", "準備完了")).font(.title.bold())
                Text(server.running ? "\(server.address):\(server.port)" : t("将电脑声音无线播放到手机", "Play computer audio on your phone", "パソコンの音声をスマートフォンで再生")).foregroundStyle(.secondary)
                HStack {
                    Text(t("端口", "Port", "ポート")).foregroundStyle(.secondary)
                    TextField("8679", value: $server.port, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 100).disabled(server.running)
                }
                HStack(spacing: 8) { ForEach(0..<18, id: \.self) { i in Capsule().fill(Double(i) / 18 < server.level ? AnyShapeStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .bottom, endPoint: .top)) : AnyShapeStyle(.white.opacity(0.08))).frame(width: 10, height: CGFloat(12 + (i % 5) * 5)) } }
                Button { server.running ? server.stop() : server.start() } label: { Label(server.running ? t("停止服务", "Stop", "停止") : t("开始共享声音", "Start sharing", "共有を開始"), systemImage: server.running ? "stop.fill" : "play.fill").frame(width: 220).padding(.vertical, 8) }
                    .buttonStyle(.borderedProminent).tint(server.running ? .red.opacity(0.8) : .indigo)
                if let error = server.error { Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center) }
            }.padding(34)
        }.frame(width: 520, height: 640).preferredColorScheme(.dark)
            .sheet(isPresented: $showingHistory) { historySheet }
            .sheet(isPresented: $showingSettings) { settingsSheet }
    }
    private func t(_ zh: String, _ en: String, _ ja: String) -> String { switch server.language { case .chinese: zh; case .english: en; case .japanese: ja } }
    private var historySheet: some View { NavigationStack { List { if server.history.isEmpty { Text(t("暂无连接记录", "No connection history", "接続履歴はありません")).foregroundStyle(.secondary) }; ForEach(server.history) { item in VStack(alignment: .leading) { Text(item.client); Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) } } }.navigationTitle(t("连接记录", "Connection history", "接続履歴")).toolbar { Button(t("清空", "Clear", "消去")) { server.clearHistory() }.disabled(server.history.isEmpty) } }.frame(width: 440, height: 420).preferredColorScheme(.dark) }
    private var settingsSheet: some View { VStack(alignment: .leading, spacing: 20) { Text(t("设置", "Settings", "設定")).font(.title2.bold()); Picker(t("界面语言", "Language", "表示言語"), selection: $server.language) { ForEach(DesktopLanguage.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented); Spacer() }.padding(28).frame(width: 420, height: 220).preferredColorScheme(.dark) }
}
