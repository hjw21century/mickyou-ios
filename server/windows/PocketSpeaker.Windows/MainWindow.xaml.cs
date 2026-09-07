using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Collections.ObjectModel;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace PocketSpeaker;

public sealed partial class MainWindow : Window {
    private const int DefaultPort = 8679;
    private readonly SpeakerServer server = new();
    private readonly AppSettings settings = AppSettings.Load();
    private readonly ObservableCollection<HistoryEntry> history = new();
    private IReadOnlyList<AudioDevice> devices = [];
    private bool initialized;

    public MainWindow() {
        InitializeComponent(); Title = "Pocket Speaker"; AppWindow.SetIcon("Assets/AppIcon.ico");
        LanguagePicker.ItemsSource = new[] { "简体中文", "English", "日本語" };
        LanguagePicker.SelectedIndex = settings.Language == "en" ? 1 : settings.Language == "ja" ? 2 : 0;
        devices = SpeakerServer.GetAudioDevices(); DevicePicker.ItemsSource = devices;
        DevicePicker.SelectedItem = devices.FirstOrDefault(device => device.Id == settings.DeviceId) ?? devices.FirstOrDefault();
        foreach (var item in settings.History) history.Add(item); HistoryList.ItemsSource = history;
        server.StateChanged += UpdateState;
        server.LevelChanged += value => DispatcherQueue.TryEnqueue(() => LevelBar.Value = value);
        server.ClientConnected += AddHistory;
        initialized = true; ApplyLanguage();
    }

    private string T(string chinese, string english, string japanese) => LanguagePicker.SelectedIndex switch { 1 => english, 2 => japanese, _ => chinese };

    private async void ToggleClicked(object sender, RoutedEventArgs e) {
        try { if (server.Running) await server.StopAsync(); else await server.StartAsync(DefaultPort, (DevicePicker.SelectedItem as AudioDevice)?.Id); }
        catch (Exception ex) { ErrorBar.Message = ex.Message; ErrorBar.IsOpen = true; }
        UpdateState();
    }

    private void UpdateState() => DispatcherQueue.TryEnqueue(() => {
        StatusText.Text = server.Connected ? T("手机已连接", "Phone connected", "スマートフォン接続済み") : server.Running ? T("等待手机连接", "Waiting for phone", "スマートフォンを待機中") : T("准备就绪", "Ready", "準備完了");
        AddressText.Text = server.Running ? $"{LocalIPv4()}:{DefaultPort}" : T("将电脑声音无线播放到手机", "Play computer audio on your phone", "パソコンの音声をスマートフォンで再生");
        ToggleButton.Content = server.Running ? T("停止服务", "Stop", "停止") : T("开始共享声音", "Start sharing", "共有を開始");
        DevicePicker.IsEnabled = !server.Running;
    });

    private void LanguageChanged(object sender, SelectionChangedEventArgs e) { if (!initialized) return; settings.Language = LanguagePicker.SelectedIndex switch { 1 => "en", 2 => "ja", _ => "zh" }; settings.Save(); ApplyLanguage(); }
    private void DeviceChanged(object sender, SelectionChangedEventArgs e) { if (!initialized) return; settings.DeviceId = (DevicePicker.SelectedItem as AudioDevice)?.Id; settings.Save(); }
    private void ClearHistoryClicked(object sender, RoutedEventArgs e) { history.Clear(); settings.History.Clear(); settings.Save(); }
    private void AddHistory(string client) => DispatcherQueue.TryEnqueue(() => { var item = new HistoryEntry { Client = client, ConnectedAt = DateTimeOffset.Now }; history.Insert(0, item); while (history.Count > 20) history.RemoveAt(history.Count - 1); settings.History = history.ToList(); settings.Save(); });
    private void ApplyLanguage() { DevicePicker.PlaceholderText = T("选择电脑输出设备", "Select computer output", "パソコンの出力デバイスを選択"); HistoryTitle.Text = T("最近连接", "Recent connections", "最近の接続"); ClearHistoryButton.Content = T("清空", "Clear", "消去"); FooterText.Text = T("无需虚拟声卡 · WASAPI 系统音频捕获 · 局域网传输", "No virtual driver · WASAPI capture · Local network", "仮想ドライバー不要 · WASAPI キャプチャ · ローカルネットワーク"); UpdateState(); }
    private static string LocalIPv4() => NetworkInterface.GetAllNetworkInterfaces().Where(n => n.OperationalStatus == OperationalStatus.Up && n.NetworkInterfaceType != NetworkInterfaceType.Loopback).SelectMany(n => n.GetIPProperties().UnicastAddresses).FirstOrDefault(a => a.Address.AddressFamily == AddressFamily.InterNetwork)?.Address.ToString() ?? "127.0.0.1";
}
