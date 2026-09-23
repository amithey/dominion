# Builds the Windows release of DOMINION:
#   1. copies the repository's art into the Godot project (prepare-desktop.ps1),
#   2. imports it and exports dist\DOMINION.exe (one file, the game packed inside),
#   3. wraps it in an installer, dist\DOMINION-Setup.exe (the version is in its file properties).
# Needs the Godot 4.7.2 Windows export template (for the portable Godot, in
# .local-tools\godot\editor_data\export_templates\4.7.2.stable) and Inno Setup 6.
# Usage:  powershell -ExecutionPolicy Bypass -File native\build-windows.ps1 [-Version 0.9.0]
param([string]$Version = "")
$ErrorActionPreference = 'Stop'
$native = $PSScriptRoot
$repo = Split-Path -Parent $native
$project = Join-Path $native 'godot'
$dist = Join-Path $repo 'dist'
$godot = Join-Path $repo '.local-tools\godot\Godot_v4.7.2-stable_win64_console.exe'

if (-not $Version) {
    $Version = (Select-String -Path (Join-Path $project 'project.godot') -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
}
# The portable Godot in .local-tools runs self-contained (._sc_), so it keeps its
# templates beside it; an installed Godot keeps them in %APPDATA%.
$template = @((Join-Path $repo '.local-tools\godot\editor_data\export_templates\4.7.2.stable\windows_release_x86_64.exe'),
    (Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $template) { throw 'Godot 4.7.2 Windows export template missing (windows_release_x86_64.exe).' }
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 (ISCC.exe) was not found. Install it with: winget install JRSoftware.InnoSetup' }

Write-Output "Building DOMINION $Version"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $native 'prepare-desktop.ps1')
New-Item -ItemType Directory -Force -Path $dist | Out-Null
& $godot --headless --path $project --import | Out-Null
$exe = Join-Path $dist 'DOMINION.exe'
if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
& $godot --headless --path $project --export-release 'Windows Desktop' $exe
if (-not (Test-Path -LiteralPath $exe)) { throw 'The Godot export did not produce dist\DOMINION.exe' }
# dist\ holds exactly two files: DOMINION.exe (the game, to play and test) and
# DOMINION-Setup.exe (the one release for the public; its version is inside the
# file, in its properties). Older numbered installers are removed.
Get-ChildItem -LiteralPath $dist -Filter 'DOMINION-Setup*.exe' | Remove-Item -Force
& $iscc "/DAppVersion=$Version" (Join-Path $native 'installer\dominion.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed ($LASTEXITCODE)" }
Get-ChildItem -LiteralPath $dist -Filter 'DOMINION*.exe' | ForEach-Object { '{0}  {1:N0} MB' -f $_.Name, ($_.Length / 1MB) }
