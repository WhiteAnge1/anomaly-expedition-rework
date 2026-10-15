# Исследование спасения рейдовых артефактов

Статус: исследование завершено; первая runtime-стадия provenance + observe-only реализована без перемещения предметов. Полевой сценарий вынесен в `ARTIFACT-RESCUE-OBSERVE.md`. Активное rescue требует отдельного разрешения и эксперимента. Штатные количества RVM `4/8/6` пока не меняются.

## Проверенная фактическая цепочка RVM

Основной источник сборки: `GRA Bolt/gamedata/scripts/raid_anomalys.script`.

1. В `raid_distribution_anom_zones` заданы Поляна `22 зоны / 4 артефакта`, Тёмная лощина `190 / 8`, Мёртвый город `90 / 6`.
2. `z_raid_item_travel_dungeons.actor_on_first_update` вызывает `raid_anomalys.spawner_anomals_zones(level.name())` только для новой infected-вылазки после перехода на рейдовую локацию.
3. `spawner_anomals_zones` выбирает terrain-прямоугольник с вероятностью, пропорциональной площади, создаёт X/Z-кандидат с `y=0`, проверяет первый `level.vertex_id`, дистанции и вызывает `spawner_anomals`.
4. `spawner_anomals` сохраняет логический центр поля в локальной `raid_current_anomaly_zones[lvid]`: `pos`, `size_zone`, `anom_zone`. Затем создаёт несколько отдельных server anomaly objects. У каждого shape — сфера с локальным центром `(0,0,0)` и собственным радиусом; единого server object для всего поля нет.
5. Пока счётчик артефактов больше нуля, для очередного успешно созданного поля вызывается `spawn_artefact_in_zone(anom_zone, gen_pos, level_tier)`. Поэтому первые успешные поля получают по одному артефакту до исчерпания `4/8/6`.
6. `shift_vector_for_artefacts` делает до 20 смещений вокруг логического центра поля. Она проверяет только X/Z внутри любого широкого `terrain_zones[level]` прямоугольника.
7. `spawn_artefact_in_zone` повторно вызывает `level.vertex_id(gen_pos)`, но в отличие от соседних путей **не проверяет** результат против `4294967295`. Затем без проверки вызывает `level.vertex_position(lvid)` и `alife_create_item`.
8. Итоговый ID сохраняется как `raid_current_anomaly_zones[field_lvid].artefact_id`. Таблица сохраняется RVM и используется при штатном cleanup.
9. Более приоритетный `GRA Rojok Artifact System/gamedata/scripts/raid_artefacts.script` оборачивает этот spawn, берёт тот же server object и помещает его в `queued_artefacts`. После появления `level.object_by_id(id)` объект получает случайный класс/мутации. И `queued_artefacts`, и `saved_artefacts` сохраняются.
10. Текущий реворк оборачивает тот же метод после Rojok и получает `anom_zone`, логический центр поля `pos`, `level_tier` и тот же ID. Это правильная точка захвата provenance, но не причина немедленно переносить любой подозрительный объект.

## Что означает `zone=chem_1_1`

`anom_zone` — ключ шаблона поля, а не имя конкретного server restrictor и не уникальная фигура на карте.

- Префикс задаёт семейство: `chem`, `electr`, `therm`, `gravi`, `mosquito`, `fuzz`, `psy`.
- Число `1/2/3` задаёт размер и насыщенность шаблона: фактические `size_zone` равны `10/16/22` м.
- Последнее число у `chem/electr/therm/fuzz/psy` выбирает вариант состава аномалий. У `gravi` и `mosquito` отдельного суффикса варианта нет.
- `chem_zone_restrictor_block` — специальный шаблон блокировки выхода, не штатное артефактное поле.

Один ключ может использоваться много раз. Для rescue недостаточно сохранить только строку: нужны переданный `pos`, ID, level, tier и размер шаблона.

## Почему `(0,0,0)` не является достаточным условием

Статический разбор terrain-таблиц показал, что X/Z-ноль входит в один штатный прямоугольник каждой целевой карты:

| Локация | Terrain-область, содержащая `(0,0)` | Прямоугольник X/Z |
|---|---|---|
| `y04_pole` | `forest_1` | `(-36,-4)..(30,73)` |
| `k01_darkscape` | `build_2` | `(-15,-43)..(97,24)` |
| `l09_deadcity` | `road_5` | `(-6,-3)..(100,8)` |

Следовательно, `near_origin` — только диагностический признак. Он не доказывает ни невалидный vertex, ни недоступность точки. Полный T3-тест уже показал два артефакта у origin, для которых реворк смог создать круги.

Причина подтверждённых плохих origin-spawn согласуется с непроверенным вторым `level.vertex_id`: terrain rectangle допускает X/Z, level graph — нет, а результат `level.vertex_position(invalid)` попадает в origin. Observe-only прогон 15 октября 2026 года подтвердил у strict origin-кандидатов исходный `m_level_vertex_id=4294967295` при удалённом центре конкретного поля. Это подтверждает классификатор и рабочую гипотезу для данной сборки, но active correction всё ещё требует отдельного same-ID эксперимента.

Надёжный `origin_invalid` требует одновременно:

- объект без parent и на текущем raid level;
- server position не далее 2 м от мирового нуля;
- сохранённый центр конкретного поля находится дальше максимального штатного смещения этого шаблона: `sqrt(2) * size_zone + 2 м`;
- server `m_level_vertex_id` невалиден **или** позиция не согласуется с валидной nav-точкой и полем;
- существует проверенная rescue-точка возле исходного поля.

Если поле само находится рядом с origin и объект укладывается в его разрешённое смещение, автоматическое действие запрещено.

## Доступные API в этой сборке

Активный `AnomalyDX11.exe` совпадает по SHA-256 с сохранённым non-MT пакетом modded exes `2026.4.6`. Поэтому нельзя полагаться на более поздний MT-only fix invalid-position recovery, появившийся в changelog 2026-06-01.

Подтверждено локальными `lua_help.script` и рабочими модами:

- `alife():teleport_object(id, gvid, lvid, pos)` переносит существующий ALife ID; `_g.TeleportObject` дополнительно очищает `db.offline_objects[id].level_vertex_id` и `db.spawned_vertex_by_id[id]`.
- `alife():set_switch_online/offline` управляет разрешением переходов, но не является документированным немедленным перемещением предмета.
- `utils_item.script` реально переносит один и тот же item ID сначала на другой уровень, затем назад, чтобы провести online/offline цикл. Это доказывает сохранение ID, но такой двухуровневый трюк слишком опасен для награды вылазки.
- У online `game_object` нет общего экспортированного `set_position`; `set_actor_position` относится к актёру.
- `physics_shell` экспортирует `get_linear_vel`, `get_angular_vel`, `apply_force`, а modded exes — также `apply_torque`. Надёжных `set_linear_velocity/set_angular_velocity` в установленном API нет.
- У `physics_element` есть `fix/release_fixed`, но временная фиксация каждого элемента меняет физическое состояние. Поэтому следующий default-off эксперимент делает fix/release синхронно в одном callback, только после двух verified обычных rescue и только на третьем independent rolling.
- Полевой same-frame опыт подтвердил API буквально: один element (`candidates=1,pre_fixed=0`), `fix/release` без ошибок; до вмешательства linear `(0,-0.2,-1)`, angular `(-9.8,0.1,-0.1)`, после release обе скорости `(0,0,0)`. Через 30.278 с предмет снова ускорился по непрерывному склону, подтвердил rolling за 15.135 с, дошёл до `action_limit_reached dispatches=3 maximum=3` и позиции `(-55.8,-46.7,-262.3)`. Следовательно, следующий held-эксперимент проверяет pickup fixed-предмета, а не остаточный импульс.
- `ray_pick` с flags `2` проверяет статическую геометрию. Сам RVM использует вертикальный луч возле nav-точки для укладки объектов на пол.

Вывод: безопасный кандидат — same-ID `alife():teleport_object` с очисткой двух db-кешей и последующей проверкой server/online позиции. Перенос online ID и поведение скорости нужно сначала проверить на временном тестовом артефакте. Recreate запрещён: он разрывает RVM `artefact_id`, очередь/сохранённые мутации Rojok, индексы реворка и map spots.

## Критерий underground

Один отрицательный `vertex_dy` недостаточен: многоуровневая геометрия, склон или один переходный кадр могут быть нормальны. Предлагаемый консервативный классификатор:

1. Имеется первый достоверный server/nav snapshot и объект появился online.
2. Нет parent actor/NPC/container, область открыта, ID/section совпадают с lineage.
3. Одновременно выполняются:
   - `online_y <= last_good_y - 12 м`;
   - текущий валидный vertex выше объекта минимум на 4 м **или** текущий vertex невалиден;
   - X/Z остаются в радиусе `linked_zone.radius + 20 м` от связанной области либо возле исходного поля.
4. Условие держится три последовательных update sample не менее 2 секунд.
5. Вертикальный `ray_pick` от nav-point `+2 м` вниз на `4 м` подтверждает статический пол возле будущей точки.

Полевой прогон подтвердил пороги на двух независимых объектах Тёмной лощины: `af_electra_moonlight#6904` (`-0.3 -> -40.8`, `vertex_dy=-40.4`, `3/2008 ms`) и `af_fuzz_kolobok#7018` (`0.1 -> -40.8`, `vertex_dy=-40.9`, `3/2021 ms`). Третий объект успел дать только первый sample до конца рейда. Значения `12/4 м`, `3 sample/2 с` остаются консервативным рабочим профилем до более широкой выборки.

## Критерий скатывания и границ

Обычное движение внутри доступного круга не является ошибкой. Согласованный zone-aware tether:

- bad episode начинается при любом устойчивом выходе дальше `linked_zone.radius + 5 м` от центра видимого круга;
- если объект вернулся внутрь до 15 секунд, episode полностью сбрасывается;
- если через 15 секунд объект всё ещё снаружи, создаётся диагностический `rescue_pending`;
- observe-only хранит max excess, duration и trend, но не выполняет действие;
- cooldown и лимит будущих реальных переносов будут утверждаться только после полевых данных этой стадии.

Так порог зависит от реально показанной игроку области, а не от произвольных мировых координат. Положение у машины, стены или забора само по себе не считается недоступным.

Точные внешние границы нельзя надёжно вывести из широких `terrain_zones`: они специально включают дороги, строения, склоны и не описывают заборы. До ручного набора boundary-полигонов механизм границ должен работать только как observe-only.

### Координаты курсора карты

Установленный PAW 2.4.1 подтверждает пригодный путь:

- modded exes callback `on_map_right_click(property_ui, map_table)` вызывается для пустого места карты;
- `map_table` уже содержит world `pos`, `lvid`, `gvid`, `object_id=65535`;
- PAW по этим данным создаёт временный `script_zone` и умеет ставить точку без собственного преобразования экранных координат.

Будущий debug-инструмент может включаться отдельной командой, регистрировать последовательность кликов для текущего level, писать `pos/lvid/gvid` в лог и показывать временные PAW-маркеры. Он не должен менять `property_ui`, поглощать callback или постоянно перехватывать правый клик. Границы становятся активными только после ручной проверки и переноса координат в версионируемый конфиг.

## Три механизма будущего rescue

### 1. Initial-origin correction

- Срабатывает один раз сразу после wrapper callback, пока объект server/offline.
- Использует строгий `origin_invalid`, а не простую проверку нулей.
- Строит кандидаты в исходном диапазоне RVM вокруг `spawn_input_pos`, проверяет terrain, vertex, post-snap distance и вертикальный static ray.
- Переносит тот же ID; затем повторно открывает `alife_object(id)` и сверяет ID/section/level/position.
- При любой ошибке только логирует и оставляет штатный объект без создания замены.

### 2. Online-underground recovery

- Начинается только после подтверждённых bad samples.
- Цель выбирается возле первого достоверного server position; если там нет опоры — новый валидный кандидат возле исходного поля.
- Выполняет same-ID teleport и проверяет server/online положение через несколько кадров.
- Точное обнуление скорости недоступно. Эксперимент должен сравнить: обычный teleport; teleport после краткого safe offline transition; краткий `physics_element:fix/release_fixed`. До результата никакая физическая стабилизация не включается в production.

### 3. Rolling/boundary return

- Rolling использует tether относительно сохранённого linked circle и выдержку времени.
- Подтверждённый rolling остаётся первичной причиной, пока объект не вернулся внутрь tether. Низкий world Y или invalid nav после ухода по реальному склону за игровую карту не являются независимым доказательством underground и не создают второе действие.
- Boundary добавляет проверенный вручную полигон текущей локации; coarse terrain rectangle остаётся только дополнительным признаком.
- Цель — сохранённая last-good точка с подтверждённой статической опорой либо новый кандидат внутри того же исходного поля.
- Cooldown 15 секунд, общий лимит 2 rescue на ID, затем observe-only.

## Сохраняемая state machine

Для каждого artifact ID нужна отдельная provenance-запись schema следующей версии:

- `section`, `anom_zone`, `zone_size`, `level`, `tier`;
- `spawn_input_pos`, первый server `pos/lvid/gvid`, linked anchor/radius;
- `last_good_server`, `last_good_online`, текущие parent/ownership/lineage IDs;
- bad-sample counters и timestamps по `origin/underground/rolling/boundary`;
- `state`, `reason`, `target`, `rescue_count`, `rolling_rescue_count`, `cooldown_until`;
- `disabled/error_once` для fail-closed поведения.

Состояния:

Полная цепочка: `captured -> observing_server -> observing_online -> suspect -> rescue_pending -> verifying -> stable`. `verifying/stable` теперь доступны только узкому default-off debug prototype для одного exact ID; публичные defaults остаются observe-only.

Отдельные терминалы: `owned`, `closed`, `released`, `disabled`. Загрузка сохранения продолжает сохранённое состояние, но никогда не повторяет уже подтверждённый teleport. Любой parent/ownership немедленно переводит запись в `owned`; cleanup настоящего выхода оставляет освобождение предмета штатному RVM.

Фактический NPC pickup в полевом логе уничтожил старые world IDs `7012/8318` и создал новые `38145/38144` тех же секций, которые Rojok затем рандомизировал. Поэтому ownership нельзя определять только parent старого ID. Observe-only runtime принимает replacement лишь из `npc_on_item_take` и лишь для точного ID либо единственного исчезнувшего open-кандидата той же секции; новый ID сохраняется в lineage/lookup. Несколько совпадающих кандидатов дают fail-closed ambiguity без сопоставления.

## Общие guardrails

- Никогда не rescue предмет у actor/NPC/container, после закрытия зоны или после lineage replacement.
- Не менять section, name/ID, класс, мутации, стоимость и очередь `raid_artefacts`.
- Не создавать второй предмет и не release исходный ради попытки исправления.
- Все engine/API обращения — через `pcall`; ошибка отключает rescue только для этого ID/сессии.
- Сначала режим `observe_only` с причиной, source/current/target, vertex/ray, owner и counters.
- Повторные callbacks должны быть идемпотентны: hook guard, запись по ID и отсутствие второго pending action.
- На save/load сохраняются provenance, counters, cooldown и уже выполненные действия.

## Поэтапная проверка перед включением

1. Provenance/observe-only принят полем на T1/T2/T3: origin, чистый underground, rolling, save/load и NPC lineage подтверждены. Полевой T1 также выявил и закрыл ложную переклассификацию rolling→underground на реальном склоне.
2. Первый default-off прогон exact ID `1407` подтвердил свежий post-load snapshot, один same-ID teleport, сохранение ID/section и достижение target; контрольный `6362` не перемещался. Repeat-rescue подтвердил два verified обычных dispatch `6362`. Same-frame third stage успешно обнулил скорости, но постоянный склон снова увёл предмет за tether; hard maximum=3 сработал. Следующий узкий этап — held third dispatch только для `6362`, 30–60 секунд наблюдения и обязательная попытка actor pickup. Если fixed pickup невозможен, held timeout освобождает только собственный element, а результат направляет разработку к proximity-release.
3. Проверить три искусственных случая: origin mismatch, underground, уход за tether. Доступный склон не должен срабатывать.
4. Включить только initial-origin correction; затем отдельными этапами underground и rolling.
5. Проверить NPC pickup, смерть NPC, `actor_pickup_recreated_id`, exact marker, Rojok queue ровно один раз и штатный cleanup.
6. Boundary оставить observe-only до ручного сбора координат через map callback.
7. Только после полевого подтверждения rescue обсуждать изменение `4/8/6` и проводить normal-player рейды с debug off.

## Аудит зависимостей LTX

В `rvm_sorties_rework.ltx` добавлены только комментарии `Связано с:` и `При изменении также проверь:`. Значения не изменялись. Комментарии связывают:

- enable-флаги с весами и forced test mode;
- радиусы с artifact/loot offsets и placement attempts;
- весь ambush timing/distance/trigger/retry каскад;
- category weights с точными squad presets;
- loot cap с medicine/valuable/ordinary/rare этапами;
- exact switches с debug mode;
- tier-параметры с level overrides.

Это пользовательская подсказка, а не новый runtime API.

## Источники API

- Фактические Lua-файлы перечислены выше и исследованы в активном MO2-порядке.
- Modded exes документирует дополнительный `on_map_right_click` callback и последующие engine fixes: https://github.com/themrdemonized/xray-monolith
- Открытая просьба о поведении движущихся артефактов подтверждает, что движение после появления online является отдельной физической механикой: https://github.com/themrdemonized/xray-monolith/issues/647
- Обсуждение гравитационных аномалий подтверждает возможность выброса физического артефакта далеко от поля: https://github.com/themrdemonized/xray-monolith/issues/602

До отдельного разрешения runtime реворка продолжает только диагностировать позиции и ничего не перемещает.
