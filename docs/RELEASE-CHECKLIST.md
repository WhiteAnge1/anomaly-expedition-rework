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

- [ ] Проверить пользовательские exact-маркеры в игре: три независимых переключателя, отсутствие технического текста при debug-off, восстановление без дублей после save/load и удаление при pickup/open/death/cleanup.

  Loot lifecycle полево принят: отдельный переключатель сохраняет красную метку после debug-off, reload восстанавливает пять зон без новых create/дублей, open удаляет loot marker/zone. Буквальный `no hint` выявлен и исправлен локализованной нетехнической строкой; hotfix, artifact и enemy user-mode ещё требуют одного комбинированного визуального подтверждения.

- [x] Подтверждены T2/T3 artifact-профили `0.10..0.20`/`0.06..0.12`, обычный tooltip круга, save/load и artifact/loot exact-иконки `14 px`.
- [ ] В финальных обычных рейдах оценить новые loot-пределы T2 `radius/5` и T3 `radius/10`.
- [ ] После forced-enemy тестов пройти по одному forced-empty рейду T1/T2/T3 до artifact rescue.
- [ ] В forced-empty T1/T2/T3 подтвердить совпадение captured/created artifact count и допустимое перекрытие истинных областей; при отказе приложить position/near-origin/reject counters.

## Уже подтверждено полем

- Squad cohesion: 3 squad T2 и 2 squad T3.
- Forced-loot counts: T1 `1×5`, T2 `4/2/2`, T3 `3/2/3`.
- Save/load контейнера до/после открытия и закрытие loot-зоны.
- Live watcher при обязательном порядке «watcher → X-Ray», автоматическое завершение `game_closed_after_grace` с 20-секундным хвостом и публикация уникального session-файла/`latest.log` подтверждены полем 18 октября.

Финальные normal-player рейды с debug off и пользовательскими `show_exact_*` остаются отложены до отдельной реализации artifact rescue и балансировки `4/8/6`.
