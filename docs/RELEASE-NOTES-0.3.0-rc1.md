# Anomaly Expedition Rework 0.3.0-rc1

Testing candidate for GRA 2.5 / GRA Bolt. This is a GitHub prerelease, not the final public release.

## Included

- Recommended, Observe-only and Diagnostic FOMOD profiles;
- independent dangerous, valuable and safe false-area switches;
- independent artifact, loot and enemy exact-marker switches outside Diagnostic;
- weighted Rojok artifact pool with native class/mutation handling;
- location-specific artifact and false-zone counts;
- schema-9 guarded artifact spawn and pickup-safe online hold;
- save/load and same-level travel lifecycle fixes;
- detailed logging and fail-closed diagnostics.

## Required acceptance smokes

1. New MO2 entry: Recommended, all area types, all exact markers, debug off, one new T2 expedition.
2. Second separate MO2 entry without merge: Recommended, all area types, no exact markers, debug off, existing shelter plus one short new expedition and save/load.

Do not merge this archive into the development or an older version folder. Install it as a separately named MO2 mod entry and disable the old entry. FOMOD does not back up or merge an old LTX.
