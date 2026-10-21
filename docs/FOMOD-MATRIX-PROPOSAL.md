# Final FOMOD matrix for 0.3.0-rc1

Status: owner-approved and implemented as RC staging. This is not a final archive, tag or GitHub Release.

## Common baseline

Every selectable full LTX keeps schema 9 (`artifact_proactive_hold=true`), the weighted artifact pool, location-specific artifact/false-zone counts, tested loot and ambush balance, and every forced/laboratory switch off. Deprecated legacy relocation is always `artifact_rescue_actions=false` and is not exposed by the installer.

The installer never merges lines and never edits an existing MO2 mod directory. Each conditional choice copies one complete `rvm_sorties_rework.ltx` over the common baseline inside the newly installed mod entry.

## Profiles

| Profile | Debug | Legacy observation | Legacy actions | Exact markers |
|---|---|---|---|---|
| Recommended | off | off | off | independently selectable, default none |
| Observe-only | off | on | off | independently selectable, default none |
| Diagnostic | on | on | off | full debug always shows all categories |

Diagnostic does not enable forced decoys/tier, one-shot cleanup, teleport or stabilization experiments.

## Search-area types

Three independent choices are available in every profile:

- dangerous false areas (`enable_enemy_decoys`), containing an owned mutant squad;
- valuable false areas (`enable_loot_decoys`), containing a loot cache;
- safe false areas (`enable_empty_decoys`), containing no reward or ambush.

All three default to enabled. Disabling all three is safe: true artifact fields remain and the false-zone plan simply creates no false areas. Their relative weights remain editable in the LTX and automatically renormalize over enabled types.

## Complete-variant count

- Recommended: 8 area-type combinations x 8 exact-marker combinations = 64.
- Observe-only: 8 x 8 = 64.
- Diagnostic: 8 area-type combinations; individual marker page is hidden because debug forces all markers = 8.
- Total: **136 complete LTX variants**.

Generated sources live under `installer/variants`; `fomod/ModuleConfig.xml` contains exactly one conditional install pattern for each. `tools/generate_fomod.ps1` regenerates them, and `tools/test_fomod.ps1` proves every file is a complete config, differs only in approved keys, retains schema 9/weighted/safe forced defaults, and has a one-to-one XML pattern.

## Advanced LTX controls intentionally not expanded into FOMOD

The following remain documented manual configuration rather than multiplying the installer matrix:

- `enabled` master switch;
- `stash_mode=anomaly/scouting/disabled`;
- `[artifact_pool] profile=weighted/stock`;
- `artifact_proactive_hold`;
- `enable_location_artifact_counts` and per-level `artifact_count_values/weights`;
- `enable_location_zone_counts` and global/per-level `zone_count_values/weights`;
- type weights, loot lists/chances, radii and placement attempts;
- per-level `ambush_spawn_timing`, including Darkscape `proximity/start`.

## Install and update policy

FOMOD does not back up user files and does not manage an existing MO2 directory. Acceptance uses a versioned GitHub archive installed as a new, separately named MO2 mod entry; the development/older entry is disabled.

For an update, install the new version as a new entry, compare the changelog and config migration notes, manually transfer still-supported custom values, then disable or remove the old entry. Do not use MO2 merge to retain an old LTX: it may omit new required keys and makes the installed result impossible to reproduce.

After acceptance, the identical archive may be mirrored to Google Drive. Both copies must publish the same SHA-256.
