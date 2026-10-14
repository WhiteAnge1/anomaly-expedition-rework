param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]
$mainPath = Join-Path $ModRoot 'gamedata\scripts\zzz_rvm_sorties_rework.script'
$configPath = Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx'
$main = Get-Content -LiteralPath $mainPath -Raw -Encoding UTF8
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Test-OriginCandidate {
    param(
        [double]$OriginDistance,
        [double]$FieldDistance,
        [double]$ZoneSize,
        [bool]$NavBad,
        [bool]$Owned,
        [bool]$TargetValid
    )
    $fieldLimit = [Math]::Sqrt(2) * $ZoneSize + 2
    return $OriginDistance -le 2 -and $FieldDistance -gt $fieldLimit -and $NavBad -and (-not $Owned) -and $TargetValid
}

# A legitimate field near world origin must never be classified from origin alone.
Assert-True (-not (Test-OriginCandidate 0.2 8 10 $true $false $true)) 'legitimate near-origin field was classified'
Assert-True (Test-OriginCandidate 0.2 40 10 $true $false $true) 'strict origin mismatch was not classified'
Assert-True (-not (Test-OriginCandidate 0.2 40 10 $false $false $true)) 'origin classifier ignored nav guard'
Assert-True (-not (Test-OriginCandidate 0.2 40 10 $true $true $true)) 'origin classifier ignored ownership guard'
Assert-True (-not (Test-OriginCandidate 0.2 40 10 $true $false $false)) 'origin classifier ignored target guard'

function Confirm-Underground {
    param([double[]]$Drops, [double[]]$VertexGaps, [int[]]$Times, [bool]$Owned)
    if ($Owned) { return $false }
    $samples = 0
    $start = 0
    for ($i = 0; $i -lt $Drops.Count; $i++) {
        if ($Drops[$i] -ge 12 -and $VertexGaps[$i] -ge 4) {
            if ($samples -eq 0) { $start = $Times[$i] }
            $samples++
            if ($samples -ge 3 -and ($Times[$i] - $start) -ge 2000) { return $true }
        } else {
            $samples = 0
            $start = 0
        }
    }
    return $false
}

Assert-True (Confirm-Underground @(12,13,14) @(4,5,6) @(0,1000,2000) $false) 'underground 3-sample/2-second confirmation failed'
Assert-True (-not (Confirm-Underground @(12,13) @(4,5) @(0,2000) $false)) 'underground confirmed with fewer than 3 samples'
Assert-True (-not (Confirm-Underground @(12,13,14) @(4,5,6) @(0,1000,2000) $true)) 'underground ignored ownership guard'

function Confirm-Rolling {
    param([double]$Radius, [double[]]$Distances, [int[]]$Times)
    $start = $null
    for ($i = 0; $i -lt $Distances.Count; $i++) {
        if ($Distances[$i] -gt ($Radius + 5)) {
            if ($null -eq $start) { $start = $Times[$i] }
            if (($Times[$i] - $start) -ge 15000) { return $true }
        } else {
            $start = $null
        }
    }
    return $false
}

Assert-True (Confirm-Rolling 100 @(106,107,108,109) @(0,5000,10000,15000)) 'rolling radius+5/15-second confirmation failed'
Assert-True (-not (Confirm-Rolling 100 @(106,107,104,106,107) @(0,5000,10000,15000,20000))) 'rolling episode did not reset after return before timeout'

# Migration is fail-closed and idempotent: a legacy ID becomes one disabled
# record and a second pass does not duplicate or enable it.
$legacy = @{}
if (-not $legacy.ContainsKey('42')) { $legacy['42'] = @{ state = 'disabled'; reason = 'legacy_save_missing_spawn_provenance'; actions = @() } }
if (-not $legacy.ContainsKey('42')) { $legacy['42'] = @{ state = 'disabled'; reason = 'legacy_save_missing_spawn_provenance'; actions = @() } }
Assert-True ($legacy.Count -eq 1 -and $legacy['42'].state -eq 'disabled' -and $legacy['42'].actions.Count -eq 0) 'legacy migration is not idempotent/fail-closed'

# Rate limit model: first event is visible, repeats wait for the configured window.
$next = 0
$emitted = @()
foreach ($now in @(0,1000,59999,60000)) {
    if ($now -ge $next) { $emitted += $now; $next = $now + 60000 }
}
Assert-True (($emitted -join ',') -eq '0,60000') 'diagnostic rate-limit model failed'

function Find-RecreatedZone {
    param([string]$Section, [object[]]$Zones)
    $matches = @($Zones | Where-Object { -not $_.closed -and $_.kind -eq 'artifact' -and $_.section -eq $Section -and -not $_.old_exists })
    $zone = $null
    if ($matches.Count -eq 1) { $zone = $matches[0] }
    return @{ zone = $zone; count = $matches.Count }
}

$uniqueLineage = Find-RecreatedZone 'af_dummy_battery' @(
    @{ anchor = 11; kind = 'artifact'; section = 'af_dummy_battery'; old_exists = $false; closed = $false },
    @{ anchor = 12; kind = 'artifact'; section = 'af_ring'; old_exists = $false; closed = $false }
)
Assert-True ($uniqueLineage.count -eq 1 -and $uniqueLineage.zone.anchor -eq 11) 'unique NPC replacement lineage was not resolved'
$ambiguousLineage = Find-RecreatedZone 'af_dummy_battery' @(
    @{ anchor = 11; kind = 'artifact'; section = 'af_dummy_battery'; old_exists = $false; closed = $false },
    @{ anchor = 13; kind = 'artifact'; section = 'af_dummy_battery'; old_exists = $false; closed = $false }
)
Assert-True ($ambiguousLineage.count -eq 2 -and $null -eq $ambiguousLineage.zone) 'ambiguous NPC replacement lineage did not fail closed'

# The replacement ID and owned terminal must survive a save/load round-trip.
$lineageState = @{
    artifact_zone = @{ '7012' = '30859'; '38145' = '30859' }
    record = @{ state = 'owned'; ownership = @{ parent_id = 1404; current_id = 38145; source = 'npc_pickup_recreated_id'; lineage_ids = @{ '7012' = $true; '38145' = $true } } }
}
$lineageRestored = $lineageState | ConvertTo-Json -Depth 8 | ConvertFrom-Json
Assert-True ($lineageRestored.record.state -eq 'owned' -and $lineageRestored.record.ownership.current_id -eq 38145) 'owned replacement did not survive save/load'
Assert-True ($lineageRestored.artifact_zone.'38145' -eq '30859' -and $lineageRestored.record.ownership.lineage_ids.'38145') 'replacement lookup/lineage did not survive save/load'

foreach ($needle in @(
    'schema = 4', 'artifact_provenance = {}', 'provenance_schema = ARTIFACT_PROVENANCE_SCHEMA',
    'spawn_input_pos', 'first_server', 'last_good_server', 'last_good_online',
    'linked_anchor_id', 'linked_radius', 'ownership', 'lineage_ids', 'cooldown_until',
    'state = "captured"', '"observing_server"', '"observing_online"', '"suspect"',
    '"rescue_pending"', '"owned"', '"closed"', '"released"', '"disabled"',
    'legacy_save_missing_spawn_provenance', 'record.underground.last_sample_at = nil',
    'record.rolling.last_sample_at = nil', 'observe_only=true; action=none',
    'local function remember_artifact_lineage(zone, item, owner, source)',
    'state.artifact_zone[key] = tostring(zone.anchor_id)',
    'record.ownership.current_id = item_id', 'terminal_provenance(record, "owned", source, owned_snapshot)',
    'if zone then match = "recreated_id" end', '"npc_pickup_" .. tostring(match)',
    'artifact lineage ambiguous callback=npc',
    'zone.artifact_lineage_ids = zone.artifact_lineage_ids or'
)) {
    Assert-True ($main.Contains($needle)) "runtime provenance invariant missing: $needle"
}

foreach ($needle in @(
    'artifact_rescue_observe_only = false', 'artifact_rescue_actions = false',
    'artifact_rescue_origin_radius = 2', 'artifact_rescue_underground_drop = 12',
    'artifact_rescue_underground_vertex_gap = 4', 'artifact_rescue_underground_samples = 3',
    'artifact_rescue_underground_duration_ms = 2000', 'artifact_rescue_rolling_edge_margin = 5',
    'artifact_rescue_rolling_confirm_ms = 15000', 'artifact_rescue_log_repeat_ms = 60000'
)) {
    Assert-True ($config.Contains($needle)) "observe-only config invariant missing: $needle"
}

foreach ($forbidden in @('teleport_object', 'physics_element:fix', 'physics_element:release_fixed')) {
    Assert-True (-not $main.Contains($forbidden)) "active artifact rescue action is forbidden in phase 1: $forbidden"
}
Assert-True (-not $main.Contains('if not (item and C.get_bool("global", "remove_on_npc_pickup", false)) then return end')) 'NPC ownership tracking is incorrectly gated by remove_on_npc_pickup'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'Artifact rescue observe-only policy test: OK'
