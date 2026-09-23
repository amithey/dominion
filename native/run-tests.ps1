# Runs every automated test of the Godot game, one after another, and prints a
# table. A test fails if it reports FAIL, does not report PASS, times out, or
# prints any SCRIPT ERROR along the way (an error in code it happened to pass
# through). Also runs the browser game's tests.
# Usage:  powershell -ExecutionPolicy Bypass -File native\run-tests.ps1 [-Exported] [-Quick]
#   -Exported  runs the same tests against dist\DOMINION.exe (the built game)
#   -Quick     skips the long ones (the 12-minute match and the AI war)
param([switch]$Exported, [switch]$Quick)
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $repo '.local-tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$exe = Join-Path $repo 'dist\DOMINION.exe'

$tests = @(
    @('smoke', @('res://main.tscn', '--', '--smoke-test'), 'DESKTOP_SMOKE_PASS', 120),
    @('navigation', @('--', '--nav-test'), 'NAV_TEST PASS', 180),
    @('camera', @('--', '--camera-test'), 'CAMERA_TEST PASS', 180),
    @('movement physics', @('--', '--motion-test'), 'MOTION_TEST PASS', 180),
    @('battle dynamics', @('--', '--battle-test'), 'BATTLE_TEST PASS', 300),
    @('armoured column driving', @('--', '--convoy-test'), 'CONVOY_TEST PASS', 240),
    @('borders, passage and operational zones', @('--', '--border-test'), 'BORDER_TEST PASS', 400),
    @('economy', @('--', '--economy-test'), 'ECONOMY_TEST PASS', 240),
    @('combat (every weapon)', @('--', '--combat-test'), 'COMBAT_TEST PASS', 400),
    @('combat fixes and aircraft service', @('--', '--combat-regression'), 'COMBAT_REGRESSION PASS', 180),
    @('naval recovery, repairs and diplomacy', @('--', '--polish-test'), 'POLISH_TEST PASS', 180),
    @('campaign maps, players and leaders', @('--', '--campaign-test'), 'CAMPAIGN_TEST PASS', 180),
    @('new campaign and map reload flow', @('--script', 'res://tools/campaign-flow-check.gd'), 'CAMPAIGN FLOW PASS', 180),
    @('air and sea', @('--', '--air-sea-test'), 'AIR_SEA_TEST PASS', 240),
    @('diplomacy', @('--', '--diplomacy-test'), 'DIPLOMACY_TEST PASS', 180),
    @('supply network', @('--', '--logistics-test'), 'LOGISTICS_TEST PASS', 240),
    @('market, spies, missiles, territory', @('--', '--systems-test'), 'SYSTEMS_TEST PASS', 300),
    @('research', @('--', '--research-test'), 'RESEARCH_TEST PASS', 300),
    @('interface (every screen and button)', @('--', '--ui-test'), 'UI_TEST PASS', 300),
    @('save and load', @('--', '--save-test'), 'SAVE_TEST PASS', 240),
    @('menus', @('--', '--menu-test'), 'MENU_TEST PASS', 180)
)
if (-not $Quick) {
    $tests += ,@('AI war (hard, fast)', @('--', '--ai-test'), 'AI_TEST PASS', 500)
    $tests += ,@('12-minute match (hard)', @('--', '--soak-test'), 'SOAK_TEST PASS', 600)
}

$results = @()
$runId = [guid]::NewGuid().ToString('N')
foreach ($t in $tests) {
    $name, $testArgs, $pass, $limit = $t
    if ($Exported -and ($testArgs[0] -like 'res://*' -or $testArgs[0] -eq '--script')) { continue }  # alternate scenes and tools are not part of the release
    if ($Exported) { $runner = $exe; $argsList = @('--headless') }
    else { $runner = $godot; $argsList = @('--headless', '--path', ('"{0}"' -f (Join-Path $PSScriptRoot 'godot'))) }
    $argsList += $testArgs
    $out = Join-Path $env:TEMP "dominion-test-$runId.log"
    $start = Get-Date
    $p = Start-Process -FilePath $runner -ArgumentList $argsList -RedirectStandardOutput $out -RedirectStandardError "$out.err" -PassThru -NoNewWindow
    $null = $p.Handle  # without this PowerShell leaves ExitCode empty after a timed wait
    if (-not $p.WaitForExit($limit * 1000)) { $p.Kill(); $status = 'TIMEOUT' }
    else {
        $log = (Get-Content $out -Raw) + (Get-Content "$out.err" -Raw)
        $errors = ([regex]::Matches($log, 'SCRIPT ERROR')).Count
        if ($p.ExitCode -ne 0 -or $log -match '\bFAIL\b' -or $log -notmatch [regex]::Escape($pass)) { $status = 'FAIL' }
        elseif ($errors -gt 0) { $status = "FAIL ($errors script errors)" }
        else { $status = 'PASS' }
    }
    $seconds = [int]((Get-Date) - $start).TotalSeconds
    $results += [pscustomobject]@{ Test = $name; Result = $status; Seconds = $seconds }
    '{0,-40} {1,-22} {2,4}s' -f $name, $status, $seconds
}
if (-not $Exported) {
    Push-Location $repo
    $browser = (npm test 2>&1 | Out-String)
    Pop-Location
    $ok = $browser -match 'fail 0'
    $count = if ($browser -match 'pass (\d+)') { $Matches[1] } else { '?' }
    $results += [pscustomobject]@{ Test = "browser game ($count tests)"; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Seconds = 0 }
    '{0,-40} {1,-22}' -f "browser game ($count tests)", $(if ($ok) { 'PASS' } else { 'FAIL' })
}
$failed = @($results | Where-Object { $_.Result -ne 'PASS' })
''
if ($failed.Count -eq 0) { "ALL $($results.Count) TEST SUITES PASSED" } else { "$($failed.Count) OF $($results.Count) FAILED: $(($failed | ForEach-Object Test) -join ', ')" }
exit $failed.Count
