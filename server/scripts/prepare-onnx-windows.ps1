$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'tauri-app'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("micyou-ort-" + [guid]::NewGuid())
$archive = Join-Path $work 'ort.zip'
$expected = '0b38df9af21834e41e73d602d90db5cb06dbd1ca618948b8f1d66d607ac9f3cd'

New-Item -ItemType Directory -Force $work | Out-Null
try {
    Invoke-WebRequest `
        'https://github.com/microsoft/onnxruntime/releases/download/v1.23.2/onnxruntime-win-x64-1.23.2.zip' `
        -OutFile $archive
    $actual = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "ONNX Runtime checksum mismatch: $actual" }
    Expand-Archive $archive -DestinationPath $work
    $ort = Join-Path $work 'onnxruntime-win-x64-1.23.2'
    New-Item -ItemType Directory -Force (Join-Path $app 'src-tauri/libs') | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $app 'src-tauri/resources') | Out-Null
    Copy-Item (Join-Path $ort 'lib/onnxruntime.dll') (Join-Path $app 'src-tauri/libs/onnxruntime.dll') -Force
    Copy-Item (Join-Path $ort 'LICENSE') (Join-Path $app 'src-tauri/resources/ONNX-Runtime-LICENSE.txt') -Force
    Copy-Item (Join-Path $ort 'ThirdPartyNotices.txt') (Join-Path $app 'src-tauri/resources/ONNX-Runtime-ThirdPartyNotices.txt') -Force
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

