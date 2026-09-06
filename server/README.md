# MicYou Intel Mac 扬声器服务端

本目录包含 MicYou 2.0.3 桌面服务端（Tauri GUI、CLI、TUI）的源码，面向 Intel Mac / x86_64。iOS 客户端仍位于仓库根目录 `MicYou/`。

## 下载与使用

在本仓库 Actions 的 **Intel macOS Server** 中打开成功的构建，下载 **MicYou-Server-macOS-Intel-x86_64**，解压后打开 DMG，将 MicYou 拖入 Applications。自动构建包未做 Apple Developer ID 签名或公证；首次打开可能需要在系统设置的“隐私与安全性”中允许打开。

1. 手机与 Mac 连接同一局域网。
2. 安装 BlackHole 2ch，在“音频 MIDI 设置”中创建多输出设备，同时勾选实际扬声器和 BlackHole。
3. 将 macOS 系统输出切换到该多输出设备。
4. Mac 服务端选择 Wi-Fi 模式并启动，允许防火墙接入。
5. iOS 客户端选择发现的 Mac 或输入 Mac IP；电脑声音将通过 TCP 8554 发送到手机扬声器。

iOS 当前不支持上游 Android 的 ADB USB 模式。避免同时启动 GUI 和 CLI/TUI（它们共用服务端和配置）。

## 本地构建

使用 Intel Mac，安装 Xcode Command Line Tools、Node.js 22、Rust stable 和 cargo-about 0.9.1：

```bash
xcode-select --install
# Node.js 和 Rust 安装完成后：
cargo install cargo-about --version 0.9.1 --locked
bash server/scripts/build-intel.sh
```

产物：`server/tauri-app/target/x86_64-apple-darwin/release/bundle/dmg/`。
构建部署目标设置为 macOS 11.0；实际最低可运行系统仍需对应版本真机验证。
脚本下载并核验 ONNX Runtime 1.23.2 的官方 x86_64 库，编译三个可执行程序，然后验证架构、动态库可加载性、CLI 启动和 DMG 完整性。完整手机音频链路仍需真机测试。

## 来源和修改

上游：https://github.com/LanRhyme/MicYou

固定源提交：`0bf286b0d06552a5fd406c0b1695a1bd52e9916b`。
`tauri-app/` 源码及模型来自该提交，保留原作者版权和 `LICENSE`（GPL-3.0-or-later，含 MicYou Plugin Exception）。

本版本新增 Intel 构建/验证脚本和 Actions 工作流。上游附带的 ARM64 macOS ONNX 库及 Windows/Linux 二进制不纳入本目录；通过校验 SHA-256 的官方下载取得 Intel 库及许可证。Rust `ort` 关闭默认的较新 API 特性并明确使用 API 23，与 ONNX Runtime 1.23.2 对齐，避免运行时请求不支持的 API。
