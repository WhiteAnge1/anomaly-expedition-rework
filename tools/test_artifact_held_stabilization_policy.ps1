param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]
$main = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\scripts\zzz_rvm_sorties_rework.script') -Raw -Encoding UTF8
$config = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx') -Raw -Encoding UTF8

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Resolve-Mode([bool]$SameFrame, [bool]$Held) {
    if ($SameFrame -and $Held) { return 'conflict' }
    if ($Held) { return 'held' }
    if ($SameFrame) { return 'same_frame' }
    return 'none'
}

Assert-True ((Resolve-Mode $false $false) -eq 'none') 'stabilization unexpectedly defaults on'
Assert-True ((Resolve-Mode $false $true) -eq 'held') 'held-only mode was not selected'
Assert-True ((Resolve-Mode $true $true) -eq 'conflict') 'same-frame and held gates were not rejected as a conflict'

function Held-TimeoutReached([int]$ConfiguredTimeout, [int]$Duration) {
    if ($ConfiguredTimeout -le 0) { return $false }
    return $Duration -ge [Math]::Max(30000, $ConfiguredTimeout)
}

Assert-True (-not (Held-TimeoutReached 0 999999999)) 'held timeout 0 did not disable automatic release'
Assert-True (Held-TimeoutReached 120000 120000) 'positive held timeout no longer releases at its deadline'

function Resolve-PostTeleportHeld([string]$RecordReason, [string]$PersistedActionReason, [bool]$ReacquireAndFix) {
    $effectiveReason = if ($PersistedActionReason) { $PersistedActionReason } else { $RecordReason }
    if ($effectiveReason -ne 'rolling') { return 'record_disabled_gate' }
    if (-not $ReacquireAndFix) { return 'record_disabled_fix' }
    return 'held'
}

Assert-True ((Resolve-PostTeleportHeld 'post_rescue_monitor' 'rolling' $true) -eq 'held') 'held_pending was rejected after position_verified changed record.reason'
Assert-True ((Resolve-PostTeleportHeld 'post_rescue_monitor' 'rolling' $false) -eq 'record_disabled_fix') 'real post-teleport reacquire/fix failure did not fail closed'

function Resolve-EarlyProductionHeld([double[]]$FreshVerticalDelta) {
    $held = $false
    $accepted = 0
    $repositions = 0
    foreach ($delta in $FreshVerticalDelta) {
        if ($held -or $delta -le 2) {
            $accepted++
            if ($accepted -eq 1) { $held = $true }
        } else {
            $accepted = 0
            $repositions++
        }
    }
    return @{ held = $held; accepted = $accepted; repositions = $repositions }
}

$fastFaller = Resolve-EarlyProductionHeld @(3.9, 0.2, 0.2, 0.2)
Assert-True ($fastFaller.held -and $fastFaller.accepted -eq 3 -and $fastFaller.repositions -eq 1) `
    'delayed underground sample was accepted instead of repositioning before held verification'

function Resolve-HeldOnlineLifecycle([bool[]]$Online, [bool[]]$Fixed, [bool[]]$SafeAfterReposition) {
    $awaiting = $false
    $dispatches = 1
    $reapply = 0
    for ($i = 0; $i -lt $Online.Count; $i++) {
        if (-not $Online[$i]) { $awaiting = $true; continue }
        if ($Fixed[$i] -and -not $awaiting) { continue }
        if ($Fixed[$i] -and $awaiting) { $awaiting = $false; continue }
        if (-not $SafeAfterReposition[$i]) { continue }
        $reapply++
        $awaiting = $false
    }
    return @{ dispatches = $dispatches; reapply = $reapply; awaiting = $awaiting }
}

$offlineRecreate = Resolve-HeldOnlineLifecycle @($true,$false,$true,$true) @($true,$false,$false,$true) @($false,$false,$true,$true)
Assert-True ($offlineRecreate.dispatches -eq 1 -and $offlineRecreate.reapply -eq 1 -and -not $offlineRecreate.awaiting) `
    'offline/online shell recreation consumed another rescue or failed to reapply held state'

function Resolve-StabilizationRequest([int]$ActionCount, [int]$VerifiedOrdinary, [string]$Mode, [int]$HeldAfterVerified) {
    $threshold = if ($Mode -eq 'held') { [Math]::Min(2, [Math]::Max(0, $HeldAfterVerified)) } else { 2 }
    return $ActionCount -eq $threshold -and $VerifiedOrdinary -ge $threshold -and @('held','same_frame').Contains($Mode)
}

Assert-True (Resolve-StabilizationRequest 0 0 'held' 0) 'test-only held threshold 0 did not request real stabilization on first rolling'
Assert-True (-not (Resolve-StabilizationRequest 0 0 'held' 2)) 'debug held threshold 2 no longer requires two verified ordinary rescues'
Assert-True (Resolve-StabilizationRequest 2 2 'held' 2) 'debug two-rescue held policy was lost'
Assert-True (-not (Resolve-StabilizationRequest 0 0 'same_frame' 0)) 'held test override leaked into same-frame mode'

function Resolve-EffectiveMaximum([int]$ActionCount, [bool]$Requested, [bool]$AlreadyDispatched, [int]$OrdinaryMaximum) {
    if ($AlreadyDispatched) { return $ActionCount }
    if ($Requested) { return $ActionCount + 1 }
    return $OrdinaryMaximum
}

Assert-True ((Resolve-EffectiveMaximum 0 $true $false 2) -eq 1) 'production first held dispatch maximum is not one'
Assert-True ((Resolve-EffectiveMaximum 1 $false $true 2) -eq 1) 'production policy allowed another rescue after held dispatch'

function Resolve-RescuePolicy([bool]$Observe, [bool]$Actions, [string]$RollingPolicy, [string]$UndergroundPolicy, [string]$Reason, [bool]$ExactDebugId) {
    if (-not $Observe -or -not $Actions -or @('rolling','underground') -notcontains $Reason) { return 'none' }
    $Policy = if ($Reason -eq 'rolling') { $RollingPolicy } else { $UndergroundPolicy }
    if ($Policy -eq 'held_first') { return 'held_first' }
    if ($Policy -eq 'debug_teleport' -and $ExactDebugId) { return 'debug_teleport' }
    return 'none'
}

Assert-True ((Resolve-RescuePolicy $true $true 'held_first' 'held_first' 'rolling' $false) -eq 'held_first') 'production rolling policy still depends on exact debug ID'
Assert-True ((Resolve-RescuePolicy $true $true 'held_first' 'held_first' 'underground' $false) -eq 'held_first') 'production underground policy still depends on exact debug ID'
Assert-True ((Resolve-RescuePolicy $true $false 'held_first' 'held_first' 'underground' $false) -eq 'none') 'production master gate default is not safe'
Assert-True ((Resolve-RescuePolicy $true $true 'held_first' 'off' 'underground' $false) -eq 'none') 'underground policy off still authorized an action'
Assert-True ((Resolve-RescuePolicy $true $true 'held_first' 'held_first' 'origin_mismatch' $false) -eq 'none') 'production policy leaked into origin rescue'
Assert-True ((Resolve-RescuePolicy $true $true 'debug_teleport' 'held_first' 'rolling' $false) -eq 'none') 'debug policy ignored exact-ID gate'

# Journal ownership: only elements observed unfixed and successfully fixed by
# this action enter the persistent release list.
$elements = @(
    @{ index = 0; pre_fixed = $true; fix_ok = $true; confirmed_fixed = $true },
    @{ index = 1; pre_fixed = $false; fix_ok = $true; confirmed_fixed = $true },
    @{ index = 2; pre_fixed = $false; fix_ok = $false; confirmed_fixed = $false }
)
$journal = @($elements | Where-Object { -not $_.pre_fixed -and $_.fix_ok -and $_.confirmed_fixed } | ForEach-Object { $_.index })
Assert-True (($journal -join ',') -eq '1') 'held journal included a pre-fixed or unconfirmed element'

$releaseReasons = @('held_gate_disabled','owner_parent_changed','current_level_changed','held_timeout','load_recovery','pre_save','before_level_changing','terminal_owned','terminal_closed','terminal_released')
Assert-True ($releaseReasons.Count -eq 10) 'held release trigger model is incomplete'

foreach ($needle in @(
    'local release_held_stabilization = nil',
    'local release_all_held_stabilizations = nil',
    'local attempt_held_stabilization = nil',
    'local function active_held_action(record)',
    'release_held_stabilization = function(record, snapshot, reason)',
    'release_all_held_stabilizations = function(reason)',
    'local function held_target_snapshot_safe(record, action, snapshot)',
    'local function dispatch_held_target_reposition(record, action, snapshot, now, context, holder)',
    'local function held_shell_still_fixed(record, held)',
    'local function maintain_held_stabilization(record, snapshot, now)',
    'attempt_held_stabilization = function(record, action, snapshot, phase)',
    'mode = "held"', 'status = "held_attempting"', 'active = false',
    'action.held_pending = true', 'status = "held_pending"',
    'if action.held_pending then', 'local early_production = action.rescue_policy == "held_first"',
    'action.status == "verifying" and (action.verification_samples or 0) >= 1',
    'record, action.reason, action.rescue_policy)',
    'local held_error = "held_gate_unavailable"',
    'post_teleport_position_not_verified', 'post_teleport_held_stabilization',
    'held.element_indices[#held.element_indices + 1] = candidate.index',
    'for _, element_index in ipairs(held.element_indices or {}) do',
    'pcall(function() candidate.element:fix() end)',
    'pcall(function() element:release_fixed() end)',
    'action_stabilization_held_attempt', 'action_stabilization_held',
    'action_stabilization_held_repositioned', 'action_stabilization_held_offline',
    'action_stabilization_held_reapply_dispatched', 'action_stabilization_held_reapplied',
    'action_stabilization_held_released', 'action_stabilization_held_release_pending',
    '"held_gate_disabled"', '"owner_parent_changed"', '"current_level_changed"',
    '"held_timeout"', '"load_recovery"', '"pre_save"', '"before_level_changing"',
    'release_zone_held_on_pickup',
    'action.stabilization.release_required = true',
    'held.release_required = true',
    'stabilization_mode == "held"', 'local physics_mode = "none"',
    'physics_mode = stabilization_mode == "held" and "held_pending" or "same_frame_fix_release"',
    'artifact_rescue_debug_held_after_verified_actions',
    'local stabilization_after_verified = rescue_policy == "held_first" and 0',
    'or stabilization_mode == "held" and held_after_verified or 2',
    'local function artifact_rescue_action_policy(record, persisted_reason)',
    'if policy == "held_first" then return policy end',
    'or reason == "underground" and "artifact_rescue_underground_policy"',
    'or "artifact_rescue_origin_policy"',
    'rescue_policy = rescue_policy',
    'local production_held = action.rescue_policy == "held_first"',
    'local configured_timeout = production_held and 0',
    'local effective_max_dispatches = stabilization_already_dispatched and action_count',
    'or stabilization_requested and (action_count + 1) or ordinary_max_dispatches'
)) {
    Assert-True ($main.Contains($needle)) "held stabilization invariant missing: $needle"
}

$updateStart = $main.IndexOf('local function update_debug_same_id_rescue(record, snapshot, now)')
$dispatchStart = $main.IndexOf('local action = {', $updateStart)
$teleport = $main.IndexOf('alife():teleport_object(', $dispatchStart)
$pending = $main.IndexOf('action.held_pending = true', $teleport)
$dispatchedLog = $main.IndexOf('provenance_log("action_dispatched"', $pending)
$goodBranch = $main.IndexOf('if good then', $updateStart)
$sampleIncrement = $main.IndexOf('action.verification_samples = (action.verification_samples or 0) + 1', $goodBranch)
$earlyHeldGate = $main.IndexOf('action.held_pending and action.rescue_policy == "held_first"', $sampleIncrement)
$heldAttemptCall = $main.IndexOf('attempt_held_stabilization(record, action, snapshot)', $earlyHeldGate)
$verifiedThreshold = $main.IndexOf('if action.verification_samples >= 3 then', $heldAttemptCall)
$verifiedLog = $main.IndexOf('provenance_log("position_verified"', $updateStart)
$persistedMode = $main.IndexOf('record, action.reason, action.rescue_policy)', $verifiedLog)
$pendingCleared = $main.IndexOf('action.held_pending = false', $heldAttemptCall)
$failedGuard = $main.IndexOf('if not held_ok then', $pendingCleared)
$failClosed = $main.IndexOf('disable_provenance(record, "post_teleport_held_stabilization"', $failedGuard)
Assert-True ($teleport -gt $dispatchStart -and $pending -gt $teleport -and $dispatchedLog -gt $pending) 'held dispatch is not journaled as pending after teleport'
Assert-True ($goodBranch -gt $updateStart -and $sampleIncrement -gt $goodBranch -and $earlyHeldGate -gt $sampleIncrement `
    -and $heldAttemptCall -gt $earlyHeldGate -and $verifiedThreshold -gt $heldAttemptCall) `
    'production held fix is not attempted after the first accepted fresh snapshot and before three-sample verification'
Assert-True ($verifiedLog -gt $verifiedThreshold -and $persistedMode -gt $verifiedLog) 'position_verified path lost its persisted action reason'
Assert-True ($main.IndexOf('attempt_held_stabilization(record, action, snapshot)', $teleport) -eq -1) 'held fix is still attempted in the dispatch callback'
Assert-True ($pendingCleared -gt $heldAttemptCall -and $failedGuard -gt $pendingCleared -and $failClosed -gt $failedGuard) 'real post-teleport held failure is not fail closed after the attempt'
Assert-True ($main.Contains('local timeout = configured_timeout > 0 and math.max(30000, configured_timeout) or 0')) 'held timeout zero-disable semantics missing'
Assert-True ($main.Contains('if timeout > 0 and held.duration_ms >= timeout then')) 'held timeout release is not guarded by a positive timeout'

foreach ($needle in @(
    'artifact_rescue_debug_same_frame_stabilization = false',
    'artifact_rescue_rolling_policy = held_first',
    'artifact_rescue_underground_policy = held_first',
    'artifact_rescue_origin_policy = held_first',
    'artifact_rescue_debug_held_after_verified_actions = 2',
    'artifact_rescue_debug_held_stabilization = false',
    'artifact_rescue_debug_held_timeout_ms = 120000'
)) {
    Assert-True ($config.Contains($needle)) "held config invariant missing: $needle"
}

$saveStart = $main.IndexOf('local function save_state(m_data)')
$saveRelease = $main.IndexOf('release_all_held_stabilizations, "pre_save"', $saveStart)
$serialize = $main.IndexOf('m_data.rvm_sorties_rework = state', $saveStart)
Assert-True ($saveStart -ge 0 -and $saveRelease -gt $saveStart -and $saveRelease -lt $serialize) 'pre-save release does not precede serialization'

$levelStart = $main.IndexOf('local function on_before_level_changing()')
$levelRelease = $main.IndexOf('release_all_held_stabilizations, "before_level_changing"', $levelStart)
$transition = $main.IndexOf('state.pending_transition = true', $levelStart)
Assert-True ($levelStart -ge 0 -and $levelRelease -gt $levelStart -and $levelRelease -lt $transition) 'level-change release does not precede transition journal'

$maintain = $main.IndexOf('maintain_held_stabilization(record, snapshot, now)', $updateStart)
$terminalGuard = $main.IndexOf('if record.disabled or record.state == "owned"', $updateStart)
Assert-True ($maintain -gt $updateStart -and $maintain -lt $terminalGuard) 'load/disabled held release is not processed before terminal guards'

$heldBlock = [regex]::Match($main, '(?s)attempt_held_stabilization = function\(.*?\nend\n\s*local function update_debug_same_id_rescue').Value
foreach ($forbidden in @('apply_force(', 'apply_torque(', 'set_switch_online', 'set_switch_offline', 'alife_create(')) {
    Assert-True (-not $heldBlock.Contains($forbidden)) "forbidden held mechanism detected: $forbidden"
}
Assert-True (-not $heldBlock.Contains('release_fixed()')) 'successful held setup released the object in the same callback'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'Artifact rescue held stabilization lifecycle policy test: OK'
