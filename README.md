# Pocket Speaker

原生 SwiftUI 客户端，通过 Wi-Fi 把电脑的系统音频送到 iPhone 扬声器播放。

当前版本专注于局域网 Wi-Fi 传输，电脑与 iPhone 需连接同一网络。

## 构建

1. 安装 Xcode 15 或更高版本，以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（例如 `brew install xcodegen`）。
2. 在本目录执行 `xcodegen generate`。
3. 打开 `PocketSpeaker.xcodeproj`，选择自己的开发团队和真机后运行。

更新 `project.yml` 或 `Info.plist` 后，请删除旧工程再重新生成，确保局域网隐私说明被打包：

```bash
rm -rf PocketSpeaker.xcodeproj
xcodegen generate
```

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
  -project PocketSpeaker.xcodeproj \
  -scheme PocketSpeaker \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

如果本机没有 `iPhone 15` 模拟器，可通过 `xcrun simctl list devices available` 查询并替换设备名称。模拟器仅用于界面和协议测试，扬声器及局域网串流仍应在真机验证。

首次连接时需允许“本地网络”权限。电脑端选择 Wi-Fi 模式后，可从发现列表连接；也可手动输入电脑 IP（默认 TCP 端口 `8554`）。电脑音频以 48 kHz/16-bit/单声道 PCM 通过 TCP 发送到手机。

macOS 原生服务端通过 ScreenCaptureKit 捕获系统音频，无需 BlackHole 或多输出设备。Windows 原生服务端通过 WASAPI loopback 捕获默认输出设备。

> 最低运行版本为 iOS 17。Intel Mac 只影响模拟器架构，不影响生成的真机应用。

## 原生桌面服务端

服务端已裁剪为单一的电脑音频共享功能。macOS 使用 SwiftUI + ScreenCaptureKit，Windows 使用 WinUI 3 + WASAPI，构建说明见 [服务端文档](server/README.md)。
