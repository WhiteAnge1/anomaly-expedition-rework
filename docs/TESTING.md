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
| Подбор NPC | При `remove_on_npc_pickup=false` область остаётся, но provenance становится terminal `owned`; callback не зависит от флага удаления | `artifact lineage ownership ... source=npc_pickup_exact_id/recreated_id`; старый ID больше не возвращается в observing после load |
| NPC → труп/обмен → actor | Новый ID сохраняется в lineage/lookup и закрывает исходную область у actor; replacement допустим только для единственного пропавшего кандидата той же секции | `current=<new_id>`, owner NPC, затем `actor_pickup`/`actor_pickup_recreated_id`; неоднозначность пишет `fail_closed=true` и не связывает зоны |
| Диагностика артефакта | Server/online existence, parent chain, позиции, `anchor_dxz/dy`, ближайшая vertex | Периодический debug-log и `rvm_rework_census` |
| Provenance save/load | По одному schema-2 record на captured ID; schema 1 мигрирует causal priority; повторный callback/load не дублирует; старый save без field center становится `disabled` | `captured/load_restore`; `primary_reason=...`; первый post-load snapshot содержит `action_deferred=true` |
| Origin observe-only | Near-origin без mismatch не срабатывает; строгий mismatch требует field distance, bad vertex, no owner и static target | `first_suspect`, затем `confirmed reason=origin_mismatch ... action=none` |
| Underground debounce | Не раньше 3 последовательных samples и 2000 мс при drop≥12 м и vertex gap≥4 м/invalid; ownership запрещает кандидат | Сверить `samples`, `duration_ms`, `vertex_dy`, parent/owner |
| Rolling tether и causal priority | Эпизод после `distance > radius+5`; возврат даёт reset, устойчивый выход подтверждается не раньше 15 с; confirmed rolling не становится underground из-за склона/invalid nav | `primary_reason=rolling`; нет вторичного `confirmed reason=underground` для того же непрерывного эпизода |
| Rolling production rescue | Safe default `actions=false` только наблюдает. При `policy=held_first` + master gate первый подтверждённый rolling любого captured ID получает один настоящий rescue; exact allowlist не используется | `confirmed action=held_first` → dispatch=1/max=1 → `position_verified` → `held_attempt` → `held`; координаты стабильны, pickup даёт held_released + closed |
| Underground production rescue | Полево принят на save 11, `af_signet#6740`: только настоящий inside-radius vertical underground после 3 samples/2 s; target строится из captured field provenance, не из failed position. Rolling causal priority выше | dispatch=1/max=1 к `field_candidate/static_ray` target → checks=3 → held с 1 element; координаты стабильны 30 223 мс; pickup дал held_released + closed; rolling IDs 1407/6362 при policy off получили action=none |
| Rescue debug prototype | Только `policy=debug_teleport`; требует debug gate и exact allowlist `1407,6362` | Старые ordinary/same-frame/held сценарии остаются воспроизводимыми диагностическим порогом |
| Third-stage stabilization | Отдельный default-off gate; только после двух verified обычных dispatch и третьего rolling episode | `action_stabilization_attempt` → element inventory → same-callback `action_stabilization_released` либо unavailable/failed → dispatch=3 verification/monitor; следующий rolling даёт limit=3; предмет обязан подбираться |
| Held lifecycle | Journal содержит только собственные post-teleport elements; production held бессрочный, но release обязателен при pickup/owner, gate-off, terminal/cleanup, save/transition/load recovery | Проверенный dispatch=1: скорости обнулены, 30 s без движения, `actor_pickup_callback` → `owned_without_world_shell` → closed |
| Exact artifact marker | Debug-on: зелёная иконка следует exact linked ID; user-mode: icon-only без собственного текста; при close исчезает | Debug-tooltip содержит технику, user exact-tooltip пуст; обычный tooltip круга доступен; exact `location_level=20` |
| Засада | Один полный squad. Start: `inside_clear → inside_anomaly_allowed → outside_anomaly_allowed`. Darkscape: три расширенные hidden-ступени → `inside_visible_anomaly_allowed → outside_visible_anomaly_allowed` | `coverage=golden_angle_nav_sweep`, attempts 180 на hidden при defaults, затем один success |
| Enemy debug marker | Одна красная точка только на живом `squad:commander_id()` нашего отряда; после смерти командира старая снимается и та же метка появляется на новом | `ambush marker detached/attached`; штатные RVM без точек |
| Геометрия контейнера | T1: offset≤radius/3; T2: offset≤radius/5; T3: offset≤radius/10; визуально ящик в центральной трети круга | Release `loot placement tier=... offset=... max=... divisor=...` и deterministic test; T2/T3 повторно оценить в финальном debug-off прогоне |
| Artifact center retry | Первый невозможный center даёт один ERROR; ID остаётся pending; одинаковые ошибки подавлены, debug-summary не чаще раза в 60 секунд | Не должно быть ежесекундного ERROR-спама; поздний успех создаёт обычную зону |
| Геометрия artifact-круга | T1 `0.35..0.80`; T2 `0.10..0.20`; T3 `0.06..0.12`; нормальный exact находится внутри круга на max zoom | Release `artifact placement tier=... level=... offset=... fraction=... limit=... range=...` |
| Кластеры артефактов | Все захваченные доступные артефакты получают область, даже если настоящие круги перекрываются; ложные области всё ещё разнесены | Число `captured raid artifact` совпадает с `create type=artifact`; при ошибке сохранить строку с `near_origin` и `rejects=[...]` |
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

Пользовательские exact-маркеры проверяются отдельно от debug. При `debug_mode=off` и всех `show_exact_*=false` их быть не должно. Затем включить по одному параметру: зелёная иконка только у связанного артефакта, красная только у loot-контейнера, красная squad-иконка только у живого командира `owned_by_rework`. Exact-иконка в пользовательском режиме не показывает собственного текста, но обычное описание приблизительного круга обязано оставаться доступным. После save/load нет дублей; pickup/open/death/cleanup удаляют метку.

После spawn enemy decoy сверить фактический состав с выбранным preset и убедиться, что все члены имеют один group/squad. Красная точка должна быть только на `commander_id`; после смерти командира она снимается со старого ID и переносится на нового. Убить всех: зона закрывается только после последнего члена. Повторить save/load и fast travel внутри уровня — второй squad появиться не должен. После настоящего выхода в логе должен быть один group cleanup; оставшиеся member IDs считаются ошибкой.

Круги используют базы `32/60/48 px`, `scale_min=1`, `scale_max=4.5`, alpha `220`. T1/T3 не изменены; только T2 увеличен с 40 до 60 px после полевого теста. Физическое катание измеряется классификатором; production policy `held_first` готова, но master actions по безопасному default выключен до широкого полевого прогона.

Если два зелёных exact-marker практически совпали, найти в журнале единственную строку `exact artifact marker overlap ids=... sections=... map_dxz=...; exact positions preserved`. Порог диагностики — 2 м по плоскости карты X/Z. Искусственного сдвига нет: обе метки обязаны оставаться привязанными к своим exact object ID. Отсутствие визуального badge/кластера является известным ограничением Lua map API, а отсутствие строки при реально близких открытых артефактах — ошибкой диагностики.

Live-log: сначала запустите `tools\watch_live_log.cmd` либо `.\tools\watch_live_log.ps1`, дождитесь `Waiting for X-Ray and matching lines...`, затем запускайте X-Ray. Watcher не завершается до первого обнаружения одного из реальных `AnomalyDX*`/`VerifiedDX11` процессов в игровом `bin`; MO2 и launcher не учитываются. После закрытия X-Ray он читает хвост ещё 20 секунд, сохраняет отфильтрованную сессию и `latest.log`, печатает оба полных пути и закрывается. `Ctrl+C` также запускает best-effort final drain/close. Исходная копия пишет в gitignored `test-artifacts\live-logs`, установленная — в `Документы\Codex\Anomaly Expedition Rework\test-artifacts\live-logs`; путь можно переопределить через `-OutputDirectory`.

Полевые проверки уже закрыты: cohesion подтверждён на трёх squad T2 и двух T3; forced-loot counts — T1 `1×5`, T2 `4/2/2`, T3 `3/2/3`; save/load контейнера до/после открытия и закрытие зоны подтверждены; watcher до запуска игры работает. Forced-empty после overlap-fix дал T1 `4/4+1`, T2 `8/8+2` с восстановлением 10 зон без дублей, отдельный T2 `7/8+2` только из-за доказанного world-origin ID (`invalid_vertex:60`), T3 `6/6+2`. Observe-only 15 октября подтвердил strict origin, чистые underground, rolling `radius+5/15 s`, save/load и полную NPC lineage-цепочку. `af_night_star#1407` и `af_fonar#6362` доказали causal priority rolling на склоне; `af_signet#6740` дал чистый underground внутри tether (`y 0.3 → -20.5 → -58.1`, confirmation ≈2.023 s, позднее `-77.7`). 16 октября production held полево принят на обоих путях: rolling `af_fonar#6362` и true-underground `af_signet#6740` прошли same-ID dispatch=1, три verification snapshots, post-teleport reacquire, 30 секунд неподвижности и штатный pickup/release/closed. Underground-тест отдельно подтвердил target provenance `field_candidate/static_ray`; при отключённой rolling policy IDs 1407/6362 действий не получили. Повтор underground не нужен. Перед широким включением master actions остаётся только общий multi-artifact smoke-test; пока master выключен.

