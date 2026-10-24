# RC6 squad isolation field test — 2026-10-24

## Результат

Проверочный gate scripted self-target на infected Darkscape пройден. Два owned ambush squad остались у своих точек создания в offline A-Life, не получили foreign smart/target, штатно перешли online при приближении игрока, сражались локальным monster AI, закрыли зоны после смерти всех членов и не оставили orphan при обычном выходе. Один из отрядов прошёл save/load.

## Подтверждённые события

- squad `39429`: request `(0,2.8,-373.1)`, creation delta `0`, `scripted_target=39429`, smart отсутствует;
- squad `39433`: request `(94.5,-1.8,-179.2)`, creation delta `0`, `scripted_target=39433`, smart отсутствует;
- контрольные точки creation `0/1/5/15/30 с` не показали изменения позиции или назначения smart;
- после первой загрузки session `135021` сохранённые позиции восстановлены с delta `0`, smart отсутствует, self-target сохранён;
- после второй загрузки session `495501` load delta снова `0`; последующее перемещение произошло уже рядом с игроком у online monster AI, при этом smart всё время отсутствовал, self-target сохранялся;
- обе enemy-зоны закрылись после уничтожения групп; exact markers исчезли;
- artifact-зона закрылась обычным pickup;
- настоящий выход завершился `cleanup reason=confirmed_level_change zones=9 closed=3 artifact=7 enemy=2 loot=0 empty=0`;
- AER `ERROR`/`FATAL` в проверяемой цепочке отсутствуют.

Сообщения `task_placeable_waypoint` после закрытия enemy-зон и ошибка `uni_anim_detectors` принадлежат другим компонентам сборки и не входят в AER prefix.

## Визуальная проверка

Шесть кадров карты подтверждают жизненный цикл: сначала две красные exact enemy-метки остаются в южных областях Darkscape при игроке далеко на севере, затем появляются рядом с локальным боем и исчезают после уничтожения групп. Один кадр является точным дубликатом другого; это не считается отдельным наблюдением.

## Локальные исходники доказательств

Сырые файлы намеренно не входят в Git и релизный архив: они содержат полный журнал локальной сборки и временные изображения.

- watcher: `test-artifacts/live-logs/aer-live-20261024-184005-098-716.log`, `135983` bytes, SHA-256 `9220DD681511DCAC8C4E89D6FAC4806A67BE46EE0A31D0B724B565D1256AD305`;
- полный `xray_maksi.log`: `1428840` bytes, SHA-256 `0933A760737168B264A1C0B173F65683DB0B645BC9E34AA1DCEB0E8672AE343F`;
- уникальные screenshot SHA-256: `B8C4DA3DBCCB0ADC7B088F4A6A1BAE255C56C82306C34CDBEE097A0C702A63CA`, `A2F3ADCC28DF2726D22A6B572B7D81BD2E07F55145E3F26E7379DE2EF62B5969`, `2A905E0663FB92A4F2DB1B44C0E3B48587F2654840FD0574C65249B471008C75`, `44F7F6BB702C804A59BF9D3D81B4351E508AE4D8923809D3F1AD0AF01C222270`, `E56333E8BE63E998EBCAE8D0EF83C5A680652B27D93EE0324E1CC4BF49AA29F7`.

## Решение после gate

Временная подробная timeline-диагностика creation/load `0/1/5/15/30 с` и per-member dumps удаляется из чистого RC6-кандидата. Остаётся одна компактная release-level строка применения isolation с reason, squad ID, self-target, smart/assigned/current и явными `online_policy=unchanged position_write=false`, плюс ошибки fail-closed/migration skip. Публичная публикация всё ещё заблокирована до трёх естественных рейдов без debug — по одному на Поляне, в Тёмной лощине и Мёртвом городе — уже на чистом кандидате.
