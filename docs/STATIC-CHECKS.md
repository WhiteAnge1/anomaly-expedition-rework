# Результат статических проверок

Последнее обновление: 2026-10-11.

- Все три `.script` разобраны `luaparser 4.2.0`: синтаксических ошибок нет.
- `fomod/info.xml` и русская string table разобраны XML-парсером; для string table отдельно проверены Windows-1251, декларация кодировки и контрольная русская строка.
- Фрагмент DXML `map_spots_rvm_sorties.xml` проверен внутри временного корня `<map_spots>`.
- Проверено наличие ключевых hooks, callbacks сохранения/загрузки/очистки и конфигурационных инвариантов.
- Проверено отсутствие обёртки `drx_da_main.spawn_artefact_on_smart` и постфактум-перебора всех артефактов уровня.
- Проверено динамическое чтение штатной таблицы артефактов, точное соответствие групп пулов `{1..5}`, `{5,6}`, `{6,7}` и вызов сохраняемой очереди `raid_artefacts.addToQueuedArtefacts`.
- Проверено использование PAW `script_zone`, видимых `raid_small_stash_*`, отсутствие несовместимых `printf`-форматов и запрещённых после полевого теста loot-секций.
- Проверены global-debug auto/default-off, три независимых пользовательских exact-marker default-off, разделение обычных и технических tooltip, безопасный вывод runtime-команд в Debug UI, census и отсутствие обёртки штатного `raid_dospawn_dungeons.raid_start_spawn`.
- Проверены exact-ID fallback владения артефактом, fail-closed сохранение области при ошибке API, калиброванные размеры кругов `64/80/96` при `scale_max=2.25` и запрет видимого fallback для засад.
- `test_loot_policy.ps1` проверяет точную формулу квоты `65/31.5/3.4475/0.0525`, 200000 детерминированных выборок и инварианты `actual <= quota`, `ordinary <= target`; static check запрещает возврат старого 45/55 fill.
- Проверены debug-marker IDs `paw_stash_green` и `alife_presentation_squad_enemy_1` в фактических XML сборки, exact artifact scope и enemy scope только через `zone.spawned_ids`; quest-pointer `crlc_squad_red` запрещён.
- Регрессия same-level cleanup закрыта статическим запретом прямого `cleanup()` из `on_before_level_changing`; очистка разрешена только после определения фактического уровня на `actor_on_first_update`.
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
