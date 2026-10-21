# Schema 8: first-online shell readiness and `game_object __eq` failure

Status: field run not accepted. All seven artifacts were eventually pickable, but the intended initial lift-and-hold lifecycle did not complete reliably. Evidence is archived locally in `test-artifacts/field-logs/2026-10-21-schema8-first-online-eq-fail-04`.

## Immutable evidence

- `xray_maksi.log`: SHA-256 `CF53C6B1910B45D614D68679E1789509653E7B204829080CED3B314E7BC499B9`.
- `aer-live-20261021-172621-821-10420.log`: SHA-256 `534E1103DF177C46B4BDAE15617755418CEEA38189FE8CA24F85EF2B14682939`.
- Tested runtime commit: `ca43606fbc9224d76af85f14415e65c5868f38b7`.
- Startup confirmed `provenance_schema=8`.

## Exact lifecycle evidence

| ID | Section | First online sequence | Rehydrate sequence | Pickup |
|---|---|---|---|---|
| 6919 | `af_propeller` | binder lift `3.4 -> 5.4`, verified; no held; next periodic throws missing `game_object.__eq` | not needed | released with no owned fixed element |
| 6431 | `af_night_star` | binder lift `2.5 -> 4.5`, verified; no held; next periodic throws missing `game_object.__eq` | not needed | released with no owned fixed element |
| 6435 | `af_vyvert` | binder lift `4.8 -> 6.8`, verified; shell was not held and later callbacks fail | after load near object: binder lift verified and `held`, own index 0 | own index 0 released on pickup |
| 6905 | `af_bracelet` | initially offline while far; on first later binder lift `2.7 -> 4.7` verified but first-update throws missing `game_object.__eq` | periodic/load near object later completes lift + `held`; next new incarnation also completes in binder | own index 0 released on pickup |

The user observed 6919 and 6431 near the surface, 6435 near the surface before a nearby save/load and clearly raised afterwards, and 6905 remaining offline/far until approached after a nearby reload. All seven artifacts were nevertheless pickable.

## Root cause

Schema 8 called `force_set_position` as soon as the online object existed. The log proves this call succeeded and its immediate position verification returned `true`, but no `held` line followed for the initial 6919/6431/6435 callbacks: their physics shell was not ready yet. X-Ray subsequently normalized or allowed the unheld object to return toward its surface pivot.

The next readiness callback entered `hold_attempt` and evaluated `lifecycle.runtime_online_ref ~= online`. X-Ray `game_object` userdata exports no equality operator, so this raised `No such operator [__eq] defined in class [game_object]`. Every periodic retry then failed at the same comparison before shell fixation. Save/load near an artifact happened to present a ready shell in the first callback, allowing lift and fix to finish atomically before the next failing comparison. A far offline object correctly stayed pending until it became online; distance was not the defect.

## Schema 9 correction

- Never retain or compare `game_object` userdata for identity. ID/section remain the exact identity checks.
- Treat binder `net_spawn` as the new-incarnation event and reset only serializable counters/strings.
- If binder/first-update arrives before the provenance record, record an ID-keyed runtime pending event; capture consumes it and immediately enters the ordinary hold path.
- Wait for a real physics shell before moving the object. Lift, verification, velocity zeroing and fixation then happen in the same callback.
- Readiness/verification retry is bounded to three actual lift calls per online incarnation. A successful verification consumes the lift allowance; missing shell does not.
- Offline objects remain pending and execute the same path on their next binder lifecycle.
- Default visible clearance is reduced from `2.0 m` to `1.0 m`; runtime clamp stays `0.5..3.0 m`.
- Schema 8 saves migrate their target to `surface_y + configured clearance`.

No ALife teleport, respawn, replacement ID or duplicate `net_spawn` is introduced.
