param(
    [string]$LogPath = 'E:\GRA2.5\Anomaly 1.5.3 up\appdata\logs\xray_maksi.log',
    [string]$Pattern = '\[Anomaly Expedition Rework\]|FATAL|SCRIPT ERROR',
    [int]$Tail = 50,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$encoding = [Text.Encoding]::Default

function Read-AppendedLines {
    param([string]$Path, [ref]$Offset, [ref]$Pending, [ref]$CreationTicks, [ref]$Reopened)
    $Reopened.Value = $false
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $file = Get-Item -LiteralPath $Path
    if (($CreationTicks.Value -ne 0 -and $file.CreationTimeUtc.Ticks -ne $CreationTicks.Value) -or $file.Length -lt $Offset.Value) {
        $Offset.Value = [long]0
        $Pending.Value = ''
        $Reopened.Value = $true
    }
    $CreationTicks.Value = $file.CreationTimeUtc.Ticks
    if ($file.Length -le $Offset.Value) { return @() }

    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        [void]$stream.Seek($Offset.Value, [IO.SeekOrigin]::Begin)
        $remaining = [int64]($stream.Length - $Offset.Value)
        $memory = New-Object IO.MemoryStream
        try {
            $buffer = New-Object byte[] 4096
            while ($remaining -gt 0) {
                $wanted = [Math]::Min($buffer.Length, $remaining)
                $read = $stream.Read($buffer, 0, [int]$wanted)
                if ($read -le 0) { break }
                $memory.Write($buffer, 0, $read)
                $Offset.Value += $read
                $remaining -= $read
            }
            $combined = $Pending.Value + $encoding.GetString($memory.ToArray())
        }
        finally { $memory.Dispose() }
    }
    catch [IO.IOException] { return @() }
    finally { if ($stream) { $stream.Dispose() } }

    $parts = $combined -split "`n", -1
    if ($combined.EndsWith("`n")) {
        $Pending.Value = ''
        if ($parts.Count -le 1) { return @() }
        return @($parts[0..($parts.Count - 2)] | ForEach-Object { $_.TrimEnd("`r") })
    }
    $Pending.Value = $parts[$parts.Count - 1]
    if ($parts.Count -le 1) { return @() }
    return @($parts[0..($parts.Count - 2)] | ForEach-Object { $_.TrimEnd("`r") })
}

function Invoke-WatcherSelfTest {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ('aer-watcher-' + [Guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $testRoot)
    $testLog = Join-Path $testRoot 'xray-test.log'
    try {
        [IO.File]::WriteAllText($testLog, "initial`r`n", $encoding)
        [long]$offset = (Get-Item -LiteralPath $testLog).Length
        [long]$ticks = (Get-Item -LiteralPath $testLog).CreationTimeUtc.Ticks
        [string]$pending = ''
        [bool]$reopened = $false
        [IO.File]::AppendAllText($testLog, "noise`r`n[Anomaly Expedition Rework] appended`r`n", $encoding)
        $lines = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened))
        if (@($lines | Where-Object { $_ -match '\[Anomaly Expedition Rework\] appended' }).Count -ne 1) { throw 'appended complete line was not observed' }

        [IO.File]::AppendAllText($testLog, '[Anomaly Expedition Rework] par', $encoding)
        $partial = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened))
        if ($partial.Count -ne 0) { throw 'partial line was emitted early' }
        [IO.File]::AppendAllText($testLog, "tial`r`n", $encoding)
        $completed = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened))
        if ($completed.Count -ne 1 -or $completed[0] -notmatch 'partial$') { throw 'partial line was not completed' }

        [IO.File]::WriteAllText($testLog, "[Anomaly Expedition Rework] after truncate`r`n", $encoding)
        $truncated = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened))
        if (-not $reopened -or $truncated.Count -ne 1 -or $truncated[0] -notmatch 'after truncate') { throw 'truncate/reopen path failed' }
        Write-Output 'Live log watcher self-test: OK'
    }
    finally {
        if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    }
}

if ($SelfTest) { Invoke-WatcherSelfTest; exit 0 }

function Write-MatchingLine([string]$Line) { if ($Line -match $Pattern) { Write-Host $Line } }
Write-Host '=== Anomaly Expedition Rework: наблюдение запущено ===' -ForegroundColor Cyan
Write-Host "Log: $LogPath"
Write-Host "Filter: $Pattern"
Write-Host 'Waiting for matches... Для остановки нажмите Ctrl+C.' -ForegroundColor Yellow
while (-not (Test-Path -LiteralPath $LogPath)) { Start-Sleep -Seconds 1 }

Get-Content -LiteralPath $LogPath -Tail $Tail | ForEach-Object { Write-MatchingLine $_ }
$file = Get-Item -LiteralPath $LogPath
[long]$offset = $file.Length
[long]$creationTicks = $file.CreationTimeUtc.Ticks
[string]$pending = ''
[bool]$reopened = $false
while ($true) {
    Start-Sleep -Milliseconds 250
    $lines = @(Read-AppendedLines $LogPath ([ref]$offset) ([ref]$pending) ([ref]$creationTicks) ([ref]$reopened))
    if ($reopened) { Write-Host 'Log recreated or truncated; reopening from start.' -ForegroundColor DarkYellow }
    foreach ($line in $lines) { Write-MatchingLine $line }
}
