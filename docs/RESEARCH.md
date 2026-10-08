# Исследование фактической реализации

Дата: 2026-10-08. Профиль MO2: `2v2(DX11) (v_6gb) 2.5, Высокие настройки (167)`.

## Владельцы и поток вызовов

- Эффективная расширенная реализация вылазок находится в `GRA Bolt/gamedata/scripts`.
- `z_raid_item_travel_dungeons.script` читает `type_dungeon` из маршрутного листа, телепортирует игрока и на первом обновлении вызывает `raid_tasks_dungeons.issue_task_dungeon(map_used_typ)`. Для `infected` затем синхронно вызывается `raid_anomalys.spawner_anomals_zones(level.name())`.
- `raid_tasks_dungeons.script` выдаёт `raid_general_task_scout_dunge` для `scouting` и `raid_general_task_search_in_treasures_and_delivery_out` для `infected`.
- `raid_tasks_scout_dunge.script` создаёт точки, проверяет 30 м/150 м с биноклем и выдаёт `raid_intelligence_note`. Эта логика не заменяется.
- `raid_tasks_search_treasures_delivery.script` в стадии 0 делает до десяти попыток `treasure_manager.get_random_stash`, отмечает найденный контейнер `secondary_task_location` и завершает задачу только после возвращения домой. Альфа подавляет именно эти десять вызовов, оставляя задачу выхода рабочей.
- `raid_anomalys.script`: `spawner_anomals_zones` создаёт динамические рейдовые зоны и вызывает `spawn_artefact_in_zone`; функция возвращает точный server ID. Это минимальная и надёжная граница источника №3 из ТЗ.
- `raid_artefacts.script` отдельно оборачивает рейдовый спавн для рандомизации параметров. Наш файл имеет префикс `zzz_`, поэтому оборачивает уже совместимую цепочку и сохраняет её результат.

## Разделение источников артефактов

- Arrival создаёт артефакты через `drx_da_main.spawn_artefact_on_smart` (`drx_da_main.script`, около строк 1450–1594).
- GRA Bolt сам различает этот путь и `raid_anomalys.spawn_artefact_in_zone` в `raid_artefacts.script`.
- Новый мод не перебирает все артефакты уровня и не оборачивает Arrival. В области попадают только ID, возвращённые рейдовым спавнером.

## Карта и PAW

- PAW добавляет map spots через `modxml_map_spots_paw.script`, а контекстное меню получает ID выбранного server object (`map_spot_menu_add_property`).
- `valid_waypoint_target` разрешает настроенные clsid, NPC/мутантов и переходы. Используемый РВМ `raid_shelter_gag:physic_object` соответствует применявшемуся в сборке паттерну временных точек.
- Поэтому круг прикреплён не к артефакту, а к отдельному якорю в смещённом центре. PAW видит только якорь.
- Собственные `map_spots.xml` не копируются: DXML включает маленький фрагмент `map_spots_rvm_sorties.xml`, совместимый с PAW.

## A-Life, callbacks и сохранения

- Доступны callbacks `actor_on_item_take` и `npc_on_item_take`; второй уже используется UI сборки и передаёт `(npc, obj)`.
- Состояние хранится в `m_data.rvm_sorties_rework`: ID артефактов, якорей, boxes, созданных мутантов, флаги и счётчики.
- Повторная загрузка не запускает генерацию: сохранены таблица `artifact_zone` и `decoys_created`. На `actor_on_first_update` только восстанавливается пропавший map spot существующего якоря.
- Перед сменой уровня выполняется идемпотентная очистка. Освобождение отсутствующего объекта защищено проверкой `alife_object(id)`.

## Радиусы и уровни

- Фактические ID: Поляна — `y04_pole` (T1), Тёмная лощина — `k01_darkscape` (T2), Мёртвый город — `l09_deadcity` (T3).
- `raid_dospawn_dungeons.raid_sim_dospawn[level][type].spawn_block_radius`: Поляна 50, Лощина 100, Мёртвый город 60. Альфа читает эти значения напрямую и добавляет `ambush_extra_padding`; при отсутствии пишет диагностическое сообщение и использует fallback.

## Переопределения и конфликты

- `gamedata/configs/mod_system_rvm_sorties_rework.ltx`: DLTX-переопределяет только `description` шести маршрутных листов, чтобы убрать безусловное упоминание тайника.
- `gamedata/scripts/modxml_rvm_sorties_map_spots.script`: DXML-вставка, без замены картографических XML сборки.
- Остальные файлы имеют уникальные имена. Полных копий Lua РВМ, Arrival или PAW нет.

