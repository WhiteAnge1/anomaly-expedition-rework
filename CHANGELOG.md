# История изменений

## 0.3.0-rc9 — 2026-10-29

- Добавлен AER-contained compatibility guard для PAW `get_screen_coords`: переходное состояние, в котором client object ещё существует после исчезновения ALife server object, больше не приводит к `se_obj:clsid()` fatal.
- Guard возвращает `nil` только для опасного кадра и не удаляет route, persistent pin или map spot; стабильные состояния остаются в ведении исходного PAW.
- Добавлена исполняемая регрессия Lua 5.1/LuaJIT для client-only перехода, race между precheck и вызовом PAW, обычной делегации, штатной PAW cleanup-семантики и проброса посторонних ошибок.
- Полевой gate исходной exact-toggle последовательности, pickup без PAW и двух дополнительных pickup с сохранёнными route/pin пройден; `se_obj nil` fatal не повторился, области закрылись штатно, PAW-состояние сохранилось.
- Один отдельный нативный `AnomalyDX11.exe` access violation не повторился после полного перезапуска и не классифицирован как Lua-регрессия AER.

## 0.3.0-rc8 — 2026-10-25

- Имя, предлагаемое FOMOD для папки MO2, сокращено до `[Геймплей] A_Exp_R by White_Angel v0.3`.
- Сокращение уменьшает глубину итоговых путей MO2 и риск ошибок Windows при распаковке или обращении к глубоко вложенным файлам.
- Публичное название проекта **Anomaly Expedition Rework** сохранено; игровая логика и настройки идентичны RC7.

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
