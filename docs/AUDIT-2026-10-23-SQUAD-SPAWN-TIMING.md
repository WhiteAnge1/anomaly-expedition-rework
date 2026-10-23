# Аудит spawn timing и перемещения enemy squad — 23 октября 2026

## Статус последнего запуска

Последний `xray_maksi.log` завершился до полевого теста RC4. Единственный FATAL:

```text
z_heatvision.script:448: attempt to index local 'hud' (a nil value)
set_nightvision_HUD -> update_nvgs -> on_option_change -> on_game_start
```

Строк исполнения AER до падения нет. Поэтому RC4 mutant diagnostics этим запуском не проверялась, а причинной связи падения с AER нет.

## Что доказано прежним T2-логом

В первой вылазке после изменения MCM и Apply активное состояние осталось прежним: десять зон, один owned squad и две valuable-зоны восстановились без нового `zone created`/`enemy squad ready`. После выхода следующая новая вылазка получила новый snapshot и создала четыре enemy-зоны при весах `50/0/0`. Одинаковые squad/member ID сохранились через load.

Следовательно, mid-raid Apply/save/load не мог переключить spawn timing, убрать valuable/empty или изменить exact markers текущей вылазки. Перемещение маркера в этот момент означает перемещение/смену живого командира того же squad, а не применение новых MCM-настроек.

## Граница snapshot

`prepare_sortie()` один раз вызывает `C.build_snapshot(level.name())`, активирует таблицу и сохраняет её вместе с `state`. В неё входят:

- включение и веса enemy/valuable/empty;
- три `show_exact_*`;
- Darkscape `ambush_spawn_timing`;
- artifact/false-zone distributions, artifact pool и schema-9 параметры;
- update interval и прочие опубликованные MCM-параметры из `specs`.

Повторный callback в той же вылазке snapshot не переснимает. `load_state()` активирует сохранённый snapshot; старый save без него мигрирует один раз. `cleanup()` очищает snapshot, поэтому только следующая новая вылазка получает новые значения MCM.

`debug_mode` в snapshot не входит: это лабораторная LTX/runtime-настройка, отсутствующая в MCM `specs`. Runtime-команда действует до перехода/перезапуска и не меняет игровые параметры snapshot.

## Фактические режимы появления

### T1 Поляна и T3 Мёртвый город

Default — `start`. После фиксации `start_pos` создаётся enemy anchor, затем в том же периодическом actor update отряд создаётся без ожидания приближения игрока. Camera/visibility не является допуском.

- T1: stock block `50` + padding `20`, профильный minimum `90`, итоговый minimum от текущего actor и `start_pos` — `90 м`.
- T3: stock block `60` + padding `20`, профильный minimum `80`, итоговый minimum — `80 м`.
- центр anchor сначала ищется не ближе `120 м` от start, fallback — `90 м` для T1 и `80 м` для T3;
- spawn-кандидат обязан быть внутри круга до `radius-8`, либо на последнем fallback в узком внешнем поясе `radius+1 .. radius+25`;
- обязательны level vertex и проверка от аномалий на первой ступени; следующие ступени могут разрешить аномалию, но не actor/start minimum.

### T2 Тёмная лощина — default `proximity`

Anchor создаётся далеко от `start_pos`: minimum равен `max(180, radius+130+20)`, то есть при радиусах `150..240` — `300..390 м`. Отряд остаётся armed до приближения actor на `radius+130` (`280..370 м`).

При создании каждый кандидат обязан быть не ближе `120 м` от текущего actor (`max(stock 100 + padding 20, profile min 120)`). Первые три ступени требуют скрытость по фактическому `device().cam_dir`; затем разрешены видимые fallback-точки. Все ступени сохраняют envelope круга: внутри `radius-8` либо снаружи не далее `radius+25`.

### T2 Тёмная лощина — MCM `start`/immediate

Новая вылазка фиксирует `start` в snapshot. Anchor ищется не ближе `120 м` от start, отряд создаётся сразу и использует тот же start-cascade, что T1/T3. Для каждого кандидата одновременно проверяются расстояния от текущего actor и сохранённого start — оба не меньше `120 м`. Visibility не проверяется.

Обнаружено несоответствие имени конфигурации, не объясняющее появление рядом: `enemy_spawn_distance_max=170` сейчас не является upper bound. Код использует maximum только в диагностической строке; реальная верхняя геометрическая граница задаётся radius/envelope enemy-зоны. Minimum `120` применяется строго.

## Anchor, squad и simulation

Anchor — отдельный невидимый объект в центре приблизительного круга. Squad создаётся через `alife_create(group_section, accepted_pos, lvid, actor_gvid)`, затем `squad:create_npc()` получает ту же позицию и vertex. После проверки полного состава каждый member проходит `SIMBOARD:setup_squad_and_group` и `squad_on_npc_creation`.

Секции AER наследуют обычный `online_offline_group`, имеют `faction=monster` и `common=true`; собственного `target_smart`, `scripted_target` или `respawn_point_id` они не задают. В отличие от штатного RVM `SIMBOARD:create_squad(smart, section)`, AER создаёт группу в произвольной безопасной точке, а не на smart terrain. После setup движок simulation вправе назначить `current_target_id`/smart, перевести членов online/offline и двигать группу. AER не фиксирует squad у anchor и не записывает ему позицию после создания.

Отсюда структурно возможны до первого управляемого кадра:

1. online AI уже начал движение от безопасной точки к actor;
2. offline simulation назначила smart/target и продвинула группу;
3. engine online switch восстановил member на simulation-позиции.

Это особенно заметно в `start`: группа существует во время завершения загрузки/первых update, тогда как `proximity` создаёт её позднее рядом с уже активным игроком. Возможность доказана архитектурой, но конкретный механизм двух наблюдений без координат RC4 пока не доказан.

## Что AER не делает

- MCM Apply не переснимает active sortie;
- marker refresh только следует за живым commander ID;
- load не вызывает повторный squad spawn;
- RC4 diagnostics только читает server/online object и пишет журнал;
- в diagnostic block запрещены create/release, teleport, `set_position` и position/vertex assignments;
- два существующих `alife():teleport_object` относятся только к artifact ID.

## Расширенная read-only диагностика для одного следующего прогона

Main после RC4 дополнительно хранит принятый spawn candidate и пишет:

- requested position/lvid и рассчитанные request→actor/start/anchor distances;
- фактические squad и member server/online positions/vertices;
- request→server/online delta;
- squad/member smart, `current_target_id`, `scripted_target`, `current_action`, `respawn_point_id`;
- timeline создания `0/1/5/15/30 с` и прежний load timeline `restore/0/5/15/30 с`.

Если stage `creation` уже показывает большой request delta — перемещение произошло внутри create/setup callbacks. Если `creation` совпадает с requested, но `creation_followup_1s` или позднее уходит — это post-create simulation/AI. Если до save всё стабильно, а delta возникает только `load_restore`/`load_first_update_0s`, виновата load/offline-online стадия.

## Минимальный следующий тест

1. Исправить/временно отключить отдельный HeatVision blocker.
2. Запустить без `-dbg`; для этих release-level `squad_load_diag` он не нужен.
3. AER `debug_mode=off`, включить только `show_exact_enemy_markers`; Darkscape `spawn_timing=start`, forced enemy при необходимости.
4. Новая infected Darkscape, actor не двигать первые 30 секунд; скрин карты на первом доступном кадре, затем 1/5/15/30 секунд.
5. У одного squad сделать save/load без MCM Apply; снова скрин сразу, 5/15/30 секунд.
6. Обычный выход и полный `xray_maksi.log`/watcher session.

`-dbg` глобально выставляет `DEV_DEBUG=true` для всей сборки и может включать чужие debug-пути. AER `debug_mode=auto` следует этому флагу; `on` всегда включает подробный AER debug; `off` подавляет его даже при `-dbg`. Exact enemy marker является независимой пользовательской настройкой. Для минимального причинного теста предпочтительны запуск без `-dbg` и `debug_mode=off`.

