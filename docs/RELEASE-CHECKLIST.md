# Release checklist

## Обязательные блокеры публичного релиза

- [ ] Подготовить отдельное подробное руководство для пользователя и тестировщика по всем возможностям debug-режима. До закрытия этого пункта финальные README и релиз не считаются готовыми.

  Руководство должно объяснять:

  - `debug_mode = auto/on/off` и связь режима `auto` с `DEV_DEBUG`/`DEV_DEBUG_DEV`;
  - runtime-команды `rvm_rework_debug_auto`, `rvm_rework_debug_on`, `rvm_rework_debug_off` и `rvm_rework_census`;
  - тестовые настройки `debug_force_decoy_type`, `debug_force_tier` и `debug_cleanup_current_sortie`;
  - технические tooltip областей и точный loot-marker;
  - census, признак `owned_by_rework` и ожидаемые строки журнала, включая безопасное отключение census при диагностической ошибке;
  - просмотр live-лога во время тестирования;
  - обязательное возвращение forced-настроек в `off`, `0` и `false` после теста.

  Пункт закрывается только после добавления и проверки самого руководства. Этот checklist не является руководством.
