#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../tauri-app"
app=target/x86_64-apple-darwin/release/bundle/macos/MicYou.app
for binary in micyou micyou-cli micyou-tui; do
  lipo "$app/Contents/MacOS/$binary" -verify_arch x86_64
done
ort="$app/Contents/Resources/resources/libonnxruntime.dylib"
lipo "$ort" -verify_arch x86_64
# Loading the bundled library catches missing transitive dependencies as well.
python3 - "$ort" <<'PYTHON'
import ctypes, sys
ort = ctypes.CDLL(sys.argv[1])
class ApiBase(ctypes.Structure):
    _fields_ = [("get_api", ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_uint32)),
                ("get_version", ctypes.CFUNCTYPE(ctypes.c_char_p))]
ort.OrtGetApiBase.restype = ctypes.POINTER(ApiBase)
base = ort.OrtGetApiBase().contents
assert base.get_api(23), "ONNX Runtime does not support API 23"
assert base.get_version() == b"1.23.2"
print("Bundled ONNX Runtime 1.23.2 / API 23 verified")
PYTHON
"$app/Contents/MacOS/micyou-cli" --help
shopt -s nullglob
dmgs=(target/x86_64-apple-darwin/release/bundle/dmg/*.dmg)
[[ ${#dmgs[@]} -eq 1 ]]
hdiutil verify "${dmgs[0]}"
