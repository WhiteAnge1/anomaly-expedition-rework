# Field test: proactive-hold startup compile failure

## Result

Commit `7a05b5094e8246100cb0e59fb153bd35130a8c68` did not load in X-Ray during the first infected T2 Darkscape test. The stock-looking sortie was caused by the AER main script failing before any callback, not by the zone generator choosing stock content.

Both the complete `xray_maksi.log` and the contemporaneous watcher log contain:

```text
zzz_rvm_sorties_rework.script:6027: main function has more than 200 local variables
Failed to load script zzz_rvm_sorties_rework
```

There is consequently no AER startup marker, hook installation, `prepare`, `artifact_pool`, `captured`, zone, decoy, or proactive-hold event in that run. This is retained as the negative-control signature for an unloaded runtime.

## Cause and fix

The proactive-hold implementation added `local PROACTIVE = {}` to a main chunk already at the X-Ray-specific local-variable boundary. Lua 5.1, LuaJIT 2.0/2.1 and `luaparser` accepted the file, but the game rejected it.

The hotfix moves the table to the collision-resistant global namespace `RVM_SORTIES_PROACTIVE`, without a local alias. The source is back to 198 explicit main-chunk locals, matching the last loadable budget. `tools/test_xray_main_chunk_locals.py` now blocks any increase and proves its own negative fixture at 199. `tools/test_startup_generation_path.py` preserves the unloaded stock-only negative control and the expected loaded path from startup through zone/decoy generation.

## Evidence

The local, intentionally git-ignored evidence bundle is:

`test-artifacts/field-logs/2026-10-21-proactive-startup-compile-fail-01`

Recorded SHA-256:

- `xray_maksi.log`: `CF0D3B7C329A2BAB5202F7B8D56A7AD3DD17EE67EF7373FCD14B0B524414F3E1`
- watcher log: `0706F03A7AB453369B1B0894E5DB236F4702603610F2D3168BA1DF6425E77749`

The unrelated `uni_anim_detectors.script:33 zzz_ea_addon_backpack nil` line remains outside AER scope.

## Required repeat test

Start from a fully closed game with the hotfix installed and a fresh watcher session. The first acceptance gate is the absence of both compile-error lines and presence of the AER startup self-test. Only then enter a new infected sortie and verify `prepare`, `artifact_pool`, `captured`, artifact/decoy zone creation and proactive held/release lifecycle events.
