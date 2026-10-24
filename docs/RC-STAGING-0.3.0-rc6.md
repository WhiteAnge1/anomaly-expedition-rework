# RC staging 0.3.0-rc6

`rc6` — непубличный кандидат минимального исправления подтверждённого ухода owned ambush squad к generic SIMBOARD smart.

## Изменение

- новый squad принимается только без smart/assigned/current/scripted target;
- после создания получает сериализуемый scripted self-target;
- self-target обходит generic target selection, но не блокирует штатный online status;
- policy восстанавливается на load, actor first update и ранних squad callbacks;
- foreign и уже назначенные старые squad не очищаются и не перемещаются;
- RC5 timeline временно сохранён для сравнительного прогона.

## Gate перед публикацией

1. Без `-dbg`; AER `debug_mode=off`, exact enemy markers on.
2. Новая infected Darkscape, принудительный `start/immediate`, actor неподвижен 30 секунд.
3. В логе ожидается `enemy isolation applied ... scripted_target=self ... online_policy=unchanged position_write=false`.
4. RC5 timeline должен показывать squad/member у request, `scripted_target=<squad_id>`, без foreign smart/target.
5. Подойти к зоне: monsters обязаны нормально перейти online, двигаться и атаковать actor локальным AI.
6. Убить группу: exact marker исчезает, зона закрывается, cleanup не оставляет orphan.
7. Для второй группы сделать save/load и повторить пункты 4–6.

GitHub release/tag не создавать до результата этого прогона.
