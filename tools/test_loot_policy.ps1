param(
    [int]$Samples = 200000,
    [int]$Seed = 20261009
)

$ErrorActionPreference = 'Stop'
$first = 0.35
$second = 0.10
$third = 0.015
$expected = @(
    (1.0 - $first)
    ($first * (1.0 - $second))
    ($first * $second * (1.0 - $third))
    ($first * $second * $third)
)
$required = @(0.65, 0.315, 0.034475, 0.000525)
for ($i = 0; $i -lt 4; $i++) {
    if ([Math]::Abs($expected[$i] - $required[$i]) -gt 0.0000000001) {
        throw "Exact valuable probability mismatch at quota ${i}: $($expected[$i])"
    }
}

$rng = New-Object -TypeName System.Random -ArgumentList $Seed
$counts = @(0, 0, 0, 0)
for ($sample = 0; $sample -lt $Samples; $sample++) {
    $quota = 0
    if ($rng.NextDouble() -lt $first) {
        $quota = 1
        if ($rng.NextDouble() -lt $second) {
            $quota = 2
            if ($rng.NextDouble() -lt $third) { $quota = 3 }
        }
    }
    $target = $rng.Next(1, 7)
    $medicineSlots = if ($rng.NextDouble() -lt 0.70) { 1 } else { 0 }
    $capacity = [Math]::Max(0, $target - $medicineSlots)
    $actual = [Math]::Min($quota, $capacity)
    if ($actual -gt $quota) { throw "valuable actual exceeded quota" }
    if (($actual + $medicineSlots) -gt $target) { throw "ordinary loot exceeded target" }
    $counts[$quota]++
}

$tolerance = @(0.005, 0.005, 0.002, 0.00025)
for ($i = 0; $i -lt 4; $i++) {
    $observed = $counts[$i] / [double]$Samples
    if ([Math]::Abs($observed - $expected[$i]) -gt $tolerance[$i]) {
        throw "Stochastic valuable frequency outside tolerance at quota ${i}: observed=$observed expected=$($expected[$i])"
    }
}

Write-Output "Loot policy test: OK ($Samples deterministic samples)"
