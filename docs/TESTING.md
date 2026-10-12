# Матрица игровой приёмки 0.2.1-alpha

| Проверка | Ожидаемый результат | Диагностика |
|---|---|---|
| Источник артефакта | Область только после `captured raid artifact` | Сопоставить ID в логе |
| Смещение | Артефакт внутри круга, не в центре | `center`, `radius`, `linked` |
| Внешний вид | `artifact/enemy/loot/empty` неразличимы | `debug_force_decoy_type` |
| Число ложных зон | Поляна: 1; Лощина: равномерно 2/3/4; Мёртвый город: 1/2/3 = 20/60/20 | `decoy plan ... false=...` и серия рейдов |
| Тип ложной зоны | Enemy/loot/empty = 50/25/25; при ошибке исходный тип не заменяется | `decoy result ... type_preserved=true`, при ошибке один `ERROR` |
| PAW | Контекстное меню не предлагает переход; маршрут указывает на центр-якорь | Сравнить с `center` в логе |
| Debug tooltip | Обычный текст сохранён; добавлены kind/anchor/radius/linked | Сравнить все четыре kind |
| Казуальные exact-маркеры | Каждый `show_exact_*` независимо показывает только выбранную категорию без kind/ID/координат и без включения census/лога | По очереди включить artifact/loot/enemy при `debug_mode=off`, затем все выключить |
| Подбор игроком | Одна область закрывается | `reason=actor_pickup` |
| Подбор NPC | При false область остаётся | Переключить `remove_on_npc_pickup` |
| NPC → труп → actor | Область остаётся у NPC и закрывается, когда linked ID оказывается у actor; после дистанционного подбора NPC допустим новый ID только для единственного пропавшего кандидата той же секции | `reason=actor_owns_linked_artifact` либо `actor_pickup_recreated_id`; неоднозначность не закрывает зоны |
| Диагностика артефакта | Server/online existence, parent chain, позиции, `anchor_dxz/dy`, ближайшая vertex | Периодический debug-log и `rvm_rework_census` |
| Exact artifact marker | Debug-on: зелёный `paw_stash_green` следует exact linked ID; при debug-off исчезает только если `show_exact_artifact_markers=false`; при close исчезает всегда | Debug-tooltip содержит `kind/artifact_id/section/name/position/parent`, пользовательский — ничего из этого |
| Засада | Одна зона создаёт один полный `online_offline_group` из точного preset; частичный состав откатывается. Start-каскад: `inside_clear → inside_anomaly_allowed → outside_anomaly_allowed`. Darkscape: `inside_hidden_clear → inside_hidden_anomaly_allowed → outside_hidden_anomaly_allowed → outside_visible_last_resort` | `ambush preset selected`, отдельные `cascade begin/exhausted`, затем ровно один `cascade success` и `ambush squad created` с tier/preset/squad_id/member IDs |
| Enemy debug marker | Одна красная точка только на живом `squad:commander_id()` нашего отряда; после смерти командира старая снимается и та же метка появляется на новом | `ambush marker detached/attached`; штатные RVM без точек |
| Геометрия контейнера | Ящик внутри круга, расстояние ящик→центр не выше `radius/3`, без отдельного 20-метрового cap | Debug-строка `loot center accepted ... offset=... max=...` |
| Контейнер | Этапы medicine→valuable→ordinary→rare; cap T1/T2/T3 = 6/7/8 плюс независимый rare; ordinary всегда хотя бы 1 | `loot result ... medicine/valuable/ordinary_rolls/rare`, затем `reason=container_opened` |
| Medicine | Два последовательных броска; распределения 0/1/2: T1 9/66.5/24.5%, T2 4.84/64.74/30.42%, T3 2.25/61.625/36.125% | `tools\test_loot_policy.ps1` |
| Valuable quota | Quota 0/1/2/3: 65/31.5/3.4475/0.0525%; без повторов, кроме T3 `lead_box` | Симуляция и debug details |
| Ordinary/осколки | Повторы допустимы; осколок за бросок имеет количество T1 1..3, T2 2..5, T3 3..7 | Симуляция частоты/количества и осмотр box |
| Точный loot-marker | Обычная красная иконка тайника PAW стоит на visual/box и исчезает при открытии | ID/координаты/contents в tooltip |
| Enemy ownership | До активации `armed`, после — один squad ID и точный section#ID каждого члена | `ambush squad created ... owned_by_rework=true` |
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
| Система аномалий Arrival | Её артефакты не получают кругов и точных меток | ID отсутствуют в `captured` |
| Производительность | Нет заметного постоянного stutter | Обновление раз в 1000 мс |

Если игра падает до главного меню, приложите конец `xray_*.log` со строками `[Anomaly Expedition Rework]`. Если круги есть, но PAW не предлагает маршрут, приложите версию PAW и результат теста на минимальном/максимальном масштабе карты.

Для runtime-проверки откройте **Debug UI debug launcher**, не обычную консоль `~`. Используйте `rvm_rework_debug_off`, затем `rvm_rework_debug_on`: Debug UI должен подтвердить mode/effective, а круги — переключиться между обычным и техническим tooltip без изменения количества зон. Команда `rvm_rework_census` должна показать краткие `squads/stalkers/mutants` в Debug UI и не создавать/удалять население.

Пользовательские exact-маркеры проверяются отдельно от debug. При `debug_mode=off` и всех `show_exact_*=false` их быть не должно. Затем включить по одному параметру: зелёная метка только у связанного артефакта, красная stash-метка только у loot-контейнера, красные squad-точки только у живых `owned_by_rework` врагов. Tooltip каждой такой метки должен содержать только понятное пользовательское описание без `RVM DEBUG`, `kind=`, ID, координат и состава контейнера. После save/load не должно быть дублей; подбор/открытие/смерть/cleanup удаляют соответствующую метку.

После spawn enemy decoy сверить фактический состав с выбранным preset и убедиться, что все члены имеют один group/squad. Красная точка должна быть только на `commander_id`; после смерти командира она снимается со старого ID и переносится на нового. Убить всех: зона закрывается только после последнего члена. Повторить save/load и fast travel внутри уровня — второй squad появиться не должен. После настоящего выхода в логе должен быть один group cleanup; оставшиеся member IDs считаются ошибкой.

Круги используют базы `32/40/48 px`, `scale_min=1`, `scale_max=4.5`, alpha `220`. По формуле движка это даёт `32/40/48 px` на общем плане и максимумы `144/180/216 px` вблизи. T1 уже принят пользователем на обоих крайних zoom; T2 на Тёмной лощине и T3 в Мёртвом городе всё ещё требуют отдельного визуального просмотра и не считаются окончательно принятыми. Проверить нахождение linked artifact внутри окружности с первого кадра. На южном склоне только Поляны (`y04_pole`) физика X-Ray затем может скатить артефакт далеко за исходную область (для «Души» наблюдалось dxz примерно 42→129); это не оправдание, если предмет был вне окружности уже на первом кадре.

Если два зелёных exact-marker практически совпали, найти в журнале единственную строку `exact artifact marker overlap ids=... sections=... map_dxz=...; exact positions preserved`. Порог диагностики — 2 м по плоскости карты X/Z. Искусственного сдвига нет: обе метки обязаны оставаться привязанными к своим exact object ID. Отсутствие визуального badge/кластера является известным ограничением Lua map API, а отсутствие строки при реально близких открытых артефактах — ошибкой диагностики.

Live-log: запустите `tools\watch_live_log.cmd` либо `.\tools\watch_live_log.ps1`. До первого совпадения watcher явно показывает `Waiting for matches...`; при пересоздании/обнулении файла он сообщает о повторном открытии и продолжает вывод без ожидания выхода из игры. Остановка — `Ctrl+C`.

