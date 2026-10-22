# RC staging 0.3.0-rc2

Source candidate: MCM implementation based on commit `3fd9736c81bd2b1fec517644e8acd1f65dcf78c1`, followed by version/release metadata commit.

Package policy:

- archive roots: `gamedata/`, `fomod/` only;
- no `docs/`, `tools/`, tests, logs, saves, caches, local paths or obsolete `installer/variants`;
- deterministic sorted manifest, fixed ZIP timestamps and two independent builds;
- independent extraction followed by full runtime/static suite and installed MCM 1.7.2 API match;
- annotated `v0.3.0-rc2` tag and GitHub prerelease only after identical build hashes.

Final ZIP SHA-256, byte size, tag commit and download verification are recorded in the GitHub release and final handoff after the verified build.
