# MicYou iOS

原生 SwiftUI 客户端，与 MicYou 桌面端的 Wi-Fi 模式兼容。

当前 iOS 版本支持局域网 Wi-Fi 传输；Android 的 ADB USB 模式不适用于 iOS。

## 构建

1. 安装 Xcode 15 或更高版本，以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（例如 `brew install xcodegen`）。
2. 在本目录执行 `xcodegen generate`。
3. 打开 `MicYou.xcodeproj`，选择自己的开发团队和真机后运行。

### Intel Mac

工程同时支持 Intel Mac 上的 `x86_64` iOS 模拟器和 iPhone 真机的 `arm64` 构建，无第三方二进制依赖。Intel Homebrew 的默认目录通常是 `/usr/local`；如果终端找不到 XcodeGen，可执行：

```bash
eval "$(/usr/local/bin/brew shellenv)"
brew install xcodegen
xcodegen generate
```

命令行验证模拟器构建：

```bash
xcodebuild \
  -project MicYou.xcodeproj \
  -scheme MicYou \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

如果本机没有 `iPhone 15` 模拟器，可通过 `xcrun simctl list devices available` 查询并替换设备名称。模拟器仅用于界面和协议测试，麦克风及局域网串流仍应在真机验证。

首次连接时需允许“麦克风”和“本地网络”权限。电脑端选择 Wi-Fi 模式后，可从发现列表连接；也可手动输入电脑 IP（默认 TCP 端口 `8554`）。音频通过 UDP `8555` 发送，控制与心跳走 TCP `8554`。

> 最低运行版本为 iOS 17。Intel Mac 只影响模拟器架构，不影响生成的真机应用。
