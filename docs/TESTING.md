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
| Exact artifact marker | Debug-on: зелёная иконка следует exact linked ID; user-mode: icon-only без любого текста; при close исчезает | Debug-tooltip содержит технику, user tooltip пуст; exact `location_level=20` |
| Засада | Один полный squad. Start: `inside_clear → inside_anomaly_allowed → outside_anomaly_allowed`. Darkscape: три расширенные hidden-ступени → `inside_visible_anomaly_allowed → outside_visible_anomaly_allowed` | `coverage=golden_angle_nav_sweep`, attempts 180 на hidden при defaults, затем один success |
| Enemy debug marker | Одна красная точка только на живом `squad:commander_id()` нашего отряда; после смерти командира старая снимается и та же метка появляется на новом | `ambush marker detached/attached`; штатные RVM без точек |
| Геометрия контейнера | T1: offset≤radius/3; T2/T3: offset≤radius/4; визуально ящик в центральной трети круга | Release `loot placement tier=... offset=... max=... divisor=...` и deterministic test |
| Контейнер | Этапы medicine→valuable→ordinary→rare; cap T1/T2/T3 = 6/7/8 плюс независимый rare; ordinary всегда хотя бы 1 | `loot result ... medicine/valuable/ordinary_rolls/rare`, затем `reason=container_opened` |
| Medicine | Два последовательных броска; распределения 0/1/2: T1 9/66.5/24.5%, T2 4.84/64.74/30.42%, T3 2.25/61.625/36.125% | `tools\test_loot_policy.ps1` |
| Valuable quota | Quota 0/1/2/3: 65/31.5/3.4475/0.0525%; без повторов, кроме T3 `lead_box` | Симуляция и debug details |
| Ordinary/осколки | Повторы допустимы; осколок за бросок имеет количество T1 1..3, T2 2..5, T3 3..7 | Симуляция частоты/количества и осмотр box |
| Точный loot-marker | Красная exact-иконка стоит на visual/box и исчезает при открытии | User-mode без tooltip; ID/contents только debug |
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

Пользовательские exact-маркеры проверяются отдельно от debug. При `debug_mode=off` и всех `show_exact_*=false` их быть не должно. Затем включить по одному параметру: зелёная иконка только у связанного артефакта, красная только у loot-контейнера, красная squad-иконка только у живого командира `owned_by_rework`. Наведение в пользовательском режиме не должно показывать вообще никакого текста; перекрывающий круг той же категории также без tooltip. После save/load нет дублей; pickup/open/death/cleanup удаляют метку.

После spawn enemy decoy сверить фактический состав с выбранным preset и убедиться, что все члены имеют один group/squad. Красная точка должна быть только на `commander_id`; после смерти командира она снимается со старого ID и переносится на нового. Убить всех: зона закрывается только после последнего члена. Повторить save/load и fast travel внутри уровня — второй squad появиться не должен. После настоящего выхода в логе должен быть один group cleanup; оставшиеся member IDs считаются ошибкой.

Круги используют базы `32/60/48 px`, `scale_min=1`, `scale_max=4.5`, alpha `220`. T1/T3 не изменены; только T2 увеличен с 40 до 60 px после полевого теста. Физическое катание артефактов остаётся отдельной проблемой будущего rescue.

Если два зелёных exact-marker практически совпали, найти в журнале единственную строку `exact artifact marker overlap ids=... sections=... map_dxz=...; exact positions preserved`. Порог диагностики — 2 м по плоскости карты X/Z. Искусственного сдвига нет: обе метки обязаны оставаться привязанными к своим exact object ID. Отсутствие визуального badge/кластера является известным ограничением Lua map API, а отсутствие строки при реально близких открытых артефактах — ошибкой диагностики.

Live-log: сначала запустите `tools\watch_live_log.cmd` либо `.\tools\watch_live_log.ps1`, дождитесь `Waiting for matches...`, затем запускайте X-Ray. Поздний запуск во время уже работающей игры не поддерживается. Остановка — `Ctrl+C`.

Полевые проверки уже закрыты: cohesion подтверждён на трёх squad T2 и двух T3; forced-loot counts — T1 `1×5`, T2 `4/2/2`, T3 `3/2/3`; save/load контейнера до/после открытия и закрытие зоны подтверждены; watcher до запуска игры работает. Финальные normal-player рейды с debug off и `show_exact_*` отложены до artifact rescue и последующей балансировки.

