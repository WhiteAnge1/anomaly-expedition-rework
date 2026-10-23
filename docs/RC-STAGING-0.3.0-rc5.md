# RC staging 0.3.0-rc5

`rc5` расширяет read-only squad diagnostics из `rc4`, чтобы один полевой прогон различил три фазы: создание в принятой safe-точке, раннее simulation/AI движение и смещение на save/load.

## Границы изменения

- игровая логика spawn, AI, save/load и marker lifecycle не меняется;
- reposition, teleport и position/vertex writes для squad отсутствуют;
- сохраняется принятая spawn position/lvid и рассчитанные расстояния до actor/start/anchor;
- creation timeline: `0/1/5/15/30 с`;
- load timeline: `load_restore`, first update `0 с`, затем `5/15/30 с`;
- лог содержит squad/member server+online positions/vertices, request delta, saved delta, smart/target/scripted target/action/respawn point;
- каждая строка содержит `owned_by_rework=true` и `position_write=false`;
- Darkscape false-zone defaults остаются `2/3/4 = 33/34/33`.

## Release gates

- Lua 5.1, LuaJIT 2.0 и 2.1 выполняют оба timeline с точным rate limit;
- policy запрещает create/release/teleport/set_position и object position/vertex assignment внутри diagnostic block;
- X-Ray main chunk остаётся в доказанном пределе `198/198`;
- Windows PowerShell 5.1 full suite, MCM, кодировки, FOMOD, geometry и loot policy проходят;
- две чистые сборки одного HEAD побайтово совпадают;
- распакованный ZIP проходит release verification;
- GitHub release — prerelease, `rc4` помечается superseded;
- установленная MO2-копия после публикации не изменяется: пользователь переустанавливает ZIP самостоятельно.

