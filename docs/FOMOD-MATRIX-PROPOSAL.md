# Final FOMOD matrix proposal

Status: design ready for owner approval. No `ModuleConfig.xml`, variants or archive are created in this step.

## Non-negotiable common baseline

Every selectable full LTX keeps:

- mod enabled;
- schema 9 proactive hold enabled at accepted `0.75` server / `1.0` online clearance;
- weighted true-field pool and accepted tier weights;
- current counts, radii, decoy weights, loot economy and ambush balance;
- all forced controls `off/0/false`;
- all same-ID/stabilization laboratory gates `false`;
- identical lists and level/tier sections.

Only the explicitly listed profile and marker keys differ. Each install choice copies one complete, statically validated `rvm_sorties_rework.ltx`; partial LTX overlays and line-merging installers are forbidden.

## Required behavior profiles

| Profile | `debug_mode` | Schema 9 | Legacy observe | Legacy actions | Intended user |
|---|---|---|---|---|---|
| **Recommended** | `off` | `artifact_proactive_hold=true` | `false` | proposed `false` | Ordinary public gameplay; weighted production behavior |
| **Observe-only** | `off` | `true` | `true` | `false` | Support/reproduction with legacy provenance observation but no legacy relocation |
| **Diagnostic** | `on` | `true` | `true` | `false` | Tester/developer: technical tooltips, all exact markers, log and census |

Diagnostic intentionally does **not** enable legacy actions, forced decoys/tier, cleanup or prototype gates. Those remain manual laboratory-only controls documented in `DEBUG-GUIDE.md`.

The owner must approve `artifact_rescue_actions=false` for Recommended. This does not turn off schema 9. If the owner instead requires legacy held-first rescue in Recommended, the complete variant can use `true`, but that choice must be documented as a separate production risk and re-smoked once.

## Independent exact marker selections

For Recommended and Observe-only, expose three independent checkboxes, default unchecked:

- exact artifact marker;
- exact loot-container marker;
- exact owned-enemy marker.

The eight possible combinations are materialized as eight complete LTX files per profile:

| Marker variant | Artifact | Loot | Enemy |
|---|---:|---:|---:|
| None | false | false | false |
| Artifact | true | false | false |
| Loot | false | true | false |
| Enemy | false | false | true |
| Artifact + Loot | true | true | false |
| Artifact + Enemy | true | false | true |
| Loot + Enemy | false | true | true |
| All | true | true | true |

This yields 16 complete public variants plus one Diagnostic variant: **17 full LTX files**. Diagnostic presents markers as “always enabled by full debug”; marker checkboxes must be hidden, disabled or ignored there rather than implying they work independently.

## FOMOD pages

1. **Welcome / requirements:** GRA 2.5 supported build, GRA Bolt, Rojok Artifact System, Arrival and PAW compatibility/load-order wording; existing saves supported; game must be restarted.
2. **Behavior profile:** single required choice among Recommended, Observe-only, Diagnostic. Recommended selected by default.
3. **Exact markers:** visible only for Recommended/Observe-only; three independent choices, all off by default, with clear balance/spoiler descriptions.
4. **Summary:** show chosen profile, marker categories, fixed weighted/schema-9 baseline, destination mod name and known debug-marker travel limitation.

## Invalid combinations excluded by construction

- `debug_mode=on` with a claim that individual marker toggles hide categories;
- schema 9 disabled;
- weighted profile disabled or custom pool weights;
- legacy actions enabled together with a profile named Observe-only;
- both stabilization gates enabled;
- debug teleport without exact hard-coded allowlist and all prerequisite gates;
- any forced decoy/tier/cleanup value left active;
- empty/zero decoy weights, invalid tier/count arrays or partial list overrides;
- partial `rvm_sorties_rework.ltx` overlays from multiple installer steps.

## Upgrade behavior requiring owner decision

A full variant necessarily replaces the config. Choose one policy before implementation:

1. **Explicit replacement (recommended):** installer warns that selecting a profile replaces the LTX; user backs up custom changes. This is deterministic and testable.
2. **Preserve existing config:** upgrade path installs no LTX when the user selects preservation. This is not a partial overlay, but it cannot guarantee new required keys/defaults and needs a separate compatibility check.

Do not attempt automatic line merge.
