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

Assert-Contains $main 'local offset_divisor = math.max(1, balanced("loot_offset_divisor", 3))' 'tier geometry'
Assert-Contains $main 'local max_offset = math.max(0, radius / offset_divisor)' 'tier geometry'
$lootDivisors = @{ 1=3; 2=5; 3=10 }
foreach ($tier in 1..3) {
    foreach ($radius in @(60, 111, 180, 240)) {
        $divisor = $lootDivisors[$tier]
        $max = $radius / [double]$divisor
        $expected = $radius / [double]$lootDivisors[$tier]
        if ([Math]::Abs($max - $expected) -gt 0.0000001) { throw "T$tier geometry mismatch radius=$radius" }
    }
}

$artifactProfiles = @{
    'tier_1'=@('artifact_offset_fraction_min = 0.35','artifact_offset_fraction_max = 0.80','loot_offset_divisor = 3')
    'tier_2'=@('artifact_offset_fraction_min = 0.10','artifact_offset_fraction_max = 0.20','loot_offset_divisor = 5')
    'tier_3'=@('artifact_offset_fraction_min = 0.06','artifact_offset_fraction_max = 0.12','loot_offset_divisor = 10')
}
$artifactRanges = @{
    1=@(0.35,0.80)
    2=@(0.10,0.20)
    3=@(0.06,0.12)
}
foreach ($section in $artifactProfiles.Keys) {
    $sectionMatch = [regex]::Match($ltx, "(?ms)^\[$([regex]::Escape($section))\]\s*(.*?)(?=^\[|\z)")
    if (-not $sectionMatch.Success) { throw "artifact geometry profile missing: $section" }
    foreach ($needle in $artifactProfiles[$section]) {
        if (-not $sectionMatch.Value.Contains($needle)) { throw "artifact geometry $section missing: $needle" }
    }
}
foreach ($tier in 1..3) {
    $minimum, $maximum = $artifactRanges[$tier]
    if ($minimum -lt 0 -or $maximum -lt $minimum -or $maximum -gt 1) { throw "invalid T$tier artifact fraction range" }
    foreach ($radius in @(55, 85, 150, 180, 220, 240)) {
        $limit = $radius * $maximum
        if ($limit -gt $radius -or $limit -lt 0) { throw "T$tier artifact limit invalid radius=$radius" }
    }
}
foreach ($needle in @(
    'balanced("artifact_offset_fraction_min", 0.35)',
    'balanced("artifact_offset_fraction_max", 0.80)',
    'snapped_offset <= offset_limit',
    'artifact placement tier=%s level=%s offset=%s fraction=%s limit=%s range=%s..%s'
)) {
    Assert-Contains $main $needle 'artifact geometry'
}
foreach ($needle in @(
    'local artifact_center_failures = {}',
    'local ARTIFACT_RETRY_SUMMARY_MS = 60000',
    'report_artifact_center_failure(artifact_id)',
    'retries continue, duplicate errors suppressed',
    'artifact center retry pending id=%s failures=%s; duplicate ERROR suppressed',
    'artifact_center_failures[tostring(artifact_id)] = nil'
)) {
    Assert-Contains $main $needle 'artifact retry rate limit'
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
foreach ($icon in @(
    @{ Node='rvm_exact_artifact_icon_spot'; Width=14 },
    @{ Node='rvm_exact_loot_icon_spot'; Width=14 },
    @{ Node='rvm_exact_enemy_icon_spot'; Width=15 }
)) {
    $match = [regex]::Match($xml, '<' + $icon.Node + '\s+([^>]+)>')
    if (-not $match.Success -or -not $match.Groups[1].Value.Contains("width=`"$($icon.Width)`" height=`"$($icon.Width)`"")) {
        throw "exact icon size mismatch: $($icon.Node)"
    }
}
Assert-Contains $main 'if debug_enabled() then return debug_text end' 'exact marker debug hint'
Assert-Contains $main 'return ""' 'icon-only user exact marker'
Assert-Contains $main 'local hint = game.translate_string("st_rvm_sorties_area_hint") .. zone_debug_text(zone, false)' 'normal circle tooltip'
if ($main.Contains('user_exact_overlaps_zone')) { throw 'circle tooltip suppression must not remain' }

Write-Output 'Geometry and cascade policy test: OK'
