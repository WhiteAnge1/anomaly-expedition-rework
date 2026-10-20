# Результат статических проверок

Последнее обновление: 2026-10-15.

- Все три `.script` разобраны `luaparser 4.2.0`: синтаксических ошибок нет.
- `fomod/info.xml` и русская string table разобраны XML-парсером; для string table отдельно проверены Windows-1251, декларация кодировки и контрольная русская строка.
- Фрагмент DXML `map_spots_rvm_sorties.xml` проверен внутри временного корня `<map_spots>`.
- Проверено наличие ключевых hooks, callbacks сохранения/загрузки/очистки и конфигурационных инвариантов.
- Проверено отсутствие обёртки `drx_da_main.spawn_artefact_on_smart` и постфактум-перебора всех артефактов уровня.
- Проверено динамическое чтение штатной таблицы артефактов, точное соответствие групп пулов `{1..5}`, `{5,6}`, `{6,7}` и вызов сохраняемой очереди `raid_artefacts.addToQueuedArtefacts`.
- `tools/test_artifact_pool.py` исполняет новый true-field selector в Lua 5.1/LuaJIT 2.0/2.1: 223 уникальные base-section, 20 непустых ячеек, aliases семейств, точные границы весов, нулевые buckets, распределение 100000 бросков на тир, повторы, все 14 T3 unique, fail-closed stock fallback и восстановление локальной `raid_groups_artifacts` после success/error.
- Проверено использование PAW `script_zone`, видимых `raid_small_stash_*`, отсутствие несовместимых `printf`-форматов и запрещённых после полевого теста loot-секций.
- Проверены global-debug auto/default-off, три независимых пользовательских exact-marker default-off, разделение обычных и технических tooltip, безопасный вывод runtime-команд в Debug UI, census и отсутствие обёртки штатного `raid_dospawn_dungeons.raid_start_spawn`.
- Проверены exact-ID fallback владения артефактом, fail-closed сохранение области, размеры кругов `32/60/48` при `scale_max=4.5`, icon-only exact markers с `location_level=20` и per-level `start/start/proximity`.
- `test_loot_policy.ps1` отдельно моделирует 200000 контейнеров каждого тира: medicine 0/1/2, valuable 0/1/2/3, число ordinary, rare, частоту и количество осколков, T3 `af_aam` и `adrenalin`, повторы и максимумы `cap+rare`; static check запрещает возврат старого 45/55 fill и tools в valuable/rare.
- `watch_live_log.ps1 -SelfTest` реально дописывает полную и частичную строки, проверяет truncate с быстрым повторным ростом файла через byte-checkpoint, delete/recreate и сохранение только отфильтрованных строк. Отдельный sharing-lock fixture держит `latest.log` эксклюзивно и доказывает, что авторитетный уникальный session-файл продолжает работу, live latest отключается без падения, handles закрываются, а atomic final publish восстанавливается после снятия lock. Детерминированная lifecycle-модель доказывает отсутствие выхода до первого обнаружения игры, фиксацию старта и завершение лишь после инъецированного короткого grace; runtime default остаётся 20 секунд. Runtime-reader читает новые байты напрямую через `FileStream`, не полагаясь на буферизацию `StreamReader`.
- `test_geometry_policy.ps1` проверяет неизменные размеры кругов `32/60/48`, loot T1/T2/T3 `radius/3`, `radius/5`, `radius/10`, artifact-профили `0.35..0.80`, `0.10..0.20`, `0.06..0.12`, фактический post-snap limit, разрешённое перекрытие только истинных artifact-зон при сохранённом separation ложных зон, подробные rate-limited artifact-center причины, порядок пяти proximity-фаз и расширенный low-discrepancy hidden search.
- `test_artifact_rescue_policy.ps1` проверяет строгий origin-мismatch против законного near-origin, универсальный exact registry-match на разных семействах `electr/chem`, fail-closed для missing/ambiguous registry, schema-3 revalidation, bounded online→offline gate с возвратом switch-флагов, rebuild области после проверки, underground debounce `12 м / 4 м / 3 samples / 2 с`, rolling `radius+5 / 15 с`, ownership/target guards и rate limit.
- `test_lua51_compile.py` обязательно компилирует каждый runtime-script настоящими frontends Lua 5.1, LuaJIT 2.0 и LuaJIT 2.1 через `loadstring`. Фактический X-Ray loader резервирует один local вокруг script chunk: именно добавление одного inert wrapper-slot воспроизводит падение предыдущего commit `1661ffd`, которое bare Lua на самой границе ещё пропускал. Synthetic chunk из 200 top-level local плюс wrapper-slot обязан быть отвергнут с `200 local`, иначе проверка считается недействительной. Это закрывает класс ошибок, который AST-only `luaparser` не обнаруживает. Зависимость устанавливается локально командой `python -m pip install --target <project>\work\lua-runtime lupa`; `static_check.ps1` принимает `-LuaRuntimeDeps` и fail-closed при отсутствии runtime.
- Исторический запрет любого `teleport_object` в предыдущем пункте относился к завершённой phase 1; для текущего prototype он заменён строгим требованием ровно одного call site. Дополнение rescue-policy проверяет causal priority без ложного rolling→underground, schema-1→2 migration, обязательный свежий post-load snapshot, четыре default-off gate и отсутствие physics actions. Unique/ambiguous NPC replacement lineage, terminal `owned`, replacement ID и lookup после save/load также остаются обязательными; ambiguous section-кандидаты fail-closed.
- Проверены исходные PAW/GRA-текстуры в фактических XML сборки, собственные exact wrappers с `location_level=20`, размеры `14/14/15`, icon-only пользовательский exact-hint, сохранённый обычный hint круга и перенос единственной enemy-метки через `squad:commander_id()`; quest-pointer `crlc_squad_red` запрещён.
- Текущий rescue-policy дополнительно закрепляет exact allowlist `1407,6362` без section fallback, независимые лимиты ID, `position_verified` вместо трёхкадрового stable, мониторинг не менее 30 секунд, новый rolling-эпизод 15 секунд, cooldown 20 секунд и максимум два dispatch на ID.
- `test_artifact_stabilization_policy.ps1` отдельно требует default-off stabilization gate, два verified обычных dispatch, третий независимый rolling-эпизод, hard maximum 3, один прежний teleport call site, обход всех physics elements, pcall-обёртки, same-callback release sweep и запрет permanent fix/offline/recreate/apply_force.
- `test_artifact_held_stabilization_policy.ps1` проверяет несовместимые stabilization-gate, journal только собственных unfixed элементов, release-before-save/transition, load-first recovery, pickup/owner/timeout/cleanup triggers, hard maximum 3 и отсутствие offline/recreate/apply_force.
- Регрессия same-level cleanup закрыта статическим запретом прямого `cleanup()` из `on_before_level_changing`; очистка разрешена только после определения фактического уровня на `actor_on_first_update`.
- Каждый вызванный helper семейства `balanced*` обязан иметь локальное определение; отдельно проверяется строковая ветка forced tier → global default → `C.get_balanced_string`. Это закрывает runtime-регрессию `attempt to call global 'balanced_string'` до запуска игры.
- Статически закреплены три start-ступени и четыре Darkscape-ступени, повторная проверка диапазона после nav-привязки, отдельные логи начала/исчерпания/успеха и отсутствие старого независимого выбора `enemy_sections`.
- Проверяются все 57 exact squad sections: наследование `online_offline_group`, `faction=monster`, `common=true`, точное совпадение `npc_in_squad` со списком `npc`, отсутствие `npc_random`, `zombie_blind` и `zombie_ghost`, а также взаимно однозначная связь с Lua manifest. При `-BuildModsRoot` проверяется существование каждой creature section в фактической сборке.
- `tools/*.ps1` с кириллицей обязаны иметь UTF-8 BOM и проверяются запуском через Windows PowerShell 5.1 (`powershell.exe`), а `.cmd`-обёртка остаётся ASCII.
- При передаче `-BuildModsRoot` дополнительно проверяется наличие сборочных секций модулей, разведданных и всех 17 моделей тайников.
- Стохастическая симуляция 100 000 вылазок дала:
  - всё включено: 60.00 / 19.98 / 10.02 / 10.00%;
  - без засад: 74.97 / 12.55 / 12.48%;
  - только пустышки: 85.78 / 14.22%;
  - все ложные типы выключены: 100% настоящих областей.

## Уровни проверки

Проверки запускаются пропорционально изменению, а не все после каждой локальной правки:

- Lua/runtime rescue: core static + rescue-policy + `luaparser`, профиль `fast`;
- watcher/PowerShell: PS parser и watcher self-test, профиль `watcher`;
- геометрия кругов/размещения: профиль `geometry`;
- loot RNG/cascade/config: профиль `loot`, который выполняет 600000 детерминированных генераций;
- интеграционная контрольная точка или release: профиль `full` плюс фактический `BuildModsRoot`.

Текущая rescue-only команда, не запускающая watcher, geometry и loot simulation:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\static_check.ps1 -ModRoot . -Profile fast -PythonDeps '..\..\work\pydeps'
```

Таргетированные профили:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\static_check.ps1 -Profile watcher
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\static_check.ps1 -Profile geometry
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\static_check.ps1 -Profile loot
```

Полная интеграционная проверка:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\static_check.ps1 -Profile full -BuildModsRoot 'E:\GRA2.5\MO2\mods'
```

Default профиля остаётся `full` для обратной совместимости. Параметр `-PythonDeps` включает полноценный синтаксический разбор Lua, если локально доступен пакет `luaparser`. `600000` loot-симуляций запускаются только после изменения loot RNG/cascade/config, на интеграционной контрольной точке или перед релизом.
