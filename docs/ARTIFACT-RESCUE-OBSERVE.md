# Artifact rescue: provenance и observe-only, стадия 1

Статус: тестируемая альфа наблюдателя. Активного спасения в этой стадии нет: предметы не перемещаются, не пересоздаются, не фиксируются физикой и не освобождаются. Штатные количества RVM `4/8/6` не изменены.

## Что сохраняется

На каждый ID, возвращённый штатным `raid_anomalys.spawn_artefact_in_zone`, создаётся идемпотентная provenance-запись schema 1 внутри общего save schema 4:

- section, `anom_zone`, размер шаблона `10/16/22`, level и tier;
- переданный центр конкретного поля и первый server `pos/lvid/gvid`;
- ID/центр/радиус связанного круга после его создания;
- last-good server/online позиции, parent, источник ownership и lineage IDs;
- отдельные samples/duration/max excess/trend для origin, underground и rolling;
- state/reason/target, timestamps, нулевые rescue counters/cooldown и пустой список actions;
- `disabled/error_once` для fail-closed поведения.

Повторный wrapper callback увеличивает только счётчик и не создаёт вторую запись. При загрузке raw sample clocks сбрасываются, а накопленная длительность сохраняется. Старое сохранение без центра исходного поля мигрирует в терминальное `disabled`: такой объект продолжает жить по штатным правилам, но классификатор не угадывает provenance.

NPC-подбор в этой сборке может уничтожить мировой объект и создать в инвентаре NPC новый ID той же секции. Callback теперь всегда обрабатывается независимо от `remove_on_npc_pickup`: точный ID либо единственный пропавший кандидат той же секции переводит provenance в `owned`, добавляет replacement ID в сохраняемый lineage и lookup области. Если подходящих пропавших областей несколько, сопоставление намеренно не выполняется и пишется `fail_closed=true`. При `remove_on_npc_pickup=false` круг остаётся, а последующая передача replacement игроку закрывает исходную область по lineage ID.

## State machine этой стадии

Рабочая цепочка: `captured -> observing_server -> observing_online -> suspect -> rescue_pending`.

Терминалы: `owned`, `closed`, `released`, `disabled`. Будущие `verifying/stable` относятся к активной стадии и сейчас недостижимы. `rescue_pending` — только запись подтверждённой диагностики; в логе она помечается `observe_only=true; action=none`.

## Классификаторы

Origin подтверждается только сочетанием всех guardrails: расстояние до мирового нуля не больше 2 м, позиция дальше `sqrt(2) * zone_size + 2 м` от переданного центра именно этого поля, invalid/несогласованный vertex, отсутствие parent и наличие static-ray цели возле поля. Законное поле возле `(0,0,0)` не срабатывает.

Underground требует падения минимум на 12 м от last-good Y, vertex минимум на 4 м выше предмета либо invalid vertex, три последовательных sample минимум за 2 секунды, отсутствие ownership и static-ray цель.

Rolling начинается, когда свободный предмет дальше центра связанного круга, чем `radius + 5 м`. Записываются max excess, duration и trend. Возврат внутрь до 15 секунд сбрасывает эпизод; нахождение снаружи не менее 15 секунд создаёт диагностический кандидат.

Если strict origin уже дал `rescue_pending`, он намеренно имеет приоритет: последующее физическое укатывание этого же ID не заменяет первичную причину на rolling. Rolling следует проверять на артефакте с нормальным первым server position.

## Полевой результат 15 октября 2026 года

- Тёмная лощина подтвердила underground debounce без ложного мгновенного срабатывания: `af_electra_moonlight#6904` перешёл с `y=-0.3` на `-40.8` и подтвердился за `3 samples / 2008 ms`; `af_fuzz_kolobok#7018` — с `y=0.1` на `-40.8`, `3 / 2021 ms`. `af_elektron#6968` до завершения уровня успел дать только `first_suspect`.
- Strict origin mismatch подтвердился на Поляне (два ID), во второй Лощине (`af_ring#6990`) и во втором Мёртвом городе (`af_electra_moonlight#11073`, `af_cristall#11662`). У них первый LVID был `4294967295`, а field center находился далеко от origin.
- Первый рейд Мёртвого города вывел все шесть артефактов online без underground-кандидатов.
- Save/load восстановил provenance и незавершённые состояния с `actions=none`.
- Попытка rolling на `af_ball#6910` не является rolling-тестом: предмет уже был `rescue_pending reason=origin_mismatch`, поэтому первичная причина закономерно сохранилась.
- Два NPC-подбора показали реальную смену ID: `af_dummy_battery#7012 -> #38145` и `af_electra_sparkler#8318 -> #38144`. Предыдущая версия видела только исчезновение старых IDs и ошибочно восстанавливала их как `observing_online`; это стало основанием для lineage-исправления выше.

Поляна завершила phase 1 отдельным rolling-тестом. `af_night_star#1407` и `af_fonar#6362` независимо подтвердили выход за `radius+5` через `15160/15157 ms`. Они затем продолжили катиться по реальному склону за игровую часть карты: последующий низкий Y/invalid nav являлся продолжением rolling, а не новым underground. Provenance schema 2 хранит `primary_reason`; подтверждённый rolling больше не передаётся underground-классификатору, пока объект не вернётся внутрь tether. Чистый underground на Поляне отдельно подтвердил `af_signet#6740`, вертикально упавший внутри своего круга.

## Лабораторный same-ID prototype

Prototype по умолчанию полностью выключен. Он поддерживает только один exact original ID с `primary_reason=rolling`, одну попытку same-ID `alife():teleport_object`, без recreate/offline-cycle/physics. Schema-1 сейв принятого теста мигрирует в schema 2 и восстанавливает первичную rolling-причину даже после старой ложной переклассификации.

После `load_restore` запись получает `fresh_snapshot_required=true`. Первый реальный update сначала запускает классификатор: если X-Ray уже восстановил предмет внутрь tether, rolling сбрасывается и действие запрещается. Даже если предмет остался снаружи, этот snapshot только пишет `post_load_snapshot ... action_deferred=true`; dispatch возможен не раньше следующего update. Успех требует сохранения server ID/section/game vertex и трёх последовательных snapshots не далее 4 м по XZ/Y от проверенной static-ray target.

Тестировать только на отдельном сохранённом сейве, не создавая поверх него новых сохранений. Сначала выбрать один ID, например `1407`:

```ini
artifact_rescue_observe_only = true
artifact_rescue_actions = true
artifact_rescue_debug_same_id_teleport = true
artifact_rescue_debug_artifact_id = 1407
artifact_rescue_debug_reason = rolling
debug_mode = on
```

Запустить watcher до загрузки сейва. Нормальный успешный путь: `load_restore ... primary_reason=rolling,fresh_snapshot_required=true` → `post_load_snapshot ... action_deferred=true` → на следующем update `action_dispatched ... same_id=true,physics=none` → после трёх проверок `action_stable`. Если X-Ray сам восстановил предмет внутрь tether, ожидается `recovery_reset`/observing state и отсутствие `action_dispatched`; это тоже успешный результат guard. После завершения полностью закрыть игру, вернуть `artifact_rescue_actions=false`, `artifact_rescue_debug_same_id_teleport=false`, `artifact_rescue_debug_artifact_id=0` и только затем продолжать обычную игру. Второй ID проверять отдельным запуском того же неизменённого сейва.

## Debug-журнал

Для полевого теста выставить:

```ini
artifact_rescue_observe_only = true
artifact_rescue_actions = false
debug_mode = on
```

События имеют общий префикс `artifact rescue observe event=`:

- `captured`, `observing_server`;
- `first_suspect`, затем `confirmed`;
- `recovery_reset` при исчезновении плохого состояния;
- `owned`, `closed`, `released`;
- `save` и `load_restore`.

Строки включают ID/section/level/template, current и first position, vertex, parent/owner, distance/radius/excess, samples/duration/source и вычисленную target. Рутинные строки видны только в debug. Ошибка engine-facing observer/action выключает только запись этого ID, запрещает дальнейшие действия и один раз пишет `ERROR artifact rescue record disabled ... further actions blocked`.

## Короткий полевой тест

1. Сохранить исходные значения forced/debug. В тестовой MO2-копии включить только `artifact_rescue_observe_only=true` и `debug_mode=on`; `artifact_rescue_actions=false` не менять.
2. Полностью закрыть X-Ray. Запустить `tools\watch_live_log.cmd`, затем игру и новую аномальную вылазку.
3. На T1/T2/T3 проверить `captured` для каждого штатного ID и отсутствие любой строки о teleport/physics/action.
4. На нормальном артефакте возле origin убедиться, что одного `near_origin` недостаточно. Для доказанного несовпадения ожидать `first_suspect` и `confirmed reason=origin_mismatch`.
5. Для провалившегося online-объекта ожидать не меньше трёх samples и `duration_ms>=2000` до `confirmed reason=underground`.
6. Для выкатившегося предмета ожидать `first_suspect reason=rolling` после `radius+5`. Возврат внутрь раньше 15 секунд должен дать `recovery_reset`; устойчивый выход — `confirmed` не раньше 15 секунд.
7. Сделать save/load во время обычного наблюдения и незавершённого rolling-эпизода. Ожидать один `load_restore`, отсутствие дубля record и продолжение накопленной длительности без мгновенного ложного подтверждения.
8. Дать NPC подобрать предмет. Ожидать `artifact lineage ownership ... source=npc_pickup_exact_id` либо `npc_pickup_recreated_id`, terminal `owned` и новый ID в save/load. При `remove_on_npc_pickup=false` круг остаётся. Получить replacement у NPC: исходная область должна закрыться по сохранённому lookup/lineage, а новые suspect-события запрещены.
9. Выйти с локации обычным переходом: ожидать `released` для оставшихся записей и штатный cleanup.
10. Сохранить `latest.log` и полный `xray_*.log`. После теста вернуть debug/forced-настройки к прежним значениям; отдельно сообщить их до и после теста.

Границы карт, клики по PDA, offline-cycle и любые physics actions относятся к следующим отдельным этапам. Единственное исключение — явно разрешённый exact-ID same-ID prototype по отдельному сценарию; обычный observe-only тест всегда держит все action gates выключенными.
