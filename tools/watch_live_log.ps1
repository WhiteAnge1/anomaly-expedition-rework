param(
    [string]$LogPath = 'E:\GRA2.5\Anomaly 1.5.3 up\appdata\logs\xray_maksi.log',
    [string]$Pattern = '\[Anomaly Expedition Rework\]|FATAL|SCRIPT ERROR',
    [int]$Tail = 50,
    [string]$OutputDirectory = '',
    [string]$GameBinPath = 'E:\GRA2.5\Anomaly 1.5.3 up\bin',
    [string[]]$ProcessNames = @(
        'AnomalyDX8', 'AnomalyDX8AVX', 'AnomalyDX9', 'AnomalyDX9AVX',
        'AnomalyDX10', 'AnomalyDX10AVX', 'AnomalyDX11', 'AnomalyDX11AVX',
        'VerifiedDX11'
    ),
    [double]$ShutdownGraceSeconds = 20,
    [int]$PollMilliseconds = 250,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$encoding = [Text.Encoding]::Default
$archiveEncoding = New-Object Text.UTF8Encoding($true)

function Test-ReadCheckpoint {
    param([string]$Path, [long]$Start, [string]$Data)
    if ($Start -lt 0 -or [string]::IsNullOrEmpty($Data)) { return $true }
    $expected = [Convert]::FromBase64String($Data)
    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        if ($stream.Length -lt ($Start + $expected.Length)) { return $false }
        [void]$stream.Seek($Start, [IO.SeekOrigin]::Begin)
        $actual = New-Object byte[] $expected.Length
        $read = $stream.Read($actual, 0, $actual.Length)
        if ($read -ne $expected.Length) { return $false }
        return [Convert]::ToBase64String($actual) -eq $Data
    }
    catch [IO.IOException] { return $true }
    finally { if ($stream) { $stream.Dispose() } }
}

function Set-ReadCheckpoint {
    param([string]$Path, [long]$Offset, [ref]$Start, [ref]$Data)
    if ($Offset -le 0) {
        $Start.Value = [long]-1
        $Data.Value = ''
        return
    }
    $count = [int][Math]::Min(64, $Offset)
    $checkpointStart = $Offset - $count
    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        if ($stream.Length -lt $Offset) { return }
        [void]$stream.Seek($checkpointStart, [IO.SeekOrigin]::Begin)
        $bytes = New-Object byte[] $count
        $read = $stream.Read($bytes, 0, $count)
        if ($read -eq $count) {
            $Start.Value = [long]$checkpointStart
            $Data.Value = [Convert]::ToBase64String($bytes)
        }
    }
    catch [IO.IOException] { }
    finally { if ($stream) { $stream.Dispose() } }
}

function Read-AppendedLines {
    param(
        [string]$Path,
        [ref]$Offset,
        [ref]$Pending,
        [ref]$CreationTicks,
        [ref]$Reopened,
        [ref]$WasMissing,
        [ref]$CheckpointStart,
        [ref]$CheckpointData
    )
    $Reopened.Value = $false
    if (-not (Test-Path -LiteralPath $Path)) {
        $WasMissing.Value = $true
        return @()
    }
    $file = Get-Item -LiteralPath $Path
    $checkpointValid = Test-ReadCheckpoint $Path $CheckpointStart.Value $CheckpointData.Value
    if ($WasMissing.Value -or
        ($CreationTicks.Value -ne 0 -and $file.CreationTimeUtc.Ticks -ne $CreationTicks.Value) -or
        $file.Length -lt $Offset.Value -or -not $checkpointValid) {
        $Offset.Value = [long]0
        $Pending.Value = ''
        $CheckpointStart.Value = [long]-1
        $CheckpointData.Value = ''
        $Reopened.Value = $true
    }
    $WasMissing.Value = $false
    $CreationTicks.Value = $file.CreationTimeUtc.Ticks
    if ($file.Length -le $Offset.Value) { return @() }

    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        if ($stream.Length -lt $Offset.Value) {
            $Offset.Value = [long]0
            $Pending.Value = ''
            $Reopened.Value = $true
        }
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

    Set-ReadCheckpoint $Path $Offset.Value $CheckpointStart $CheckpointData
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

function Resolve-OutputDirectory([string]$Requested) {
    if (-not [string]::IsNullOrWhiteSpace($Requested)) { return [IO.Path]::GetFullPath($Requested) }
    $projectRoot = Split-Path -Parent $PSScriptRoot
    if (Test-Path -LiteralPath (Join-Path $projectRoot '.git')) {
        return Join-Path $projectRoot 'test-artifacts\live-logs'
    }
    $documents = [Environment]::GetFolderPath('MyDocuments')
    return Join-Path $documents 'Codex\Anomaly Expedition Rework\test-artifacts\live-logs'
}

function New-SessionArchive([string]$Directory) {
    [void](New-Item -ItemType Directory -Path $Directory -Force)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $path = Join-Path $Directory ("aer-live-$stamp-$PID.log")
    if (Test-Path -LiteralPath $path) { $path = Join-Path $Directory ("aer-live-$stamp-$PID-$([Guid]::NewGuid().ToString('N')).log") }
    $latestPath = Join-Path $Directory 'latest.log'
    $writer = $null
    try {
        $stream = New-Object IO.FileStream($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
            ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
        $writer = New-Object IO.StreamWriter($stream, $archiveEncoding)
        $writer.AutoFlush = $true
    }
    catch {
        if ($writer) { try { $writer.Dispose() } catch { } }
        if (Test-Path -LiteralPath $path) {
            try { Remove-Item -LiteralPath $path -Force } catch { }
        }
        throw
    }
    $archive = [pscustomobject]@{
        Path = $path
        LatestPath = $latestPath
        Writer = $writer
        LatestWriter = $null
        LatestWarningIssued = $false
        LatestError = $null
    }
    try {
        $latestStream = New-Object IO.FileStream($latestPath, [IO.FileMode]::Create, [IO.FileAccess]::Write,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $archive.LatestWriter = New-Object IO.StreamWriter($latestStream, $archiveEncoding)
        $archive.LatestWriter.AutoFlush = $true
    }
    catch [IO.IOException] {
        $archive.LatestError = $_.Exception.Message
        $archive.LatestWarningIssued = $true
        Write-Warning "latest.log is busy; continuing with authoritative session file '$path': $($archive.LatestError)"
    }
    return $archive
}

function Disable-LatestWriter([object]$Archive, [string]$Reason) {
    if (-not $Archive) { return }
    if ($Archive.LatestWriter) {
        try { $Archive.LatestWriter.Dispose() } catch { }
        $Archive.LatestWriter = $null
    }
    $Archive.LatestError = $Reason
    if (-not $Archive.LatestWarningIssued) {
        $Archive.LatestWarningIssued = $true
        Write-Warning "latest.log disabled; authoritative session continues at '$($Archive.Path)': $Reason"
    }
}

function Write-WatcherLine {
    param([object]$Archive, [string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Gray, [switch]$Quiet)
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Color }
    if ($Archive -and $Archive.Writer) { $Archive.Writer.WriteLine($Text) }
    if ($Archive -and $Archive.LatestWriter) {
        try { $Archive.LatestWriter.WriteLine($Text) }
        catch [IO.IOException] { Disable-LatestWriter $Archive $_.Exception.Message }
        catch [ObjectDisposedException] { Disable-LatestWriter $Archive $_.Exception.Message }
    }
}

function Write-MatchingLine {
    param([string]$Line, [string]$Filter, [object]$Archive, [switch]$Quiet)
    if ($Line -match $Filter) {
        Write-WatcherLine $Archive $Line ([ConsoleColor]::Gray) -Quiet:$Quiet
        return $true
    }
    return $false
}

function Close-SessionArchive([object]$Archive) {
    if (-not $Archive) { return }
    if ($Archive.Writer) {
        try { $Archive.Writer.Flush() }
        finally {
            $Archive.Writer.Dispose()
            $Archive.Writer = $null
        }
    }
    if ($Archive.LatestWriter) {
        try { $Archive.LatestWriter.Flush() }
        finally {
            $Archive.LatestWriter.Dispose()
            $Archive.LatestWriter = $null
        }
    }
}

function Publish-LatestCopy([object]$Archive) {
    if (-not $Archive -or -not (Test-Path -LiteralPath $Archive.Path)) { return $false }
    $latestDirectory = Split-Path -Parent $Archive.LatestPath
    $nonce = [Guid]::NewGuid().ToString('N')
    $temporary = Join-Path $latestDirectory ('.latest-' + $nonce + '.tmp')
    $backup = Join-Path $latestDirectory ('.latest-' + $nonce + '.bak')
    try {
        [IO.File]::Copy($Archive.Path, $temporary, $false)
        if (Test-Path -LiteralPath $Archive.LatestPath) {
            [IO.File]::Replace($temporary, $Archive.LatestPath, $backup, $true)
        }
        else {
            [IO.File]::Move($temporary, $Archive.LatestPath)
        }
        $Archive.LatestError = $null
        return $true
    }
    catch [IO.IOException] {
        $Archive.LatestError = $_.Exception.Message
        if (-not $Archive.LatestWarningIssued) {
            $Archive.LatestWarningIssued = $true
            Write-Warning "Could not publish latest.log; authoritative session is preserved at '$($Archive.Path)': $($Archive.LatestError)"
        }
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            try { Remove-Item -LiteralPath $temporary -Force } catch { }
        }
        if (Test-Path -LiteralPath $backup) {
            try { Remove-Item -LiteralPath $backup -Force } catch { }
        }
    }
}

function Get-RunningGameProcess {
    param([string[]]$Names, [string]$BinPath)
    $binPrefix = $null
    if (-not [string]::IsNullOrWhiteSpace($BinPath) -and (Test-Path -LiteralPath $BinPath)) {
        $binPrefix = [IO.Path]::GetFullPath($BinPath).TrimEnd('\') + '\'
    }
    foreach ($process in @(Get-Process -Name $Names -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $process.Path } catch { }
        if ($path -and $binPrefix -and -not $path.StartsWith($binPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
        return [pscustomobject]@{ Name = $process.ProcessName; Id = $process.Id; Path = $path }
    }
    return $null
}

function Update-GameLifecycle {
    param([bool]$Running, [datetime]$Now, [double]$GraceSeconds, [ref]$WasSeen, [ref]$ShutdownAt)
    $detected = $false
    $stopped = $false
    $resumed = $false
    $shouldStop = $false
    if ($Running) {
        if (-not $WasSeen.Value) {
            $WasSeen.Value = $true
            $detected = $true
        }
        elseif ($null -ne $ShutdownAt.Value) { $resumed = $true }
        $ShutdownAt.Value = $null
    }
    elseif ($WasSeen.Value) {
        if ($null -eq $ShutdownAt.Value) {
            $ShutdownAt.Value = $Now.AddSeconds($GraceSeconds)
            $stopped = $true
        }
        elseif ($Now -ge $ShutdownAt.Value) { $shouldStop = $true }
    }
    return [pscustomobject]@{ Detected=$detected; Stopped=$stopped; Resumed=$resumed; ShouldStop=$shouldStop }
}

function Test-ControlCKey([object]$KeyInfo) {
    return $KeyInfo -and $KeyInfo.Key -eq [ConsoleKey]::C -and
        (($KeyInfo.Modifiers -band [ConsoleModifiers]::Control) -ne 0)
}

function Get-ControlCRequested([bool]$Enabled) {
    if (-not $Enabled) { return $false }
    try {
        while ([Console]::KeyAvailable) {
            if (Test-ControlCKey ([Console]::ReadKey($true))) { return $true }
        }
    }
    catch { }
    return $false
}

function Invoke-WatcherSelfTest {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ('aer-watcher-' + [Guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $testRoot)
    $testLog = Join-Path $testRoot 'xray-test.log'
    $archive = $null
    try {
        $archive = New-SessionArchive (Join-Path $testRoot 'saved')
        Write-WatcherLine $archive '# self-test session metadata' ([ConsoleColor]::Gray) -Quiet
        [IO.File]::WriteAllText($testLog, "initial`r`n", $encoding)
        [long]$offset = (Get-Item -LiteralPath $testLog).Length
        [long]$ticks = (Get-Item -LiteralPath $testLog).CreationTimeUtc.Ticks
        [string]$pending = ''
        [bool]$reopened = $false
        [bool]$wasMissing = $false
        [long]$checkpointStart = -1
        [string]$checkpointData = ''
        Set-ReadCheckpoint $testLog $offset ([ref]$checkpointStart) ([ref]$checkpointData)

        [IO.File]::AppendAllText($testLog, "noise`r`n[Anomaly Expedition Rework] appended`r`n", $encoding)
        $lines = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
        foreach ($line in $lines) { [void](Write-MatchingLine $line '\[Anomaly Expedition Rework\]' $archive -Quiet) }
        if (@($lines | Where-Object { $_ -match '\[Anomaly Expedition Rework\] appended' }).Count -ne 1) { throw 'appended complete line was not observed' }

        [IO.File]::AppendAllText($testLog, '[Anomaly Expedition Rework] par', $encoding)
        $partial = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
        if ($partial.Count -ne 0) { throw 'partial line was emitted early' }
        [IO.File]::AppendAllText($testLog, "tial`r`n", $encoding)
        $completed = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
        foreach ($line in $completed) { [void](Write-MatchingLine $line '\[Anomaly Expedition Rework\]' $archive -Quiet) }
        if ($completed.Count -ne 1 -or $completed[0] -notmatch 'partial$') { throw 'partial line was not completed' }

        $replacement = "[Anomaly Expedition Rework] after truncate`r`n" + ('x' * ($offset + 100)) + "`r`n"
        [IO.File]::WriteAllText($testLog, $replacement, $encoding)
        $truncated = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
        foreach ($line in $truncated) { [void](Write-MatchingLine $line '\[Anomaly Expedition Rework\]' $archive -Quiet) }
        if (-not $reopened -or @($truncated | Where-Object { $_ -match 'after truncate' }).Count -ne 1) { throw 'truncate/regrow checkpoint path failed' }

        Remove-Item -LiteralPath $testLog -Force
        [void](Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
        [IO.File]::WriteAllText($testLog, "[Anomaly Expedition Rework] after recreate`r`n", $encoding)
        $recreated = @(Read-AppendedLines $testLog ([ref]$offset) ([ref]$pending) ([ref]$ticks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
        foreach ($line in $recreated) { [void](Write-MatchingLine $line '\[Anomaly Expedition Rework\]' $archive -Quiet) }
        if (-not $reopened -or $recreated.Count -ne 1) { throw 'delete/recreate path failed' }

        [bool]$gameWasSeen = $false
        $shutdownAt = $null
        $now = Get-Date
        $beforeStart = Update-GameLifecycle $false $now 0.05 ([ref]$gameWasSeen) ([ref]$shutdownAt)
        if ($beforeStart.ShouldStop -or $gameWasSeen) { throw 'watcher exited before game was ever detected' }
        $started = Update-GameLifecycle $true $now.AddSeconds(1) 0.05 ([ref]$gameWasSeen) ([ref]$shutdownAt)
        if (-not $started.Detected -or -not $gameWasSeen) { throw 'game start was not recorded' }
        $ended = Update-GameLifecycle $false $now.AddSeconds(2) 0.05 ([ref]$gameWasSeen) ([ref]$shutdownAt)
        if (-not $ended.Stopped -or $ended.ShouldStop) { throw 'grace period did not start correctly' }
        $insideGrace = Update-GameLifecycle $false $now.AddSeconds(2.02) 0.05 ([ref]$gameWasSeen) ([ref]$shutdownAt)
        if ($insideGrace.ShouldStop) { throw 'watcher stopped before grace elapsed' }
        $afterGrace = Update-GameLifecycle $false $now.AddSeconds(2.06) 0.05 ([ref]$gameWasSeen) ([ref]$shutdownAt)
        if (-not $afterGrace.ShouldStop) { throw 'watcher did not stop after injected grace elapsed' }
        $ctrlC = [pscustomobject]@{ Key=[ConsoleKey]::C; Modifiers=[ConsoleModifiers]::Control }
        if (-not (Test-ControlCKey $ctrlC)) { throw 'Ctrl+C key recognition failed' }

        Close-SessionArchive $archive
        if (-not (Publish-LatestCopy $archive)) { throw 'normal final latest publish failed' }
        $archiveText = Get-Content -LiteralPath $archive.Path -Raw -Encoding UTF8
        foreach ($needle in @('# self-test session metadata','appended','partial','after truncate','after recreate')) {
            if (-not $archiveText.Contains($needle)) { throw "saved watcher output missing: $needle" }
        }
        if ($archiveText.Contains("noise`r`n")) { throw 'unfiltered line was saved' }
        if (-not (Test-Path -LiteralPath $archive.LatestPath)) { throw 'latest watcher copy was not saved' }

        $lockedRoot = Join-Path $testRoot 'locked-latest'
        [void](New-Item -ItemType Directory -Path $lockedRoot)
        $lockedLatest = Join-Path $lockedRoot 'latest.log'
        [IO.File]::WriteAllText($lockedLatest, 'locked', $archiveEncoding)
        $exclusive = [IO.File]::Open($lockedLatest, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $lockedArchive = $null
        $savedWarningPreference = $WarningPreference
        try {
            $WarningPreference = 'SilentlyContinue'
            $lockedArchive = New-SessionArchive $lockedRoot
            if (-not $lockedArchive.Writer -or $lockedArchive.LatestWriter) { throw 'latest lock prevented authoritative session startup' }
            if (-not $lockedArchive.LatestWarningIssued) { throw 'latest lock warning was not recorded' }
            Write-WatcherLine $lockedArchive '# authoritative while latest locked' ([ConsoleColor]::Gray) -Quiet
            Close-SessionArchive $lockedArchive
            if (Publish-LatestCopy $lockedArchive) { throw 'locked latest unexpectedly accepted final replacement' }
            $lockedText = Get-Content -LiteralPath $lockedArchive.Path -Raw -Encoding UTF8
            if (-not $lockedText.Contains('authoritative while latest locked')) { throw 'authoritative session was lost while latest locked' }
        }
        finally {
            $WarningPreference = $savedWarningPreference
            if ($lockedArchive) { Close-SessionArchive $lockedArchive }
            $exclusive.Dispose()
        }
        if (-not (Publish-LatestCopy $lockedArchive)) { throw 'latest publish did not recover after sharing lock release' }
        $publishedText = Get-Content -LiteralPath $lockedArchive.LatestPath -Raw -Encoding UTF8
        if (-not $publishedText.Contains('authoritative while latest locked')) { throw 'recovered latest copy does not match authoritative session' }
        Write-Output 'Live log watcher self-test: OK'
    }
    finally {
        if ($archive -and $archive.Writer) { $archive.Writer.Dispose() }
        if ($archive -and $archive.LatestWriter) { $archive.LatestWriter.Dispose() }
        if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    }
}

if ($SelfTest) { Invoke-WatcherSelfTest; exit 0 }

if ($ShutdownGraceSeconds -lt 0) { throw 'ShutdownGraceSeconds cannot be negative' }
if ($PollMilliseconds -lt 50) { throw 'PollMilliseconds must be at least 50' }
$OutputDirectory = Resolve-OutputDirectory $OutputDirectory
$archive = New-SessionArchive $OutputDirectory
$terminationReason = 'interrupted_or_host_stop'
[long]$offset = 0
[long]$creationTicks = 0
[string]$pending = ''
[bool]$reopened = $false
[bool]$wasMissing = $false
[long]$checkpointStart = -1
[string]$checkpointData = ''
[bool]$logInitialized = $false
[bool]$gameWasSeen = $false
$shutdownAt = $null
$nextProcessCheck = [datetime]::MinValue
$controlCAsInput = $false
$previousTreatControlCAsInput = $false
try {
    if (-not [Console]::IsInputRedirected) {
        $previousTreatControlCAsInput = [Console]::TreatControlCAsInput
        [Console]::TreatControlCAsInput = $true
        $controlCAsInput = $true
    }
}
catch { }

try {
    Write-WatcherLine $archive '=== Anomaly Expedition Rework: наблюдение запущено ===' ([ConsoleColor]::Cyan)
    Write-WatcherLine $archive ("Started: " + (Get-Date).ToString('o'))
    Write-WatcherLine $archive "Log: $LogPath"
    Write-WatcherLine $archive "Filter: $Pattern"
    Write-WatcherLine $archive "Game bin: $GameBinPath"
    Write-WatcherLine $archive ("Game processes: " + ($ProcessNames -join ', '))
    Write-WatcherLine $archive "Post-exit grace: $ShutdownGraceSeconds seconds"
    Write-WatcherLine $archive "Session file: $($archive.Path)"
    Write-WatcherLine $archive 'Waiting for X-Ray and matching lines... Для остановки нажмите Ctrl+C.' ([ConsoleColor]::Yellow)

    while ($true) {
        if (Get-ControlCRequested $controlCAsInput) {
            $terminationReason = 'ctrl_c'
            break
        }
        if (-not $logInitialized -and (Test-Path -LiteralPath $LogPath)) {
            foreach ($line in @(Get-Content -LiteralPath $LogPath -Tail $Tail)) { [void](Write-MatchingLine $line $Pattern $archive) }
            $file = Get-Item -LiteralPath $LogPath
            $offset = $file.Length
            $creationTicks = $file.CreationTimeUtc.Ticks
            Set-ReadCheckpoint $LogPath $offset ([ref]$checkpointStart) ([ref]$checkpointData)
            $logInitialized = $true
        }
        elseif ($logInitialized) {
            $lines = @(Read-AppendedLines $LogPath ([ref]$offset) ([ref]$pending) ([ref]$creationTicks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
            if ($reopened) { Write-WatcherLine $archive 'Log recreated or truncated; reopening from start.' ([ConsoleColor]::DarkYellow) }
            foreach ($line in $lines) { [void](Write-MatchingLine $line $Pattern $archive) }
        }

        $now = Get-Date
        if ($now -ge $nextProcessCheck) {
            $game = Get-RunningGameProcess $ProcessNames $GameBinPath
            $lifecycle = Update-GameLifecycle ($null -ne $game) $now $ShutdownGraceSeconds ([ref]$gameWasSeen) ([ref]$shutdownAt)
            if ($lifecycle.Detected) { Write-WatcherLine $archive ("X-Ray detected: $($game.Name) pid=$($game.Id) path=$($game.Path)") ([ConsoleColor]::Green) }
            elseif ($lifecycle.Resumed) { Write-WatcherLine $archive ("X-Ray detected again during grace: $($game.Name) pid=$($game.Id); automatic exit cancelled.") ([ConsoleColor]::Green) }
            if ($lifecycle.Stopped) { Write-WatcherLine $archive ("X-Ray process closed; reading log for $ShutdownGraceSeconds more seconds.") ([ConsoleColor]::Yellow) }
            if ($lifecycle.ShouldStop) {
                $terminationReason = 'game_closed_after_grace'
                break
            }
            $nextProcessCheck = $now.AddMilliseconds([Math]::Max(250, $PollMilliseconds))
        }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
}
finally {
    try {
        if ($logInitialized) {
            $finalLines = @(Read-AppendedLines $LogPath ([ref]$offset) ([ref]$pending) ([ref]$creationTicks) ([ref]$reopened) ([ref]$wasMissing) ([ref]$checkpointStart) ([ref]$checkpointData))
            if ($reopened) { Write-WatcherLine $archive 'Log recreated or truncated during final drain; reopening from start.' ([ConsoleColor]::DarkYellow) }
            foreach ($line in $finalLines) { [void](Write-MatchingLine $line $Pattern $archive) }
            if (-not [string]::IsNullOrEmpty($pending)) {
                [void](Write-MatchingLine $pending $Pattern $archive)
                $pending = ''
            }
        }
        Write-WatcherLine $archive "Session ending: $terminationReason at $((Get-Date).ToString('o'))"
        Write-WatcherLine $archive "Saved session: $($archive.Path)" ([ConsoleColor]::Cyan)
    }
    catch { Write-Warning "Final watcher drain failed: $($_.Exception.Message)" }
    try { Close-SessionArchive $archive }
    catch { Write-Warning "Watcher archive close failed: $($_.Exception.Message)" }
    try {
        if (Publish-LatestCopy $archive) {
            Write-Host "Latest copy: $($archive.LatestPath)" -ForegroundColor Cyan
        }
        else {
            Write-Host "Latest copy unavailable; authoritative session preserved: $($archive.Path)" -ForegroundColor Yellow
        }
    }
    catch { Write-Warning "Final latest publish failed; session preserved at '$($archive.Path)': $($_.Exception.Message)" }
    if ($controlCAsInput) {
        try { [Console]::TreatControlCAsInput = $previousTreatControlCAsInput } catch { }
    }
}
