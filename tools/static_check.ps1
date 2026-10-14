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
    'gamedata\configs\mod_system_rvm_sorties_squads.ltx',
    'gamedata\configs\ui\map_spots_rvm_sorties.xml',
    'gamedata\configs\text\rus\st_rvm_sorties_rework.xml',
    'fomod\info.xml',
    'meta.ini',
    '.gitignore',
    'docs\CONFIG.md',
    'docs\RELEASE-CHECKLIST.md',
    'tools\watch_live_log.ps1',
    'tools\watch_live_log.cmd',
    'tools\test_loot_policy.ps1',
    'tools\test_geometry_policy.ps1',
    'docs\ARTIFACT-RESCUE-DESIGN.md',
    'docs\ARTIFACT-RESCUE-RESEARCH.md'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModRoot $relative))) { $failures.Add("missing: $relative") }
}

# Windows PowerShell 5.1 treats BOM-less UTF-8 scripts as the active ANSI code
# page. Both scripts contain Cyrillic text, so the BOM is a runtime requirement.
foreach ($relative in @('tools\static_check.ps1','tools\watch_live_log.ps1','tools\test_loot_policy.ps1')) {
    $toolPath = Join-Path $ModRoot $relative
    if (Test-Path -LiteralPath $toolPath) {
        $bytes = [IO.File]::ReadAllBytes($toolPath)
        $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        if (-not $hasUtf8Bom) { $failures.Add("Windows PowerShell 5.1 requires UTF-8 BOM: $relative") }
    }
}
$watchCmdPath = Join-Path $ModRoot 'tools\watch_live_log.cmd'
if (Test-Path -LiteralPath $watchCmdPath) {
    $cmdBytes = [IO.File]::ReadAllBytes($watchCmdPath)
    if (@($cmdBytes | Where-Object { $_ -gt 0x7F }).Count -gt 0) { $failures.Add('watch_live_log.cmd must remain ASCII for cmd.exe compatibility') }
}

$main = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\scripts\zzz_rvm_sorties_rework.script') -Raw
foreach ($helper in @([regex]::Matches($main, '\b(balanced(?:_[A-Za-z0-9_]+)?)\s*\(') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)) {
    if ($main -notmatch ("local\s+function\s+" + [regex]::Escape($helper) + "\s*\(")) {
        $failures.Add("balanced helper is called without a local definition: $helper")
    }
}
foreach ($needle in @(
    'local function balanced_string(key, default)',
    'C.get_string("tier_" .. tostring(forced), key, C.get_string("global", key, default))',
    'C.get_balanced_string(level.name(), key, default)'
)) {
    if (-not $main.Contains($needle)) { $failures.Add("balanced string helper regression: $needle") }
}
foreach ($needle in @('raid_anomalys.spawn_artefact_in_zone','actor_on_item_take','npc_on_item_take','save_state','load_state','on_before_level_changing')) {
    if (-not $main.Contains($needle)) { $failures.Add("main hook missing: $needle") }
}
foreach ($needle in @('raid_artefacts_tiers_by_dop','raid_artefacts.addToQueuedArtefacts','{ 1, 2, 3, 4, 5 }','{ 5, 6 }','{ 6, 7 }')) {
    if (-not $main.Contains($needle)) { $failures.Add("artifact integration missing: $needle") }
}
foreach ($needle in @('generate_scripted_mapspot_at','set_pingspot_persistence','deregister_script_zone','visual_id','decoy plan','pending_transition','confirmed_level_change','safe_remove_map_spot')) {
    if (-not $main.Contains($needle)) { $failures.Add("test-fix integration missing: $needle") }
}
foreach ($needle in @('DEV_DEBUG','DEV_DEBUG_DEV','rvm_rework_debug','rvm_rework_census','population_census','owned_by_rework','spawned_info','SendOutput','paw_stash_red')) {
    if (-not $main.Contains($needle)) { $failures.Add("debug integration missing: $needle") }
}
foreach ($needle in @('safe_alive','safe_class_check','census_disabled','pcall(population_census_impl','pcall(detect_rvm_squad_changes_impl')) {
    if (-not $main.Contains($needle)) { $failures.Add("census safety missing: $needle") }
}
foreach ($needle in @('artifact_snapshot','actor_inventory','server_parent_chain','actor_owns_linked_artifact','artifact diagnostic reason=periodic','zone kept open')) {
    if (-not $main.Contains($needle)) { $failures.Add("artifact ownership safety missing: $needle") }
}
foreach ($needle in @('recreated_artifact_zone','actor_pickup_recreated_id','artifact lineage recovered','count == 1 and candidate')) {
    if (-not $main.Contains($needle)) { $failures.Add("recreated artifact lineage safety missing: $needle") }
}
foreach ($needle in @('ambush_start_trigger_margin','ambush_start_zone_margin','ambush_outside_zone_padding','anomaly_distance','ambush anomaly scan','offlevel_ignored','spawn_timing=%s','start_distance','device().cam_dir','ambush cascade begin','ambush cascade exhausted','ambush cascade success','inside_clear','inside_anomaly_allowed','outside_anomaly_allowed','inside_hidden_clear','inside_hidden_anomaly_allowed','outside_hidden_anomaly_allowed','inside_visible_anomaly_allowed','outside_visible_anomaly_allowed','golden_angle_nav_sweep','ambush_hidden_attempt_multiplier','ambush_retry_context_changed','resume_after=actor_moves_10m_or_camera_turns_20deg','ambush deferred','zone remains armed','reject=invalid:')) {
    if (-not $main.Contains($needle)) { $failures.Add("ambush placement safety missing: $needle") }
}
foreach ($needle in @(
    'local function ambush_spawn_squad(zone, spawn_timing)',
    'local inside_limit = math.max(0, zone.radius - math.min(zone.radius, inside_margin))',
    'min_zone = zone.radius + 1, max_zone = zone.radius + outside_padding',
    'if stage.require_view and not outside_view',
    'if stage.require_anomaly_clear and zone.anomaly_scan_complete == false',
    'if not ambush_spawn_squad(zone, spawn_timing) then'
)) {
    if (-not $main.Contains($needle)) { $failures.Add("ambush cascade regression: $needle") }
}
if ($main.Contains('spawn_timing=start next_spawn_timing=proximity')) { $failures.Add('start ambush must not fall back to remote proximity placement') }
if ($main.Contains('close_zone(zone, "unsafe_spawn_rejected")')) { $failures.Add('unsafe ambush search must defer while keeping the zone armed') }
foreach ($needle in @('ENEMY_SQUAD_PRESETS','choose_enemy_preset','enemy_category_weight_frequent','enemy_category_weight_rare','enemy_category_weight_superrare','spawn_exact_squad','squad:create_npc(nil, pos, lvid','SIMBOARD:setup_squad_and_group','SendScriptCallback("squad_on_npc_creation"','same_members(expected, sections)','partial_spawn_rollback','callback_rollback','release_enemy_squad','squad_id','member_ids')) {
    if (-not $main.Contains($needle)) { $failures.Add("exact squad integration missing: $needle") }
}
foreach ($needle in @('local roll = math.random() * total','roll < weights.frequent + weights.rare','presets[math.random(1, #presets)]')) {
    if (-not $main.Contains($needle)) { $failures.Add("two-stage squad probability regression: $needle") }
}
if ($main -match 'local\s+section\s*=\s*sections\[math\.random') { $failures.Add('independent random mutant creation returned') }
foreach ($needle in @('ARTIFACT_EXACT_SPOT = "rvm_exact_artifact_icon"','LOOT_EXACT_SPOT = "rvm_exact_loot_icon"','ENEMY_EXACT_SPOT = "rvm_exact_enemy_icon"','artifact_exact_marker_enabled','loot_exact_marker_enabled','enemy_exact_marker_enabled','exact_marker_hint','sync_artifact_exact_spot','sync_enemy_exact_spot','sync_enemy_squad_exact_spot','squad:commander_id()','marker_target_id','pairs(zone.spawned_ids or {})','owned_by_rework=true')) {
    if (-not $main.Contains($needle)) { $failures.Add("exact debug marker integration missing: $needle") }
}
foreach ($needle in @('ARTIFACT_EXACT_OVERLAP_DISTANCE = 2','diagnose_artifact_exact_overlaps','exact artifact marker overlap','exact positions preserved')) {
    if (-not $main.Contains($needle)) { $failures.Add("exact artifact overlap diagnostic missing: $needle") }
}
foreach ($needle in @(
    'return debug_enabled() or C.get_bool("global", "show_exact_artifact_markers", false)',
    'return debug_enabled() or C.get_bool("global", "show_exact_loot_markers", false)',
    'return debug_enabled() or C.get_bool("global", "show_exact_enemy_markers", false)',
    'if debug_enabled() then return debug_text end',
    'if debug_enabled() then return debug_text end',
    'local hint = game.translate_string("st_rvm_sorties_area_hint") .. zone_debug_text(zone, false)'
)) {
    if (-not $main.Contains($needle)) { $failures.Add("casual/debug exact marker separation missing: $needle") }
}
if ($main.Contains('user_exact_overlaps_zone')) { $failures.Add('user exact mode must not suppress the normal circle tooltip') }
if ($main.Contains('crlc_squad_red')) { $failures.Add('quest-pointer crlc_squad_red must not be used for enemy debug markers') }
if ($main.Contains('census skipped: diagnostics disabled')) { $failures.Add('debug-off/casual markers must not emit census diagnostics') }
foreach ($needle in @('roll_valuable_quota','percent_roll','weighted_section','valuable_first_chance','valuable_second_chance','valuable_third_chance','loot_valuable','loot_ordinary','loot_fragments','loot_cap','medicine_rolls','ordinary_capacity','rare_artifact_chance')) {
    if (-not $main.Contains($needle)) { $failures.Add("loot quality policy missing: $needle") }
}
foreach ($needle in @('math.random(2, 4)','roll <= 20 and 1 or roll <= 80 and 2 or 3','type preserved, no replacement created','local offset_divisor = math.max(1, balanced("loot_offset_divisor", 3))','local max_offset = math.max(0, radius / offset_divisor)','actual_offset <= max_offset','elseif snapped_offset > offset_limit then','artifact placement tier=%s level=%s offset=%s fraction=%s limit=%s range=%s..%s','separated(fixed, true)','local blocks = not (allow_artifact_overlap and zone.kind == "artifact")','report_artifact_center_failure(artifact_id, art.position, attempted, rejects)','ARTIFACT_RETRY_SUMMARY_MS = 60000','near_origin=%s','invalid_vertex','post_snap_limit','anchor_failure','retries continue, duplicate errors suppressed','artifact center retry pending id=%s position=(%s) near_origin=%s passes=%s attempts=%s rejects=[%s]; duplicate ERROR suppressed','ambush_start_center_exclusion_radius')) {
    if (-not $main.Contains($needle)) { $failures.Add("zone policy missing: $needle") }
}
if ($main -match 'create_decoy\([^\)]*\)[\s\S]{0,300}create_decoy\(') { $failures.Add('failed decoy type must not be rerolled or replaced') }
if ($main -match 'member:alive\s*\(') { $failures.Add('unsafe squad iterator member:alive() call detected') }
if ($main -match 'function on_before_level_changing\(\)[\s\S]{0,250}cleanup\(') { $failures.Add('before-level-change must defer cleanup until the destination level is known') }
if ($main -match 'drx_da_main\.spawn_artefact_on_smart\s*=') { $failures.Add('Arrival spawn function must not be wrapped') }
if ($main -match 'raid_dospawn_dungeons\.raid_start_spawn\s*=') { $failures.Add('RVM dospawn function must not be wrapped') }
if ($main -match 'math\.random\s*\(\s*1\s*,\s*100\s*\)\s*<=\s*45') { $failures.Add('old equal utility/modules loot fill detected') }
if ($main -match 'for\s+id\s*=\s*1\s*,\s*65534[\s\S]{0,300}IsArtefact') { $failures.Add('post-factum global artefact scan detected') }
if ($main -match '%\.\d+f') { $failures.Add('X-Ray printf-incompatible floating-point format detected') }

$ltx = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx') -Raw
$ambushProfiles = @{
    'level_y04_pole' = @('ambush_spawn_timing = start','enemy_spawn_distance_min = 90','enemy_spawn_distance_max = 150')
    'level_k01_darkscape' = @('ambush_spawn_timing = proximity','enemy_spawn_distance_min = 120','enemy_spawn_distance_max = 170')
    'level_l09_deadcity' = @('ambush_spawn_timing = start','enemy_spawn_distance_min = 80','enemy_spawn_distance_max = 120')
}
foreach ($section in $ambushProfiles.Keys) {
    $sectionMatch = [regex]::Match($ltx, "(?ms)^\[$([regex]::Escape($section))\]\s*(.*?)(?=^\[|\z)")
    if (-not $sectionMatch.Success) { $failures.Add("ambush profile section missing: $section"); continue }
    foreach ($needle in $ambushProfiles[$section]) {
        if (-not $sectionMatch.Value.Contains($needle)) { $failures.Add("ambush profile $section missing: $needle") }
    }
}
foreach ($needle in @('stash_mode = scouting','weight_enemy = 50','weight_loot = 25','weight_empty = 25','remove_on_npc_pickup = false','ambush_start_center_exclusion_radius = 120','artifact_offset_fraction_min = 0.10','artifact_offset_fraction_max = 0.20','artifact_offset_fraction_min = 0.06','artifact_offset_fraction_max = 0.12','loot_offset_divisor = 3','loot_offset_divisor = 5','loot_offset_divisor = 10','valuable_first_chance = 35','valuable_second_chance = 10','valuable_third_chance = 1.5','loot_cap = 6','loot_cap = 7','loot_cap = 8','loot_medicine_half_weight = medkit_army','loot_medicine_half_weight = medkit_scientic','loot_medicine_half_weight = adrenalin','loot_valuable = af_iam, lead_box, detector_simple, detector_advanced, af_cooler, af_freon, af_camelbak, af_frames, af_grid, af_surge, device_torch','loot_valuable = detector_advanced, detector_elite, af_iam, af_aac, lead_box, af_grid_up, af_freon_up, af_cooler_up, af_camelbak_up, af_frames_up, device_torch_nv_1, device_torch_nv_2','loot_valuable = detector_elite, detector_scientific, lead_box, af_aac, af_aam, device_torch_nv_3','rare_artifact_chance = 70','loot_rare_non_artifact = raid_intelligence_note','loot_container_visuals = raid_small_stash_1','map_spot = rvm_search_small','debug_mode = auto','debug_log = false','[level_y04_pole]','[level_k01_darkscape]','[level_l09_deadcity]')) {
    if (-not $ltx.Contains($needle)) { $failures.Add("config invariant missing: $needle") }
}
foreach ($needle in @('ambush_spawn_timing = proximity','ambush_start_trigger_margin = 20','ambush_start_zone_margin = 8','ambush_outside_zone_padding = 25','ambush_anomaly_clearance = 15','ambush_unknown_anomaly_radius = 20','ambush_retry_delay_ms = 10000','enemy_category_weight_frequent = 4','enemy_category_weight_rare = 2','enemy_category_weight_superrare = 1')) {
    if (-not $ltx.Contains($needle)) { $failures.Add("ambush config invariant missing: $needle") }
}
if ($ltx -match '(?m)^enemy_(?:sections|count_min|count_max)\s*=') { $failures.Add('obsolete independent enemy pools/counts must not remain in config') }
foreach ($forbidden in @('itm_ammokit','itm_advancedkit','itm_expertkit')) {
    if ($ltx -match "(?m)^loot_(?:valuable|rare_non_artifact)\s*=.*\b$forbidden\b") { $failures.Add("forbidden tool in valuable/rare pool: $forbidden") }
}
if ($ltx -match '(?m)^loot_rare_non_artifact\s*=.*\bdevice_torch\b') { $failures.Add('device_torch must not be in the rare pool') }
if ($ltx -match '(?m)^max_false_zones\s*=') { $failures.Add('obsolete max_false_zones must not control per-level false counts') }

$squadLtx = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\mod_system_rvm_sorties_squads.ltx') -Raw
$squadSections = [regex]::Matches($squadLtx, '(?ms)^\[(aer_(?:pole|darkscape|deadcity)_(?:frequent|rare|superrare)_[^\]]+)\]:online_offline_group\s*(.*?)(?=^\[|\z)')
if ($squadSections.Count -ne 57) { $failures.Add("expected 57 exact squad presets, found $($squadSections.Count)") }
$declaredPresets = @{}
$configuredCreatures = [System.Collections.Generic.HashSet[string]]::new()
$presetCounts = @{}
foreach ($match in $squadSections) {
    $name, $body = $match.Groups[1].Value, $match.Groups[2].Value
    if ($declaredPresets.ContainsKey($name)) { $failures.Add("duplicate exact squad section: $name") }
    $declaredPresets[$name] = $true
    if ($name -match '^aer_(pole|darkscape|deadcity)_(frequent|rare|superrare)_') {
        $countKey = "$($Matches[1])/$($Matches[2])"
        $presetCounts[$countKey] = 1 + [int]($presetCounts[$countKey])
    }
    if ($body -notmatch '(?m)^faction\s*=\s*monster\s*$' -or $body -notmatch '(?m)^common\s*=\s*true\s*$') { $failures.Add("invalid squad base fields: $name") }
    if ($body -match '(?m)^npc_random\s*=') { $failures.Add("npc_random forbidden in exact squad: $name") }
    $npcMatch = [regex]::Match($body, '(?m)^npc\s*=\s*([^;\r\n]+)')
    $countMatch = [regex]::Match($body, '(?m)^npc_in_squad\s*=\s*(\d+)\s*$')
    $members = @($npcMatch.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $npcMatch.Success -or -not $countMatch.Success -or $members.Count -ne [int]$countMatch.Groups[1].Value) { $failures.Add("exact npc/count mismatch: $name") }
    foreach ($member in $members) {
        [void]$configuredCreatures.Add($member)
        if ($member -notmatch '^(dog_|cat_|boar_|lurker_|pseudodog_|psy_dog_|bloodsucker_|snork_|fracture_|zombie_strong$|burer_|psysucker_|chimera_|m_controller_)') {
            $failures.Add("non-approved/non-mutant member in exact squad $name`: $member")
        }
    }
}
$expectedPresetCounts = @{
    'pole/frequent'=5; 'pole/rare'=4; 'pole/superrare'=3
    'darkscape/frequent'=12; 'darkscape/rare'=6; 'darkscape/superrare'=8
    'deadcity/frequent'=5; 'deadcity/rare'=7; 'deadcity/superrare'=7
}
foreach ($countKey in $expectedPresetCounts.Keys) {
    if ([int]$presetCounts[$countKey] -ne $expectedPresetCounts[$countKey]) { $failures.Add("preset category count mismatch $countKey`: expected $($expectedPresetCounts[$countKey]), found $([int]$presetCounts[$countKey])") }
}
foreach ($forbidden in @('zombie_blind','zombie_ghost')) {
    if ($squadLtx -match "(?m)^npc\s*=.*\b$forbidden\b") { $failures.Add("forbidden psi/ghost zombie in exact squads: $forbidden") }
}
foreach ($preset in $declaredPresets.Keys) {
    if ([regex]::Matches($main, '"' + [regex]::Escape($preset) + '"').Count -ne 1) { $failures.Add("preset must appear exactly once in Lua manifest: $preset") }
}
$manifestPresets = [regex]::Matches($main, '"(aer_(?:pole|darkscape|deadcity)_(?:frequent|rare|superrare)_[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
foreach ($preset in $manifestPresets) {
    if (-not $declaredPresets.ContainsKey($preset)) { $failures.Add("Lua manifest references missing exact squad: $preset") }
}
if (@($manifestPresets).Count -ne 57) { $failures.Add("Lua manifest must contain 57 exact presets, found $(@($manifestPresets).Count)") }
foreach ($needle in @('show_exact_artifact_markers = false','show_exact_loot_markers = false','show_exact_enemy_markers = false')) {
    if (-not $ltx.Contains($needle)) { $failures.Add("casual exact marker default missing: $needle") }
}
foreach ($key in @('show_exact_artifact_markers','show_exact_loot_markers','show_exact_enemy_markers')) {
    $matches = [regex]::Matches($ltx, "(?m)^$key\s*=\s*false\s*$")
    if ($matches.Count -ne 1) { $failures.Add("casual exact marker must have one global false default: $key") }
}
foreach ($forbidden in @('simk_card','artifact_container')) {
    if ($ltx -match "(?m)^loot_[^=]+=[^`r`n]*\b$([regex]::Escape($forbidden))\b") { $failures.Add("invalid configured loot section: $forbidden") }
}

[xml](Get-Content -LiteralPath (Join-Path $ModRoot 'fomod\info.xml') -Raw -Encoding UTF8) | Out-Null
$fomod = Get-Content -LiteralPath (Join-Path $ModRoot 'fomod\info.xml') -Raw -Encoding UTF8
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
if (-not $scoutingText.Contains('На документе отмечены стратегические точки и схроны, которые можно проверить.')) { $failures.Add('scouting intelligence text differs from the approved wording') }
if (-not $infectedText.Contains('вывести прямо к логову мутантов.')) { $failures.Add('infected danger text differs from the approved wording') }
if ($infectedText.Contains('или к стоянке недружественных людей')) { $failures.Add('infected route text retains the removed hostile-people phrase') }
$artifactExactHint = ($stringsXml.string_table.string | Where-Object id -eq 'st_rvm_sorties_exact_artifact_hint').text
$lootExactHint = ($stringsXml.string_table.string | Where-Object id -eq 'st_rvm_sorties_exact_loot_hint').text
$enemyExactHint = ($stringsXml.string_table.string | Where-Object id -eq 'st_rvm_sorties_exact_enemy_hint').text
foreach ($hint in @($artifactExactHint, $lootExactHint, $enemyExactHint)) {
    if (-not $hint -or $hint -match '(?i)RVM DEBUG|kind=|\bid\b|координат') { $failures.Add('casual exact marker hint is missing or exposes technical data') }
}
$scoutingUiText = $scoutingText + $stashSuffix
$infectedUiText = $infectedText
if ([regex]::Matches($scoutingUiText, [regex]::Escape('На документе отмечены координаты тайника.')).Count -ne 1) { $failures.Add('build_desc_header simulation must add the stash sentence exactly once to scouting') }
if ($infectedUiText.Contains('координаты тайника')) { $failures.Add('infected UI text must not mention a stash in scouting mode') }
if ($scoutingUiText -match '(?i)экспедиц' -or $infectedUiText -match '(?i)экспедиц') { $failures.Add('route UI text must use original RVM terminology, not expedition') }
$fragment = Get-Content -LiteralPath (Join-Path $ModRoot 'gamedata\configs\ui\map_spots_rvm_sorties.xml') -Raw
[xml]("<map_spots>" + $fragment + "</map_spots>") | Out-Null
foreach ($needle in @('rvm_search_small','rvm_search_medium','rvm_search_large','rvm_debug_target','width="32" height="32"','width="60" height="60"','width="48" height="48"','scale_min="1" scale_max="4.5"','a="220" r="255" g="210" b="64"','rvm_exact_artifact_icon','rvm_exact_loot_icon','rvm_exact_enemy_icon','location_level="20"')) {
    if (-not $fragment.Contains($needle)) { $failures.Add("map spot invariant missing: $needle") }
}
foreach ($needle in @('rvm_exact_artifact_icon_spot width="14" height="14"','rvm_exact_loot_icon_spot width="14" height="14"','rvm_exact_enemy_icon_spot width="15" height="15"')) {
    if (-not $fragment.Contains($needle)) { $failures.Add("exact icon sizing invariant missing: $needle") }
}
$watcher = Get-Content -LiteralPath (Join-Path $ModRoot 'tools\watch_live_log.ps1') -Raw
foreach ($needle in @(
    'CreationTimeUtc.Ticks','FileShare]::Delete','Log recreated or truncated','Start-Sleep -Milliseconds $PollMilliseconds',
    'Read-AppendedLines','Test-ReadCheckpoint','[switch]$SelfTest','partial line was not completed','truncate/regrow checkpoint path failed',
    '[double]$ShutdownGraceSeconds = 20','watcher exited before game was ever detected','game start was not recorded',
    'watcher stopped before grace elapsed','injected grace elapsed','Get-RunningGameProcess','AnomalyDX11AVX','VerifiedDX11',
    'game_closed_after_grace','finally {','Saved session:','latest.log','test-artifacts\live-logs','saved watcher output missing',
    'TreatControlCAsInput','Test-ControlCKey','Ctrl+C key recognition failed','terminationReason = ''ctrl_c'''
)) {
    if (-not $watcher.Contains($needle)) { $failures.Add("live log reopen support missing: $needle") }
}
if ($watcher.Contains('Get-Content -LiteralPath $LogPath -Wait')) { $failures.Add('live log watcher must not retain the old file handle with Get-Content -Wait') }
if ($watcher.Contains('New-Object IO.StreamReader')) { $failures.Add('live log watcher must read appended bytes directly, not buffer behind StreamReader') }
$gitIgnore = Get-Content -LiteralPath (Join-Path $ModRoot '.gitignore') -Raw
if (-not $gitIgnore.Contains('/test-artifacts/live-logs/')) { $failures.Add('generated live watcher archives must be gitignored') }
$configReference = Get-Content -LiteralPath (Join-Path $ModRoot 'docs\CONFIG.md') -Raw -Encoding UTF8
foreach ($needle in @('Необязательный казуальный режим точных меток','show_exact_artifact_markers','show_exact_loot_markers','show_exact_enemy_markers','enemy_spawn_distance_min/max','90..150','120..170','80..120','система аномалий Arrival')) {
    if (-not $configReference.Contains($needle)) { $failures.Add("config reference missing: $needle") }
}

if ($BuildModsRoot) {
    if (-not (Test-Path -LiteralPath $BuildModsRoot)) { $failures.Add("build mods root missing: $BuildModsRoot") }
    else {
        $lootSections = [regex]::Matches($ltx, '(?m)^loot_(?:medicine|ordinary|fragments|valuable|rare_non_artifact)\s*=\s*([^;\r\n]+)') |
            ForEach-Object { $_.Groups[1].Value -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
        foreach ($section in $lootSections) {
            & rg -q --glob '*.ltx' "^\[$([regex]::Escape($section))\]" $BuildModsRoot
            if ($LASTEXITCODE -ne 0) { $failures.Add("loot section not found in build: $section") }
        }
        foreach ($section in 1..17 | ForEach-Object { "raid_small_stash_$_" }) {
            & rg -q --glob '*.ltx' "^\[$section\]" $BuildModsRoot
            if ($LASTEXITCODE -ne 0) { $failures.Add("loot visual section not found in build: $section") }
        }
        foreach ($section in $configuredCreatures) {
            & rg -q --glob '*.ltx' "^\[$([regex]::Escape($section))\]" $BuildModsRoot
            if ($LASTEXITCODE -ne 0) { $failures.Add("exact squad creature section not found in build: $section") }
        }
        & rg -q --glob '*.xml' '<paw_stash_red>' $BuildModsRoot
        if ($LASTEXITCODE -ne 0) { $failures.Add('PAW red stash map spot not found in build: paw_stash_red') }
        & rg -q --glob '*.xml' '<paw_stash_green>' $BuildModsRoot
        if ($LASTEXITCODE -ne 0) { $failures.Add('PAW green stash map spot not found in build: paw_stash_green') }
        & rg -q --glob 'map_spots*.xml' '<alife_presentation_squad_enemy_1>' $BuildModsRoot
        if ($LASTEXITCODE -ne 0) { $failures.Add('GRA red squad map spot not found in build: alife_presentation_squad_enemy_1') }
        $safeEnemySpot = $false
        foreach ($spotFile in Get-ChildItem -LiteralPath $BuildModsRoot -Recurse -File -Filter 'map_spots*.xml') {
            $spotText = Get-Content -LiteralPath $spotFile.FullName -Raw
            $match = [regex]::Match($spotText, '<alife_presentation_squad_enemy_1>([\s\S]*?)</alife_presentation_squad_enemy_1>')
            if ($match.Success -and $match.Value.Contains('alife_presentation_squad_enemy_spot_1') -and $match.Value -notmatch 'pointer\s*=') {
                $safeEnemySpot = $true
                break
            }
        }
        if (-not $safeEnemySpot) { $failures.Add('GRA red squad map spot is missing a pointer-free wrapper') }
    }
}

& (Join-Path $ModRoot 'tools\watch_live_log.ps1') -SelfTest
& (Join-Path $ModRoot 'tools\test_geometry_policy.ps1') -ModRoot $ModRoot
& (Join-Path $ModRoot 'tools\test_loot_policy.ps1') -Samples 200000

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
