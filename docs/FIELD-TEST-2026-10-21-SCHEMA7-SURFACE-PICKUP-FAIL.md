# Field test: schema 7 fixed two models below pickup height

Date: 2026-10-21  
Build: `8eaa38902f0600cd49e62aee53b2fdc93f15c07f`  
Level/type: `k01_darkscape`, infected T2

## Result

Schema 7 solved the underground-fall failure: all seven artifacts reached the real physics-shell hold and none fell tens of metres. It still failed accessibility. IDs 6700 and 6911 were visibly a little below ground and could not be picked up. The user exited after save/load.

## Exact raid inventory and hold geometry

| ID | Section | Family / quality | Surface Y | Spawn Y | Held/post Y | Relative to surface | Outcome |
|---:|---|---|---:|---:|---:|---:|---|
| 6436 | `af_armor_4` | chem / low | 1.3 | 2.0 | 1.3 | 0.0 | picked |
| 6700 | `af_indeikam3` | gravi / low | 7.7 | 8.5 | 7.6 | -0.1 | fixed, unpickable |
| 6743 | `af_vyve` | gravi / low | -1.1 | -0.3 | -1.0 | +0.1 | picked |
| 6911 | `af_rusty_thorn` | chem / low | 0.4 | 1.2 | 0.1 | -0.3 | fixed, unpickable |
| 6991 | `af_bracelet` | chem / low | 2.8 | 3.6 | 3.0 | +0.2 | picked |
| 7002 | `af_rusty_kristall` | chem / medium | 0.8 | 1.6 | 1.1 | +0.3 | picked |
| 7012 | `af_mayatnik3` | gravi / medium | -1.6 | -0.8 | -1.4 | +0.1 | picked |

The pool returned seven valid distinct sections; weighting is not causal.

## Proven lifecycle

Startup reported `provenance_schema=7`. Exact targets used `source=guarded_surface_pivot`. All seven artifacts reached `artifact proactive held`; each problematic object had one element and `own_fixed=0`:

```text
id=6700 ... post=(359.1,7.6,-143.5) ... clearance=-0.1 ... own_fixed=0
id=6911 ... post=(415.8,0.1,480.2) ... clearance=-0.3 ... own_fixed=0
```

Thus the hook, exact-ID linkage, online callbacks, shell lookup, velocity zeroing and `physics_element:fix()` all worked. The failure is the final pickup clearance of heterogeneous meshes when a pivot is fixed at the ray surface.

Five accessible controls emitted `actor_pickup_callback`, proactive release and zone close. IDs 6700/6911 emitted no pickup callback or close. They later went offline with `online_shell_disappeared`; save persisted `awaiting_online` and `own_fixed=none`. Load restored the same IDs and targets, but the user then left the level, so confirmed-level-change cleanup released the records. There was no ALife teleport, respawn, duplicate net-spawn or weighted-pool failure.

Increasing only `artifact_proactive_clearance` cannot solve this: field evidence again proves that X-Ray discards server Y clearance when an artifact becomes online.

## Safe online lift API evidence

The installed game exports the string `force_set_position` in every DX8/DX9/DX10/DX11/AVX executable and `VerifiedDX11.exe`. The checked-in Modded Exes changelog for this build family explicitly states that physics initialization was fixed for `obj:force_set_position(pos, true)`. Conversely, generated `lua_help.script` has no general inventory `game_object:set_position`, and `physics_shell` exports no position transform setter.

Schema 8 therefore uses the proven client-object method exactly once per new online shell:

1. verify exact ID, section and no owner;
2. verify current pivot remains in the narrow fresh static-surface envelope;
3. call `object:force_set_position(surface + artifact_online_hold_clearance, true)`;
4. immediately verify the raised position;
5. zero shell velocities and fix only previously free elements.

Default online hold clearance is intentionally visible `2.0 m`, configurable and clamped to `0.5..3.0 m`. This does not call `alife():teleport_object`, does not recreate the object and cannot create duplicate IDs. Save/load repeats lift+fix for a new online incarnation; pickup releases only mod-owned fixed indices.

## Evidence

Local git-ignored bundle:

`test-artifacts/field-logs/2026-10-21-schema7-surface-pickup-fail-03`

- `xray_maksi.log`: `8F0F82224FE4E2721DDB5D2E23BE77578AF74D4BE98CFA0CA0E5128899CA2F32`
- watcher: `5DA980D97C73806481CCF152768E8433F6E435706DC64BBDBF05EB5600103B24`
