# Regenerates native/godot/data/map-seed<N>.json from the browser game, so the
# Godot world picks up new config.js data (units, buildings, economy, AI,
# combat, logistics). Needs Node.js and Microsoft Edge (or Chrome).
# Usage:  powershell -ExecutionPolicy Bypass -File native/export-map.ps1 [-Seed 1]
param([int]$Seed = 1, [int]$Port = 3017)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $PSScriptRoot "godot\data\map-seed$Seed.json"
$work = Join-Path $env:TEMP "dominion-export"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$target = Join-Path $work "map.json"
if (Test-Path -LiteralPath $target) { [System.IO.File]::Delete($target) }

# One small Node process serves the game and saves the map the page POSTs back.
$serverScript = @'
const http=require('http'),fs=require('fs'),path=require('path');
const [root,target,port]=process.argv.slice(2);
const types={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.glb':'model/gltf-binary','.gltf':'model/gltf+json','.svg':'image/svg+xml'};
http.createServer((q,s)=>{
  if(q.method==='POST'){let b='';q.on('data',d=>b+=d);q.on('end',()=>{fs.writeFileSync(target,b);s.end('ok');setTimeout(()=>process.exit(0),200);});return;}
  let p=decodeURIComponent(q.url.split('?')[0]);if(p.endsWith('/'))p+='index.html';
  const file=path.join(root,p);
  fs.readFile(file,(e,data)=>{if(e){s.statusCode=404;s.end();return;}s.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');s.end(data);});
}).listen(+port);
'@
$serverFile = Join-Path $work "serve-and-collect.cjs"
Set-Content -LiteralPath $serverFile -Value $serverScript -Encoding utf8
$server = Start-Process node -ArgumentList "`"$serverFile`"", "`"$repo`"", "`"$target`"", $Port -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2

$browser = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$profileDir = Join-Path $work "profile"
$url = "http://localhost:$Port/?seed=$Seed&export=http://localhost:$Port/map"
Start-Process $browser -ArgumentList "--user-data-dir=`"$profileDir`"", '--no-first-run', '--window-size=1280,800', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', "--app=$url" | Out-Null
try {
    $deadline = (Get-Date).AddSeconds(90)
    while (-not (Test-Path -LiteralPath $target) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
    if (-not (Test-Path -LiteralPath $target)) { throw "The browser did not export the map within 90 seconds." }
    Start-Sleep -Milliseconds 500
    Copy-Item -LiteralPath $target -Destination $out -Force
    Write-Output "Exported seed $Seed to $out"
} finally {
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe'" | Where-Object { $_.CommandLine -like "*dominion-export*" } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }
    try { Stop-Process -Id $server.Id -Force -ErrorAction Stop } catch {}
}
