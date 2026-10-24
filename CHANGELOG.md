# История изменений

## 0.3.0-rc7 — 2026-10-24

- Исправлено исчезновение незавершённого круга AER после автоматического закрытия, ручной отмены, переноса или debug-перехода PAW waypoint.
- Новые anchors принадлежат AER и не входят в реестр временных `script_zone` PAW.
- Добавлено fail-closed восстановление потерянного anchor открытой зоны без повторного создания артефакта, тайника или enemy squad.
- Открытые зоны из RC6 мигрируют на новый anchor; закрытые зоны не восстанавливаются.
- Сохранён принятый в RC6 scripted self-target, предотвращающий уход принадлежащих AER мутантских отрядов к generic SIMBOARD smart terrain без `__lock` и без принудительного online.
- Пройдены естественные T1/T2/T3 рейды, RC6 squad-isolation gate и RC7 PAW auto-clear/teleport/manual cancel/waypoint replacement/zone close field gate.

## 0.3.0-rc6

- Owned ambush squad получили сериализуемый scripted self-target вместо generic SIMBOARD target selection.
- Подтверждены сохранение позиции offline, штатный online monster AI, смерть/закрытие зоны, cleanup и save/load.
- Временная подробная squad timeline удалена после полевой проверки.

## 0.3.0-rc5 и ранее

Исторические release notes и staging-документы сохранены в `docs/RELEASE-NOTES-*` и `docs/RC-STAGING-*`.
