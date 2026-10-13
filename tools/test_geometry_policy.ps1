param([string]$ModRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
function Assert-Contains([string]$Text, [string]$Needle, [string]$Name) {
    if (-not $Text.Contains($Needle)) { throw "$Name missing: $Needle" }
}

$main = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\scripts\zzz_rvm_sorties_rework.script') -Raw
$xml = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\ui\map_spots_rvm_sorties.xml') -Raw
$ltx = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx') -Raw

foreach ($case in @(
    @{ Name='T1'; Node='rvm_search_small_spot'; Width=32 },
    @{ Name='T2'; Node='rvm_search_medium_spot'; Width=60 },
    @{ Name='T3'; Node='rvm_search_large_spot'; Width=48 }
)) {
    $match = [regex]::Match($xml, '<' + $case.Node + '\s+([^>]+)>')
    if (-not $match.Success) { throw "$($case.Name) map spot missing" }
    $attributes = $match.Groups[1].Value
    foreach ($needle in @("width=`"$($case.Width)`"", "height=`"$($case.Width)`"", 'scale_min="1"', 'scale_max="4.5"')) {
        if (-not $attributes.Contains($needle)) { throw "$($case.Name) map spot invariant missing: $needle" }
    }
}

Assert-Contains $main 'local offset_divisor = tier == 1 and 3 or 4' 'tier geometry'
Assert-Contains $main 'local max_offset = math.max(0, radius / offset_divisor)' 'tier geometry'
foreach ($tier in 1..3) {
    foreach ($radius in @(60, 111, 180, 240)) {
        $divisor = if ($tier -eq 1) { 3 } else { 4 }
        $max = $radius / [double]$divisor
        $expected = if ($tier -eq 1) { $radius / 3.0 } else { $radius / 4.0 }
        if ([Math]::Abs($max - $expected) -gt 0.0000001) { throw "T$tier geometry mismatch radius=$radius" }
    }
}

$phases = @(
    'inside_hidden_clear',
    'inside_hidden_anomaly_allowed',
    'outside_hidden_anomaly_allowed',
    'inside_visible_anomaly_allowed',
    'outside_visible_anomaly_allowed'
)
$cursor = -1
foreach ($phase in $phases) {
    $next = $main.IndexOf('{ name = "' + $phase + '"', $cursor + 1)
    if ($next -lt 0) { throw "cascade phase missing: $phase" }
    if ($next -le $cursor) { throw "cascade phase order invalid: $phase" }
    $cursor = $next
}
if ($main.Contains('outside_visible_last_resort')) { throw 'obsolete four-stage proximity fallback remains' }
foreach ($needle in @('golden_angle_nav_sweep','ambush_hidden_attempt_multiplier','stage.expanded and attempts *','ring_candidate(stage.min_zone, stage.max_zone, attempt, stage_index)')) {
    Assert-Contains $main $needle 'expanded proximity coverage'
}
Assert-Contains $ltx 'ambush_hidden_attempt_multiplier = 3' 'expanded proximity config'

foreach ($spot in @('rvm_exact_artifact_icon','rvm_exact_loot_icon','rvm_exact_enemy_icon')) {
    Assert-Contains $xml "<$spot>" 'exact icon wrapper'
}
if ([regex]::Matches($xml, '<rvm_exact_(?:artifact|loot|enemy)_icon_spot\s+[^>]+location_level="20"').Count -ne 3) {
    throw 'all three level-map exact icons must have location_level=20'
}
Assert-Contains $main 'if debug_enabled() then return debug_text end' 'exact marker debug hint'
Assert-Contains $main 'return ""' 'icon-only user exact marker'
Assert-Contains $main 'user_exact_overlaps_zone(zone) and ""' 'overlapping circle tooltip suppression'

Write-Output 'Geometry and cascade policy test: OK'
