param(
    [string]$LogPath = 'E:\GRA2.5\Anomaly 1.5.3 up\appdata\logs\xray_maksi.log',
    [string]$Pattern = '\[Anomaly Expedition Rework\]|FATAL|SCRIPT ERROR',
    [int]$Tail = 50
)

$ErrorActionPreference = 'Stop'
Write-Host '=== Anomaly Expedition Rework: наблюдение запущено ===' -ForegroundColor Cyan
Write-Host "Log: $LogPath"
Write-Host "Filter: $Pattern"
Write-Host 'Waiting for matches... Для остановки нажмите Ctrl+C.' -ForegroundColor Yellow

while (-not (Test-Path -LiteralPath $LogPath)) {
    Start-Sleep -Seconds 1
}

function Write-MatchingLine([string]$Line) {
    if ($Line -match $Pattern) { Write-Host $Line }
}

# Get-Content -Wait can keep following an orphaned handle when X-Ray replaces
# its log during startup. Polling the path and reopening it every iteration also
# handles truncation without requiring a game exit to flush visible matches.
Get-Content -LiteralPath $LogPath -Tail $Tail | ForEach-Object { Write-MatchingLine $_ }
$file = Get-Item -LiteralPath $LogPath
[long]$offset = $file.Length
[long]$creationTicks = $file.CreationTimeUtc.Ticks
$encoding = [Text.Encoding]::Default

while ($true) {
    Start-Sleep -Milliseconds 250
    if (-not (Test-Path -LiteralPath $LogPath)) {
        continue
    }

    $file = Get-Item -LiteralPath $LogPath
    $recreated = $file.CreationTimeUtc.Ticks -ne $creationTicks
    $truncated = $file.Length -lt $offset
    if ($recreated -or $truncated) {
        $offset = 0
        $creationTicks = $file.CreationTimeUtc.Ticks
        Write-Host 'Log recreated or truncated; reopening from start.' -ForegroundColor DarkYellow
    }
    if ($file.Length -le $offset) { continue }

    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($LogPath, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        [void]$stream.Seek($offset, [IO.SeekOrigin]::Begin)
        $reader = New-Object IO.StreamReader($stream, $encoding, $true)
        while (-not $reader.EndOfStream) {
            Write-MatchingLine $reader.ReadLine()
        }
        $offset = $stream.Position
    }
    catch [IO.IOException] {
        # X-Ray may briefly own or replace the file between metadata lookup and
        # open. The next 250 ms iteration retries the current path.
    }
    finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
}
