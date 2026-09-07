$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'PocketSpeaker.Windows\PocketSpeaker.Windows.csproj'
dotnet publish $project -c Release -r win-x64 --self-contained true
Write-Host '构建完成：server\windows\PocketSpeaker.Windows\bin\Release\net8.0-windows10.0.19041.0\win-x64\publish'
