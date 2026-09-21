$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$assetDir = Join-Path $PSScriptRoot 'godot\assets'

# Copies the repository's existing CC0 assets into the Godot project. The copies
# are ignored by Git; the originals (and their licence files) stay in assets/.
function Copy-Assets($destination, $sources) {
    $target = Join-Path $assetDir $destination
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    foreach ($relative in $sources) {
        Copy-Item -Path (Join-Path $repoRoot $relative) -Destination $target -Force
    }
}

Copy-Assets '.' @(
    'assets\models\quaternius-characters\CharacterSoldier.glb', 'assets\models\quaternius-characters\Worker.glb',
    'assets\models\kenney-suburban\House_D.glb', 'assets\models\quaternius-farm\SiloHouse.glb',
    'assets\models\kenney-city\building-e.glb', 'assets\models\kenney-city\building-g.glb',
    'assets\models\kenney-city\building-a.glb', 'assets\models\kenney-city\building-b.glb',
    'assets\models\kenney-city\building-c.glb', 'assets\models\kenney-city\building-d.glb',
    'assets\models\kenney-city\building-f.glb', 'assets\models\kenney-city\building-h.glb',
    'assets\models\kenney-suburban\House_A.glb', 'assets\models\kenney-suburban\House_B.glb',
    'assets\models\kenney-suburban\House_C.glb',
    'assets\models\quaternius-farm\BigBarn.glb',
    'assets\models\quaternius-tanks\Tank.fbx',
    'assets\models	hree\Soldier.glb',
    'assets\textures\terrain\grass_color.jpg'
)
Copy-Assets 'Textures' @('assets\models\kenney-city\Textures\colormap.png')
Copy-Assets 'terrain' @('assets\textures\terrain\*.jpg')
Copy-Assets 'armor' @('assets\textures\units\armor_*.jpg')
Copy-Assets 'architecture' @('assets\textures\architecture\concrete_*.jpg')
Copy-Assets 'nature' @('assets\models\quaternius-nature\BirchTree_*')
Copy-Assets 'downtown' @('assets\models\quaternius-downtown\Building_Medium_2_001.*', 'assets\models\quaternius-downtown\T_*.png')
Write-Output 'Desktop prototype assets prepared from the existing local library.'
