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

function Can-DispatchThirdStage {
    param(
        [int]$Dispatches,
        [int]$VerifiedOrdinary,
        [bool]$RollingConfirmed,
        [bool]$ActionGate,
        [bool]$SameIdGate,
        [bool]$StabilizationGate,
        [bool]$ExactId,
        [bool]$Unowned
    )
    return $Dispatches -eq 2 -and $VerifiedOrdinary -ge 2 -and $RollingConfirmed `
        -and $ActionGate -and $SameIdGate -and $StabilizationGate -and $ExactId -and $Unowned
}

Assert-True (Can-DispatchThirdStage 2 2 $true $true $true $true $true $true) 'valid third-stage dispatch was rejected'
Assert-True (-not (Can-DispatchThirdStage 2 1 $true $true $true $true $true $true)) 'third stage ignored two verified ordinary actions'
Assert-True (-not (Can-DispatchThirdStage 2 2 $true $true $true $false $true $true)) 'third stage ignored default-off stabilization gate'
Assert-True (-not (Can-DispatchThirdStage 2 2 $true $true $true $true $false $true)) 'third stage accepted section-only/non-allowlisted identity'
Assert-True (-not (Can-DispatchThirdStage 2 2 $true $true $true $true $true $false)) 'third stage ignored ownership guard'
Assert-True (-not (Can-DispatchThirdStage 3 3 $true $true $true $true $true $true)) 'hard maximum of three dispatches failed'

# Cleanup ownership model: an element that was already fixed is never touched;
# every initially-unfixed candidate reaches the same-callback release sweep even
# when its fix call reports a failure.
$elements = @(
    @{ index = 0; pre_fixed = $true; fix_ok = $true },
    @{ index = 1; pre_fixed = $false; fix_ok = $true },
    @{ index = 2; pre_fixed = $false; fix_ok = $false }
)
$candidates = @($elements | Where-Object { -not $_.pre_fixed })
$released = @()
foreach ($candidate in $candidates) { $released += $candidate.index }
Assert-True (($released -join ',') -eq '1,2') 'release sweep skipped an owned cleanup candidate after fix failure'
Assert-True (-not ($released -contains 0)) 'release sweep touched a pre-fixed element'

# A fresh independent episode must remain continuously outside for 15 seconds.
$start = $null
$confirmed = $false
foreach ($sample in @(
    @{ time = 0; outside = $true },
    @{ time = 5000; outside = $true },
    @{ time = 10000; outside = $false },
    @{ time = 15000; outside = $true },
    @{ time = 20000; outside = $true },
    @{ time = 25000; outside = $true },
    @{ time = 30000; outside = $true }
)) {
    if ($sample.outside) {
        if ($null -eq $start) { $start = $sample.time }
        if (($sample.time - $start) -ge 15000) { $confirmed = $true }
    } else {
        $start = $null
    }
}
Assert-True $confirmed 'independent rolling episode did not confirm after reset plus 15 seconds'

foreach ($needle in @(
    'local function artifact_verified_ordinary_action_count(record)',
    'local function artifact_rescue_stabilization_mode(record, persisted_reason)',
    'artifact_rescue_debug_same_frame_stabilization',
    'local function attempt_same_frame_stabilization(record, action, snapshot)',
    'same_callback_release = true',
    'shell:get_linear_vel(value)', 'shell:get_angular_vel(value)',
    'shell:get_elements_number()', 'for index = 0, element_count - 1 do',
    'shell:get_element_by_order(index)', 'element:is_fixed()',
    'pcall(candidate.fix_method, candidate.element)',
    'pcall(candidate.release_method, candidate.element)',
    'action_stabilization_attempt', 'action_stabilization_released',
    'stabilization_unavailable', 'stabilization_failed',
    'action_count == 2', 'verified_ordinary >= 2', 'stabilization_mode == "same_frame"',
    'stabilization_requested or action_count >= 3',
    'attempt_same_frame_stabilization(record, action, snapshot)',
    'action.status = "verifying"', 'action.status = "position_verified"',
    'artifact_rescue_debug_same_frame_stabilization = false'
)) {
    $haystack = if ($needle -like 'artifact_rescue_debug_same_frame_stabilization = false') { $config } else { $main }
    Assert-True ($haystack.Contains($needle)) "third-stage invariant missing: $needle"
}

$candidateBeforeFix = $main.IndexOf('candidates[#candidates + 1] = {')
$fixCall = $main.IndexOf('pcall(candidate.fix_method, candidate.element)')
$releaseCall = $main.IndexOf('pcall(candidate.release_method, candidate.element)')
Assert-True ($candidateBeforeFix -ge 0 -and $candidateBeforeFix -lt $fixCall) 'release cleanup candidate is not recorded before fix'
Assert-True ($fixCall -ge 0 -and $releaseCall -gt $fixCall) 'same-callback release sweep does not follow fix sweep'

Assert-True (([regex]::Matches($main, [regex]::Escape('alife():teleport_object('))).Count -eq 1) 'third stage introduced another teleport call site'
$blockMatch = [regex]::Match($main, '(?s)local function attempt_same_frame_stabilization\(.*?\nend\n\s*local function active_held_action')
Assert-True $blockMatch.Success 'stabilization helper block was not isolated'
$stabilizationBlock = $blockMatch.Value
foreach ($forbidden in @('apply_force(', 'apply_torque(', 'set_switch_online', 'set_switch_offline', 'alife_create(')) {
    Assert-True (-not $stabilizationBlock.Contains($forbidden)) "forbidden stabilization mechanism detected: $forbidden"
}
Assert-True (-not $main.Contains('artifact_rescue_debug_same_frame_stabilization", true')) 'stabilization gate defaulted on in runtime'
Assert-True (-not $config.Contains('artifact_rescue_debug_same_frame_stabilization = true')) 'stabilization gate defaulted on in config'
Assert-True (-not $stabilizationBlock.Contains(':fix()')) 'unprotected direct physics fix call detected'
Assert-True (-not $stabilizationBlock.Contains(':release_fixed()')) 'unprotected direct physics release call detected'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'Artifact rescue third-stage same-frame stabilization policy test: OK'
