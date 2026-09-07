using Microsoft.UI.Xaml;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
namespace PocketSpeaker;
public sealed partial class MainWindow : Window {
    private const int DefaultPort = 8679;
    private readonly SpeakerServer server = new();
    public MainWindow() { InitializeComponent(); Title = "Pocket Speaker"; AppWindow.SetIcon("Assets/AppIcon.ico"); DevicePicker.ItemsSource = SpeakerServer.GetAudioDevices(); DevicePicker.SelectedIndex = 0; server.StateChanged += UpdateState; server.LevelChanged += value => DispatcherQueue.TryEnqueue(() => LevelBar.Value = value); }
    private async void ToggleClicked(object sender, RoutedEventArgs e) { try { if (server.Running) await server.StopAsync(); else await server.StartAsync(DefaultPort, (DevicePicker.SelectedItem as AudioDevice)?.Id); } catch (Exception ex) { ErrorBar.Message = ex.Message; ErrorBar.IsOpen = true; } UpdateState(); }
    private void UpdateState() => DispatcherQueue.TryEnqueue(() => { StatusText.Text = server.Connected ? "手机已连接" : server.Running ? "等待手机连接" : "准备就绪"; AddressText.Text = server.Running ? $"{LocalIPv4()}:{DefaultPort}" : "将电脑声音无线播放到手机"; ToggleButton.Content = server.Running ? "停止服务" : "开始共享声音"; DevicePicker.IsEnabled = !server.Running; });
    private static string LocalIPv4() => NetworkInterface.GetAllNetworkInterfaces().Where(n => n.OperationalStatus == OperationalStatus.Up && n.NetworkInterfaceType != NetworkInterfaceType.Loopback).SelectMany(n => n.GetIPProperties().UnicastAddresses).FirstOrDefault(a => a.Address.AddressFamily == AddressFamily.InterNetwork)?.Address.ToString() ?? "127.0.0.1";
}
