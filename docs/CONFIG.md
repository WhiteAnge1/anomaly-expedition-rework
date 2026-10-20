# Настройки Anomaly Expedition Rework

Файл настроек: `gamedata/configs/plugins/rvm_sorties_rework.ltx`. После ручного изменения полностью закройте игру и запустите её снова. Начинать новую игру не требуется; новые параметры применятся при следующем входе на локацию вылазки.

## Основные настройки

- `enabled = true|false` — включает или отключает игровую логику мода.
- `stash_mode = scouting|anomaly|disabled` — оставляет один исходный тайник в разведывательной вылазке, возвращает его в аномальную либо отключает перенос.
- `enable_enemy_decoys`, `enable_loot_decoys`, `enable_empty_decoys` — разрешают соответствующие виды ложных областей.
- `weight_enemy`, `weight_loot`, `weight_empty` — относительные веса типов ложных областей; штатно `50/25/25`. После отключения одного вида остальные веса автоматически перенормируются. Число ложных областей считается отдельно: Поляна всегда 1, Тёмная лощина равновероятно 2–4, Мёртвый город 1/2/3 с вероятностями 20/60/20.

Количество настоящих артефактов задаётся отдельно в каждой `[level_*]` ключами `artifact_count_profile`, `artifact_count_values` и `artifact_count_weights`. Counts должны быть строго возрастающими положительными целыми числами; веса — положительными целыми процентами той же длины с суммой ровно 100.

- Поляна: `3/4/5 = 35/60/5%`, среднее `3.7`.
- Тёмная лощина: `5/6/7/8/9 = 5/20/47/26/2%`, среднее `7`.
- Мёртвый город: `4/5/6/7 = 11/80/7/2%`, среднее `5`.

Бросок выполняется ровно один раз перед штатной генерацией новой infected-вылазки и сохраняется; load и переход внутри того же уровня не перебрасывают и не добавляют поля. Невалидный/отсутствующий профиль либо недоступный безопасный hook дают явный release-log и оставляют stock `4/8/6`. Временное значение в local-таблице GRA Bolt восстанавливается после успешного или аварийного stock-вызова. Число ложных областей бросается независимо. При изменении профиля одновременно проверяйте экономику артефактов/классов/мутаций, число кругов и rescue; count не должен превышать stock `count_zones` локации.

## Пул настоящих артефактов

Секция `[artifact_pool]` управляет выбором base-section внутри настоящего anomaly-field. `profile=weighted` — рекомендуемый production-профиль, `profile=stock` — исходные короткие списки GRA Bolt. Выбор семейства и привязка к местности остаются штатными: `gravi/mosquito → gravi`, `electr/psy → electro`, `chem/fuzz → chem`, `therm → thermo`. Затем мод бросает качество и равновероятно выбирает секцию внутри соответствующей ячейки полного каталога АЭР.

| Тир | Junk | Low | Medium | High | Unique |
|---|---:|---:|---:|---:|---:|
| T1 | 45 | 45 | 10 | 0 | 0 |
| T2 | 10 | 32 | 43 | 15 | 0 |
| T3 | 2 | 8 | 43 | 45 | 2 |

Каждый ряд должен состоять из целых неотрицательных чисел и давать ровно 100. Нулевой bucket никогда не выбирается. Каталог содержит только 223 базовые секции из `raid_artefacts_tiers_by_dop`: без контейнерных суффиксов, absorbation/base/marker и технических вариантов. Все 20 `family × quality` ячеек непусты; 14 unique, включая `af_oasis_heart`, достижимы только через T3. Независимые броски могут дать одинаковую секцию.

При запуске проверяются веса, сумма, наличие каждой секции в `ini_sys`, полное и однозначное соответствие официальной классификации и доступность локальной `raid_groups_artifacts`. Любая ошибка выключает weighted-путь целиком на текущую сессию и оставляет stock-selector. Временная подмена одной ячейки восстанавливается и после ошибки штатного вызова. Rojok-wrapper вызывается как обычно, поэтому exact ID продолжает проходить его очередь классов, мутаций и сохранения. Эти веса не меняют отдельный rare-artifact pool loot-контейнеров.

Если выбранный тип не удалось разместить, мод пишет `ERROR ... type preserved, no replacement created` и не перебрасывает результат в более удобный тип. Это относится и к `debug_force_decoy_type`.

## Необязательный казуальный режим точных меток

Стандартный баланс реворка использует приблизительные области: точную цель внутри них игрок ищет самостоятельно. Следующие переключатели являются необязательной помощью и по умолчанию выключены:

| Параметр | По умолчанию | Что показывает |
|---|---:|---|
| `show_exact_artifact_markers` | `false` | Зелёную точную метку связанного рейдового артефакта |
| `show_exact_loot_markers` | `false` | Красную stash-метку точного контейнера области добычи |
| `show_exact_enemy_markers` | `false` | Одну красную точку на текущем командире отряда опасной области |

Каждый параметр принимает `true` или `false` и работает независимо. Вне debug метки строго icon-only: без подписи, названия, ID, координат и собственного tooltip. Обычное содержательное описание приблизительного круга остаётся доступным при наведении во всех режимах. Exact-иконка имеет `location_level=20`. Проверка всех 11 `map_spots*.xml` фактической сборки не нашла отдельного hit-area/click-area, поэтому artifact/loot-иконки умеренно увеличены до `14×14`, движущаяся enemy-иконка — до `15×15`, без смещения точных координат. Метки исчезают при закрытии области, подборе цели, открытии контейнера, смерти/удалении врага и уходе; после загрузки восстанавливаются без дублей.

В исходной аномальной вылазке RVM отдельной точной подсказки на рейдовые артефакты нет — их ищут по всей локации. Реворк добавляет приблизительные районы. Точная наводка на исходный тайник относится к другой механике. Поэтому `show_exact_*` ничего не «возвращают» и не компенсируют: это отдельный выбор игрока для более казуального прохождения.

## Баланс и сложные параметры

Радиусы областей, дистанции засад, состав противников, наполнение контейнеров и пулы редких артефактов задаются ниже в `[global]`, `[tier_1..3]` и `[level_*]`. Иерархия: глобальное значение → тир → конкретная локация. Значения по умолчанию рассчитаны на текущую альфа-версию; перед массовой настройкой рекомендуется сохранить копию файла.

`enemy_spawn_distance_min/max` задаются в метрах и имеют явный профиль для каждой поддерживаемой локации: Поляна `90..150`, Тёмная лощина `120..170`, Мёртвый город `80..120`. Минимум участвует в обязательной безопасной дистанции от actor, а для `start` — и от сохранённой стартовой позиции. Максимум сохранён как профиль/диагностический ориентир; фактическая точка выбирается каскадом относительно enemy-круга. После привязки к level vertex повторно проверяются навигация и фактическое расстояние до центра.

`ambush_spawn_timing` задаётся отдельно по локациям. Поляна и Мёртвый город используют `start`: внутри вне аномалий → внутри с разрешёнными аномалиями → узкий пояс снаружи. Тёмная лощина использует пять proximity-ступеней: `inside_hidden_clear → inside_hidden_anomaly_allowed → outside_hidden_anomaly_allowed → inside_visible_anomaly_allowed → outside_visible_anomaly_allowed`. Первые три получают `placement_attempts × ambush_hidden_attempt_multiplier` кандидатов (по умолчанию `60×3`) с low-discrepancy покрытием разных углов, расстояний и nav-вершин. Геометрически невалидная точка не принимается.

`ambush_start_zone_margin` — внутренний отступ от видимого края области на внутренних ступенях. `ambush_outside_zone_padding` задаёт ширину крайнего пояса сразу за кругом. `ambush_anomaly_clearance` — свободный отступ от края прочитанной shape на первых строгих ступенях; более поздние ступени осознанно допускают аномалии, но не отменяют level vertex и проверку диапазона после nav-привязки. Аномалии других уровней игнорируются. Если scan неполон, строгая ступень не считается безопасной, после чего каскад переходит к разрешающей аномалии. Если полный squad создать невозможно, область остаётся вооружённой и повторяет поиск позднее.

`ambush_start_center_exclusion_radius = 120` задаёт предпочтительную дистанцию центра start-области от старта. При исчерпании попыток она ослабляется до локального `enemy_spawn_distance_min`; прежнего требования искать центр за полным порогом активации `205–235 м` для Поляны/Мёртвого города нет. Проверки безопасного размещения самих членов squad остаются полными.

## Контейнеры добычи

Ящик должен восприниматься в центральной трети отображаемого круга на КПК. Поскольку Lua не даёт надёжного перевода физического радиуса в экранные пиксели конкретного spot, параметр `loot_offset_divisor` задаётся по тирам: `3` для T1, `5` для T2 и `10` для более компактного T3. То есть пределы равны `radius/3`, `radius/5` и `radius/10`. Фактические `offset/max/divisor` пишутся в компактный runtime-log. Новые T2/T3 пределы будут дополнительно просмотрены в финальных обычных рейдах без debug. Этапы генерации выполняются последовательно:

1. Medicine — два броска с шансом `70/78/85%`; если первый успешен, шанс второго вдвое меньше, иначе второй повторяет полный шанс. Повторы разрешены, а отмеченная `loot_medicine_half_weight` секция имеет половинный вес.
2. Valuable — независимая цепочка `35% → 10% → 1.5%`, дающая 0–3 предмета. Повторы запрещены, кроме `lead_box` на T3.
3. Ordinary — от 1 до `loot_cap - medicine - valuable` бросков; повторы разрешены. Лимиты T1/T2/T3 равны `6/7/8`. Количество одного осколка: `1..3`, `2..5`, `3..7`.
4. Rare — независимый шанс 4%, затем 70% артефакт из штатного тир-пула РВМ или 30% `raid_intelligence_note`. Фонари относятся к valuable, а не rare.

`tools\test_loot_policy.ps1` моделирует по 200000 контейнеров каждого тира и проверяет распределения, лимиты, повторы, осколки, `af_aam` и `adrenalin`.

Мод не меняет штатный начальный спавн и повторный доспавн RVM. Собственная опасная область выбирает категорию с относительными весами `enemy_category_weight_frequent/rare/superrare = 4/2/1` (примерно `57.14/28.57/14.29%`), затем равновероятно выбирает один точный preset внутри категории. Составы находятся в `gamedata/configs/mod_system_rvm_sorties_squads.ltx`: это фиксированные mutant-only `online_offline_group` без `npc_random`. Частично созданный либо не совпавший по составу отряд откатывается целиком.

Центр artifact-области настраивается ключами `artifact_offset_fraction_min/max` через обычную иерархию `[global] → [tier_N] → [level_*]`. Принятые профили: T1 `0.35..0.80` без изменений, T2 `0.10..0.20`, T3 `0.06..0.12`. После привязки к level-vertex проверяется уже фактическое смещение центра; превышение max отклоняется. Release-log сообщает `tier/level/offset/fraction/limit/range`. Настоящие artifact-области могут перекрываться друг с другом, потому что штатный RVM способен создать несколько артефактов в одной anomaly-zone; `zone_separation_min` по-прежнему действует для ложных областей и не превращён в общий запрет кластеров. Это исправляет только отображаемую геометрию и не перемещает сам артефакт; случаи `(0,0,0)` и underground остаются отдельной задачей rescue. При невозможности построить центр rate-limited лог показывает позицию, `near_origin` (не далее 2 м от мирового нуля) и накопленные причины отказов `invalid_vertex/post_snap_limit/separation/anchor_failure`.

## Artifact rescue: production policy, наблюдение и лабораторный prototype

| Параметр | Default | Назначение |
|---|---:|---|
| `artifact_proactive_hold` | `true` | Production lifecycle новых raid-artifacts: создать на доказанном target и удерживать physics shell до ownership/pickup |
| `artifact_proactive_clearance` | `0.75` | Высота pivot над свежей static-ray surface; runtime жёстко ограничивает значение диапазоном `0.5..1.0 м` |
| `artifact_proactive_position_tolerance` | `0.35` | Допуск проверки current shell; не разрешает relocation или online teleport |
| `artifact_rescue_observe_only` | `false` | Диагностический классификатор старого rescue; schema-6 proactive records его обходят |
| `artifact_rescue_actions` | `false` | Общий master gate любых активных действий; безопасный default оставляет только наблюдение |
| `artifact_rescue_rolling_policy` | `held_first` | Production policy: первый подтверждённый rolling сразу проходит teleport → 3 snapshots → reacquire → indefinite held; `debug_teleport` выбирает старую exact-ID лабораторную схему |
| `artifact_rescue_underground_policy` | `held_first` | Отдельная production policy настоящего vertical underground; использует captured field target и тот же held executor, не меняя rolling/origin |
| `artifact_rescue_origin_policy` | `held_first` | Отдельная policy только для строгого `origin_mismatch`; master gate по умолчанию выключен |
| `artifact_spawn_guard_attempts` | `8` | Число bounded-повторов штатного RVM spawn при invalid vertex, отсутствии static support или выходе кандидата за captured field |
| `artifact_rescue_debug_same_id_teleport` | `false` | Второй gate лабораторного same-ID teleport |
| `artifact_rescue_debug_artifact_ids` | `1407,6362` | Закрытый exact original-ID allowlist; код отклоняет любые другие ID и section fallback |
| `artifact_rescue_debug_reason` | `rolling` | Единственная разрешённая причина prototype; сейчас поддерживается только `rolling` |
| `artifact_rescue_debug_monitor_ms` | `30000` | Минимальный мониторинг после `position_verified` |
| `artifact_rescue_debug_monitor_log_ms` | `5000` | Интервал журнала displacement/distance/tether margin |
| `artifact_rescue_debug_cooldown_ms` | `20000` | Пауза после повторного rolling-confirmation до второго dispatch |
| `artifact_rescue_debug_max_dispatches` | `2` | Предел обычных same-ID отправок на original ID |
| `artifact_rescue_debug_same_frame_stabilization` | `false` | Отдельный gate третьего experimental dispatch после двух verified обычных; требует все предыдущие rescue-gate |
| `artifact_rescue_debug_held_after_verified_actions` | `2` | Порог только для `debug_teleport`; production `held_first` всегда использует ноль обычных rescue |
| `artifact_rescue_debug_held_stabilization` | `false` | Альтернативный third-stage gate: удерживает только зафиксированные модом элементы до pickup/release trigger; несовместим с same-frame gate |
| `artifact_rescue_debug_held_timeout_ms` | `120000` | Аварийное освобождение held-элементов; `0` отключает time release, положительное значение ограничивается снизу 30 секундами |
| `artifact_rescue_origin_radius` | `2` | Радиус признака near-origin; сам по себе никогда не подтверждает ошибку |
| `artifact_rescue_origin_field_margin` | `2` | Запас сверх `sqrt(2) * size` при проверке несовпадения с исходным полем |
| `artifact_rescue_origin_nav_mismatch` | `4` | Порог несогласованности позиции с nav vertex |
| `artifact_rescue_underground_drop` | `12` | Минимальное падение Y от последней достоверной позиции |
| `artifact_rescue_underground_vertex_gap` | `4` | Vertex должен быть выше объекта минимум на это расстояние либо быть invalid |
| `artifact_rescue_underground_samples` | `3` | Число последовательных плохих samples |
| `artifact_rescue_underground_duration_ms` | `2000` | Минимальная длительность underground-эпизода |
| `artifact_rescue_rolling_edge_margin` | `5` | Эпизод начинается дальше `linked radius + margin` |
| `artifact_rescue_rolling_confirm_ms` | `15000` | Устойчивое время снаружи до диагностического `rescue_pending` |
| `artifact_rescue_log_repeat_ms` | `60000` | Минимальный интервал повторных save/сводных сообщений |

Provenance schema 5 сохраняет ID/section, шаблон и размер поля, первый server position/LVID/GVID, связанную область, last-good позиции, ownership/lineage, bad-sample counters, timestamps, состояние, первичную причину, preventive spawn journal и action journal. Для origin дополнительно сохраняется доказательство из штатного `raid_current_anomaly_zones`: unique matching artifact ID, field LVID/template/size и цель `rvm_field_center/stock_lvid_static_ray`. RVM registry center после marshal-load непригоден — vector восстанавливается get-based нулевым значением, — поэтому schema 5 хранит канонический центр отдельно. Legacy schema 1–3 сохраняет исходный target LVID до очистки угаданной цели и допускается только при точном равенстве ключу реестра вместе с ID/level/template/size; ambiguous/missing fail-closed. Persisted origin-lineage не понижается до rolling из-за вручную смещённого current shell. При NPC pickup RVM может заменить world ID новым inventory ID; однозначный replacement той же секции добавляется в lineage независимо от `remove_on_npc_pickup`.

Строгий origin-кандидат требует одновременно near-origin, несовпадение с конкретным полем и его размером, плохой vertex/nav, отсутствие parent и валидную static-ray цель. Underground требует всех порогов из таблицы и отсутствия владельца. Rolling начинается при любом устойчивом превышении `radius + 5 м`; возврат внутрь полностью сбрасывает эпизод. Первая подтверждённая причина сохраняет причинный приоритет: rolling за пределами игровой nav-сетки не становится underground только из-за низкого world Y/invalid vertex.

Для новых schema-6 записей production не ждёт rolling/underground: guarded spawn выбирает target внутри captured anomaly field, проверяет vertex и static ray, ставит итоговый Y ровно в `surface_y + clearance`, а затем early binder/capture callback фиксирует только ранее не fixed physics elements. Save не снимает этот hold; после новой online-shell он rehydrate без counters. Pickup/NPC/container/cleanup освобождает только indices, зафиксированные модом. Если fresh shell уже не у target или static support не совпал, путь остаётся `unresolved` и не вызывает `teleport_object` online. Старые записи с exact persisted guarded target могут перейти в rehydrate; остальные работают legacy observe-only.

Preventive слой не копирует таблицы артефактов RVM. Он доказывает через Lua 5.1 environment связь внутренней функции `raid_anomalys` с внешней `raid_artefacts`-обёрткой, временно и синхронно защищает второй vertex/create и всё равно вызывает штатный внешний wrapper. Поэтому выбор section, классы/мутации и `addToQueuedArtefacts` сохраняются. При недоказуемом hook path создание fail-closed запрещается с явным `ERROR`.

Prototype не является пользовательской функцией. Он выбирается только через `artifact_rescue_rolling_policy=debug_teleport` и дополнительно требует `artifact_rescue_debug_same_id_teleport=true`, exact ID `1407`/`6362` и debug-настройки ниже. В нём по-прежнему можно воспроизвести старые ordinary/same-frame/held сценарии.

`artifact_rescue_debug_same_frame_stabilization=true` разрешает ровно третий dispatch только после двух обычных действий с `verified_at` и нового независимого rolling-confirmation. После same-ID teleport код проверяет exact online-object и все physics elements, временно фиксирует только ранее не fixed элементы и освобождает только их в том же callback. Shell/API/element failure не отменяет teleport: пишется `stabilization_unavailable/failed`, затем продолжаются position verification и мониторинг. Permanent fix, перенос fixed-состояния через кадр/save, recreate, offline-cycle, `apply_force` и section fallback запрещены. После третьего dispatch действует hard maximum `3`.

`artifact_rescue_debug_held_stabilization=true` относится только к `debug_teleport` и не может работать одновременно с same-frame gate. Его timeout и порог сохраняются для диагностики. Production `held_first` использует тот же проверенный post-teleport journal/release-контракт, но всегда с порогом `0` и без автоматического timeout.

## Диагностика и тестовые параметры

- `debug_mode = auto|on|off` — полный технический режим. `auto` следует `DEV_DEBUG`/`DEV_DEBUG_DEV`.
- `debug_log` — совместимость со старыми конфигами при отсутствии `debug_mode`.
- `debug_force_decoy_type`, `debug_force_tier`, `debug_cleanup_current_sortie` — только для контролируемых тестов.

Полный debug всегда показывает все exact-маркеры с техническими tooltip, даже если пользовательские `show_exact_*` равны `false`. Он также включает журнал и census; это не обычный игровой режим. После тестирования верните forced-параметры к `off`, `0`, `false`.

Отдельная система аномалий Arrival пользовательскими метками не охватывается. Не отмечаются также обычные артефакты мира и штатное население RVM.
