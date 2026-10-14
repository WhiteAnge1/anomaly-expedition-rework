# Результат статических проверок

Последнее обновление: 2026-10-12.

- Все три `.script` разобраны `luaparser 4.2.0`: синтаксических ошибок нет.
- `fomod/info.xml` и русская string table разобраны XML-парсером; для string table отдельно проверены Windows-1251, декларация кодировки и контрольная русская строка.
- Фрагмент DXML `map_spots_rvm_sorties.xml` проверен внутри временного корня `<map_spots>`.
- Проверено наличие ключевых hooks, callbacks сохранения/загрузки/очистки и конфигурационных инвариантов.
- Проверено отсутствие обёртки `drx_da_main.spawn_artefact_on_smart` и постфактум-перебора всех артефактов уровня.
- Проверено динамическое чтение штатной таблицы артефактов, точное соответствие групп пулов `{1..5}`, `{5,6}`, `{6,7}` и вызов сохраняемой очереди `raid_artefacts.addToQueuedArtefacts`.
- Проверено использование PAW `script_zone`, видимых `raid_small_stash_*`, отсутствие несовместимых `printf`-форматов и запрещённых после полевого теста loot-секций.
- Проверены global-debug auto/default-off, три независимых пользовательских exact-marker default-off, разделение обычных и технических tooltip, безопасный вывод runtime-команд в Debug UI, census и отсутствие обёртки штатного `raid_dospawn_dungeons.raid_start_spawn`.
- Проверены exact-ID fallback владения артефактом, fail-closed сохранение области, размеры кругов `32/60/48` при `scale_max=4.5`, icon-only exact markers с `location_level=20` и per-level `start/start/proximity`.
- `test_loot_policy.ps1` отдельно моделирует 200000 контейнеров каждого тира: medicine 0/1/2, valuable 0/1/2/3, число ordinary, rare, частоту и количество осколков, T3 `af_aam` и `adrenalin`, повторы и максимумы `cap+rare`; static check запрещает возврат старого 45/55 fill и tools в valuable/rare.
- `watch_live_log.ps1 -SelfTest` реально дописывает полную и частичную строки, проверяет truncate с быстрым повторным ростом файла через byte-checkpoint, delete/recreate, сохранение только отфильтрованных строк и `latest.log`. Детерминированная lifecycle-модель доказывает отсутствие выхода до первого обнаружения игры, фиксацию старта и завершение лишь после инъецированного короткого grace; runtime default остаётся 20 секунд. Runtime-reader читает новые байты напрямую через `FileStream`, не полагаясь на буферизацию `StreamReader`.
- `test_geometry_policy.ps1` проверяет неизменные размеры кругов `32/60/48`, loot T1/T2/T3 `radius/3`, `radius/5`, `radius/10`, artifact-профили `0.35..0.80`, `0.10..0.20`, `0.06..0.12`, фактический post-snap limit, разрешённое перекрытие только истинных artifact-зон при сохранённом separation ложных зон, подробные rate-limited artifact-center причины, порядок пяти proximity-фаз и расширенный low-discrepancy hidden search.
- Проверены исходные PAW/GRA-текстуры в фактических XML сборки, собственные exact wrappers с `location_level=20`, размеры `14/14/15`, icon-only пользовательский exact-hint, сохранённый обычный hint круга и перенос единственной enemy-метки через `squad:commander_id()`; quest-pointer `crlc_squad_red` запрещён.
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

Команда повторной проверки:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\static_check.ps1 -BuildModsRoot 'E:\GRA2.5\MO2\mods'
```

Параметр `-PythonDeps` включает полноценный синтаксический разбор Lua, если локально доступен пакет `luaparser`.
