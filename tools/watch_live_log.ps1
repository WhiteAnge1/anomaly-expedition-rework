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

Get-Content -LiteralPath $LogPath -Wait -Tail $Tail |
    Where-Object { $_ -match $Pattern } |
    ForEach-Object { Write-Host $_ }
