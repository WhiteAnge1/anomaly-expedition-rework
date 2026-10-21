# Public configuration audit — 2026-10-21

Scope: every user-editable key currently shipped in `gamedata/configs/plugins/rvm_sorties_rework.ltx`. This document proposes release defaults; it does not change runtime or the installed MO2 copy.

## Proposed public baseline

- `debug_mode = off` — mandatory public default.
- `artifact_proactive_hold = true`, `artifact_online_hold_clearance = 1.0` — the accepted schema-9 lifecycle remains enabled.
- `[artifact_pool] profile = weighted` with the accepted `T1 45/45/10/0/0`, `T2 10/32/43/15/0`, `T3 2/8/43/45/2` weights.
- All forced/debug laboratory switches remain `off`, `0` or `false`.
- `show_exact_artifact_markers`, `show_exact_loot_markers`, `show_exact_enemy_markers` default to `false`; the installer may independently enable them.
- All field-tested gameplay, loot, decoy, count, radius and ambush values remain frozen.

Important distinction: schema 9 is controlled by `artifact_proactive_hold`, not by `artifact_rescue_actions`. The latter gates only the deprecated rolling/underground/origin executor. The owner-approved public configuration keeps schema 9 **on** and legacy actions **off** in every profile. The deprecated runtime remains only to load older alpha saves and preserve research diagnostics; it is not a supported user feature or FOMOD choice.

Ranges below are either enforced by runtime or required safe invariants. A value described as “freeze” is technically editable but should not be exposed by FOMOD because invalid or untested combinations fail closed, degrade placement, or alter balance.

## Global core, decoys and placement

| Key | Current | Accepted / safe domain | Proposed public | Dependencies and exposure |
|---|---:|---|---:|---|
| `enabled` | `true` | boolean | `true` | Master switch; advanced manual only |
| `enable_location_artifact_counts` | `true` | boolean | `true` | `false` preserves stock RVM counts `4/8/6`; manual advanced switch |
| `enable_location_zone_counts` | `true` | boolean | `true` | `false` uses global `zone_count_values/weights`; manual advanced switch |
| `zone_count_values` / `zone_count_weights` | `1` / `1` | ordered integers `0..20` / positive relative integer weights | unchanged | Global false-zone-count fallback |
| `stash_mode` | `scouting` | `anomaly/scouting/disabled` | `scouting` | Field-tested; freeze, not FOMOD |
| `enable_enemy_decoys` | `true` | boolean | `true` | Independent FOMOD dangerous-area choice |
| `enable_loot_decoys` | `true` | boolean | `true` | Independent FOMOD valuable-area choice |
| `enable_empty_decoys` | `true` | boolean | `true` | Independent FOMOD safe-area choice |
| `weight_enemy` | `50` | number `>=0` | `50` | At least one enabled type must have positive weight |
| `weight_loot` | `25` | number `>=0` | `25` | Remaining enabled weights normalize automatically |
| `weight_empty` | `25` | number `>=0` | `25` | Not a count |
| `loot_container_visuals` | 17 `raid_small_stash_*` sections | non-empty CSV of existing sections | unchanged | Invalid entries are ignored; empty disables loot creation; never expose |
| `remove_on_npc_pickup` | `false` | boolean | `false` | `true` reveals NPC theft by removing the exact/area lifecycle; advanced only |
| `artifact_offset_fraction_min` | `0.35` | effective `[0,1]` | `0.35` | Global fallback; tier/level overrides win |
| `artifact_offset_fraction_max` | `0.80` | effective `[min,1]` | `0.80` | Must keep artifact inside circle after nav snap |
| `loot_offset_divisor` | `3` | effective `>=1` | `3` | Tier overrides win; larger means closer to center |
| `zone_separation_min` | `45` | non-negative metres | `45` | Applies to decoys; freeze |
| `placement_attempts` | `60` | positive integer | `60` | Several paths do not clamp zero; freeze |
| `ambush_hidden_attempt_multiplier` | `3` | integer `>=1` | `3` | Multiplies hidden proximity search cost |

## Ambush behavior

| Key | Current | Accepted / safe domain | Proposed public | Dependencies |
|---|---:|---|---:|---|
| `ambush_start_exclusion_radius` | `180` | `>=0` m | `180` | Combined with zone radius and trigger padding |
| `ambush_start_center_exclusion_radius` | `120` | `>=0` m | `120` | Start-timing preferred center |
| `ambush_start_trigger_margin` | `20` | `>=0` m | `20` | Start safety margin |
| `ambush_trigger_padding` | `130` | `>=0` m | `130` | Proximity activation threshold = radius + padding |
| `ambush_extra_padding` | `20` | `>=0` m | `20` | RVM dospawn reserve |
| `ambush_spawn_timing` | `proximity` | `proximity/start` | `proximity` | Level overrides Pole/Dead City to `start` |
| `ambush_anomaly_clearance` | `15` | `>=0` m | `15` | Strict first cascade stage |
| `ambush_start_zone_margin` | `8` | `>=0` m | `8` | Internal zone-edge margin |
| `ambush_outside_zone_padding` | `25` | `>=0` m | `25` | Emergency outside band |
| `ambush_unknown_anomaly_radius` | `20` | `>=0` m | `20` | Fallback shape radius |
| `ambush_retry_delay_ms` | `10000` | runtime minimum `1000` | `10000` | Retry cannot be faster than update tick |
| `ambush_spawn_safe_fallback` | `85` | `>=0` m | `85` | Used only if RVM distance unavailable |
| `enemy_spawn_distance_min` | `35` | `>=0`, `max>=min` | `35` | Tier/level overrides win |
| `enemy_spawn_distance_max` | `90` | `>=min` | `90` | Freeze |
| `enemy_category_weight_frequent` | `4` | `>=0` | `4` | At least one category positive |
| `enemy_category_weight_rare` | `2` | `>=0` | `2` | Relative weights |
| `enemy_category_weight_superrare` | `1` | `>=0` | `1` | Relative weights |
| `enemy_missing_resolves` | `true` | boolean | `true` | Missing owned squad resolves its zone |

None of these keys should be exposed in the first public FOMOD. They form one field-tested balance set.

## Loot economy

| Key | Current | Accepted / safe domain | Proposed public | Dependencies |
|---|---:|---|---:|---|
| `loot_ordinary` | 16 sections | non-empty existing-section CSV | unchanged | Repeats allowed |
| `loot_fragments` | 4 fragment sections | subset of `loot_ordinary` | unchanged | Controls stack quantity |
| `valuable_first_chance` | `35` | clamped `[0,100]` | `35` | First expensive slot |
| `valuable_second_chance` | `10` | clamped `[0,100]` | `10` | Conditional second slot |
| `valuable_third_chance` | `1.5` | clamped `[0,100]` | `1.5` | Conditional third slot |
| `rare_slot_chance` | `4` | clamped `[0,100]` | `4` | Separate from cap |
| `rare_artifact_chance` | `70` | clamped `[0,100]` | `70` | Conditional on rare slot |
| `update_interval_ms` | `1000` | documented `250..5000`, runtime minimum `250` | `1000` | Affects all periodic work |

Loot lists and chances are advanced balance controls, not FOMOD options.

## Schema 9 and legacy rescue

| Key | Current | Effective domain | Proposed public | Notes |
|---|---:|---|---:|---|
| `artifact_proactive_hold` | `true` | boolean | `true` | **Schema-9 master; mandatory ON** |
| `artifact_proactive_clearance` | `0.75` | runtime clamp `0.5..1.0` m | `0.75` | Server spawn clearance |
| `artifact_online_hold_clearance` | `1.0` | runtime clamp `0.5..3.0` m | `1.0` | Accepted visible/pickup clearance |
| `artifact_proactive_position_tolerance` | `0.35` | runtime clamp `0.1..1.0` m | `0.35` | Verification only, not relocation permission |
| `artifact_spawn_guard_attempts` | `8` | runtime clamp integer `1..20` | `8` | Invalid guarded spawn remains fail-closed |
| `artifact_rescue_observe_only` | `false` | boolean | profile-dependent | Legacy provenance monitor, not schema 9 |
| `artifact_rescue_actions` | `false` | boolean | **`false`** | Deprecated legacy relocation; unavailable in FOMOD |
| `artifact_rescue_rolling_policy` | `held_first` | `held_first/debug_teleport`; other values disable | `held_first` | Used only if legacy actions enabled |
| `artifact_rescue_underground_policy` | `held_first` | same | `held_first` | Same executor |
| `artifact_rescue_origin_policy` | `held_first` | same | `held_first` | Strict origin proof required |
| `artifact_rescue_origin_radius` | `2` | runtime `>=0` m | `2` | Freeze evidence threshold |
| `artifact_rescue_origin_field_margin` | `2` | non-negative m | `2` | Freeze |
| `artifact_rescue_origin_nav_mismatch` | `4` | runtime `>=0` m | `4` | Freeze |
| `artifact_rescue_underground_drop` | `12` | runtime `>=0` m | `12` | Freeze |
| `artifact_rescue_underground_vertex_gap` | `4` | runtime `>=0` m | `4` | Freeze |
| `artifact_rescue_underground_samples` | `3` | runtime integer `>=1` | `3` | Freeze |
| `artifact_rescue_underground_duration_ms` | `2000` | runtime `>=0` | `2000` | Freeze |
| `artifact_rescue_rolling_edge_margin` | `5` | runtime `>=0` m | `5` | Freeze |
| `artifact_rescue_rolling_confirm_ms` | `15000` | runtime `>=0` | `15000` | Freeze |
| `artifact_rescue_log_repeat_ms` | `60000` | runtime minimum `1000` | `60000` | Diagnostic throttling |

### Laboratory-only rescue keys

These keys must be identical and inert in every public FOMOD profile: `artifact_rescue_debug_same_id_teleport=false`, `artifact_rescue_debug_artifact_ids=1407,6362`, `artifact_rescue_debug_reason=rolling`, `artifact_rescue_debug_monitor_ms=30000` (effective minimum 30000), `artifact_rescue_debug_monitor_log_ms=5000` (minimum 1000), `artifact_rescue_debug_cooldown_ms=20000` (effective minimum 20000 after reconfirmation), `artifact_rescue_debug_max_dispatches=2` (clamp 1..2), `artifact_rescue_debug_same_frame_stabilization=false`, `artifact_rescue_debug_held_after_verified_actions=2` (clamp 0..2), `artifact_rescue_debug_held_stabilization=false`, `artifact_rescue_debug_held_timeout_ms=120000` (`0` disables timeout; positive values minimum 30000).

`same_frame_stabilization` and `held_stabilization` are mutually exclusive and require the debug teleport gate, exact hard-coded ID allowlist and legacy actions. They are never valid installer choices.

## Exact markers and debug

| Key | Current | Domain | Proposed public | FOMOD |
|---|---:|---|---:|---|
| `show_exact_artifact_markers` | `false` | boolean | `false` | Independent checkbox |
| `show_exact_loot_markers` | `false` | boolean | `false` | Independent checkbox |
| `show_exact_enemy_markers` | `false` | boolean | `false` | Independent checkbox |
| `debug_mode` | `off` | `auto/on/off` | **`off`** | Chosen by profile, not marker checkbox |
| `debug_log` | `false` | boolean | `false` | Legacy fallback only if `debug_mode` absent |
| `debug_force_decoy_type` | `off` | `off/artifact/enemy/loot/empty` | `off` | Never expose publicly |
| `debug_force_tier` | `0` | integer `0..3` | `0` | Never expose publicly |
| `debug_cleanup_current_sortie` | `false` | boolean one-shot | `false` | Never expose publicly |

Full debug forces all three exact marker categories regardless of their booleans and adds technical tooltips/log/census. Therefore marker selections are intentionally disabled or described as ignored in the Diagnostic profile.

## Weighted artifact pool

| Tier | Current / proposed `junk,low,medium,high,unique` | Validation |
|---|---|---|
| T1 | `45,45,10,0,0` | every weight `>=0`, exact sum `100` |
| T2 | `10,32,43,15,0` | same |
| T3 | `2,8,43,45,2` | same |

`profile` currently and publicly remains `weighted`; accepted values are `weighted` and `stock`. Invalid profile, invalid weight, non-100 sum, missing section, bad canonical map or inaccessible stock upvalue disables the weighted path for that session and falls back to stock. Weight sliders are excluded from FOMOD because arbitrary combinations multiply the test matrix and can silently select the stock fallback.

## Tier tables

| Key | T1 | T2 | T3 | Safe invariant / public decision |
|---|---:|---:|---:|---|
| `map_spot` | `rvm_search_small` | `rvm_search_medium` | `rvm_search_large` | Must reference existing DXML spot; freeze |
| `zone_radius_min` | `60` | `110` | `140` | positive integer, max >= min; level overrides below |
| `zone_radius_max` | `100` | `180` | `230` | freeze |
| `artifact_offset_fraction_min` | `.35` | `.10` | `.06` | runtime clamp `[0,1]` |
| `artifact_offset_fraction_max` | `.80` | `.20` | `.12` | runtime clamp `[min,1]` |
| `loot_offset_divisor` | `3` | `5` | `10` | effective `>=1`; field accepted T2/T3 |
| `medicine_chance` | `70` | `78` | `85` | percent clamped by roll helper |
| `loot_cap` | `6` | `7` | `8` | integer `>=1`; rare slot is additional |
| `loot_medicine` | 5 sections | 5 | 6 | existing sections; invalid entries ignored |
| `loot_medicine_half_weight` | `medkit_army` | `medkit_scientic` | `adrenalin` | should be in medicine list |
| `loot_valuable` | 11 sections | 12 | 6 | existing sections; distinct except T3 lead box |
| `loot_ordinary_nonfragment_weight` | `1` | `.75` | `.5` | non-negative relative weight |
| `loot_hand_watch_weight` | `.5` | `.375` | `.25` | non-negative relative weight |
| `loot_fragment_quantity_min` | `1` | `2` | `3` | integer >=1 |
| `loot_fragment_quantity_max` | `3` | `5` | `7` | integer >= min |
| `loot_rare_non_artifact` | `raid_intelligence_note` | same | same | existing-section CSV |

All tier loot lists and values remain frozen and outside FOMOD.

## Supported level overrides

| Section | Tier | Count values / weights | Timing | Radius | Enemy distance | Decision |
|---|---:|---|---|---|---|---|
| `level_y04_pole` | 1 | `3,4,5 / 35,60,5` | `start` | `55..85` | `90..150` | freeze |
| `level_k01_darkscape` | 2 | `5,6,7,8,9 / 5,20,47,26,2` | `proximity` | `150..240` | `120..170` | freeze |
| `level_l09_deadcity` | 3 | `4,5,6,7 / 11,80,7,2` | `start` | `140..220` | `80..120` | freeze |

For each level, `tier` must be `1..3`; count values and weights must have equal non-zero lengths, values must be unique positive integers, weights non-negative with positive total, and counts must not exceed supported RVM zone capacity. `artifact_count_profile` is a diagnostic name and must remain synchronized with its arrays.

False-zone count tables are explicit too: Pole `1` with weight `1`, Darkscape `2/3/4` with equal relative weights `1/1/1`, Dead City `1/2/3` with weights `20/60/20`. Values are ordered integers `0..20`; weights are positive relative integers and need not sum to 100. Invalid configuration logs an error and safely falls back to one false zone.

## What is safe to expose in FOMOD

Expose only:

1. one complete behavior profile: Recommended / Observe-only / Diagnostic;
2. independent artifact / loot / enemy exact marker choices for Recommended and Observe-only;
3. independent dangerous / valuable / safe false-area type choices for every profile.

Do not expose weights, radii, counts, rescue thresholds, spawn timing, forced settings, loot lists, pool weights, update rate or individual debug laboratory gates. They lack a bounded field-tested combination matrix and would require partial overlays or dynamic LTX merging.
