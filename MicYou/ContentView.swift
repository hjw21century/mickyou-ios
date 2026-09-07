import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingHistory = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x070B1D), Color(hex: 0x11133B)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(Color.indigo.opacity(0.24)).frame(width: 330).blur(radius: 70).offset(x: 150, y: -310)
            ScrollView { VStack(spacing: 28) { header; hero; mainCard }.padding(24) }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingHistory) { historySheet }
        .sheet(isPresented: $showingSettings) { settingsSheet }
    }

    private var header: some View {
        HStack {
            Image(systemName: "wave.3.right.circle.fill").font(.title2).foregroundStyle(.cyan, .indigo)
            Text("Pocket Speaker").font(.headline.weight(.semibold))
            Spacer()
            Button { showingHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }.buttonStyle(GlassButtonStyle())
            Button { showingSettings = true } label: { Image(systemName: "gearshape.fill") }.buttonStyle(GlassButtonStyle())
            if model.state != .streaming {
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(GlassButtonStyle())
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 172, height: 172)
                Circle().fill(statusColor.opacity(0.16)).frame(width: 138, height: 138).blur(radius: 4)
                Image(systemName: model.state == .streaming ? "iphone.radiowaves.left.and.right" : "iphone")
                    .font(.system(size: 58, weight: .light)).foregroundStyle(.white)
            }
            Text(statusTitle).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.56)).multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var mainCard: some View {
        if model.state == .streaming {
            VStack(spacing: 22) {
                HStack { Text(t("实时音量", "Live volume", "リアルタイム音量")).font(.headline); Spacer(); Text("LIVE").font(.caption2.bold()).foregroundStyle(.cyan) }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(LinearGradient(colors: [.cyan, .indigo, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, proxy.size.width * CGFloat(min(1, model.level))))
                    }
                }.frame(height: 10)
                Button(role: .destructive) { model.disconnect() } label: {
                    Label(t("断开连接", "Disconnect", "接続を解除"), systemImage: "stop.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).tint(Color(hex: 0xCC4260))
            }.glassCard()
        } else {
            VStack(alignment: .leading, spacing: 18) {
                Label(t("附近的电脑", "Nearby computers", "近くのパソコン"), systemImage: "desktopcomputer").font(.headline)
                if model.servers.isEmpty {
                    HStack { ProgressView(); Text(t("正在搜索 Pocket Speaker…", "Searching for Pocket Speaker…", "Pocket Speaker を検索中…")).foregroundStyle(.secondary) }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                } else {
                    ForEach(model.servers) { server in
                        Button { model.connect(to: server) } label: {
                            HStack { Image(systemName: "laptopcomputer"); Text(server.name); Spacer(); Image(systemName: "chevron.right") }
                                .padding(14).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain)
                    }
                }
                HStack { Rectangle().frame(height: 1); Text(t("手动连接", "Manual connection", "手動接続")).font(.caption); Rectangle().frame(height: 1) }
                    .foregroundStyle(.white.opacity(0.12))
                TextField(t("电脑 IP 地址", "Computer IP address", "パソコンの IP アドレス"), text: $model.host).textInputAutocapitalization(.never).keyboardType(.numbersAndPunctuation)
                    .padding(14).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                TextField(t("端口", "Port", "ポート"), value: $model.port, format: .number).keyboardType(.numberPad)
                    .padding(14).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                Button { model.connect() } label: {
                    Label(t("连接电脑", "Connect", "接続"), systemImage: "bolt.horizontal.circle.fill").frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(.borderedProminent).tint(.indigo).disabled(model.host.isEmpty || model.state == .connecting)
            }.glassCard()
        }
    }

    private var subtitle: String {
        if case .failed(let message) = model.state { return message }
        return model.state == .streaming ? t("电脑的声音，正在此处播放", "Computer audio is playing here", "パソコンの音声を再生中") : t("让手机成为电脑的无线扬声器", "Turn your phone into a wireless speaker", "スマートフォンをワイヤレススピーカーに")
    }
    private var statusColor: Color { model.state == .streaming ? .cyan : .indigo }
    private var statusTitle: String {
        switch model.state {
        case .idle: t("未连接", "Not connected", "未接続")
        case .connecting: t("正在连接…", "Connecting…", "接続中…")
        case .streaming: t("播放中", "Playing", "再生中")
        case .failed: t("连接失败", "Connection failed", "接続に失敗しました")
        }
    }
    private func t(_ chinese: String, _ english: String, _ japanese: String) -> String { switch model.language { case .chinese: chinese; case .english: english; case .japanese: japanese } }

    private var historySheet: some View {
        NavigationStack {
            List {
                if model.history.isEmpty { ContentUnavailableView(t("暂无连接记录", "No connection history", "接続履歴はありません"), systemImage: "clock") }
                ForEach(model.history) { record in
                    Button { showingHistory = false; model.connect(to: record) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.name).font(.headline)
                            Text("\(record.host):\(record.port) · \(record.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }.buttonStyle(.plain)
                }
            }.navigationTitle(t("连接记录", "Connection history", "接続履歴")).toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(t("清空", "Clear", "消去")) { model.clearHistory() }.disabled(model.history.isEmpty) }
            }
        }.preferredColorScheme(.dark)
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form { Picker(t("界面语言", "Language", "表示言語"), selection: $model.language) { ForEach(AppLanguage.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented) }
                .navigationTitle(t("设置", "Settings", "設定"))
        }.presentationDetents([.medium]).preferredColorScheme(.dark)
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(10).background(.white.opacity(configuration.isPressed ? 0.14 : 0.07), in: Circle())
    }
}
private extension View {
    func glassCard() -> some View { padding(22).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.08))) }
}
private extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}
