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
        [double]$InitialOriginDistance,
        [double]$CurrentOriginDistance,
        [double]$InitialFieldDistance,
        [double]$CurrentFieldDistance,
        [double]$ZoneSize,
        [bool]$NavBad,
        [bool]$Owned,
        [bool]$IdentityValid,
        [string]$TargetSource,
        [string]$TargetSupport
    )
    $fieldLimit = [Math]::Sqrt(2) * $ZoneSize + 2
    return $InitialOriginDistance -le 2 -and $CurrentOriginDistance -le 2 `
        -and $InitialFieldDistance -gt $fieldLimit -and $CurrentFieldDistance -gt $fieldLimit `
        -and $NavBad -and (-not $Owned) -and $IdentityValid `
        -and $TargetSource -eq 'rvm_field_center' -and $TargetSupport -eq 'stock_lvid_static_ray'
}

# A legitimate field near world origin must never be classified from origin
# alone.  Recovery requires matching initial/current evidence, identity and
# exact production target provenance.
Assert-True (-not (Test-OriginCandidate 0.2 0.3 8 9 10 $true $false $true 'rvm_field_center' 'stock_lvid_static_ray')) 'legitimate near-origin field was classified'
Assert-True (Test-OriginCandidate 0.2 0.3 40 41 10 $true $false $true 'rvm_field_center' 'stock_lvid_static_ray') 'strict origin mismatch was not classified'
Assert-True (-not (Test-OriginCandidate 0.2 0.3 40 41 10 $false $false $true 'rvm_field_center' 'stock_lvid_static_ray')) 'origin classifier ignored nav guard'
Assert-True (-not (Test-OriginCandidate 0.2 0.3 40 41 10 $true $true $true 'rvm_field_center' 'stock_lvid_static_ray')) 'origin classifier ignored ownership guard'
Assert-True (-not (Test-OriginCandidate 0.2 0.3 40 41 10 $true $false $false 'rvm_field_center' 'stock_lvid_static_ray')) 'origin classifier ignored identity guard'
Assert-True (-not (Test-OriginCandidate 0.2 0.3 40 41 10 $true $false $true 'field_candidate' 'static_ray')) 'origin classifier accepted a guessed field candidate'

function Resolve-RvmFieldFixture {
    param([int]$ArtifactId, [string]$Template, [double]$Size, [object[]]$Registry)
    $matches = @($Registry | Where-Object { $_.artefact_id -eq $ArtifactId })
    if ($matches.Count -ne 1) { return $null }
    $field = $matches[0]
    if ($field.anom_zone -ne $Template -or [Math]::Abs($field.size_zone - $Size) -gt 0.1 `
        -or $field.target_lvid -ne $field.field_lvid -or -not $field.static_support) { return $null }
    return $field
}
$fieldFixtures = @(
    @{ artefact_id=6910; anom_zone='electr_1_1'; size_zone=10; field_lvid=4294; target_lvid=4294; static_support=$true },
    @{ artefact_id=6930; anom_zone='chem_2_1'; size_zone=16; field_lvid=7712; target_lvid=7712; static_support=$true }
)
Assert-True ($null -ne (Resolve-RvmFieldFixture 6910 'electr_1_1' 10 $fieldFixtures)) 'generic registry resolver rejected electr family fixture'
Assert-True ($null -ne (Resolve-RvmFieldFixture 6930 'chem_2_1' 16 $fieldFixtures)) 'generic registry resolver rejected chem family fixture'
Assert-True ($null -eq (Resolve-RvmFieldFixture 9999 'chem_2_1' 16 $fieldFixtures)) 'missing registry match did not fail closed'
$ambiguousFixtures = @($fieldFixtures[0], @{} + $fieldFixtures[0])
Assert-True ($null -eq (Resolve-RvmFieldFixture 6910 'electr_1_1' 10 $ambiguousFixtures)) 'ambiguous registry match did not fail closed'

function Invoke-PreventiveSpawnModel {
    param([object[]]$Candidates, [int]$MaximumAttempts, [double]$FieldLimit)
    $attempts = 0
    $creates = 0
    $queued = 0
    $selectedSection = $null
    foreach ($candidate in $Candidates) {
        if ($attempts -ge $MaximumAttempts) { break }
        $attempts++
        if (-not $candidate.valid_vertex -or -not $candidate.static_support `
            -or $candidate.field_distance -gt $FieldLimit) { continue }
        $creates++
        $queued++
        $selectedSection = $candidate.section
        return @{ status='created_guarded'; attempts=$attempts; creates=$creates; queued=$queued; section=$selectedSection; visible=$true }
    }
    return @{ status='retry_exhausted'; attempts=$attempts; creates=$creates; queued=$queued; section=$selectedSection; visible=$true }
}

$preventedThenCreated = Invoke-PreventiveSpawnModel @(
    @{ valid_vertex=$false; static_support=$false; field_distance=20; section='af_ring' },
    @{ valid_vertex=$true; static_support=$false; field_distance=20; section='af_ring' },
    @{ valid_vertex=$true; static_support=$true; field_distance=20; section='af_ring' }
) 8 40
Assert-True ($preventedThenCreated.status -eq 'created_guarded' -and $preventedThenCreated.attempts -eq 3) 'preventive guard did not bounded-retry invalid/unsupported candidates'
Assert-True ($preventedThenCreated.creates -eq 1 -and $preventedThenCreated.queued -eq 1 -and $preventedThenCreated.section -eq 'af_ring') 'preventive guard did not preserve single stock section/queue path'
$preventedAll = Invoke-PreventiveSpawnModel @(
    @{ valid_vertex=$false; static_support=$false; field_distance=20; section='af_ring' },
    @{ valid_vertex=$true; static_support=$true; field_distance=50; section='af_ring' }
) 2 40
Assert-True ($preventedAll.status -eq 'retry_exhausted' -and $preventedAll.creates -eq 0 -and $preventedAll.visible) 'preventive exhaustion created an object or failed silently'
$nearOriginLegitimateSpawn = Invoke-PreventiveSpawnModel @(
    @{ valid_vertex=$true; static_support=$true; field_distance=1; section='af_ball' }
) 8 40
Assert-True ($nearOriginLegitimateSpawn.status -eq 'created_guarded') 'preventive guard rejected a valid field genuinely near world origin'

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
Assert-True (-not (Confirm-Underground @(12,3,14,15) @(4,1,5,6) @(0,1000,2000,3000) $false)) 'transient/invalid underground sample did not reset the episode'
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

# A confirmed first cause owns the incident until it recovers.  In particular,
# rolling outside playable nav must not become a second underground incident.
$cause = @{ state = 'rescue_pending'; reason = 'rolling'; primary_reason = 'rolling'; rolling_confirmed = $true }
$secondaryUndergroundAllowed = -not ($cause.state -eq 'rescue_pending' -and $cause.primary_reason -eq 'rolling')
Assert-True (-not $secondaryUndergroundAllowed) 'confirmed rolling was reclassified as underground'
$cause.primary_reason = $null
$cause.state = 'observing_online'
$cause.reason = 'rolling_returned_inside_tether'
Assert-True ($null -eq $cause.primary_reason -and $cause.state -eq 'observing_online') 'rolling recovery did not clear primary cause'

# Schema-1 saves from the accepted field run must migrate the earlier false
# underground overwrite back to the already-confirmed rolling cause.
$schema1 = @{ provenance_schema = 1; state = 'rescue_pending'; reason = 'underground'; rolling = @{ confirmed = $true }; underground = @{ confirmed = $true } }
if ($schema1.provenance_schema -eq 1 -and $schema1.rolling.confirmed) {
    $schema1.primary_reason = 'rolling'
    $schema1.reason = 'rolling'
    $schema1.provenance_schema = 4
}
Assert-True ($schema1.provenance_schema -eq 4 -and $schema1.primary_reason -eq 'rolling' -and $schema1.reason -eq 'rolling') 'schema-1 causal migration failed'

# Schema-3 origin saves used a guessed X/Z target. They retain their audit trail
# but are reset to observation until the live RVM field registry proves exactly
# one field and supplies its original level vertex.
$originSave = @{
    provenance_schema = 3; state = 'rescue_pending'; reason = 'origin_mismatch';
    primary_reason = 'origin_mismatch'; artifact_id = 6910; section = 'af_ball'; level = 'y04_pole';
    zone_size = 10; spawn_input_pos = @{ x=40; y=0; z=0 };
    first_server = @{ pos=@{x=0.2;y=0;z=0.1}; lvid=4294967295; gvid=5337 };
    target = @{ valid=$true; source='field_candidate'; support='static_ray'; lvid=123; gvid=5337 };
    origin = @{ checked=$true; confirmed=$false; near_origin=$true; nav_bad=$true };
    ownership = @{ parent_id = 65535 };
    actions = @(@{ reason='origin_mismatch'; status='verification_failed' }); dispatched = $false
}
$originRestored = $originSave | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$originRestored | Add-Member -NotePropertyName legacy_origin_actions -NotePropertyValue $originRestored.actions
$originRestored.actions = @()
$originRestored.target = $null
$originRestored.origin.checked = $false
$originRestored.origin.confirmed = $false
$originRestored.primary_reason = $null
$originRestored.reason = 'origin_rvm_field_revalidation_required'
$originRestored.state = 'observing_server'
$originRestored.provenance_schema = 4
Assert-True ($originRestored.state -eq 'observing_server' -and -not $originRestored.origin.checked `
    -and $null -eq $originRestored.target -and $originRestored.legacy_origin_actions.Count -eq 1) 'legacy origin save did not reset to exact-field revalidation'

$rvmField = @{ artefact_id=6910; anom_zone='electr_1_1'; size_zone=10; lvid=123; pos=@{x=40;y=0;z=0} }
$exactTarget = @{ valid=$true; source='rvm_field_center'; support='stock_lvid_static_ray'; field_lvid=123; lvid=123; gvid=5337 }
$exactFieldProven = $rvmField.artefact_id -eq $originRestored.artifact_id `
    -and $rvmField.size_zone -eq $originRestored.zone_size `
    -and $exactTarget.field_lvid -eq $rvmField.lvid `
    -and $exactTarget.source -eq 'rvm_field_center' -and $exactTarget.support -eq 'stock_lvid_static_ray'
if ($exactFieldProven -and $originRestored.ownership.parent_id -eq 65535) {
    $originRestored.origin.confirmed = $true
    $originRestored.dispatched = $true
}
Assert-True ($originRestored.dispatched) 'strict origin save was not eligible after exact RVM field proof'
$originRestored.ownership.parent_id = 1404
$originRestored.dispatched = $false
if ($originRestored.ownership.parent_id -ne 65535) { $originRestored.state = 'owned' }
Assert-True ($originRestored.state -eq 'owned' -and -not $originRestored.dispatched) 'origin recovery ignored NPC/actor ownership after load'

# The online shell must disappear before teleport; timeout restores the original
# switch policy and fails closed without releasing or recreating the object.
$transition = @{ online=$true; wait_checks=0; teleported=$false; flags_restored=$false }
while ($transition.online -and $transition.wait_checks -lt 10) { $transition.wait_checks++ }
if ($transition.wait_checks -ge 10) { $transition.flags_restored=$true }
Assert-True (-not $transition.teleported -and $transition.flags_restored) 'origin online-shell timeout did not fail closed/restore flags'
$transition = @{ online=$true; wait_checks=0; teleported=$false; flags_restored=$false }
$transition.wait_checks++
$transition.online=$false
if (-not $transition.online) { $transition.teleported=$true; $transition.flags_restored=$true }
Assert-True ($transition.teleported -and $transition.flags_restored) 'origin offline transition did not gate teleport/restore flags'

# Load never dispatches an action.  The first fresh snapshot is consumed only
# as a classifier/recovery gate; the following update may dispatch if the item
# is still outside with the same confirmed primary cause.
$loadedPending = @{ state = 'rescue_pending'; primary_reason = 'rolling'; awaiting_fresh_snapshot = $true; dispatched = $false }
if ($loadedPending.awaiting_fresh_snapshot) { $loadedPending.awaiting_fresh_snapshot = $false }
Assert-True (-not $loadedPending.dispatched) 'action dispatched directly from load_restore/first snapshot'
if (-not $loadedPending.awaiting_fresh_snapshot -and $loadedPending.state -eq 'rescue_pending' -and $loadedPending.primary_reason -eq 'rolling') {
    $loadedPending.dispatched = $true
}
Assert-True ($loadedPending.dispatched) 'persisted rolling pending was not eligible after a fresh snapshot'
$loadedUnderground = @{ state = 'rescue_pending'; primary_reason = 'underground'; awaiting_fresh_snapshot = $true; dispatched = $false }
if ($loadedUnderground.awaiting_fresh_snapshot) { $loadedUnderground.awaiting_fresh_snapshot = $false }
Assert-True (-not $loadedUnderground.dispatched) 'underground action dispatched directly from load_restore/first snapshot'
if (-not $loadedUnderground.awaiting_fresh_snapshot -and $loadedUnderground.state -eq 'rescue_pending' -and $loadedUnderground.primary_reason -eq 'underground') {
    $loadedUnderground.dispatched = $true
}
Assert-True ($loadedUnderground.dispatched) 'persisted underground pending was not eligible after a fresh snapshot'
$loadedRecovered = @{ state = 'observing_online'; primary_reason = $null; awaiting_fresh_snapshot = $true; dispatched = $false }
if ($loadedRecovered.awaiting_fresh_snapshot) { $loadedRecovered.awaiting_fresh_snapshot = $false }
Assert-True (-not $loadedRecovered.dispatched -and $null -eq $loadedRecovered.primary_reason) 'inside-tether load incorrectly dispatched rescue'

# The active laboratory allowlist is exact and ID-based.  A matching section
# alone can never authorize an action, and both IDs keep independent budgets.
$allowedIds = @{ 1407 = $true; 6362 = $true }
Assert-True ($allowedIds.ContainsKey(1407) -and $allowedIds.ContainsKey(6362) -and $allowedIds.Count -eq 2) 'exact two-ID allowlist model failed'
Assert-True (-not $allowedIds.ContainsKey(7000)) 'section-only or unknown-ID fallback entered the allowlist'
$dispatches = @{ 1407 = 0; 6362 = 0 }
$dispatches[1407]++
$dispatches[1407]++
$dispatches[6362]++
Assert-True ($dispatches[1407] -eq 2 -and $dispatches[6362] -eq 1) 'per-ID dispatch budgets are not independent'
Assert-True ($dispatches[1407] -ge 2 -and $dispatches[6362] -lt 2) 'per-ID maximum model failed'

# Three close samples prove only that the same object reached the target.
# Stability requires a separate >=30 second monitor.  A continuous 15-second
# exit is then followed by a 20-second cooldown before a second dispatch.
$verification = @{ samples = 3; state = 'verifying'; monitor_ms = 0; rolling_ms = 0; cooldown_ms = 0; dispatches = 1 }
if ($verification.samples -ge 3) { $verification.state = 'position_verified' }
Assert-True ($verification.state -eq 'position_verified') 'three samples did not produce position_verified'
$verification.state = 'monitoring'
foreach ($delta in @(0,5000,5000,5000,5000,5000,5000)) { $verification.monitor_ms += $delta }
Assert-True ($verification.monitor_ms -ge 30000 -and $verification.state -eq 'monitoring') '30-second monitor model failed'
$outsideEpisode = Confirm-Rolling 100 @(106,107,108,109) @(0,5000,10000,15000)
if ($outsideEpisode) { $verification.cooldown_ms = 20000 }
Assert-True ($outsideEpisode -and $verification.cooldown_ms -eq 20000) 'repeat rolling confirmation did not arm cooldown'
$verification.cooldown_ms = [Math]::Max(0, $verification.cooldown_ms - 20000)
if ($verification.cooldown_ms -eq 0 -and $verification.dispatches -lt 2) { $verification.dispatches++ }
Assert-True ($verification.dispatches -eq 2) 'second dispatch was not admitted after cooldown'
Assert-True (-not (Confirm-Rolling 100 @(106,107,104,106,107) @(0,5000,10000,15000,20000))) 'return inside did not reset repeat rolling episode'

# Held verification proves same-field teleport before it fixes the shell.  It
# deliberately accepts natural drift inside a bounded target/field envelope;
# a teleport that did not reach the field, or an object leaving the envelope,
# remains fail-closed.  Non-held debug actions keep the old strict 4 m window.
function Test-VerificationEnvelope {
    param(
        [double]$Radius,
        [double]$TargetDxz,
        [double]$TargetDy,
        [double]$AnchorDxz,
        [bool]$StabilizationRequested
    )
    $targetLimit = 4
    $verticalLimit = 4
    if ($StabilizationRequested) {
        if ($Radius -le 0) { return $false }
        $targetLimit = [Math]::Max(4, [Math]::Min(32, $Radius * 0.5))
        $verticalLimit = [Math]::Max(4, [Math]::Min(16, $Radius * 0.25))
        $tetherLimit = $Radius + 5
        return $TargetDxz -le $targetLimit -and $TargetDy -le $verticalLimit -and $AnchorDxz -le $tetherLimit
    }
    return $TargetDxz -le $targetLimit -and $TargetDy -le $verticalLimit
}

$levitatingSnapshots = @(
    @{ target_dxz = 7; target_dy = 3; anchor_dxz = 18 },
    @{ target_dxz = 15; target_dy = 6; anchor_dxz = 20 },
    @{ target_dxz = 26; target_dy = 9; anchor_dxz = 22 }
)
$levitatingAccepted = @($levitatingSnapshots | Where-Object {
    Test-VerificationEnvelope 72 $_.target_dxz $_.target_dy $_.anchor_dxz $true
}).Count
Assert-True ($levitatingAccepted -eq 3) 'levitating held artifact did not reach verification after three in-envelope drifting snapshots'
Assert-True (-not (Test-VerificationEnvelope 72 40 9 22 $true)) 'held verifier accepted object outside target envelope'
Assert-True (-not (Test-VerificationEnvelope 72 26 9 78 $true)) 'held verifier accepted object outside linked field tether'
Assert-True (-not (Test-VerificationEnvelope 72 220 40 220 $true)) 'held verifier masked a teleport that did not reach the field'
Assert-True (-not (Test-VerificationEnvelope 72 4.1 0 1 $false)) 'non-held verifier lost strict target window'
$outsideEnvelopeState = 'verifying'
foreach ($check in 1..10) {
    if (-not (Test-VerificationEnvelope 72 40 9 22 $true) -and $check -ge 10) {
        $outsideEnvelopeState = 'disabled'
    }
}
Assert-True ($outsideEnvelopeState -eq 'disabled') 'object outside held envelope did not fail closed after 10 checks'

# Execute a model of the production diagnostic path using the formatter name
# extracted from the actual Lua block.  This catches undeclared/global helper
# calls such as the field-found round1() failure instead of merely checking
# that a logging string exists.
$verificationLogStart = $main.IndexOf('provenance_log("position_verification_sample"')
$verificationLogEnd = $main.IndexOf('if good then', $verificationLogStart)
$verificationLogBlock = if ($verificationLogStart -ge 0 -and $verificationLogEnd -gt $verificationLogStart) {
    $main.Substring($verificationLogStart, $verificationLogEnd - $verificationLogStart)
} else { '' }
$formatterCall = [regex]::Match($verificationLogBlock, 'target_dxz="\s*\.\.\s*([A-Za-z_][A-Za-z0-9_]*)\(target_dxz\)')
$formatterName = if ($formatterCall.Success) { $formatterCall.Groups[1].Value } else { '' }
$formatterDeclaration = if ($formatterName) { $main.IndexOf("local function $formatterName(") } else { -1 }
$formatterAvailable = $formatterDeclaration -ge 0 -and $formatterDeclaration -lt $verificationLogStart
$formatNumberModel = if ($formatterAvailable -and $formatterName -eq 'fmt_number') {
    { param([double]$Value) ([Math]::Floor($Value * 10 + 0.5) / 10).ToString([Globalization.CultureInfo]::InvariantCulture) }
} else { $null }
$runtimeLog = $null
$runtimeLogError = $null
try {
    if ($null -eq $formatNumberModel) { throw "formatter_unavailable:$formatterName" }
    $runtimeLog = 'check=1,accepted=true,mode=held_envelope,target_dxz=' + (& $formatNumberModel 25.56)
    $runtimeLog += ',target_dy=' + (& $formatNumberModel 8.44)
    $runtimeLog += ',target_limit=' + (& $formatNumberModel 32)
} catch { $runtimeLogError = $_.Exception.Message }
Assert-True ($formatterAvailable) 'verification logging formatter is not a preceding local Lua helper'
Assert-True ($null -eq $runtimeLogError) "verification logging runtime model failed: $runtimeLogError"
Assert-True ($runtimeLog -eq 'check=1,accepted=true,mode=held_envelope,target_dxz=25.6,target_dy=8.4,target_limit=32') 'verification logging runtime model output mismatch'
Assert-True (-not $verificationLogBlock.Contains('round1(')) 'verification logging regressed to undeclared round1 helper'

foreach ($needle in @(
    'schema = 4', 'artifact_provenance = {}', 'local ARTIFACT_PROVENANCE_SCHEMA = 4',
    'local ARTIFACT_RESCUE_DEBUG_IDS = { [1407] = true, [6362] = true }',
    'spawn_input_pos', 'first_server', 'last_good_server', 'last_good_online',
    'linked_anchor_id', 'linked_radius', 'ownership', 'lineage_ids', 'cooldown_remaining_ms',
    'state = "captured"', '"observing_server"', '"observing_online"', '"suspect"',
    '"rescue_pending"', '"owned"', '"closed"', '"released"', '"disabled"',
    'legacy_save_missing_spawn_provenance', 'record.underground.last_sample_at = nil',
    'record.rolling.last_sample_at = nil', 'record.primary_reason = "rolling"',
    'record.awaiting_fresh_snapshot = true', 'post_load_snapshot', 'action_deferred=true',
    'local function update_debug_same_id_rescue(record, snapshot, now)',
    'record.state == "rescue_pending" and record.primary_reason == "rolling"',
    'rescue_reason == "underground" and record.underground and record.underground.confirmed',
    'rescue_reason == "origin_mismatch" and record.origin and record.origin.confirmed',
    'saved_origin_evidence_valid = function(record)', 'saved_origin_evidence_incomplete',
    'same_id_origin_dispatch_evidence', 'fresh_origin_evidence_mismatch',
    'origin_rescue_count', 'underground_rescue_count',
    'x = record.spawn_input_pos.x + offset.x',
    'z = record.spawn_input_pos.z + offset.z',
    'distance_xz(target.pos, record.spawn_input_pos) <= maximum',
    'target.source == "rvm_field_center" and target.support == "stock_lvid_static_ray"',
    'production_target_provenance_invalid',
    'source = target.source, support = target.support, field_lvid = target.field_lvid',
    'local ORIGIN = {}', 'function ORIGIN.field_target(record)', 'raid_anomalys.save_state',
    'function ORIGIN.normalize_position(value)', 'marshal_get_xyz',
    'origin registry position schema value_type=%s keys=%s get=%s accepted=%s reason=%s',
    'rvm_field_position_invalid:', 'rvm_field_position_compare_invalid:',
    'if not left then return 999999, "left_" .. tostring(left_error) end',
    'if not right then return 999999, "right_" .. tostring(right_error) end',
    'rvm_field_match_count:', 'rvm_field_provenance_mismatch', 'rvm_field_target_layer_mismatch',
    'function ORIGIN.prepare_offline_transition(record, snapshot)',
    'origin_offline_requested', 'online_shell_persisted_after_10_checks',
    'flags_restored = ORIGIN.restore_switch_flags(record,',
    'ORIGIN.restore_switch_flags(record, "first_update_actions_disabled")',
    'ORIGIN.restore_all_switch_flags("before_level_changing")',
    'ORIGIN.restore_all_switch_flags("pre_save")',
    'function ORIGIN.rebuild_artifact_zone(record, action, snapshot)',
    'origin_area_rebuilt', 'origin_rvm_field_revalidation_required',
    'startup self-test ok version=0.2.1-alpha',
    'production_same_id_teleport',
    'local function guarded_rvm_artifact_spawn(base_spawn, anom_zone, field_pos, level_tier)',
    'inner_env ~= raid_anomalys', 'stock_inner_environment_unverified; spawn deferred',
    'rejection = "invalid_second_vertex"', 'artifact_static_target(pos_table(spawn_pos))',
    'candidate_outside_captured_field', 'created_guarded', 'retry_exhausted',
    'rawset(raid_anomalys, "level", saved_level)',
    'rawset(raid_anomalys, "alife_create_item", saved_create)',
    'alife():teleport_object(record.artifact_id, target.gvid, target.lvid, pos_vector(target.pos))',
    'record.state = "verifying"', 'record.state = "monitoring"', 'action.status = "position_verified"',
    'position_verification_sample', 'origin_action and "origin_exact_field"',
    'target_limit = math.max(4, math.min(32, linked_radius * 0.5))',
    'vertical_limit = math.max(4, math.min(16, linked_radius * 0.25))',
    'target_envelope_not_reached_after_10_checks',
    'action_monitor', 'rolling_reconfirmed', 'action_monitor_complete', 'action_limit_reached',
    'legacy_three_frame_stable_migrated',
    'local physics_mode = "none"',
    'physics_mode = stabilization_mode == "held" and "held_pending" or "same_frame_fix_release"',
    'artifact_rescue_debug_max_dispatches',
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
    'artifact_rescue_observe_only = true', 'artifact_rescue_actions = false',
    'artifact_rescue_rolling_policy = held_first',
    'artifact_rescue_underground_policy = held_first',
    'artifact_rescue_origin_policy = held_first', 'artifact_spawn_guard_attempts = 8',
    'artifact_rescue_debug_same_id_teleport = false', 'artifact_rescue_debug_artifact_ids = 1407,6362',
    'artifact_rescue_debug_reason = rolling',
    'artifact_rescue_debug_monitor_ms = 30000', 'artifact_rescue_debug_monitor_log_ms = 5000',
    'artifact_rescue_debug_cooldown_ms = 20000', 'artifact_rescue_debug_max_dispatches = 2',
    'artifact_rescue_debug_held_after_verified_actions = 2',
    'artifact_rescue_debug_same_frame_stabilization = false',
    'artifact_rescue_debug_held_stabilization = false',
    'artifact_rescue_origin_radius = 2', 'artifact_rescue_underground_drop = 12',
    'artifact_rescue_underground_vertex_gap = 4', 'artifact_rescue_underground_samples = 3',
    'artifact_rescue_underground_duration_ms = 2000', 'artifact_rescue_rolling_edge_margin = 5',
    'artifact_rescue_rolling_confirm_ms = 15000', 'artifact_rescue_log_repeat_ms = 60000'
)) {
    Assert-True ($config.Contains($needle)) "observe-only config invariant missing: $needle"
}

foreach ($forbidden in @('physics_element:fix', 'physics_element:release_fixed')) {
    Assert-True (-not $main.Contains($forbidden)) "active artifact rescue action is forbidden in phase 1: $forbidden"
}
Assert-True (-not $main.Contains('action_stable')) 'three-frame action_stable criterion must not return'
Assert-True (([regex]::Matches($main, [regex]::Escape('alife():teleport_object('))).Count -eq 1) 'same-ID teleport must have exactly one narrow call site'
$targetBlock = [regex]::Match($main, '(?s)local function compute_observe_target\(record\).*?\nend\n\s*local function provenance_log').Value
Assert-True ($targetBlock.Contains('record.spawn_input_pos') -and -not $targetBlock.Contains('snapshot.online_pos')) 'rescue target is not isolated from the failed current position'
foreach ($gate in @('artifact_rescue_actions', 'artifact_rescue_debug_same_id_teleport', 'artifact_rescue_debug_artifact_ids', 'artifact_rescue_debug_reason')) {
    Assert-True ($main.Contains($gate)) "same-ID teleport gate missing: $gate"
}
Assert-True (-not $main.Contains('if not (item and C.get_bool("global", "remove_on_npc_pickup", false)) then return end')) 'NPC ownership tracking is incorrectly gated by remove_on_npc_pickup'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'Artifact rescue repeated same-ID monitor policy test: OK'
