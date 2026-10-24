# RC staging 0.3.0-rc7

`rc7` — публичный pre-release с исправлением исчезновения открытой приблизительной зоны AER после автоматического закрытия или отмены маршрутной метки PAW.

## Причина

RC6 создавал anchor через `tasks_placeable_waypoints.generate_scripted_mapspot_at` и делал его PAW-persistent. Такой объект оставался во внутреннем `script_zones` PAW. `cancel_task()` безусловно вызывает `set_pingspot_persistence(id,false)`, после чего PAW cleanup выполняет `deregister_script_zone()` и `alife_release` того же объекта. Map spot AER исчезал вместе с уничтоженным anchor, хотя содержимое зоны ещё не было завершено.

## Изменение

- новые AER anchors создаются напрямую как raw `script_zone` и не входят в PAW registry;
- waypoint PAW по-прежнему может указывать на объект, но его cancel/auto-clear не получает права владения им;
- открытый legacy RC6 `paw_anchor` мигрирует на собственный raw anchor при первом update;
- любой пропавший anchor открытой зоны восстанавливается на сохранённом центре;
- меняются только anchor ID, ключ `state.zones`, artifact lineage mapping и связанный provenance anchor;
- artifact, loot container/visual, enemy squad, exact markers, counters и rolled content не создаются повторно;
- закрытые зоны пропускаются; ошибка создания оставляет открытую зону и содержимое для следующей безопасной попытки;
- release старого RC6 anchor сохраняет совместимость с `paw_anchor=true` и использует PAW deregistration только для уже существующего legacy ownership.

## Gate

1. Полный перезапуск игры, RC6-запись MO2 отключена, RC7 установлена отдельной записью.
2. На новой открытой зоне поставить PAW waypoint и проверить auto-clear, ручную отмену и смену waypoint: круг AER не исчезает.
3. Убедиться, что содержимое и exact marker созданы ровно по одному разу.
4. Загрузить сохранение с открытой RC6-зоной; ожидается одна строка `zone anchor recovered ... legacy_paw=true content_preserved=true`, после чего waypoint больше не влияет на круг.
5. Сделать save/load уже RC7-состояния: повторной миграции и дублей нет.
6. Завершить содержимое зоны: круг/точная метка закрываются и после следующего update/save/load не восстанавливаются.

Полевой gate принят 24 октября 2026 года: пользователь подтвердил пеший PAW auto-clear, PAW/debug-переход к waypoint, ручную отмену/перенос и штатное закрытие зоны. Кандидат разрешён к публикации как `v0.3.0-rc7`.

## Исходное полевое доказательство

Натуральная T1/T2/T3 серия в остальном принята. В watcher T2 завершил `cleanup zones=10 closed=7 artifact=7 enemy=2 loot=1 empty=0`, T3 — `zones=6 closed=6 artifact=5 enemy=1 loot=0 empty=0`; незавершённые T2 зоны сами по себе не классифицируются как дефект. Пользователь дважды воспроизвёл исчезновение круга после PAW cleanup именно на T2.

- локальный watcher: `test-artifacts/live-logs/aer-live-20261024-194003-921-9972.log`, `53850` bytes, SHA-256 `BE2B6928DB81B7A9AB2146BB068B12E8E336FBEEE9E33B109539D51BD30267A6`;
- screenshots SHA-256: `2503432F552EEF79EC3F5F1D0B46813133B99FFA311B5354693917850B9E3F2C`, `BFD11BDBFEFD8C5E18CE88EA950C6BE91D09D95694E0EF4680198408EE37C6E7`, `AF5B3728130ABEADD4CC5BAE250141D010B7CFCE3DA453DF903B17D7D1AD414E`.

Сырые материалы локальные и в релизный архив не входят.
