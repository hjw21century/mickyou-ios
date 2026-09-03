# MicYou iOS

原生 SwiftUI 客户端，与 MicYou 桌面端的 Wi-Fi 模式兼容。

当前 iOS 版本支持局域网 Wi-Fi 传输；Android 的 ADB USB 模式不适用于 iOS。

## 构建

1. 安装 Xcode 16 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（例如 `brew install xcodegen`）。
2. 在本目录执行 `xcodegen generate`。
3. 打开 `MicYou.xcodeproj`，选择自己的开发团队和真机后运行。

首次连接时需允许“麦克风”和“本地网络”权限。电脑端选择 Wi-Fi 模式后，可从发现列表连接；也可手动输入电脑 IP（默认 TCP 端口 `8554`）。音频通过 UDP `8555` 发送，控制与心跳走 TCP `8554`。

> iOS 模拟器不能代表真实的麦克风和局域网音频表现，请使用 iOS 17 或更高版本真机测试。
