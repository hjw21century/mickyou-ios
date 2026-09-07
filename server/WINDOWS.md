# Pocket Speaker Windows

Windows 客户端采用 WinUI 3 界面，通过 WASAPI loopback 捕获默认输出设备，不需要虚拟声卡。

## 构建要求

- Windows 10 1809 或更高版本（x64）
- Visual Studio 2022，安装“.NET 桌面开发”和“Windows 应用 SDK C# 模板”
- .NET 8 SDK

打开 `server/windows/PocketSpeaker.Windows.sln`，选择 `Release | x64` 构建；也可运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\server\windows\build.ps1
```

启动前可选择需要捕获的电脑输出设备。允许 Windows 防火墙的专用网络访问，在 iPhone 中填写界面显示的 IPv4 地址和端口 `8679`。
