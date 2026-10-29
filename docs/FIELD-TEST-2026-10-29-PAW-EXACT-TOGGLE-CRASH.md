# PAW stale exact-marker reference: RC8 crash and compatibility fix

Дата воспроизведения и повторной проверки: 2026-10-29. Статус: причина доказана, AER-contained исправление прошло автоматическую регрессию и полевой gate на commit `c5076176e58dfea3c34df1c56ec816f1bc3b4157`.

## Воспроизведение

1. Включить точные метки артефактов AER.
2. Поставить PAW route и persistent pin на зелёную exact-метку.
3. Завершить вылазку, не удаляя route/pin, и сохранить их между вылазками.
4. В убежище выключить exact artifact markers.
5. Начать следующую infected-вылазку и подобрать AER-linked артефакт.

RC8 воспроизводимо завершался fatal в `tasks_placeable_waypoints.script:4430`: `attempt to index local 'se_obj' (a nil value)`. Зафиксированный объект: `af_crystal_gravi`, ID `8036`. SHA-256 полного исходного журнала: `A49A46F14CB126C9091B5B1003F4917600544A957163D7C4F44B3E7DE021C3EE`.

Перед fatal AER штатно получил pickup callback, освободил proactive hold и закрыл ровно связанную область. Следующим действием PAW обновил сохранённую экранную route/pin-метку.

## Доказанная причина

Экспортированный `tasks_placeable_waypoints.get_screen_coords(id)` получает client object и ALife server object независимо. Его early return обрабатывает только отсутствие обоих. Во время pickup X-Ray допускает переходное состояние `obj ~= nil`, `se_obj == nil`; следующая ветка PAW без проверки вызывает `se_obj:clsid()`.

Это не ошибка lifecycle зоны или proactive hold AER. Exact artifact marker позволяет пользователю привязать PAW route/pin к физическому artifact ID, а сохранённая PAW-ссылка переживает смену вылазки и попадает в уязвимое окно при следующем использовании ID.

## Контракт исправления

AER не изменяет установленный файл PAW. При старте он оборачивает только экспортированный `tasks_placeable_waypoints.get_screen_coords`:

- если server object отсутствует, но client object ещё существует, wrapper возвращает `nil` на этот кадр и не вызывает PAW cleanup;
- если оба объекта отсутствуют либо server object существует, управление передаётся исходному PAW без изменения его семантики;
- дополнительный `pcall` закрывает меньший race исчезновения server object между precheck и внутренним lookup PAW;
- подавляется только точная ошибка отсутствующего local `se_obj`; любая другая ошибка повторно выбрасывается;
- установка идемпотентна и повторяется до общего hook-gate, чтобы пережить позднюю загрузку/замену экспортированной функции;
- диагностическая строка rate-limited по `ID:stage` и явно сообщает `route_pin_preserved=true`.

Wrapper не вызывает `end_waypoint_task`, `pn_del`, удаление map spot и не меняет AER exact-marker, anchor или zone lifecycle.

## Автоматическая регрессия

`tools/test_paw_screen_coords_guard.py` выполняет извлечённый runtime-блок на Lua 5.1, LuaJIT 2.0 и LuaJIT 2.1 и проверяет:

- client-only/server-missing переход без вызова исходной функции и cleanup;
- fail-closed отказ и успешный повтор установки при поздней доступности PAW;
- повторные HUD updates без спама;
- делегацию стабильного server/client состояния;
- делегацию both-missing состояния штатной PAW cleanup-ветке;
- узкий catch race внутри PAW;
- проброс несвязанной ошибки;
- идемпотентную установку wrapper.

## Результат полевого gate

- Исходная exact-toggle последовательность прошла без повторения `tasks_placeable_waypoints.script:4430 / se_obj nil`.
- Отдельный pickup без PAW и два pickup с route/pin на приблизительных областях также прошли.
- AER штатно выполнил два `artifact proactive release` и два `zone closed`, сохранив PAW route/pin; guard безопасно отложил screen coords для transient IDs `30407` и `30405`.
- Игра завершилась штатно через меню, Lua FATAL и native crash в финальном прогоне отсутствовали.
- SHA-256 финального полного лога: `F8BCF192D362013B232536BB7A33090BEB2AF2A8D78B157BCC1A4BCC58CF04A5`.
- PAW хранит собственную map-coordinate рядом с визуальной меткой; object-level привязка к маркеру AER не реализована и не требуется этим исправлением.

Один более ранний запуск завершился неповторившимся нативным `AnomalyDX11.exe` access violation `0xc0000005` (offset `0x6585a7`) без Lua fatal. После полного перезапуска он не повторился на двух контролируемых pickup и без воспроизводимости не считается блокером PAW Lua-fix.

Gate закрыт; полная матрица и обязательные автоматические проверки остаются в `docs/TESTING.md`.
