# Read-only release gate: the launcher and installer must ship the same source version.
param([string]$Directory = '', [string]$ExpectedVersion = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $Directory) { $Directory = Join-Path $repo 'dist' }
if (-not $ExpectedVersion) {
    $ExpectedVersion = (Select-String -LiteralPath (Join-Path $PSScriptRoot 'godot\project.godot') -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
}
$preset = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'godot\export_presets.cfg') -Raw
foreach ($field in @('file_version', 'product_version')) {
    if ($preset -notmatch ('application/' + $field + '="' + [regex]::Escape($ExpectedVersion + '.0') + '"')) {
        throw "Export preset $field does not match $ExpectedVersion."
    }
}
foreach ($name in @('DOMINION.exe', 'DOMINION-Setup.exe')) {
    $file = Get-Item -LiteralPath (Join-Path $Directory $name)
    $fileVersion = $file.VersionInfo.FileVersion.Trim()
    if ($file.Length -lt 1MB -or $fileVersion -ne ($ExpectedVersion + '.0')) {
        throw "$name has version $($file.VersionInfo.FileVersion); expected $ExpectedVersion.0. Rebuild both canonical files."
    }
    [pscustomobject]@{
        File = $file.Name
        Version = $fileVersion
        Bytes = $file.Length
        SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
