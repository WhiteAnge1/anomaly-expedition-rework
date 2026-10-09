param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$PythonDeps = "",
    [string]$BuildModsRoot = ""
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
foreach ($needle in @('generate_scripted_mapspot_at','set_pingspot_persistence','deregister_script_zone','visual_id','max_false_zones','decoy plan')) {
    if (-not $main.Contains($needle)) { $failures.Add("test-fix integration missing: $needle") }
}
foreach ($needle in @('DEV_DEBUG','DEV_DEBUG_DEV','rvm_rework_debug','rvm_rework_census','population_census','owned_by_rework','spawned_info','rvm_debug_target')) {
    if (-not $main.Contains($needle)) { $failures.Add("debug integration missing: $needle") }
}
foreach ($needle in @('safe_alive','safe_class_check','census_disabled','pcall(population_census_impl','pcall(detect_rvm_squad_changes_impl')) {
    if (-not $main.Contains($needle)) { $failures.Add("census safety missing: $needle") }
}
if ($main -match 'member:alive\s*\(') { $failures.Add('unsafe squad iterator member:alive() call detected') }
if ($main -match 'drx_da_main\.spawn_artefact_on_smart\s*=') { $failures.Add('Arrival spawn function must not be wrapped') }
if ($main -match 'raid_dospawn_dungeons\.raid_start_spawn\s*=') { $failures.Add('RVM dospawn function must not be wrapped') }
if ($main -match 'for\s+id\s*=\s*1\s*,\s*65534[\s\S]{0,300}IsArtefact') { $failures.Add('post-factum global artefact scan detected') }
if ($main -match '%\.\d+f') { $failures.Add('X-Ray printf-incompatible floating-point format detected') }

$ltx = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx') -Raw
foreach ($needle in @('stash_mode = scouting','weight_artifact = 60','remove_on_npc_pickup = false','rare_artifact_chance = 70','loot_rare_non_artifact = raid_intelligence_note','loot_container_visuals = raid_small_stash_1','map_spot = rvm_search_small','max_false_zones = 1','debug_mode = auto','debug_log = false','[level_y04_pole]','[level_k01_darkscape]','[level_l09_deadcity]')) {
    if (-not $ltx.Contains($needle)) { $failures.Add("config invariant missing: $needle") }
}
foreach ($forbidden in @('simk_card','artifact_container')) {
    if ($ltx -match "(?m)^loot_[^=]+=[^`r`n]*\b$([regex]::Escape($forbidden))\b") { $failures.Add("invalid configured loot section: $forbidden") }
}

[xml](Get-Content -LiteralPath (Join-Path $ModRoot 'fomod\info.xml') -Raw) | Out-Null
$fomod = Get-Content -LiteralPath (Join-Path $ModRoot 'fomod\info.xml') -Raw
if (-not $fomod.Contains('[Геймплей] Anomaly Expedition Rework by White_Angel v0.2.1-alpha')) { $failures.Add('FOMOD display name must include category and version') }
$stringsPath = Join-Path $ModRoot 'gamedata\configs\text\rus\st_rvm_sorties_rework.xml'
$strict1251 = [Text.Encoding]::GetEncoding(1251, [Text.EncoderFallback]::ExceptionFallback, [Text.DecoderFallback]::ExceptionFallback)
$stringsText = $strict1251.GetString([IO.File]::ReadAllBytes($stringsPath))
if ($stringsText -notmatch '<\?xml[^>]+encoding="windows-1251"') { $failures.Add('Russian string table must declare windows-1251') }
if (-not $stringsText.Contains('Область интереса')) { $failures.Add('Russian string table failed Windows-1251 decoding') }
[xml]$stringsXml = $stringsText
$scoutingText = ($stringsXml.string_table.string | Where-Object id -eq 'st_rvm_sorties_scouting_route_descr').text
$infectedText = ($stringsXml.string_table.string | Where-Object id -eq 'st_rvm_sorties_anomaly_route_descr').text
$stashSuffix = ($stringsXml.string_table.string | Where-Object id -eq 'st_rvm_sorties_stash_suffix').text
if (-not $scoutingText.Contains('%c[255,160,160,160] \n')) { $failures.Add('scouting color tag must keep the original space before \n') }
if (-not $infectedText.Contains('%c[255,160,160,160] \n')) { $failures.Add('infected color tag must keep the original space before \n') }
if (-not $scoutingText.Contains('\n \n') -or -not $infectedText.Contains('\n \n')) { $failures.Add('route descriptions must keep the original blank-line token \n \n') }
if ($stashSuffix -ne '\nНа документе отмечены координаты тайника.') { $failures.Add('stash suffix differs from the RVM-style final text') }
$scoutingUiText = $scoutingText + $stashSuffix
$infectedUiText = $infectedText
if ([regex]::Matches($scoutingUiText, [regex]::Escape('На документе отмечены координаты тайника.')).Count -ne 1) { $failures.Add('build_desc_header simulation must add the stash sentence exactly once to scouting') }
if ($infectedUiText.Contains('координаты тайника')) { $failures.Add('infected UI text must not mention a stash in scouting mode') }
if ($scoutingUiText -match '(?i)экспедиц' -or $infectedUiText -match '(?i)экспедиц') { $failures.Add('route UI text must use original RVM terminology, not expedition') }
$fragment = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\ui\map_spots_rvm_sorties.xml') -Raw
[xml]("<map_spots>" + $fragment + "</map_spots>") | Out-Null
foreach ($needle in @('rvm_search_small','rvm_search_medium','rvm_search_large','rvm_debug_target','scale_min="1" scale_max="1"')) {
    if (-not $fragment.Contains($needle)) { $failures.Add("map spot invariant missing: $needle") }
}

if ($BuildModsRoot) {
    if (-not (Test-Path -LiteralPath $BuildModsRoot)) { $failures.Add("build mods root missing: $BuildModsRoot") }
    else {
        $lootSections = [regex]::Matches($ltx, '(?m)^loot_(?:medicine|utility|modules|rare_non_artifact)\s*=\s*([^;\r\n]+)') |
            ForEach-Object { $_.Groups[1].Value -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Where-Object { $_ -match '^(?:raid_|af_)' -or $_ -eq 'lead_box' } |
            Sort-Object -Unique
        foreach ($section in $lootSections) {
            & rg -q --glob '*.ltx' "^\[$([regex]::Escape($section))\]" $BuildModsRoot
            if ($LASTEXITCODE -ne 0) { $failures.Add("loot section not found in build: $section") }
        }
        foreach ($section in 1..17 | ForEach-Object { "raid_small_stash_$_" }) {
            & rg -q --glob '*.ltx' "^\[$section\]" $BuildModsRoot
            if ($LASTEXITCODE -ne 0) { $failures.Add("loot visual section not found in build: $section") }
        }
    }
}

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
