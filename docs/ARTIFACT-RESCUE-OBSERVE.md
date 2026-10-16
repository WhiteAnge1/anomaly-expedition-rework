# Artifact rescue: provenance, observe-only и rolling held policy

Статус: production-кандидат для причины `rolling` подтверждён полевым тестом; безопасный master gate по умолчанию выключен. `origin/underground` остаются observe-only. Предметы никогда не пересоздаются, штатные количества RVM `4/8/6` не изменены.

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

Рабочая цепочка: `captured -> observing_server -> observing_online -> suspect -> rescue_pending -> verifying -> monitoring`.

Терминалы: `owned`, `closed`, `released`, `disabled`. При выключенном master gate `rescue_pending` остаётся диагностикой с `action=none`. При `held_first` подтверждённый rolling получает единственный активный rescue; остальные причины действий не получают.

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

## Принятая production policy `held_first`

После штатного непрерывного rolling-confirmation за 15 секунд первый rescue делает same-ID teleport к проверенной static-ray цели. Три fresh snapshots подтверждают тот же ID/section/level и позицию; только затем runtime повторно получает текущий online physics shell, фиксирует ранее unfixed elements и сохраняет release journal. Production held бессрочный: proximity и time release отсутствуют. Освобождение разрешено только при ownership/pickup, выключении master gate, terminal/cleanup, перед save/level transition и при load recovery.

Полевой тест 16 октября 2026 года на `af_fonar#6362` прошёл полностью: dispatch `1/1`, три проверки позиции, post-teleport reacquire, один held element с `pre_fixed=0`; linear velocity изменилась с `0,-0.2,-1` на `0,0,0`, angular — с `-9.8,0,-0.1` на `0,0,0`. Координаты не менялись весь 30-секундный monitor. Обычный pickup дал `held_released reason=actor_pickup_callback release=owned_without_world_shell`, затем `closed reason=actor_pickup`; последующий переход с предметом в инвентаре проблем не показал.

Production policy не использует exact-ID allowlist и debug stabilization gates. Её выбирает `artifact_rescue_rolling_policy=held_first`; общий `artifact_rescue_actions=false` остаётся безопасным default до ограниченного multi-artifact smoke-test.

## Лабораторный same-ID prototype

Prototype по умолчанию полностью выключен. Закрытый allowlist содержит только exact original IDs `1407` и `6362` с причиной rolling; section-only fallback отсутствует. Каждый ID имеет независимый предел в два same-ID `alife():teleport_object`, без recreate/offline-cycle/physics. Schema-1 сейв принятого теста мигрирует в schema 2 и восстанавливает первичную rolling-причину даже после старой ложной переклассификации.

После `load_restore` запись получает `fresh_snapshot_required=true`. Первый реальный update сначала запускает классификатор: если X-Ray уже восстановил предмет внутрь tether, rolling сбрасывается и действие запрещается. Даже если предмет остался снаружи, этот snapshot только пишет `post_load_snapshot ... action_deferred=true`; dispatch возможен не раньше следующего update. Сохранение server ID/section/game vertex и три snapshots не далее 4 м по XZ/Y дают только `position_verified`. Затем предмет наблюдается минимум 30 секунд с журналом displacement, расстояния до target/anchor и запаса tether. Новый непрерывный выход за `radius+5` должен длиться 15 секунд; возврат внутрь сбрасывает эпизод. После подтверждения действует cooldown 20 секунд, затем разрешён второй и последний dispatch этого ID.

Тестировать только на отдельном сохранённом сейве, не создавая поверх него новых сохранений. Оба ID разрешены одновременно и отслеживаются независимо:

```ini
artifact_rescue_observe_only = true
artifact_rescue_actions = true
artifact_rescue_rolling_policy = debug_teleport
artifact_rescue_debug_same_id_teleport = true
artifact_rescue_debug_artifact_ids = 1407,6362
artifact_rescue_debug_reason = rolling
artifact_rescue_debug_monitor_ms = 30000
artifact_rescue_debug_monitor_log_ms = 5000
artifact_rescue_debug_cooldown_ms = 20000
artifact_rescue_debug_max_dispatches = 2
artifact_rescue_debug_same_frame_stabilization = false
debug_mode = on
```

Запустить watcher до загрузки сейва. Нормальный путь каждого ID: `load_restore ... fresh_snapshot_required=true` → `post_load_snapshot ... action_deferred=true` → `action_dispatched ... dispatch=1` → `position_verified` → не менее 30 секунд `action_monitor`. Если предмет снова непрерывно находится за tether 15 секунд, ожидаются `rolling_reconfirmed`, cooldown 20 секунд и `action_dispatched ... dispatch=2`; третьей отправки быть не должно, вместо неё один `action_limit_reached`. Возврат внутрь до 15 секунд обязан дать `recovery_reset` и начать следующий эпизод с нуля. После завершения полностью закрыть игру, вернуть `artifact_rescue_actions=false` и `artifact_rescue_debug_same_id_teleport=false`; allowlist можно оставить, поскольку два action-gate выключены.

## Отдельный third-stage stabilization test

Этот сценарий не является продолжением обычного теста и не включается заранее. Использовать только именной save после принятого repeat-rescue прогона, где `af_fonar#6362` уже имеет два verified обычных dispatch и третий confirmed rolling. Перед загрузкой полностью закрыть игру и временно выставить:

```ini
artifact_rescue_observe_only = true
artifact_rescue_actions = true
artifact_rescue_rolling_policy = debug_teleport
artifact_rescue_debug_same_id_teleport = true
artifact_rescue_debug_artifact_ids = 6362
artifact_rescue_debug_reason = rolling
artifact_rescue_debug_monitor_ms = 30000
artifact_rescue_debug_monitor_log_ms = 5000
artifact_rescue_debug_cooldown_ms = 20000
artifact_rescue_debug_max_dispatches = 2
artifact_rescue_debug_same_frame_stabilization = true
debug_mode = on
debug_force_decoy_type = empty
```

Первый post-load snapshot обязан только снять fresh-snapshot gate. После cooldown ожидается `action_dispatched ... dispatch=3,physics=same_frame_fix_release`, перед ним `action_stabilization_attempt`, затем inventory всех элементов и `action_stabilization_released`; отсутствие shell/API допустимо только как `stabilization_unavailable/failed`, сам same-ID teleport всё равно должен пройти. Далее обязательны обычные `position_verified` и минимум 30 секунд `action_monitor`. Сверить pre/post linear/angular velocity, ID `6362`, section `af_fonar`, отсутствие permanent fixed-состояния и нового dispatch после hard limit=3. Финальная обязательная проверка — игрок подбирает именно этот Фонарь: должен появиться `owned`/закрытие области, предмет остаётся в инвентаре и нормально участвует в Rojok-классе/мутации. После теста полностью закрыть игру и вернуть actions/same-ID/stabilization gates в `false`, `debug_mode=auto`.

## Отдельный held pickup experiment

Same-frame тест доказал корректное мгновенное обнуление обеих скоростей, но не остановил повторное ускорение на постоянном склоне. Held-вариант проверяет только один вопрос: разрешает ли X-Ray подобрать артефакт, пока его единственный physics element остаётся fixed. Загружать нужно то же именное сохранение **до** третьего same-frame dispatch, где у `6362` записаны ровно два verified обычных действия. Во время опыта запрещены ручные save/load и выход с уровня; pre-save/load/transition release существуют только как аварийная защита.

```ini
artifact_rescue_observe_only = true
artifact_rescue_actions = true
artifact_rescue_rolling_policy = debug_teleport
artifact_rescue_debug_same_id_teleport = true
artifact_rescue_debug_artifact_ids = 6362
artifact_rescue_debug_reason = rolling
artifact_rescue_debug_monitor_ms = 30000
artifact_rescue_debug_monitor_log_ms = 5000
artifact_rescue_debug_cooldown_ms = 20000
artifact_rescue_debug_max_dispatches = 2
artifact_rescue_debug_same_frame_stabilization = false
artifact_rescue_debug_held_after_verified_actions = 0
artifact_rescue_debug_held_stabilization = true
artifact_rescue_debug_held_timeout_ms = 0
debug_mode = on
debug_force_decoy_type = empty
```

Этот исторический test-only профиль подтвердил путь, который теперь принят как production `held_first`: `action_dispatched ... dispatch=1,physics=held_pending,stabilization_after_verified=0` → `position_verified` → `action_stabilization_held_attempt` → `action_stabilization_held ... held=1,pre_fixed=0`. Debug-порог `2` сохраняется только для воспроизведения прежней схемы; production всегда начинает held на первом rescue. После диагностического теста вернуть `actions/same-ID/held=false`, `debug_mode=auto`.

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
