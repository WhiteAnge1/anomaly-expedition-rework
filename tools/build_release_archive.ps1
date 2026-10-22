param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist'),
    [string]$FileName = 'Anomaly-Expedition-Rework-0.3.0-rc2.zip'
)

$ErrorActionPreference = 'Stop'
$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path
if (-not (Test-Path -LiteralPath $OutputDirectory)) { [void](New-Item -ItemType Directory -Path $OutputDirectory) }
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$archivePath = Join-Path $OutputDirectory $FileName
$checksumPath = $archivePath + '.sha256'
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
if (Test-Path -LiteralPath $checksumPath) { Remove-Item -LiteralPath $checksumPath -Force }

$relativeFiles = New-Object System.Collections.Generic.List[string]
foreach ($relativeRoot in @('gamedata','fomod')) {
    $sourceRoot = Join-Path $ModRoot $relativeRoot
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "Missing package root: $relativeRoot" }
    foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
        $relative = $file.FullName.Substring($ModRoot.Length).TrimStart('\','/') -replace '\\','/'
        $relativeFiles.Add($relative)
    }
}
$relativeFiles = @($relativeFiles | Sort-Object -Unique)
if ($relativeFiles.Count -lt 10) { throw "Unexpectedly small package manifest: $($relativeFiles.Count) files" }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        $fixedTime = [DateTimeOffset]::new(2026, 10, 22, 0, 0, 0, [TimeSpan]::Zero)
        foreach ($relative in $relativeFiles) {
            $source = Join-Path $ModRoot ($relative -replace '/','\')
            $entry = $zip.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTime
            $input = [IO.File]::OpenRead($source)
            $output = $entry.Open()
            try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }

$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
[IO.File]::WriteAllText($checksumPath, "$hash  $FileName`n", (New-Object Text.UTF8Encoding($false)))
$size = (Get-Item -LiteralPath $archivePath).Length
Write-Output "Archive: $archivePath"
Write-Output "Files: $($relativeFiles.Count)"
Write-Output "Bytes: $size"
Write-Output "SHA256: $hash"
Write-Output "Checksum: $checksumPath"
