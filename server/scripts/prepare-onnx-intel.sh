#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../tauri-app"
[[ "$(uname -s)" == Darwin ]] || { echo 'Requires macOS' >&2; exit 1; }
archive="$(mktemp -d)"
trap 'rm -rf "$archive"' EXIT
curl --fail --location --retry 3 \
  https://github.com/microsoft/onnxruntime/releases/download/v1.23.2/onnxruntime-osx-x86_64-1.23.2.tgz \
  -o "$archive/ort.tgz"
printf '%s  %s\n' d10359e16347b57d9959f7e80a225a5b4a66ed7d7e007274a15cae86836485a6 "$archive/ort.tgz" | shasum -a 256 -c -
tar -xzf "$archive/ort.tgz" -C "$archive"
ort="$archive/onnxruntime-osx-x86_64-1.23.2"
mkdir -p src-tauri/libs src-tauri/resources
cp -L "$ort/lib/libonnxruntime.dylib" src-tauri/libs/libonnxruntime.dylib
lipo -verify_arch x86_64 src-tauri/libs/libonnxruntime.dylib
cp "$ort/LICENSE" src-tauri/resources/ONNX-Runtime-LICENSE.txt
cp "$ort/ThirdPartyNotices.txt" src-tauri/resources/ONNX-Runtime-ThirdPartyNotices.txt
