# Узкий полевой тест proactive artifact hold

Статические проверки не заменяют этот прогон. До его прохождения нельзя объявлять проблему падения артефактов исправленной.

1. Полностью закрыть X-Ray, обновить runtime-файлы мода и проверить byte-identical source/MO2 hashes.
2. Оставить `[artifact_pool] profile=weighted`, `artifact_proactive_hold=true`, `artifact_proactive_clearance=0.75`, `artifact_proactive_position_tolerance=0.35`, `debug_mode=on`. Forced decoy/tier должны быть `off/0`.
3. Запустить `tools\watch_live_log.cmd`, затем X-Ray и одну новую infected T2-вылазку в Тёмную лощину.
4. До подбора обойти все настоящие артефакты. Каждый обязан быть видимым, доступным детектору и подбору, слегка находиться над поверхностью и не падать/катиться. Сохранить для каждого цепочку `artifact proactive target`, `online`, `hold attempt`, `held`.
5. У одного ещё не поднятого артефакта записать ID и позицию, сделать одно штатное сохранение/загрузку, отойти и подойти снова. Ожидается `save ... hold_preserved=true`; при новой shell — `rehydrate pending` и новый `held` того же ID без action counters.
6. Поднять проверенный артефакт. Ожидается release только `own_fixed`, сохранение `foreign_preserved`, затем обычный `actor_pickup/closed`.
7. Поднять остальные артефакты и штатно выйти с локации. Ожидается `cleanup reason=confirmed_level_change` без release чужих pre-fixed элементов.
8. FAIL: любой `CGameObject:net_spawn() Object with ID already exists`, `artifact proactive unresolved`, online `teleport_object`, артефакт ниже поверхности/недоступен, смена ID/section, потеря hold после load или AER FATAL.

Только после успешного узкого T2-прогона расширять выборку на T1/T3, PAW same-level fast travel, NPC/container ownership и несколько последовательных сохранений.
