# Field test: proactive hold rejected every online artifact

Date: 2026-10-21  
Build: `ea4b6c343396b0a98dd35a14d28e8dc634e8316b`  
Level/type: `k01_darkscape`, infected T2

## Result

The compile-limit hotfix loaded correctly. Startup self-test, sortie hooks, weighted pool, exact-ID capture, both artifact lifecycle callbacks, save and load all executed. Nevertheless three of seven artifacts fell roughly 40–47 metres below their proven surfaces. Save/load preserved that bad state. The build is rejected.

## Exact raid inventory

| ID | Section | Pool family / quality | Surface Y | Binder online Y | Outcome |
|---:|---|---|---:|---:|---|
| 6703 | `af_cristall_flower2` | gravi / medium | 1.0 | 1.0 | picked |
| 6905 | `af_zhelch` | chem / junk | -0.4 | -0.4 | underground, final online Y -40.7 |
| 6959 | `af_absorbent` | gravi / low | -1.0 | -1.0 | underground, final online Y -40.8 |
| 6994 | `af_cristall_flower3` | gravi / medium | 0.7 | 0.7 | picked |
| 7002 | `af_blood` | chem / medium | 11.1 | 11.1 | picked |
| 7016 | `af_water_flower1` | chem / medium | 9.2 | 9.1 | picked |
| 7795 | `af_fuzz_kolobok3` | chem / medium | 5.1 | 5.1 | underground, final online Y -40.9 |

The weighted selector produced seven valid, distinct sections and is not causally involved.

## Proven callback chain

For all three failed IDs, guarded spawn produced a static-ray target and exact schema-6 provenance. `item_artefact.artefact_binder.net_spawn` then invoked the AER wrapper, followed by `artefact_on_first_update`. This proves the wrapper was neither missing nor overwritten by load order.

The decisive lines are structurally identical:

```text
artifact proactive online id=6905 source=binder_net_spawn ...
artifact proactive hold attempt id=6905 ... target=(292.6,0.3,-158.2)
ERROR artifact proactive unresolved ... current=(292.6,-0.4,-158.2) ... clearance=0,required=0.4
```

The server spawn target was `surface_y + 0.75`, but X-Ray converted the online artifact pivot to the static surface before the binder callback. The old predicate incorrectly treated the raised server spawn point as the required online pivot. It rejected every observed binder position before inspecting or fixing the physics shell. There are 24 `artifact proactive online` events, 65 hold attempts, and zero `artifact proactive held` events.

After rejection, IDs 6905/7795 fell rapidly through `-9`, `-17`, `-36` and finally about `-40`; ID 6959 followed the same path when it came online later. The four picked artifacts survived only because collision happened to keep them accessible despite also being rejected.

Save recorded all three failures as `state=unresolved`, `own_fixed=none`. Load restored the same exact IDs and targets, then correctly refused to move already buried online objects. No proactive or legacy `teleport_object`, respawn, duplicate ID, or rescue action occurred.

## Architectural correction

Schema 7 separates two coordinate contracts:

- `spawn_pos` / `spawn_clearance`: raised server creation point used only by guarded spawn;
- `target.pos`: proven static surface pivot used by online validation and physics-shell hold.

The surface envelope remains strict: exact ID/section, horizontal tolerance, fresh static ray, matching surface and pivot within `±artifact_proactive_position_tolerance`. It merely stops demanding impossible visible hover from heterogeneous artifact pivots. The binder then zeroes velocity and fixes every previously free shell element; save/load rehydrates a new shell at the same surface target. Online relocation and `teleport_object` remain forbidden.

The integration regression uses all seven field-observed binder/first-update Y values. The old `surface+0.75` predicate fails those rows; schema 7 must accept and fix them, then repeat the hold after simulated save/load.

## Evidence

Local immutable bundle (git-ignored full logs):

`test-artifacts/field-logs/2026-10-21-proactive-underground-fail-02`

- `xray_maksi.log`: `497C022834635AAC106ADCF366DB74E27D291C2BF1D6A72FF5638459F3D50077`
- watcher: `01333CB3D15C877DDCFE06A500DBE7FD512FF6B03CC2CFC7A178A8C335AEBE57`
