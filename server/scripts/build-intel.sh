#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin && "$(uname -m)" == x86_64 ]] || {
  echo 'Build on an Intel Mac (or an x86_64 macOS build environment).' >&2; exit 1;
}
export MACOSX_DEPLOYMENT_TARGET=11.0
export TAURI_ENV_TARGET_TRIPLE=x86_64-apple-darwin
rustup target add "$TAURI_ENV_TARGET_TRIPLE"
bash scripts/prepare-onnx-intel.sh
cd tauri-app
npm ci --include=dev
npm run tauri -- build --bundles dmg --target "$TAURI_ENV_TARGET_TRIPLE"
bash ../scripts/verify-intel.sh
