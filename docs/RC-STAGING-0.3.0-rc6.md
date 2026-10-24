# RC staging 0.3.0-rc6

`rc6` — непубличный кандидат минимального исправления подтверждённого ухода owned ambush squad к generic SIMBOARD smart.

## Изменение

- новый squad принимается только без smart/assigned/current/scripted target;
- после создания получает сериализуемый scripted self-target;
- self-target обходит generic target selection, но не блокирует штатный online status;
- policy восстанавливается на load, actor first update и ранних squad callbacks;
- foreign и уже назначенные старые squad не очищаются и не перемещаются;
- временная RC5/RC6 timeline была сохранена только для сравнительного прогона и удалена после успешного gate; в чистом кандидате остаётся компактная строка применения isolation без периодических per-member dumps.

## Пройденный isolation gate

1. Без `-dbg`; AER `debug_mode=off`, exact enemy markers on.
2. Новая infected Darkscape, принудительный `start/immediate`, actor неподвижен 30 секунд.
3. В логе подтверждена `enemy isolation applied ... scripted_target=self ... online_policy=unchanged position_write=false`.
4. Временная timeline показала squad/member у request, `scripted_target=<squad_id>`, без foreign smart/target на `0/1/5/15/30 с` и после save/load.
5. Подойти к зоне: monsters обязаны нормально перейти online, двигаться и атаковать actor локальным AI.
6. Убить группу: exact marker исчезает, зона закрывается, cleanup не оставляет orphan.
7. Для второй группы сделать save/load и повторить пункты 4–6.

Все пункты пройдены; подробности в `docs/FIELD-TEST-2026-10-24-RC6-SQUAD-ISOLATION.md`.

## Оставшийся gate публикации

Установить чистый post-test RC6-кандидат и провести без debug три естественных рейда — по одному на каждой поддерживаемой локации, без forced-настроек. GitHub release/tag не создавать до их результата.
