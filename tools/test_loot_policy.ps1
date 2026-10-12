param([int]$Samples = 200000, [int]$Seed = 20261009)

$ErrorActionPreference = 'Stop'
if ($Samples -lt 10000) { throw 'Samples must be at least 10000' }

function Test-Roll([System.Random]$Rng, [double]$Chance) { return $Rng.NextDouble() -lt $Chance }
function Get-WeightedPick([System.Random]$Rng, [object[]]$Entries) {
    [double]$total = 0
    foreach ($entry in $Entries) { $total += [double]$entry.Weight }
    [double]$roll = $Rng.NextDouble() * $total
    [double]$cursor = 0
    foreach ($entry in $Entries) {
        $cursor += [double]$entry.Weight
        if ($roll -lt $cursor) { return [string]$entry.Name }
    }
    return [string]$Entries[$Entries.Count - 1].Name
}
function Assert-Near([string]$Name, [double]$Observed, [double]$Expected, [double]$Tolerance) {
    if ([Math]::Abs($Observed - $Expected) -gt $Tolerance) {
        throw "$Name outside tolerance: observed=$Observed expected=$Expected tolerance=$Tolerance"
    }
}

$ordinaryNames = @('flashlight_broken','itm_sleepbag','gloves','ecolog_patch','csky_patch','headlamp','walkie','broken_detector','compression_bag','bolt','bolts_pack','hand_watch')
$fragmentNames = @('item_raid_art_fragment_gravi','item_raid_art_fragment_electro','item_raid_art_fragment_chem','item_raid_art_fragment_thermo')
$profiles = @(
    [pscustomobject]@{ Tier=1; Cap=6; MedicineChance=.70; Medicine=@('medkit_army','medkit','antirad','stimpack','caffeine'); Half='medkit_army'; Valuable=@('af_iam','lead_box','detector_simple','detector_advanced','af_cooler','af_freon','af_camelbak','af_frames','af_grid','af_surge','device_torch'); OrdinaryWeight=1.0; WatchWeight=.5; FragmentMin=1; FragmentMax=3 },
    [pscustomobject]@{ Tier=2; Cap=7; MedicineChance=.78; Medicine=@('medkit_army','medkit_scientic','antirad','stimpack_army','drug_booster'); Half='medkit_scientic'; Valuable=@('detector_advanced','detector_elite','af_iam','af_aac','lead_box','af_grid_up','af_freon_up','af_cooler_up','af_camelbak_up','af_frames_up','device_torch_nv_1','device_torch_nv_2'); OrdinaryWeight=.75; WatchWeight=.375; FragmentMin=2; FragmentMax=5 },
    [pscustomobject]@{ Tier=3; Cap=8; MedicineChance=.85; Medicine=@('medkit_scientic','medkit_army','antirad','stimpack_scientic','stimpack_army','adrenalin'); Half='adrenalin'; Valuable=@('detector_elite','detector_scientific','lead_box','af_aac','af_aam','device_torch_nv_3'); OrdinaryWeight=.5; WatchWeight=.25; FragmentMin=3; FragmentMax=7 }
)
$expectedMedicine = @(
    @(0.09, 0.665, 0.245),
    @(0.0484, 0.6474, 0.3042),
    @(0.0225, 0.61625, 0.36125)
)
$expectedValuable = @(0.65, 0.315, 0.034475, 0.000525)
$expectedFragmentUnits = @(1.41, 3.53, 7.46)

foreach ($profile in $profiles) {
    $rng = New-Object System.Random ($Seed + [int]$profile.Tier * 1000)
    $medicineCounts = @(0,0,0)
    $valuableCounts = @(0,0,0,0)
    [long]$ordinaryRolls = 0
    [long]$rareCount = 0
    [long]$fragmentContainers = 0
    [long]$fragmentUnits = 0
    [long]$aamContainers = 0
    [long]$adrenalinAny = 0
    [long]$adrenalinTwo = 0
    [bool]$medicineDuplicateObserved = $false
    [bool]$ordinaryDuplicateObserved = $false
    [int]$maxEntries = 0

    $medicineEntries = @($profile.Medicine | ForEach-Object {
        [pscustomobject]@{ Name=$_; Weight=if ($_ -eq $profile.Half) { .5 } else { 1.0 } }
    })
    $ordinaryEntries = @()
    foreach ($name in $ordinaryNames) {
        $ordinaryEntries += [pscustomobject]@{ Name=$name; Weight=if ($name -eq 'hand_watch') { $profile.WatchWeight } else { $profile.OrdinaryWeight } }
    }
    foreach ($name in $fragmentNames) { $ordinaryEntries += [pscustomobject]@{ Name=$name; Weight=1.0 } }

    for ($sample = 0; $sample -lt $Samples; $sample++) {
        $medicine = @()
        $first = Test-Roll $rng $profile.MedicineChance
        if ($first) { $medicine += Get-WeightedPick $rng $medicineEntries }
        $secondChance = if ($first) { $profile.MedicineChance / 2 } else { $profile.MedicineChance }
        if (Test-Roll $rng $secondChance) { $medicine += Get-WeightedPick $rng $medicineEntries }
        $medicineCounts[$medicine.Count]++
        if ($medicine.Count -eq 2 -and $medicine[0] -eq $medicine[1]) { $medicineDuplicateObserved = $true }
        $adrenalinCount = @($medicine | Where-Object { $_ -eq 'adrenalin' }).Count
        if ($adrenalinCount -gt 0) { $adrenalinAny++ }
        if ($adrenalinCount -eq 2) { $adrenalinTwo++ }

        $quota = 0
        if (Test-Roll $rng .35) {
            $quota = 1
            if (Test-Roll $rng .10) {
                $quota = 2
                if (Test-Roll $rng .015) { $quota = 3 }
            }
        }
        $valuableCounts[$quota]++
        $valuable = @()
        $used = @{}
        while ($valuable.Count -lt $quota) {
            $candidates = @($profile.Valuable | Where-Object { -not $used.ContainsKey($_) })
            if ($candidates.Count -eq 0) { break }
            $picked = [string]$candidates[$rng.Next(0, $candidates.Count)]
            $valuable += $picked
            if (-not ($profile.Tier -eq 3 -and $picked -eq 'lead_box')) { $used[$picked] = $true }
        }
        foreach ($name in @($valuable | Select-Object -Unique)) {
            if ($name -ne 'lead_box' -and @($valuable | Where-Object { $_ -eq $name }).Count -gt 1) { throw "forbidden valuable duplicate: $name" }
        }
        if ($valuable -contains 'af_aam') { $aamContainers++ }

        $capacity = [Math]::Max(1, [int]$profile.Cap - $medicine.Count - $valuable.Count)
        $ordinaryCount = $rng.Next(1, $capacity + 1)
        $ordinaryRolls += $ordinaryCount
        $ordinary = @()
        [int]$containerFragmentUnits = 0
        for ($roll = 0; $roll -lt $ordinaryCount; $roll++) {
            $picked = Get-WeightedPick $rng $ordinaryEntries
            $ordinary += $picked
            if ($fragmentNames -contains $picked) {
                $quantity = $rng.Next([int]$profile.FragmentMin, [int]$profile.FragmentMax + 1)
                $containerFragmentUnits += $quantity
            }
        }
        if (@($ordinary | Select-Object -Unique).Count -lt $ordinary.Count) { $ordinaryDuplicateObserved = $true }
        if ($containerFragmentUnits -gt 0) { $fragmentContainers++ }
        $fragmentUnits += $containerFragmentUnits

        $rare = Test-Roll $rng .04
        if ($rare) { $rareCount++ }
        $entries = $medicine.Count + $valuable.Count + $ordinaryCount + $(if ($rare) { 1 } else { 0 })
        if ($entries -gt $profile.Cap + 1) { throw "tier $($profile.Tier) entry cap exceeded: $entries" }
        if ($ordinaryCount -lt 1) { throw "tier $($profile.Tier) ordinary guarantee violated" }
        if ($entries -gt $maxEntries) { $maxEntries = $entries }
    }

    for ($index = 0; $index -le 2; $index++) { Assert-Near "T$($profile.Tier) medicine[$index]" ($medicineCounts[$index]/[double]$Samples) $expectedMedicine[$profile.Tier-1][$index] .006 }
    for ($index = 0; $index -le 3; $index++) { Assert-Near "T$($profile.Tier) valuable[$index]" ($valuableCounts[$index]/[double]$Samples) $expectedValuable[$index] $(if ($index -eq 3) { .0003 } else { .006 }) }
    Assert-Near "T$($profile.Tier) rare" ($rareCount/[double]$Samples) .04 .003
    Assert-Near "T$($profile.Tier) fragment units" ($fragmentUnits/[double]$Samples) $expectedFragmentUnits[$profile.Tier-1] .30
    if (-not $medicineDuplicateObserved -or -not $ordinaryDuplicateObserved) { throw "tier $($profile.Tier) expected repeat path was not observed" }
    if ($maxEntries -ne $profile.Cap + 1) { throw "tier $($profile.Tier) maximum entry path not observed" }
    if ($profile.Tier -eq 3) {
        Assert-Near 'T3 af_aam' ($aamContainers/[double]$Samples) .06405 .004
        Assert-Near 'T3 adrenalin any' ($adrenalinAny/[double]$Samples) .11872 .005
        Assert-Near 'T3 adrenalin two' ($adrenalinTwo/[double]$Samples) .00299 .001
    }
    Write-Output ("T{0} samples={1} med=({2:N4},{3:N4},{4:N4}) valuable=({5:N4},{6:N4},{7:N4},{8:N4}) avg_ordinary={9:N4} rare={10:N4} fragment_hit={11:N4} avg_fragment_units={12:N4} af_aam={13:N4} adrenalin_any={14:N4} adrenalin_two={15:N4} max_entries={16}" -f
        $profile.Tier,$Samples,($medicineCounts[0]/$Samples),($medicineCounts[1]/$Samples),($medicineCounts[2]/$Samples),
        ($valuableCounts[0]/$Samples),($valuableCounts[1]/$Samples),($valuableCounts[2]/$Samples),($valuableCounts[3]/$Samples),
        ($ordinaryRolls/$Samples),($rareCount/$Samples),($fragmentContainers/$Samples),($fragmentUnits/$Samples),
        ($aamContainers/$Samples),($adrenalinAny/$Samples),($adrenalinTwo/$Samples),$maxEntries)
}
Write-Output "Loot policy test: OK ($Samples deterministic samples per tier)"
