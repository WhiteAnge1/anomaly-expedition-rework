param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BuildModsRoot = '',
    [string]$PythonDeps = ''
)

$ErrorActionPreference = 'Stop'
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('aer-rc-verify-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temporary)

function Invoke-PythonTest([string]$Name, [string[]]$Arguments) {
    & python (Join-Path $SourceRoot "tools\$Name") @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Python archive test failed: $Name" }
}

try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entries = @($zip.Entries | Where-Object { $_.Name })
        if ($entries.Count -lt 140) { throw "Archive manifest too small: $($entries.Count)" }
        foreach ($entry in $entries) {
            $name = $entry.FullName
            if ($name.Contains('\') -or $name.Contains(':') -or $name.StartsWith('/') -or $name -match '(^|/)\.\.(/|$)') {
                throw "Unsafe archive path: $name"
            }
            if ($name -notmatch '^(gamedata|fomod|installer)/') { throw "Unexpected archive root: $name" }
            if ($name -match '(?i)\.(log|sav|scop|db|bak|tmp)$') { throw "Forbidden runtime artifact: $name" }
        }
        foreach ($required in @('fomod/info.xml','fomod/ModuleConfig.xml','gamedata/scripts/zzz_rvm_sorties_rework.script','gamedata/configs/plugins/rvm_sorties_rework.ltx')) {
            if (-not ($entries.FullName -contains $required)) { throw "Required archive entry missing: $required" }
        }
        $variantCount = @($entries | Where-Object FullName -Match '^installer/variants/[^/]+/rvm_sorties_rework\.ltx$').Count
        if ($variantCount -ne 136) { throw "Expected 136 installer variants, found $variantCount" }
    } finally { $zip.Dispose() }

    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $temporary
    foreach ($file in Get-ChildItem -LiteralPath $temporary -Recurse -File) {
        if ($file.Extension -match '^\.(script|ltx|xml|ini)$') {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            $text = [Text.Encoding]::GetEncoding(1251).GetString($bytes)
            if ($text -match '(?i)([A-Z]:\\Users\\|E:\\GRA|/home/|/Users/|xray_[^\s]+\.log)') {
                throw "Local absolute path or log name leaked into package: $($file.FullName)"
            }
        }
    }

    & (Join-Path $SourceRoot 'tools\test_fomod.ps1') -ModRoot $temporary
    & (Join-Path $SourceRoot 'tools\test_artifact_rescue_policy.ps1') -ModRoot $temporary
    & (Join-Path $SourceRoot 'tools\test_artifact_stabilization_policy.ps1') -ModRoot $temporary
    & (Join-Path $SourceRoot 'tools\test_artifact_held_stabilization_policy.ps1') -ModRoot $temporary
    & (Join-Path $SourceRoot 'tools\test_geometry_policy.ps1') -ModRoot $temporary

    if (-not $PythonDeps) {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $SourceRoot)
        $candidate = Join-Path $projectRoot 'work\pydeps'
        if (Test-Path -LiteralPath $candidate) { $PythonDeps = $candidate }
    }
    $projectRoot = Split-Path -Parent (Split-Path -Parent $SourceRoot)
    $luaDeps = Join-Path $projectRoot 'work\lua-runtime'
    if (-not (Test-Path -LiteralPath $luaDeps)) { throw 'Lua runtime dependencies unavailable' }
    $oldPythonPath = $env:PYTHONPATH
    try {
        $env:PYTHONPATH = if ($PythonDeps) { "$luaDeps;$PythonDeps" } else { $luaDeps }
        Invoke-PythonTest 'test_lua51_compile.py' @($temporary)
        Invoke-PythonTest 'test_artifact_spawn_level_proxy.py' @($temporary)
        Invoke-PythonTest 'test_origin_position_normalization.py' @($temporary)
        Invoke-PythonTest 'test_artifact_count_policy.py' @($temporary)
        if ($BuildModsRoot) { Invoke-PythonTest 'test_artifact_pool.py' @($temporary, $BuildModsRoot) }
        else { Invoke-PythonTest 'test_artifact_pool.py' @($temporary) }
        Invoke-PythonTest 'test_artifact_proactive_hold.py' @($temporary)
        Invoke-PythonTest 'test_xray_main_chunk_locals.py' @($temporary)
        Invoke-PythonTest 'test_startup_generation_path.py' @($temporary)
        if ($PythonDeps) {
            $scripts = Join-Path $temporary 'gamedata\scripts'
            python -c "from pathlib import Path; from luaparser import ast; [ast.parse(p.read_text(encoding='utf-8')) for p in Path(r'$scripts').glob('*.script')]; print('Archive Lua parser: OK')"
            if ($LASTEXITCODE -ne 0) { throw 'Archive Lua parser failed' }
        }
    } finally { $env:PYTHONPATH = $oldPythonPath }

    [xml](Get-Content -LiteralPath (Join-Path $temporary 'fomod\info.xml') -Raw -Encoding UTF8) | Out-Null
    [xml](Get-Content -LiteralPath (Join-Path $temporary 'fomod\ModuleConfig.xml') -Raw -Encoding UTF8) | Out-Null
    $hash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToUpperInvariant()
    $size = (Get-Item -LiteralPath $ArchivePath).Length
    Write-Output 'Release archive verification: OK'
    Write-Output "Bytes: $size"
    Write-Output "SHA256: $hash"
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($temporary)
    $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-temp path: $resolvedTemp"
    }
    if (Test-Path -LiteralPath $resolvedTemp) { Remove-Item -LiteralPath $resolvedTemp -Recurse -Force }
}
