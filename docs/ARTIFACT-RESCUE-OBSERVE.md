# Artifact rescue: provenance, observe-only и rolling held policy

Статус: production executor полево подтверждён для `rolling` и `underground`; safe master gate по умолчанию выключен. Для `origin_mismatch` реализованы preventive spawn guard и готовая recovery policy, требующая отдельного минимального полевого теста. Предметы никогда не пересоздаются.

## Что сохраняется

На каждый ID, возвращённый штатным `raid_anomalys.spawn_artefact_in_zone`, создаётся идемпотентная provenance-запись schema 5 внутри общего save schema 4. Schema 1 относится к ранним полевым сохранениям и мигрирует:

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

Поляна завершила phase 1 отдельным rolling-тестом. `af_night_star#1407` и `af_fonar#6362` независимо подтвердили выход за `radius+5` через `15160/15157 ms`. Они затем продолжили катиться по реальному склону за игровую часть карты: последующий низкий Y/invalid nav являлся продолжением rolling, а не новым underground. Provenance schema 3 хранит `primary_reason`, preventive journal и строгую origin-миграцию; подтверждённый rolling больше не передаётся underground-классификатору, пока объект не вернётся внутрь tether. Чистый underground на Поляне отдельно подтвердил `af_signet#6740`, вертикально упавший внутри своего круга.

## Принятая production policy `held_first`

После штатного непрерывного rolling-confirmation за 15 секунд первый rescue делает same-ID teleport к проверенной static-ray цели. Три fresh snapshots подтверждают тот же ID/section/level и позицию; только затем runtime повторно получает текущий online physics shell, фиксирует ранее unfixed elements и сохраняет release journal. Production held бессрочный: proximity и time release отсутствуют. Освобождение разрешено только при ownership/pickup, выключении master gate, terminal/cleanup, перед save/level transition и при load recovery.

Полевой тест 16 октября 2026 года на `af_fonar#6362` прошёл полностью: dispatch `1/1`, три проверки позиции, post-teleport reacquire, один held element с `pre_fixed=0`; linear velocity изменилась с `0,-0.2,-1` на `0,0,0`, angular — с `-9.8,0,-0.1` на `0,0,0`. Координаты не менялись весь 30-секундный monitor. Обычный pickup дал `held_released reason=actor_pickup_callback release=owned_without_world_shell`, затем `closed reason=actor_pickup`; последующий переход с предметом в инвентаре проблем не показал.

Production policy не использует exact-ID allowlist и debug stabilization gates. Rolling, underground, origin и multi-record routing полево приняты; общий `artifact_rescue_actions=false` остаётся безопасным default.

## Production policy настоящего underground

`artifact_rescue_underground_policy=held_first` маршрутизирует только подтверждённый vertical underground в тот же исполнитель. Истинный образец — `af_signet#6740` на `y04_pole`: исходный `y=0.3`, X/Z и distance оставались внутри linked radius, затем online `y=-20.5`, confirmation примерно через `2.023 s` при `y=-58.1`, позднее `-77.7`. Это не rolling. Напротив, уже подтверждённый rolling при низком Y/invalid nav остаётся rolling и не попадает в underground policy.

Для rolling/underground rescue target вычисляется только из captured `spawn_input_pos` и `zone_size`: кандидаты проходят nav vertex, downward static-ray support и максимальную дистанцию от исходного поля. Для origin этого оказалось недостаточно на многоуровневой геометрии. Новый путь читает штатный локальный реестр RVM через публичный `raid_anomalys.save_state`, требует ровно одну запись с тем же artifact ID/template/size/center и строит цель от сохранённого field LVID. Текущая повреждённая позиция и наша жёлтая область не являются источником цели.

Полевой тест true-underground принят 16 октября на save 11 с `af_signet#6740`. После загрузки мод восстановил underground `rescue_pending`, снял fresh snapshot в `(18.9,-77.7,173.6)` и отложил действие до подтверждения. Production dispatch сохранил тот же ID (`dispatch=1`, `maximum=1`) и использовал только допустимый target provenance `source=field_candidate`, `support=static_ray`: `(18.9,0.5,189.7)`. После трёх `position_verified` checks исполнитель перешёл в `held_attempt`/`held` с одним element; координаты оставались неизменными 30 223 мс. Pickup штатно дал `actor_pickup_callback` → `held_released reason=owned_without_world_shell` → `closed`. Rolling-кандидаты `af_night_star#1407` и `af_fonar#6362` при отключённой rolling policy действий не получили. Ошибок с префиксом мода не было; единственная сторонняя ошибка `uni_anim_detectors.script ... zzz_ea_addon_backpack nil` к rescue не относится. Underground-путь считается полево принятым и отдельного повтора не требует; master actions после теста возвращён в `false`.

## Лабораторный same-ID prototype

Prototype по умолчанию полностью выключен. Закрытый allowlist содержит только exact original IDs `1407` и `6362` с причиной rolling; section-only fallback отсутствует. Каждый ID имеет независимый предел в два same-ID `alife():teleport_object`, без recreate. Schema-1 сейв принятого теста мигрирует в schema 5 и восстанавливает первичную rolling-причину даже после старой ложной переклассификации. Только origin использует отдельный bounded offline-переход того же ID перед teleport, потому что полевой тест доказал duplicate-ID net spawn при прямом вызове на повреждённом online-shell. `set_switch_online/offline` являются только policy-setters; новый путь требует `server.online=true`, вызывает экспортированный `server:switch_offline()` и ждёт исчезновения exact client shell. У C++-метода `void`-возврат, поэтому Lua `nil` допустим; успех подтверждается исчезновением shell и fresh exact `alife_object(id)`, а не чтением ставшего stale исходного userdata. Split-state `live shell + server.online=false`, exception, identity mismatch и timeout отключаются без teleport и с восстановлением policy.

## Preventive и recovery для world origin

Фактический RVM после `shift_vector_for_artefacts` вычисляет второй `level.vertex_id(gen_pos)` и без проверки вызывает `level.vertex_position(lvid)`. При `4294967295` это объясняет создание объекта у world origin. Preventive guard выполняется внутри доказанного Lua 5.1 environment исходной функции, запрещает invalid vertex до настоящего `vertex_position`, требует static-ray support и нахождение кандидата в captured field, затем вызывает штатный внешний `raid_artefacts` wrapper. Поэтому section roll и `addToQueuedArtefacts` для классов/мутаций сохраняются. Восемь неудачных попыток дают явный `ERROR` и ни одного объекта.

Recovery не использует один `near_origin`. Для свежей записи обязательны initial и current server position внутри origin radius. Для persisted legacy origin current shell может быть вручную смещён, но initial обязан оставаться у origin, а causal lineage подтверждается exact registry LVID. В обоих случаях обязательны bad initial/nav evidence, прежние ID/section/level/GVID, отсутствие owner, ровно одна запись исходного поля в реестре RVM и цель `rvm_field_center/stock_lvid_static_ray`. Если exact object online, recovery сохраняет его switch policy, запрашивает offline и bounded ждёт исчезновения online-shell; при timeout флаги возвращаются и действие запрещается. После teleport три snapshots проверяют тот же ID, старая yellow area атомарно заменяется новой и held ждёт штатного online-shell. Путь полево принят; `artifact_rescue_actions=false` сохраняется как безопасный пользовательский default.

Для legacy origin допускается вручную смещённый current shell: `#6910` пользователь вытолкал из world origin до сохранения, но initial server `(0,0,0)` и causal origin-lineage сохраняются. Такая запись не понижается до rolling. Поскольку marshal уничтожает registry center, legacy revalidation требует unique exact artifact ID, текущий level, совпадающие template/size и точное равенство сохранённого target LVID ключу RVM registry. Для новых записей после первого доказательства сохраняются `rvm_field.lvid/template/size/center`; ambiguous/missing и любое расхождение остаются fail-closed с именованной причиной. Yellow area доказательством не является.

Первый active origin-тест 16 октября 2026 года на `af_ball#6910` и `af_peas#6930` не принят. Старая X/Z-цель попала для `#6910` на нижний слой (`target y=-20.9`) и обе цели оказались вне связанных жёлтых областей (`213.4/97.5 м`). Прямой `teleport_object` при существующем online-shell дал `CGameObject:net_spawn() Object with ID already exists` для обоих ID. Верификатор fail-closed остановил дальнейшие действия, но только после неудачной мутации; этот путь заменён описанной выше pre-dispatch exact-field/offline схемой. Повторять тест на старом коде нельзя.

Следующий active origin-тест 17 октября подтвердил schema 5, обе exact registry proofs и отсутствие secondary rolling, но также не принят. Policy-setters были вызваны с исходными `can_switch_online=true`, `can_switch_offline=true`; оба client shell остались после десяти проверок, записи отключились fail-closed до teleport/rebuild/held. Архив: `test-artifacts/field-logs/2026-10-17-origin-offline-timeout-01`. Аудит движка показал, что оба boolean — независимые разрешения, а не состояние. Online-сущность удалена из ALife graph registry, поэтому scheduler не применяет новые флаги к ней. Исправление использует доказанный штатными скриптами direct `server:switch_offline()` только при read-only `server.online=true`; ошибки, split-state и timeout остаются bounded/fail-closed, исходные policy восстанавливаются. Новый полевой прогон не активирован.

Контрольный active origin-прогон 18 октября подтвердил вызов direct `switch_offline()` для обоих exact ID, но runtime ошибочно потребовал немедленно прочитать `server.online` из того же userdata. После перехода это чтение вернуло `nil`, поэтому записи отключились как `direct_switch_failed` до teleport/rebuild/held, хотя `nil` является нормальным результатом `void`-binding и может сопровождать инвалидированный переходом userdata. Duplicate-ID не было. Оба артефакта затем штатно подобраны игроком: для `#6910` и `#6930` получены `closed reason=actor_pickup`, `zone closed` и `close type=artifact`, так что pickup cleanup этого legacy origin-сценария полево принят. Архив: `test-artifacts/field-logs/2026-10-18-origin-direct-offline-readback-fail-01`. Исправление проверяет наличие метода, сохраняет только `pcall_ok/return_type`, не читает исходный userdata после вызова и подтверждает успех лишь по исчезновению exact shell плюс fresh coherent identity. Новый active тест не запускался; defaults возвращены в safe observe-only.

Финальный active origin-прогон 18 октября полево принял весь production-путь сразу на двух независимых legacy ID. `#6910` и `#6930` получили по одному `origin_offline_requested` с `method_exists=true,pcall_ok=true,return_type=nil`, затем по одному `origin_offline_confirmed` после исчезновения exact shell и fresh identity. Для каждого выполнен ровно один same-ID dispatch (`1/1`), три принятых `origin_exact_field` snapshots, атомарный rebuild anchor (`26895→27137` и `26894→27138`), held одного physics element и monitor `30255 ms` с результатом `inside_tether`. Оба предмета штатно подобраны: held освобождён как `owned_without_world_shell`, зоны закрыты по новым anchors. Duplicate-ID, FATAL и ошибок с префиксом мода нет. Единственная `SCRIPT ERROR` — прежняя внешняя `uni_anim_detectors.script → zzz_ea_addon_backpack`. Архив: `test-artifacts/field-logs/2026-10-18-origin-held-success-01`. Origin recovery принят и отдельного повтора не требует; конфиг возвращён к safe profile.

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
