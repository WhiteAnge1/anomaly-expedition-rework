# Schema 9 weighted five-raid field acceptance

Status: **PASS** for schema-9 proactive artifact lifecycle, configured variable counts, weighted true-field selection and T1/T2/T3 correctness smoke. This sample does **not** establish long-run balance percentages.

Tested commit: `42322e4603d3ca77d94a102a9c4a7e35cd85bf05`. Every game startup reported `provenance_schema=9`. Local immutable evidence bundle: `test-artifacts/field-logs/2026-10-21-schema9-weighted-five-raid-pass-05`.

## Evidence hashes

| File | SHA-256 |
|---|---|
| `xray_maksi.log` | `4E5A7DD0856901DF9708616F50E73D50F7F4373D1707FD9C526BEA3D0AB72B1F` |
| `aer-live-20261021-181136-505-22656.log` | `F847EAB02BE35E0F531ED92D642820DA3D0668CBF76ED2603931F660518341C8` |
| `01-t2-darkscape-7-artifacts.log` | `9C4FFC55A34A6390E584B172CF0C1B90ABFA27E16B49A25559E919D253D18696` |
| `02-t2-darkscape-6-artifacts-same-level-reload.log` | `9D73B375AF537240C8038C559FA7B3A9E45C7602EF9F5725884D92BFEB1D9C96` |
| `03-t2-darkscape-7-artifacts-same-level-reload.log` | `E908CB1A07B307757EB5D3A73ABBBBFAF30E5C4CDA2187B436FB4C1D845ED177` |
| `04-t1-pole-4-artifacts.log` | `86663596EFC3C906AF04E50E0CE88C55F82BDC2895AB4A142C0B79D717662ADC` |
| `05-t3-deadcity-5-artifacts.log` | `A95E18BE9BC0BB882F13BF0472463B9CEC6A9A0F645FDCCD2526F7D2733BFF55` |

## Raid matrix

| Raid | Configured count | Exact sections | Pool result | Cleanup |
|---|---:|---|---|---|
| T2 Darkscape 1 | 7 | `af_pudd_2`, `af_night_star2`, `af_night_star`, `af_vyvert2`, `af_dummy_dummy2`, `af_cristall_flower2`, `af_gravi2` | 3 low, 4 medium; all `fallback=none` | 11 zones: 7 artifact, 2 enemy, 1 loot, 1 empty; both owned squads cleaned |
| T2 Darkscape 2 | 6 | `af_bracelet`, `af_seaej`, `af_cristall_flower`, `af_swivel`, `af_fuzz_kolobok3`, `af_seaej` | 1 low, 5 medium; all `fallback=none` | same-level reload preserved 10/10 zones; final cleanup 6 artifact, 2 enemy, 2 empty; both owned squads cleaned |
| T2 Darkscape 3 | 7 | `af_cristall_flower2`, `af_gubka3`, `af_lifekam`, `af_dik_1`, `af_lifekam`, `af_night_star`, `af_gravi2` | 2 low, 3 medium, 2 high; all `fallback=none` | same-level reload preserved 10/10 zones; final cleanup 7 artifact, 1 enemy, 1 loot, 1 empty; owned squad cleaned |
| T1 Pole | 4 | `af_night_star2`, `af_medusa`, `af_fire_ba`, `af_kogot` | 1 junk, 3 low; high/unique weights zero, all `fallback=none` | 5 zones: 4 artifact, 1 empty |
| T3 Dead City | 5 | `af_gold_fish2`, `af_dik_2`, `jup_b1_half_artifact2`, `af_chelust`, `af_baloon` | 1 junk, 1 medium, 3 high; all `fallback=none` | 8 zones: 5 artifact, 2 loot, 1 empty; both containers opened before cleanup |

All configured rolls were within the supported count profiles: Darkscape `7/6/7`, Pole `4`, Dead City `5`. For every raid, `requested=callbacks=created=captured=linked`. No unique quality appeared outside T3; T1 emitted neither high nor unique. T3 permits unique but none occurred in this five-item smoke, which is expected and proves nothing about its 2% long-run rate.

## Exact lifecycle audit

All **29** captured exact IDs independently produced:

- one `artifact proactive lift ... verified=true`;
- one `artifact proactive held` with `clearance=1`;
- one pickup `release` and one `closed` record;
- the same ID and section from weighted selection through pickup.

No ID produced `verified=false`, `unresolved`, `retry_exhausted`, repeated lift, `game_object __eq`, online teleport, replacement ID or duplicate creation. Far objects remained offline until streamed and then completed the same one-lift lifecycle. The two same-level loading cycles preserved existing zones rather than generating new ones.

Within all five raid boundaries there were zero AER `ERROR`, `FATAL` or `SCRIPT ERROR` lines. The user reported no underground, inaccessible or unpickable artifact and successfully collected all 29.

## Decoys, loot and cleanup

Every decoy plan completed with `created=true` and `type_preserved=true`: T2 plans `4/4/3`, T1 `1`, T3 `3`. Loot placement stayed inside the configured limits in ordinary weighted raids: T2 offsets `32.8 <= 33.6` and `23.3 <= 46.2`; T3 offsets `8 <= 14.2` and `14.2 <= 14.9`. Present loot containers were opened and closed normally. Final confirmed-level cleanup ran once for every raid and removed the complete zone set; every spawned owned ambush squad has a cleanup record.

## Debug-only known limitation

The tester directly associated one same-level full loading cycle in T2 raid 2 and one in T2 raid 3 with debug artifact-marker travel. AER evidence proves safe preservation, not the caller: lines `40977 -> 53285/53287` and `76875 -> 89155/89156` show pending transition followed by `same_level` resolution and restoration of all 10 zones. Destination and continued play were correct. Tracked separately as GitHub issue #5; it is a non-blocking debug UX/performance limitation.

## Verdict boundaries

- **PASS:** schema-9 lift/hold/pickup lifecycle across T1/T2/T3 and same-level reload.
- **PASS:** configured count correctness and weighted-selector correctness smoke with no fallback or tier leakage.
- **PASS:** decoy/loot/zone/squad cleanup smoke.
- **NOT CLAIMED:** statistical validation of production percentages, rare 2% unique frequency, or public-release packaging readiness.

