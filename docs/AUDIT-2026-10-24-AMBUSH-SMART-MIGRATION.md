# Аудит ухода ambush squad к generic smart — 2026-10-24

## Подтверждённая причина

RC5 доказал, что точка создания и save/load не являются первичной причиной. Для sortie `k01_darkscape:infected:180012:k01_darkscape` все четыре owned squad созданы в принятой safe-точке с `request_server_delta=0`, `scripted_target=none` и `position_write=false`.

- `43008`: request `(0.7,6.7,-434)`, actor distance `823.1`;
- `43017`: request `(81.2,-0.7,-600.6)`, actor distance `941.2`;
- `43025`: request `(-33.6,-3.7,-466.9)`, actor distance `868.7`;
- `43021`: request `(-160.3,-0.1,506.1)`, actor distance `606.4`.

К 15 секундам generic simulation уже назначила smart/target каждому отряду при `scripted_target=none`. У `43025` это `16913`; между 15 и 30 сек offline A-Life перенёс squad из `(-33.6,-3.7,-466.9)` в `(393.3,-2.6,322.6)`, сменив level/game vertex и приблизив к actor примерно до 33–39 м. К `before_save` другие дальние группы также ушли к smart: `43008` получил `16905`, `43017` — `16913`, `43021` — `16915`. Load восстановил уже изменённые позиции с нулевым saved delta и нового первичного скачка не создал.

В базовом `sim_squad_scripted:update()` после `squad_on_update` вызывается `get_script_target()`: при nil он передаёт squad в `generic_update()`, который выбирает `SIMBOARD:get_squad_target`, записывает assigned/current action и настраивает членов группы на выбранный smart. Именно этот путь наблюдается в RC5.

## Почему не используется `__lock`

`generic_update()` действительно немедленно возвращает при `self.__lock`. Но тот же базовый класс в `check_online_status()` выставляет `forced_online_status=false` при `__lock`, а `can_switch_online()` затем запрещает переход online. Постоянный lock поэтому рискует отключить нормальное срабатывание засады возле игрока.

## Выбранный seam

Для нового owned ambush squad после успешных `setup_squad_and_group`/callbacks и до публикации zone задаётся штатный сериализуемый `scripted_target` на собственный squad ID.

`get_script_target()` распознаёт этот ID как online/offline group, а `specific_update(self_id)` возвращает до назначения smart. В отличие от `__lock`, этот путь не меняет `forced_online_status`; online monster AI, дистанционное online/offline-переключение, exact marker и смерть членов остаются штатными.

Политика сохраняется в zone как `squad_isolation_policy=self_target`. Базовый `STATE_Write/STATE_Read` уже сериализует `scripted_target`; дополнительно callbacks `squad_on_first_update` и `squad_on_update` восстанавливают только отсутствующий self-target до ветки `get_script_target/generic_update`.

## Сравнение T1/T2/T3 immediate

Отдельного T2 immediate lifecycle в AER нет. Разрешение настроек выполняется до spawn:

- Поляна (`level_y04_pole`) и Мёртвый город (`level_l09_deadcity`) имеют `ambush_spawn_timing=start` в level LTX;
- Тёмная лощина (`level_k01_darkscape`) по умолчанию `proximity`, а MCM-переключатель записывает `start` в snapshot новой вылазки;
- при создании enemy zone значение один раз сохраняется в `zone.spawn_timing`;
- `update_zones` делает единственный выбор: `start` запускает `trigger_ambush` сразу, `proximity` ждёт дистанционный trigger;
- после этого все уровни проходят одни и те же `trigger_ambush → ambush_spawn_squad`; режим `start` выбирает одну общую таблицу start-cascade;
- принятый кандидат на всех трёх уровнях идёт в единственную `spawn_exact_squad`, затем в одинаковые `alife_create → create_npc → setup_squad_and_group → squad_on_npc_creation` и isolation.

Следовательно, отдельный `if` для T2 уже фактически существует только как выбор `start`/`proximity` до общей ветки; копировать T1/T3 код в ещё один T2 путь было бы дублированием. До RC6 ни T1, ни T3 не имели скрытого удерживающего target/lock: все уровни оставляли `scripted_target=nil`. Наблюдаемое расхождение объясняется данными конкретной simulation map — доступными smart terrain, их preconditions/графом, временем назначения и online/offline состоянием, — а не разными AER create/register функциями. T2 RC5 дал прямое доказательство выбора smart; отсутствие заметного скачка в прежних T1/T3 прогонах не является отдельной защитной схемой.

RC6 применяет один и тот же self-target seam после общей `spawn_exact_squad`, поэтому T2 immediate в точности использует тот же жизненный цикл, что T1/T3, и одновременно устраняет карту-зависимую возможность generic выбора smart на всех режимах.

## Границы безопасности

- нет teleport/set_position/position/vertex write;
- нет `__lock` или `force_online` write;
- нет очистки assigned/current target или detach от smart;
- новый spawn откатывается целиком, если до isolation уже имеет smart/target;
- чистый старый RC5 squad может мигрировать на месте;
- уже перемещённый/назначенный RC5 squad не изменяется и не возвращается;
- foreign squad не затрагиваются;
- cleanup по-прежнему освобождает исходный squad ID, а закрытие зоны по смерти и exact marker используют прежний lifecycle.

## Результат RC6 field gate

Darkscape immediate/start прогон пройден 24 октября: два отряда сохранили точные spawn-позиции и self-target без smart `0/1/5/15/30 с`, один прошёл save/load без переноса, оба штатно перешли online, атаковали, были уничтожены и закрыли зоны с удалением marker; обычный выход дал полный cleanup. Подробности и hashes локальных доказательств: `docs/FIELD-TEST-2026-10-24-RC6-SQUAD-ISOLATION.md`.

Из чистого кандидата удалена временная timeline/per-member телеметрия. Публикация остаётся заблокированной до трёх естественных no-debug рейдов на T1/T2/T3; это проверяет release-like сборку без forced timing/type и не переоткрывает уже пройденный целевой Darkscape repro.
