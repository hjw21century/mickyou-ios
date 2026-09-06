$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'tauri-app'
$target = Join-Path $app 'target/x86_64-pc-windows-msvc/release'

function Assert-X64PE([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Missing binary: $Path" }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "Not a PE binary: $Path"
    }
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    $machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
    if ($machine -ne 0x8664) { throw "Binary is not Windows x64: $Path (machine=0x$($machine.ToString('x4')))" }
}

Assert-X64PE (Join-Path $target 'micyou.exe')
Assert-X64PE (Join-Path $target 'micyou-cli.exe')
Assert-X64PE (Join-Path $target 'micyou-tui.exe')
Assert-X64PE (Join-Path $app 'src-tauri/resources/onnxruntime.dll')

& (Join-Path $target 'micyou-cli.exe') --help | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'micyou-cli --help failed' }

$installers = @(Get-ChildItem (Join-Path $target 'bundle/nsis/*.exe'))
if ($installers.Count -ne 1) { throw "Expected one NSIS installer, found $($installers.Count)" }
Write-Host "Verified Windows x64 server and installer: $($installers[0].Name)"

