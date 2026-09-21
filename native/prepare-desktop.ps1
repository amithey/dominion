$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$assetDir = Join-Path $PSScriptRoot 'godot\assets'
New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
$sources = @(
    'assets\models\quaternius-characters\CharacterSoldier.glb',
    'assets\models\kenney-city\building-a.glb',
    'assets\models\kenney-city\building-b.glb',
    'assets\models\kenney-city\building-c.glb',
    'assets\models\kenney-suburban\House_A.glb',
    'assets\models\kenney-suburban\House_B.glb',
    'assets\models\kenney-suburban\House_C.glb',
    'assets\textures\terrain\grass_color.jpg'
)
foreach ($relative in $sources) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $relative) -Destination $assetDir -Force
}
$textureDir = Join-Path $assetDir 'Textures'
New-Item -ItemType Directory -Force -Path $textureDir | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'assets\models\kenney-city\Textures\colormap.png') -Destination $textureDir -Force
Write-Output 'Desktop prototype assets prepared from the existing local library.'
