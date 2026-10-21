# RC staging 0.3.0-rc1

This repository tree is the release-candidate staging source. No final ZIP, Git tag or GitHub Release exists yet.

## Package layout

- common runtime: `gamedata/`;
- FOMOD metadata: `fomod/info.xml` and `fomod/ModuleConfig.xml`;
- 136 complete configs: `installer/variants/`;
- deterministic generator: `tools/generate_fomod.ps1`;
- matrix validator: `tools/test_fomod.ps1`.

The eventual archive root must contain `gamedata`, `fomod` and `installer` directly. Development documents, tests, `.git`, evidence logs and local dependencies are not runtime payload and must be excluded by the later archive builder.

## Exactly two field smokes before final packaging

1. Install the GitHub RC archive into a new versioned MO2 entry, disable the development copy, choose Recommended + all three area types + all exact markers, keep debug off, then run one new T2. Confirm nontechnical exact hints, effective debug false, weighted/schema-9 startup and a normal exit.
2. Install the same RC into another separately named MO2 entry without merging, disable the first RC entry, choose Recommended + all three area types + no exact markers, then load the existing shelter and run one short new expedition with save/load. Confirm no exact/technical markers, no reroll/respawn, and no files inherited from the other entry.

After both pass, build one clean archive from a clean Git commit, publish its SHA-256 with the GitHub asset, and only then place a byte-identical copy on Google Drive with the same hash.
