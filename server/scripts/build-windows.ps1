$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Run this script on 64-bit Windows.' }

$root = Split-Path -Parent $PSScriptRoot
$env:TAURI_ENV_TARGET_TRIPLE = 'x86_64-pc-windows-msvc'
rustup target add $env:TAURI_ENV_TARGET_TRIPLE
& (Join-Path $PSScriptRoot 'prepare-onnx-windows.ps1')

Push-Location (Join-Path $root 'tauri-app')
try {
    npm ci --include=dev
    if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
    npm run tauri -- build --bundles nsis --target $env:TAURI_ENV_TARGET_TRIPLE
    if ($LASTEXITCODE -ne 0) { throw 'Tauri build failed' }
} finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot 'verify-windows.ps1')

