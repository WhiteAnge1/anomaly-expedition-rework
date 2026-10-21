# MCM static report — 2026-10-22

Status: implementation complete in source; **MO2 copy not changed; rc2 not created**.

## Implemented

- 56 public controls under `Настройки → MCM → Переработка аномальных вылазок`.
- Master switch, stash routing, three decoy types and weights, three exact-marker switches, NPC pickup policy, weighted/stock pool and all 15 quality weights.
- Per-location artifact-count enable and explicit weights for Pole 3/4/5, Darkscape 5–9, Dead City 4–7.
- Per-location false-area-count enable and explicit weights for Pole 1, Darkscape 2/3/4, Dead City 1/2/3.
- Darkscape proximity/start choice, schema-9 master/clearances/tolerance/attempts, update interval.
- Debug, forced controls and deprecated legacy rescue deliberately remain outside MCM.
- Russian and English label plus detailed tooltip for every control. Each tooltip states gameplay effect, dependencies/disabled behavior, exact public default, range/options and `next new expedition` timing.

## Effective settings and save safety

`rvm_sorties_config.script` is now the sole effective reader. Valid MCM overrides LTX; missing/gathering/throwing/invalid MCM falls back to LTX. A versioned snapshot is created once at the new-expedition boundary, persisted in `state`, reactivated on load and cleared only with sortie cleanup. Repeated callbacks and same-level travel do not resnapshot. Old active saves without a snapshot migrate once.

Quality and artifact-count rows use deterministic largest-remainder normalization to exactly 100. Invalid/zero pool rows and all-zero enabled decoy weights fall back as a whole to LTX. False-area rows use validated positive relative weights. No division occurs before a positive-total guard.

## FOMOD

The 136 complete LTX variants and conditional matrix were removed. FOMOD now installs one required `Recommended MCM baseline`; supported choices live in MCM. Packaging and archive verification reject any reintroduced `installer/` variants.

## Static results

- Actual installed MCM API `Anomaly-MCM 1.7.2/ui_mcm.script`: matched (`get`, `is_gathering`, `get_opt_table`, gathering prohibition, `_desc` convention).
- Lua 5.1, LuaJIT 2.0, LuaJIT 2.1: all 5 runtime scripts compile.
- X-Ray main chunk: `198/198`; negative fixture fails at 199 as expected.
- MCM defaults parity, round-trip, normalization, zero/invalid handling, missing/broken fallback and immutable snapshot: OK on all three runtimes.
- Bilingual localization: 56/56 controls have label, exact default, apply timing, range/options and dependency text.
- Existing artifact spawn proxy, origin evidence, artifact counts, 223-section pool, proactive hold, startup path, geometry/cascade, rescue/stabilization and FOMOD tests: OK.
- Loot policy: 200,000 deterministic samples per tier, OK.
- `luaparser`, XML parsing and `git diff --check`: OK.

## Required field acceptance before rc2

1. Install a clean archive/copy only after owner approval; fully restart X-Ray.
2. Open the MCM tab, visually inspect Russian labels/tooltips and use Reset/Defaults.
3. Start a new infected expedition and confirm `settings snapshot created` plus normal generation.
4. Change conspicuous settings during that expedition; save/load or same-level travel must preserve the original snapshot without new creates.
5. Leave normally, start the next expedition and confirm the new settings apply once.
6. Temporarily test missing MCM only in an isolated profile if desired; LTX baseline must load without mod ERROR/FATAL.
7. Return every forced/debug LTX key to public defaults. Only then consider `0.3.0-rc2`.
