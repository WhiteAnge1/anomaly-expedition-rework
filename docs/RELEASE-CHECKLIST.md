# Release checklist

## Обязательные блокеры публичного релиза

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
- [ ] В финальных обычных рейдах оценить новые loot-пределы T2 `radius/5` и T3 `radius/10`.
- [x] Forced-empty рейды T1/T2/T3 пройдены до artifact rescue: T1 `4/4+1`, T2 `8/8+2`, T3 `6/6+2`.
- [x] В forced-empty T1/T2/T3 подтверждены captured/created counts и допустимое перекрытие истинных областей; отдельный T2 `7/8+2` документирован как доказанный world-origin `invalid_vertex:60`, а не потеря callback.

## Уже подтверждено полем

- Squad cohesion: 3 squad T2 и 2 squad T3.
- Forced-loot counts: T1 `1×5`, T2 `4/2/2`, T3 `3/2/3`.
- Save/load контейнера до/после открытия и закрытие loot-зоны.
- Live watcher при обязательном порядке «watcher → X-Ray», автоматическое завершение `game_closed_after_grace` с 20-секундным хвостом и публикация уникального session-файла/`latest.log` подтверждены полем 18 октября.

Остались обычные debug-off визуальные loot-проверки T2/T3, решение о публичном default `artifact_rescue_actions`, release-candidate install/upgrade smoke и упаковка. Полный порядок: `docs/ROADMAP-TO-RELEASE.md`.
