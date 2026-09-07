# Pocket Speaker 原生服务端

Pocket Speaker 只做一件事：把电脑正在播放的声音通过局域网发送到 iPhone。

## macOS

原生 SwiftUI + ScreenCaptureKit，支持 macOS 13 或更高版本以及 Intel/Apple Silicon。首次启动需要允许“屏幕与系统音频录制”权限，不再依赖 BlackHole。

```bash
cd server/macos
chmod +x build.sh
./build.sh
```

## Windows

原生 WinUI 3 + WASAPI loopback，支持 Windows 10 1809 或更高版本 x64，无需虚拟声卡。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\server\windows\build.ps1
```

电脑和 iPhone 需位于同一局域网。桌面端启动共享后，在手机端选择发现的电脑；Windows 暂时需要手动输入界面显示的 IPv4 地址，默认端口为 `8554`。
