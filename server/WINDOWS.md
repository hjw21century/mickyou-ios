# MicYou Windows x64 扬声器服务端

本服务端配合仓库中的 iOS 客户端，把 Windows 系统声音通过局域网发送到 iPhone。Windows 使用 WASAPI loopback 直接捕获默认播放设备，不需要安装 BlackHole 或虚拟声卡。

## 使用

1. 按下方说明构建服务端，并运行 `bundle/nsis` 目录生成的安装程序。未签名安装包可能触发 SmartScreen，可选择“更多信息 → 仍要运行”。
2. 完成安装后启动 MicYou。
3. 打开 MicYou，选择 **Wi-Fi**，保持默认端口 `8554` 并启动服务端；在 Windows 防火墙提示中允许“专用网络”。
4. 确保 Windows 正在使用需要转发的默认扬声器或耳机，然后在 iPhone 上选择该电脑或输入电脑的局域网 IPv4 地址。
5. iPhone 显示“播放中”后，Windows 系统声音会从手机扬声器播放。

如果连接成功但没有声音，请确认 Windows 音量混合器中应用未静音、默认输出设备选择正确，并重新启动服务端。蓝牙耳机切换或默认输出设备变化后也需要重新连接。

## 本地构建

安装 Visual Studio 2022 Build Tools（Desktop development with C++）、WebView2 Runtime、Node.js 22、Rust stable 和 cargo-about 0.9.1，然后在 PowerShell 中运行：

```powershell
cargo install cargo-about --version 0.9.1 --locked
./server/scripts/build-windows.ps1
```

安装包输出目录：`server/tauri-app/target/x86_64-pc-windows-msvc/release/bundle/nsis/`。
