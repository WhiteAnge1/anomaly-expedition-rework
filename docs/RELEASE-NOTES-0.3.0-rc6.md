# Anomaly Expedition Rework 0.3.0-rc6 — draft

Непубличный проверочный кандидат. RC5 подтвердил: мутанты создавались в правильных точках, но затем generic SIMBOARD назначал им чужие smart terrain и offline A-Life уводил группы к ним. Save/load лишь сохранял уже испорченную позицию.

RC6 задаёт только новым owned ambush squad штатный scripted target на собственный squad ID. Это предотвращает generic target selection без телепортации, без `__lock`, без принудительного online/offline и без назначения actor или чужого smart.

Старые уже перемещённые группы не возвращаются. Darkscape gate подтвердил сохранение позиции offline, отсутствие foreign smart/target, штатный online monster AI, markers, смерть/закрытие двух зон, cleanup и save/load. Временные периодические и per-member dumps после проверки удалены; сохранена компактная release-level строка применения isolation.

Публикация всё ещё отложена до трёх естественных рейдов без debug — по одному на каждой поддерживаемой локации — на чистом post-test кандидате.
