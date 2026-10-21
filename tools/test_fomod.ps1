param([string]$ModRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path
$variantRoot = Join-Path $ModRoot 'installer\variants'
$basePath = Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx'
$modulePath = Join-Path $ModRoot 'fomod\ModuleConfig.xml'

function Read-Ltx([string]$Path) {
    $result = @{}
    $section = ''
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = ($raw -split ';', 2)[0].Trim()
        if (-not $line) { continue }
        if ($line -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($line -match '^([^=]+)=(.*)$') {
            $key = "$section/$($Matches[1].Trim())"
            if ($result.ContainsKey($key)) { throw "Duplicate LTX key in $Path`: $key" }
            $result[$key] = $Matches[2].Trim()
        }
    }
    return $result
}

$base = Read-Ltx $basePath
$allowedDifferences = @{
    'global/debug_mode' = $true
    'global/artifact_rescue_observe_only' = $true
    'global/enable_enemy_decoys' = $true
    'global/enable_loot_decoys' = $true
    'global/enable_empty_decoys' = $true
    'global/show_exact_artifact_markers' = $true
    'global/show_exact_loot_markers' = $true
    'global/show_exact_enemy_markers' = $true
}
$counts = @{ recommended = 0; observe = 0; diagnostic = 0 }
$variants = @(Get-ChildItem -LiteralPath $variantRoot -Directory)
if ($variants.Count -ne 136) { throw "Expected 136 full variants, found $($variants.Count)" }

foreach ($folder in $variants) {
    if ($folder.Name -notmatch '^(recommended|observe|diagnostic)-z([01])([01])([01])-m([01])([01])([01])$') {
        throw "Invalid variant name: $($folder.Name)"
    }
    $profile, $enemy, $loot, $empty = $Matches[1], $Matches[2], $Matches[3], $Matches[4]
    $artifactMarker, $lootMarker, $enemyMarker = $Matches[5], $Matches[6], $Matches[7]
    if ($profile -eq 'diagnostic' -and "$artifactMarker$lootMarker$enemyMarker" -ne '000') {
        throw "Diagnostic marker toggles must be canonical 000: $($folder.Name)"
    }
    $counts[$profile]++
    $path = Join-Path $folder.FullName 'rvm_sorties_rework.ltx'
    $config = Read-Ltx $path
    if ($config.Count -ne $base.Count) { throw "Variant is not a full LTX: $($folder.Name)" }
    foreach ($key in $base.Keys) {
        if (-not $config.ContainsKey($key)) { throw "Variant missing $key`: $($folder.Name)" }
        if (-not $allowedDifferences.ContainsKey($key) -and $config[$key] -ne $base[$key]) {
            throw "Unexpected difference $key in $($folder.Name)"
        }
    }
    $expectedDebug = if ($profile -eq 'diagnostic') { 'on' } else { 'off' }
    $expectedObserve = if ($profile -eq 'recommended') { 'false' } else { 'true' }
    $expected = @{
        'global/debug_mode' = $expectedDebug
        'global/artifact_rescue_observe_only' = $expectedObserve
        'global/artifact_rescue_actions' = 'false'
        'global/artifact_proactive_hold' = 'true'
        'artifact_pool/profile' = 'weighted'
        'global/enable_enemy_decoys' = @('false','true')[[int]$enemy]
        'global/enable_loot_decoys' = @('false','true')[[int]$loot]
        'global/enable_empty_decoys' = @('false','true')[[int]$empty]
        'global/show_exact_artifact_markers' = @('false','true')[[int]$artifactMarker]
        'global/show_exact_loot_markers' = @('false','true')[[int]$lootMarker]
        'global/show_exact_enemy_markers' = @('false','true')[[int]$enemyMarker]
        'global/debug_force_decoy_type' = 'off'
        'global/debug_force_tier' = '0'
        'global/debug_cleanup_current_sortie' = 'false'
    }
    foreach ($entry in $expected.GetEnumerator()) {
        if ($config[$entry.Key] -ne $entry.Value) {
            throw "Variant $($folder.Name) has $($entry.Key)=$($config[$entry.Key]), expected $($entry.Value)"
        }
    }
}
if ($counts.recommended -ne 64 -or $counts.observe -ne 64 -or $counts.diagnostic -ne 8) {
    throw "Profile variant counts invalid: recommended=$($counts.recommended), observe=$($counts.observe), diagnostic=$($counts.diagnostic)"
}

[xml]$module = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
$patterns = @($module.config.conditionalFileInstalls.patterns.pattern)
if ($patterns.Count -ne 136) { throw "Expected 136 conditional patterns, found $($patterns.Count)" }
$sources = @{}
foreach ($pattern in $patterns) {
    $source = [string]$pattern.files.file.source
    if ($sources.ContainsKey($source)) { throw "Duplicate FOMOD variant source: $source" }
    $sources[$source] = $true
    if (-not (Test-Path -LiteralPath (Join-Path $ModRoot $source))) { throw "Missing FOMOD variant source: $source" }
    if ([string]$pattern.files.file.destination -ne 'gamedata\configs\plugins\rvm_sorties_rework.ltx') {
        throw "Unexpected FOMOD destination for $source"
    }
}
if ($sources.Count -ne $variants.Count) { throw 'FOMOD patterns and variant directories differ' }

Write-Output 'FOMOD matrix: OK (136 complete LTX variants; 64 Recommended, 64 Observe-only, 8 Diagnostic)'
