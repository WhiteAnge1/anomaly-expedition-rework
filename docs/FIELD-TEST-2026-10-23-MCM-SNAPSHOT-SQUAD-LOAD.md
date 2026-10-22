# RC3: MCM snapshot принят, перемещение squad после load не доказано

Дата анализа: 23 октября 2026. Проверены десять пользовательских скриншотов и свежий
`xray_maksi.log` из обычного каталога GRA. Runtime и опубликованный RC3 не изменялись.

## Принято: MCM и snapshot

- До первой T2-вылазки debug был выключен, пользовательские exact-маркеры artifact/enemy/valuable работали без технических ID и координат.
- Первая вылазка создала снимок настроек: `settings snapshot created ... level=k01_darkscape`, затем `false=3`, `type_weights=50/25/25` и итоговые 7 artifact + 1 enemy + 2 valuable области.
- Изменение MCM уже внутри вылазки и последующий save/load не перестроили её: `restored_zones=10`, новых `zone created`/`enemy squad ready` после load нет. Прежние exact-маркеры и состав областей сохранились.
- После обычного выхода первая вылазка завершилась `cleanup ... artifact=7 enemy=1 loot=2 empty=0`.
- Вторая новая T2-вылазка получила новый снимок: `false=4`, `type_weights=50/0/0`, итог 7 artifact + 4 enemy, без valuable и empty. Это точно соответствует изменённым MCM-настройкам.
- Save/load второй вылазки дал `restored_zones=11` без повторного создания.

Итог: lifecycle снимка настроек **принят** — текущая вылазка неизменна, следующая применяет новые значения ровно один раз.

Терминология пользовательских типов ложных областей: **valuable / enemy / empty**. Внутренний исторический идентификатор valuable-типа в коде и журнале — `loot`; отдельного `safe`-типа нет.

## Что доказано по squad

Первый рейд:

- до load создан ровно один трёхчленный preset `aer_darkscape_frequent_boar_normal_3`;
- после load движок вывел online те же сохранённые member ID `35107`, `35108`, `35109`;
- после load нет нового `enemy squad ready`, нового decoy result или второго создания зоны;
- после смерти членов исходная enemy-область закрылась штатно: `ambush_squad_resolved_all_dead_or_missing`.

Второй рейд даёт более сильное same-ID доказательство:

- до load существовали squad `39940`, `39943`, `39946`, `39950` с member ID `39941..39953`;
- после load LSS снова вывел online ровно эти ID, census перечислил те же четыре squad и тот же состав;
- `restored_zones=11`, повторного `enemy squad ready` нет.

Следовательно, **recreate, duplicate spawn и подмена squad ID исключены**.

## Аудит кода позиционирования

- Единственное место создания enemy squad — `trigger_ambush -> ambush_spawn_squad`, где `alife_create` и `squad:create_npc` вызываются только до установки `zone.triggered=true`.
- `zone.triggered`, `squad_id` и member ID сохраняются вместе с zone. `load_state` не сбрасывает `triggered` и не вызывает spawn.
- `load_state` для enemy только восстанавливает таблицы ID и очищает process-local retry/anomaly cache.
- `refresh_zone_squad_members` только перечисляет существующих членов и обновляет bookkeeping; координаты и vertex не записывает.
- Rebind exact-маркера только выбирает живого командира и добавляет/удаляет map spot; позицию объекта не меняет.
- В основном скрипте есть два `alife():teleport_object`, но оба находятся в artifact-rescue и получают только `record.artifact_id`. Squad/member ID туда попасть не может.
- Для enemy squad нет `teleport_object`, `force_set_position`, присваивания server position, `m_level_vertex_id` или `m_game_vertex_id` на load/rebind.

Поэтому в текущем коде мода не найден путь, способный вернуть squad к anchor, командиру или actor после загрузки.

## Чего журнал не доказывает

Compact release logging первой вылазки не записал `squad_id`, member world positions и vertices при создании/save/load. Census второй вылазки записал ID и alive-source, но не координаты. Скриншоты показывают заметный сдвиг enemy-marker примерно за 14 секунд, однако карта не связывает точку с ID и не даёт точных world coordinates.

На этих данных нельзя строго отличить:

1. восстановление движком сохранённой позиции;
2. штатный offline simulation / online switch группы;
3. обычное AI/агро-движение сразу после first update;
4. реальное engine-side reposition при загрузке.

Поэтому runtime-исправление сейчас было бы догадкой и может сломать сохранённые позиции настоящим телепортом.

## Узкий дополнительный тест

Если эффект повторится, нужен один T2 start-spawn и контрольный отрезок без load:

1. Не двигать actor после появления enemy-marker.
2. Сделать save и сразу скрин карты; загрузить этот save и открыть карту на первом доступном кадре, затем через 5, 15 и 30 секунд.
3. Для контроля повторить те же 30 секунд от того же исходного save без промежуточного reload.
4. Сохранить полный `xray_maksi.log`, точное имя save и скриншоты с игровым таймером.

Перед таким повтором следует добавить только диагностику, без позиционных действий. Для каждого owned squad/member нужны compact production строки в трёх точках — `save`, `load_state captured`, `actor_on_first_update restored`:

- sortie/session nonce, anchor ID, squad ID/section, commander ID;
- member ID/section и online/offline;
- server position, level vertex, game vertex;
- online position, если объект online;
- actor position и расстояния member→actor, member→anchor/zone center;
- сохранённые position/vertices и delta после first update;
- признак `same_id`, `created_this_session=false`, `position_write=false`;
- smart terrain/target, если API безопасно доступен.

Только пара сохранённых и восстановленных координат позволит решить, нужен ли engine-load workaround. До этого accepted start/proximity spawn, save/load и squad lifecycle не меняются.
