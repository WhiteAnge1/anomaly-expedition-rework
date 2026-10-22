# Release checklist

> `0.3.0-rc1` сохранён как superseded prerelease. `0.3.0-rc2` допускается как устанавливаемый prerelease после воспроизводимой сборки и полного статического suite; финальным релизом он не является, а полевая new-expedition/save-load проверка остаётся acceptance-блокером.

## Обязательные блокеры публичного релиза

- [x] Владелец утвердил public config/FOMOD: Recommended/Observe-only `debug_mode=off`, Diagnostic `on`, schema 9 и weighted во всех профилях, legacy actions всегда off, exact markers default None, три типа ложных зон независимо отключаемы. Обновление ставится новой MO2-записью без автоматического backup/merge старого LTX.

- [x] Proactive artifact hold принят серией из пяти weighted-рейдов: T2 `7/6/7`, T1 `4`, T3 `5`. Все 29 exact ID дали ровно один `lift verified=true -> held clearance=1 -> release -> closed`; два same-level reload сохранили зоны, duplicate create/net-spawn, online teleport, `__eq`, unresolved и AER errors отсутствуют. Полный аудит: `docs/FIELD-TEST-2026-10-21-SCHEMA9-WEIGHTED-FIVE-RAID-PASS.md`.

- [x] Подготовлено и статически проверяется отдельное руководство `docs/DEBUG-GUIDE.md` для пользователя и тестировщика по всем возможностям debug-режима.

  Руководство должно объяснять:

  - `debug_mode = auto/on/off` и связь режима `auto` с `DEV_DEBUG`/`DEV_DEBUG_DEV`;
  - runtime-команды `rvm_rework_debug_auto`, `rvm_rework_debug_on`, `rvm_rework_debug_off` и `rvm_rework_census`;
  - тестовые настройки `debug_force_decoy_type`, `debug_force_tier` и `debug_cleanup_current_sortie`;
  - технические tooltip областей и точный loot-marker;
  - независимые пользовательские `show_exact_*`: defaults OFF, казуальный режим без ID/координат/census и приоритет полного debug;
  - census, признак `owned_by_rework` и ожидаемые строки журнала, включая безопасное отключение census при диагностической ошибке;
  - просмотр live-лога во время тестирования;
  - обязательное возвращение forced-настроек в `off`, `0` и `false` после теста.

  Пункт закрыт самим руководством; этот checklist его не заменяет.

- [x] Пользовательские exact-маркеры проверены в игре: три независимых категории, локализованный нетехнический tooltip при debug-off, восстановление без дублей после load и удаление при pickup/open/death/cleanup.

  Loot lifecycle принят отдельным прогоном; последующий combined artifact/enemy прогон визуально подтвердил общий `no hint` hotfix, русские casual hints, reload, artifact pickup и commander handoff/final death.

- [x] Подтверждены T2/T3 artifact-профили `0.10..0.20`/`0.06..0.12`, обычный tooltip круга, save/load и artifact/loot exact-иконки `14 px`.
- [x] В обычных weighted-рейдах подтверждены loot-пределы: T2 `32.8 <= 33.6` и `23.3 <= 46.2`; T3 `8 <= 14.2` и `14.2 <= 14.9`, контейнеры открылись и закрылись штатно.
- [x] Forced-empty рейды T1/T2/T3 пройдены до artifact rescue: T1 `4/4+1`, T2 `8/8+2`, T3 `6/6+2`.
- [x] В forced-empty T1/T2/T3 подтверждены captured/created counts и допустимое перекрытие истинных областей; отдельный T2 `7/8+2` документирован как доказанный world-origin `invalid_vertex:60`, а не потеря callback.
- [x] Утверждены и реализованы переменные локационные распределения настоящих артефактов: Поляна `3/4/5 = 35/60/5%`, Лощина `5/6/7/8/9 = 5/20/47/26/2%`, Мёртвый город `4/5/6/7 = 11/80/7/2%`. Lua 5.1/LuaJIT regression проверяет support/веса/средние, один сохранённый roll, stock fallback, восстановление upvalue при success/error, unique IDs и независимость decoys.
- [ ] Полевым normal debug-off прогоном подтвердить новый roll, `requested=created=captured=linked`, отсутствие повторного spawn после save/load/same-level и независимый decoy count.

- [ ] Smoke A — GitHub RC ставится новой версионной MO2-записью, dev-копия отключается: Recommended + все типы зон + exact markers All, `debug_mode=off`; одна новая T2 проверяет effective debug false, нетехнические exact hints, schema-9/weighted startup и обычный выход.
- [ ] Smoke B — тот же RC ставится второй отдельной MO2-записью без merge, первая RC-запись отключается: Recommended + все типы зон + exact markers None, `debug_mode=off`; существующее убежище + новая короткая вылазка + save/load подтверждают отсутствие exact/technical markers, отсутствие reroll/respawn и отсутствие унаследованных файлов.
- [x] RC FOMOD реализован 136 полными LTX-вариантами: 64 Recommended, 64 Observe-only, 8 Diagnostic. Partial overlays/merge отсутствуют; генератор и `test_fomod.ps1` проверяют полные ключи, разрешённые различия и взаимно-однозначные XML patterns.
- [ ] GitHub README собран по `docs/GITHUB-README-OUTLINE.md`; добавлены license/attribution, known limitation #5, update/rollback, SHA verification и support template.
- [x] Зафиксировано продуктовое решение не добавлять координатные границы карты в artifact rescue. Известное редкое ограничение описано: пока физически недоступный артефакт остаётся внутри связанного круга, rescue не срабатывает; обычный rolling-path применим после устойчивого выхода за `radius + 5 м`.

## Уже подтверждено полем

- Squad cohesion: 3 squad T2 и 2 squad T3.
- Forced-loot counts: T1 `1×5`, T2 `4/2/2`, T3 `3/2/3`.
- Save/load контейнера до/после открытия и закрытие loot-зоны.
- Live watcher при обязательном порядке «watcher → X-Ray», автоматическое завершение `game_closed_after_grace` с 20-секундным хвостом и публикация уникального session-файла/`latest.log` подтверждены полем 18 октября.
- Schema-9/weighted correctness smoke: пять рейдов T2/T2/T2/T1/T3, 29/29 артефактов доступны и подобраны; counts, pool, decoys, loot и cleanup прошли без AER errors. Проценты распределений этой короткой выборкой не доказываются.

Остались два presentation-smoke с debug-off (exact markers on, затем all exact markers off), чистая установка RC отдельной MO2-записью, license/attribution, финальная версия/tag/release и публичные/Discord-материалы. Public defaults и RC FOMOD уже зафиксированы. Точный порядок: `docs/RELEASE-READINESS-GAPS-2026-10-21.md`.
