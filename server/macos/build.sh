#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
command -v xcodegen >/dev/null || { echo "请先安装 XcodeGen：brew install xcodegen" >&2; exit 1; }
xcodegen generate
xcodebuild -project PocketSpeakerServer.xcodeproj -scheme PocketSpeakerServer -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
echo "构建完成：server/macos/build/Build/Products/Release/Pocket Speaker.app"
