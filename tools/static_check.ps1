param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$PythonDeps = ""
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

$required = @(
    'gamedata\scripts\rvm_sorties_config.script',
    'gamedata\scripts\zzz_rvm_sorties_rework.script',
    'gamedata\scripts\modxml_rvm_sorties_map_spots.script',
    'gamedata\configs\plugins\rvm_sorties_rework.ltx',
    'gamedata\configs\ui\map_spots_rvm_sorties.xml',
    'gamedata\configs\text\rus\st_rvm_sorties_rework.xml',
    'fomod\info.xml',
    'meta.ini'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModRoot $relative))) { $failures.Add("missing: $relative") }
}

$main = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\scripts\zzz_rvm_sorties_rework.script') -Raw
foreach ($needle in @('raid_anomalys.spawn_artefact_in_zone','actor_on_item_take','npc_on_item_take','save_state','load_state','on_before_level_changing')) {
    if (-not $main.Contains($needle)) { $failures.Add("main hook missing: $needle") }
}
foreach ($needle in @('raid_artefacts_tiers_by_dop','raid_artefacts.addToQueuedArtefacts','{ 1, 2, 3, 4, 5 }','{ 5, 6 }','{ 6, 7 }')) {
    if (-not $main.Contains($needle)) { $failures.Add("artifact integration missing: $needle") }
}
if ($main -match 'drx_da_main\.spawn_artefact_on_smart\s*=') { $failures.Add('Arrival spawn function must not be wrapped') }
if ($main -match 'for\s+id\s*=\s*1\s*,\s*65534[\s\S]{0,300}IsArtefact') { $failures.Add('post-factum global artefact scan detected') }

$ltx = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx') -Raw
foreach ($needle in @('stash_mode = scouting','weight_artifact = 60','remove_on_npc_pickup = false','rare_artifact_chance = 70','loot_rare_non_artifact = raid_intelligence_note','[level_y04_pole]','[level_k01_darkscape]','[level_l09_deadcity]')) {
    if (-not $ltx.Contains($needle)) { $failures.Add("config invariant missing: $needle") }
}

[xml](Get-Content -LiteralPath (Join-Path $ModRoot 'fomod\info.xml') -Raw) | Out-Null
[xml](Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\text\rus\st_rvm_sorties_rework.xml') -Raw) | Out-Null
$fragment = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\ui\map_spots_rvm_sorties.xml') -Raw
[xml]("<map_spots>" + $fragment + "</map_spots>") | Out-Null

if ($PythonDeps) {
    $env:PYTHONPATH = $PythonDeps
    $scripts = Join-Path $ModRoot 'gamedata\scripts'
    python -c "from pathlib import Path; from luaparser import ast; [ast.parse(p.read_text(encoding='utf-8')) for p in Path(r'$scripts').glob('*.script')]; print('Lua parser: OK')"
    if ($LASTEXITCODE -ne 0) { $failures.Add('Lua parser failed') }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'Static checks: OK'
