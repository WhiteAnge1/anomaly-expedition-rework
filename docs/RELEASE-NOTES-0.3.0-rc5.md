# Anomaly Expedition Rework 0.3.0-rc5

`0.3.0-rc5` — расширенный диагностический prerelease. Он не исправляет и не перемещает мутантов: задача версии — отличить неправильную исходную точку от последующего движения X-Ray simulation/AI и от save/load-перехода.

## Что добавлено относительно RC4

- accepted spawn request: position, level vertex и расстояния до actor, сохранённого старта и anchor;
- request→server/online delta для каждого owned member;
- фактические server position/vertices самого squad;
- member/squad smart, current target, scripted target, current action и respawn point;
- timeline создания: `creation` и ровно по одному снимку через `1/5/15/30 с`;
- timeline загрузки: `load_restore`, первый update `0 с`, затем `5/15/30 с`;
- отдельный аудит T1/T3 start и обоих режимов T2 в `docs/AUDIT-2026-10-23-SQUAD-SPAWN-TIMING.md`.

Diagnostic block остаётся read-only и fail-closed. В нём нет NPC create/release, teleport, `set_position` или position/vertex assignment. Баланс не менялся; Darkscape `2/3/4 = 33/34/33` сохранён.

## Установка

1. Скачать ZIP из GitHub Release и установить новой отдельной записью MO2.
2. Не объединять с локально пропатченной `rc4` или dev-копией; старую запись отключить.
3. Оставить имя `[Геймплей] Anomaly Expedition Rework by White_Angel v0.3.0-rc5`.
4. Поставить мод выше GRA Bolt, Arrival и PAW и полностью перезапустить игру.

## Минимальный тест

1. Запустить игру **без `-dbg`**: RC5 `squad_load_diag` пишет release-level строки самостоятельно, а глобальный `-dbg` может включить чужие debug-пути.
2. Оставить AER `debug_mode = off`; включить только exact enemy markers.
3. Новая infected-вылазка в Darkscape, `spawn_timing = start`/immediate; forced enemy допустим только для воспроизводимости.
4. Не двигать actor первые 30 секунд. Сделать скриншоты на первом доступном кадре и через `1/5/15/30 с`.
5. Возле одного squad выполнить save/load без MCM Apply; скриншоты сразу и через `5/15/30 с`.
6. Выйти обычным способом и сохранить полный `xray_maksi.log` или watcher session.

Интерпретация: delta уже на `creation` указывает на create/setup callback; появление delta на `creation_followup_*` — на post-create simulation/AI; первая delta только на `load_restore`/`load_first_update_0s` — на load/offline-online стадию.

