# GitHub README and repository description outline

Status: реализовано для публичного `v0.3.0-rc7`; документ сохранён как контроль структуры README.

## Proposed repository description

`MO2 gameplay mod for GRA 2.5 infected expeditions: search areas, weighted Rojok artifact pools, variable counts, decoys, loot, ambushes and save-safe schema-9 artifact placement.`

## README structure

1. **Title, maturity and compatibility badge**
   - public version and release status;
   - exact supported GRA 2.5/GRA Bolt stack;
   - open-source repository and issue tracker.
2. **Thirty-second player summary**
   - approximate search circles instead of exact answers by default;
   - variable true-artifact counts;
   - weighted broad artifact catalogue preserving Rojok classes/mutations;
   - enemy/loot/empty decoys;
   - schema-9 accessibility hold preventing underground/unpickable rewards.
3. **What the mod does not change**
   - original mods remain untouched;
   - Arrival/world artifacts are not captured;
   - Rojok class/mutation queue remains authoritative;
   - no ALife teleport/respawn of schema-9 artifacts.
4. **Requirements and load order**
   - MO2, supported game/build, GRA Bolt, Rojok, Arrival, PAW;
   - precise priority wording and expected conflict indicators.
5. **Installation**
   - clean FOMOD installation;
   - Recommended profile and default marker state;
   - restart requirement;
   - existing-save behavior and next-expedition activation.
6. **FOMOD profiles**
   - Recommended, Observe-only, Diagnostic comparison table;
   - exact-marker choices and spoiler implications;
   - 136 complete-config combinations: profiles, area types and exact markers;
   - new-entry update policy; explicitly state that FOMOD neither backs up nor merges an old config.
7. **Gameplay details**
   - T1/T2/T3 counts and search radii;
   - true-field quality weights, explicitly labelled probabilities rather than guarantees;
   - decoy distribution and enemy timing;
   - loot construction and rare slot;
   - map circles and optional exact markers.
8. **Artifact safety and saves**
   - schema-9 guarded spawn and 1 m hold in player language;
   - save/load and streaming behavior;
   - pickup/NPC/container cleanup;
   - disable/uninstall behavior.
9. **Configuration**
   - link to `docs/CONFIG.md` and public config audit;
   - list only safe common switches in README;
   - warn that forced/laboratory keys are not gameplay options.
10. **Diagnostics and support**
    - log prefix, watcher, exact files to attach;
    - link to DEBUG-GUIDE;
    - issue template data: profile, versions, save state, steps, log SHA.
11. **Testing status**
    - schema-9 five-raid acceptance: 29/29 lifecycle PASS;
    - counts/pool correctness smoke scope;
    - clear disclaimer that five raids do not prove statistical percentages.
12. **Known limitations**
    - debug artifact-marker travel may cause a safe but slow same-level reload; link issue #5;
    - supported locations/build only;
    - balance remains versioned and configurable.
13. **Updating, rollback and uninstall**
   - install a versioned archive as a new MO2 entry and disable the old entry;
   - manually migrate supported custom values using changelog/config migration notes; never merge an old LTX;
    - disabling mod restores original behavior because source mods are unmodified.
14. **Integrity**
    - release archive SHA-256 and PowerShell verification command;
    - signed/annotated tag and GitHub release asset correspondence.
15. **Credits, attribution and license**
    - White_Angel;
    - GRA/GRA Bolt, Rojok Artifact System, Arrival and PAW integration/assets/API acknowledgements;
    - repository license and third-party boundaries.
16. **Changelog and links**
    - current release notes;
    - GitHub issues/releases;
    - Google Drive mirror only after identical-hash verification;
    - Discord announcement/support link if approved.

## Tone and information split

- Opening half: concise Russian player-facing explanation and installation.
- Advanced details: collapsible or linked documents, with no requirement to understand Lua/X-Ray.
- Technical names, IDs, coordinates and census stay in diagnostic documentation, not casual tooltips.
- Avoid categorical "start completely over": require a full game restart after installation, then enter a newly generated expedition; existing route papers are merely access keys.
