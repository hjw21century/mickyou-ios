import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    if model.state == .streaming { levelCard } else { connectionCard }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("MicYou")
            .toolbar {
                if model.state != .streaming {
                    Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.14)).frame(width: 96, height: 96)
                Image(systemName: model.state == .streaming ? (model.muted ? "mic.slash.fill" : "mic.fill") : "mic")
                    .font(.system(size: 38)).foregroundStyle(statusColor)
            }
            Text(model.state.title).font(.title2.bold())
            if case .failed(let message) = model.state { Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity).padding(24).background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.muted ? "电脑端已静音" : "麦克风电平").font(.headline)
            ProgressView(value: Double(model.muted ? 0 : model.level)).tint(statusColor).scaleEffect(y: 3)
            Button(role: .destructive) { model.disconnect() } label: {
                Label("停止传输", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent)
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("附近的电脑").font(.headline)
            if model.servers.isEmpty { ContentUnavailableView("未发现服务端", systemImage: "desktopcomputer.trianglebadge.exclamationmark", description: Text("请先在电脑端启动 Wi-Fi 模式")) }
            else {
                ForEach(model.servers) { server in
                    Button { model.connect(to: server) } label: {
                        HStack { Image(systemName: "desktopcomputer"); Text(server.name); Spacer(); Image(systemName: "chevron.right") }
                    }.buttonStyle(.plain).padding(.vertical, 6)
                }
            }
            Divider()
            Text("手动连接").font(.headline)
            TextField("电脑 IP，例如 192.168.1.10", text: $model.host).textInputAutocapitalization(.never).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder)
            TextField("端口", value: $model.port, format: .number).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            Button { model.connect() } label: { Label("连接并开始传输", systemImage: "antenna.radiowaves.left.and.right").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).disabled(model.host.isEmpty || model.state == .connecting)
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var statusColor: Color {
        if model.muted { return .orange }
        switch model.state { case .streaming: .green; case .failed: .red; default: .accentColor }
    }
}

