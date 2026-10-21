# Public release readiness gaps — 2026-10-21

Current state: gameplay alpha has passed schema-9 and weighted T1/T2/T3 correctness smoke. Public release remains blocked by presentation/default/packaging acceptance, not by the artifact lifecycle verified in the five-raid series.

## Already complete

- Schema-9 proactive lifecycle: 29/29 exact artifacts across five raids lifted once to `clearance=1`, held, picked up, released and closed without runtime errors.
- Configured count smoke: T2 `7/6/7`, T1 `4`, T3 `5`; every raid had `requested=created=captured=linked`.
- Weighted-pool smoke: correct tier weights, no fallback, no unique outside T3 and no high/unique at T1.
- Same-level state persistence: both observed full reloads restored all 10 zones without regeneration.
- T2/T3 loot-radius smoke and container lifecycle.
- Existing debug guide, static suite, PowerShell 5.1 compatibility and live watcher.
- GitHub repository, alpha tags through `v0.2.1-alpha`, MO2 install and source/installed runtime hash checks.

## Remaining release gates, in order

1. **Freeze public defaults and documentation.** Decide whether the public package keeps `debug_mode=on` and legacy `artifact_rescue_actions=true`; release-oriented defaults should normally be `debug_mode=auto` or `off`, forced settings `off/0/false`, weighted profile explicit, schema-9 proactive hold enabled at `1.0 m`, and legacy rescue policy documented. Reconcile stale documentation that still calls the stock artifact pool recommended/default. Record GitHub issue #5 under known limitations.
2. **Two minimal debug-off field smokes.** First: debug off with user exact markers explicitly enabled, confirming localized nontechnical tooltips and pickup/open/death cleanup. Second: debug off with all exact-marker categories disabled, confirming ordinary circles/gameplay with no technical marker leakage. The second run should also close the checklist item for normal debug-off count persistence/no respawn after load.
3. **Finish installer design and FOMOD validation.** Current package contains only `fomod/info.xml`; there is no `ModuleConfig.xml`. Define one unambiguous install path for the supported GRA 2.5 stack, dependency/conflict wording, displayed `[Геймплей]` name/version and upgrade behavior. Do not add optional combinations that were not tested.
4. **Clean archive/install/upgrade test.** Build from a clean Git tree, exclude `.git`, evidence logs and development artifacts, install into a fresh MO2 mod entry, verify expected conflicts/priority, run static fast checks against the installed copy, then upgrade from `0.2.1-alpha` while preserving user config intentionally. Validate disable/uninstall restores source-mod behavior.
5. **Release metadata and attribution.** Choose the next version, update README/FOMOD/meta consistently, prepare changelog, create the matching signed or annotated tag and GitHub release only after acceptance. Add an explicit license and credits/attribution for GRA Bolt, Rojok Artifact System, Arrival and PAW APIs/assets where applicable; currently no standalone license/credits file is present.
6. **Public documentation package.** Split concise spectator-facing installation/feature summary from the advanced configuration/debug guide. Include compatibility requirements, load-order priority, existing-save behavior, schema-9 safety behavior, rollback/uninstall, known limitations, log collection and SHA-256 verification instructions.
7. **Discord/release materials.** Prepare short announcement, installation block, highlights, limitations, testing status, support template and links to GitHub/release archive. Include screenshots only after the two debug-off presentation smokes.

## Minimal next stage

Do not change gameplay runtime. First freeze intended public config defaults and perform the two debug-off presentation smokes. Only then implement/validate FOMOD and produce a clean release-candidate archive.

