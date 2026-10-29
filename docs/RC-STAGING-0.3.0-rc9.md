# RC staging 0.3.0-rc9

`rc9` — подготовленный pre-release candidate с AER-contained compatibility guard для PAW stale artifact screen coordinates.

## Принятые доказательства

- тестовый runtime соответствовал commit `c5076176e58dfea3c34df1c56ec816f1bc3b4157` по SHA-256;
- исходная exact-toggle/route/persistent-pin последовательность завершилась без `tasks_placeable_waypoints.script:4430 / se_obj nil`;
- pickup без PAW и два дополнительных pickup с route/pin прошли;
- финальный лог содержит два `artifact proactive release`, два `zone closed` и безопасный rate-limited guard для IDs `30407`/`30405`;
- AER сохранил PAW route/pin и не удалял PAW map spot;
- SHA-256 принятого полного лога: `F8BCF192D362013B232536BB7A33090BEB2AF2A8D78B157BCC1A4BCC58CF04A5`.

Один отдельный нативный `0xc0000005` (offset `0x6585a7`) не повторился после полного перезапуска и не блокирует RC9 без воспроизводимости.

## Артефакты кандидата

- ZIP: `dist/Anomaly-Expedition-Rework-0.3.0-rc9.zip`
- sidecar: `dist/Anomaly-Expedition-Rework-0.3.0-rc9.zip.sha256`
- размер ZIP: `94078` байт
- ожидаемый SHA-256: `43A13A8A2DF36C298F4B98C6A84C561AAB7F7B55AF33C36AB737E85B0633C641`
- FOMOD version: `0.3.0-rc9`
- предлагаемое имя MO2: `[Геймплей] A_Exp_R by White_Angel v0.3`

## Порядок независимой публикации

1. Агент 0 независимо сверяет ZIP, sidecar, manifest, version metadata и полный archive suite.
2. Только после этой проверки создаются annotated tag `v0.3.0-rc9` и GitHub pre-release.
3. Опубликованные GitHub assets скачиваются обратно и сверяются с подготовленным SHA-256.
4. Тот же неизменный ZIP копируется в Google Drive; для Discord используется подтверждённый hash и пользовательское описание из release notes.

На этапе staging установленная MO2-копия, публичный tag/Release и Google Drive не изменяются.
