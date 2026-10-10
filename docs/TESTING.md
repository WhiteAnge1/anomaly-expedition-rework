# Матрица игровой приёмки 0.2.1-alpha

| Проверка | Ожидаемый результат | Диагностика |
|---|---|---|
| Источник артефакта | Область только после `captured raid artifact` | Сопоставить ID в логе |
| Смещение | Артефакт внутри круга, не в центре | `center`, `radius`, `linked` |
| Внешний вид | `artifact/enemy/loot/empty` неразличимы | `debug_force_decoy_type` |
| Плотность Поляны | Все настоящие области + не более одной ложной | `decoy plan ... cap=1` |
| PAW | Контекстное меню не предлагает переход; маршрут указывает на центр-якорь | Сравнить с `center` в логе |
| Debug tooltip | Обычный текст сохранён; добавлены kind/anchor/radius/linked | Сравнить все четыре kind |
| Подбор игроком | Одна область закрывается | `reason=actor_pickup` |
| Подбор NPC | При false область остаётся | Переключить `remove_on_npc_pickup` |
| NPC → труп → actor | Область остаётся у NPC и закрывается, когда linked ID оказывается у actor; после дистанционного подбора NPC допустим новый ID только для единственного пропавшего кандидата той же секции | `reason=actor_owns_linked_artifact` либо `actor_pickup_recreated_id`; неоднозначность не закрывает зоны |
| Диагностика артефакта | Server/online existence, parent chain, позиции, `anchor_dxz/dy`, ближайшая vertex | Периодический debug-log и `rvm_rework_census` |
| Exact artifact marker | Debug-on: зелёный `paw_stash_green` следует exact linked ID; debug-off/close: исчезает | Tooltip `kind/artifact_id/section/name/position/parent` |
| Засада | 2–3 разрешённых мутанта вне взгляда, штатного spawn-radius и заданного зазора от аномалий; старт находится дальше полного порога активации | `ambush entity ... owned_by_rework=true`, `spawned`; допустим `fallback=relaxed_out_of_view`, но не видимый fallback |
| Enemy debug markers | Красная точка только на каждом живом `zone.spawned_ids`; смерть/пропажа удаляет её на update | Tooltip `section/id/owned_by_rework/alive`; штатные RVM без точек |
| Контейнер | Видимая модель открывается; ordinary target 1–6, при исчерпании low pool допустимо меньше, rare независим | `target/created/ordinary/valuable_quota/actual/sections/rare`, затем `reason=container_opened` |
| Valuable quota T1 | Quota 0/1/2/3: 65/31.5/3.4475/0.0525%; actual никогда не выше quota | `tools\test_loot_policy.ps1`, затем серия полевых логов |
| Точный loot-marker | Обычная красная иконка тайника PAW стоит на visual/box и исчезает при открытии | ID/координаты/contents в tooltip |
| Enemy ownership | До активации `armed`, после — section#ID каждого нашего мутанта | `ambush entity ... owned_by_rework=true` |
| Census | Стартовый снимок и новый снимок после появления raid squad | `census begin/end`, `rvm_squad_added=` |
| Редкий пул T1 | Только мусорные группы 1–4 и T1-группа 5 РВМ | Временно выставить оба rare-шанса 100 |
| Редкий пул T2 | Только группы 5 и 6 РВМ | `rare artifact queued: section=... id=...` |
| Редкий пул T3 | Только группы 6 и 7 РВМ, без группы 8 | Сверить section с `raid_artefacts_tiers_by_dop` |
| Класс и мутации | Артефакт получает штатный класс/доп. свойства РВМ | Лог `raid_artefacts randomize with tier`; осмотр в UI |
| Save до открытия box | После загрузки артефакт всё равно рандомизируется один раз | Сверить ID и отсутствие повторного reroll |
| Пустышка | Нет content/spawn, живёт до выхода | `type=empty linked=none` |
| Save/load на месте | Нет новых `create`, spots восстановлены | Счётчики до/после одинаковы |
| Fast travel на той же локации | Незакрытые zones/anchors/loot сохраняются | `transition pending`, затем `transition resolved same_level` |
| Настоящий выход | Нет оставшихся якорей/мутантов/boxes | `cleanup reason=confirmed_level_change` |
| Тайники | `scouting`: только разведка; `anomaly`: только infected; `disabled`: нигде | Проверить все три режима |
| Arrival | Его артефакты не получают кругов | ID отсутствуют в `captured` |
| Производительность | Нет заметного постоянного stutter | Обновление раз в 1000 мс |

Если игра падает до главного меню, приложите конец `xray_*.log` со строками `[Anomaly Expedition Rework]`. Если круги есть, но PAW не предлагает маршрут, приложите версию PAW и результат теста на минимальном/максимальном масштабе карты.

Для runtime-проверки откройте **Debug UI debug launcher**, не обычную консоль `~`. Используйте `rvm_rework_debug_off`, затем `rvm_rework_debug_on`: Debug UI должен подтвердить mode/effective, а круги — переключиться между обычным и техническим tooltip без изменения количества зон. Команда `rvm_rework_census` должна показать краткие `squads/stalkers/mutants` в Debug UI и не создавать/удалять население.

После spawn enemy decoy проверить каждого живого mod-owned врага отдельно: красная точка должна следовать его object ID и исчезать не позднее следующего update после смерти. Повторить debug-off/on и same-level save/load. Наличие точек на штатных `owned_by_rework=false` squad является ошибкой.

После несовпадения логического круга и изображения в полевом тесте базы изменены на `64/80/96 px`, `scale_max=2.25`, alpha `220`: на общем плане они компактнее, а на максимальном приближении на треть крупнее прежнего варианта. Особенно проверить T1 на обоих крайних zoom и нахождение linked artifact внутри нарисованной окружности с первого кадра.

Live-log: запустите `tools\watch_live_log.cmd` либо `.\tools\watch_live_log.ps1`. До первого совпадения watcher явно показывает `Waiting for matches...`; при пересоздании/обнулении файла он сообщает о повторном открытии и продолжает вывод без ожидания выхода из игры. Остановка — `Ctrl+C`.

