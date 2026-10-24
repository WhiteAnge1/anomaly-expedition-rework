# План после публичного RC7

Текущее состояние: `v0.3.0-rc7` принят к публикации 24 октября 2026 года. Natural T1/T2/T3, schema-9 artifact lifecycle, enemy squad isolation, PAW anchor lifecycle, save/load, FOMOD и clean MO2 install прошли обязательные gates.

## Выполнено в RC7

- переменное количество настоящих артефактов и weighted-пул всех поддерживаемых семейств/качеств;
- сохранение штатных классов и мутаций Rojok;
- ложные enemy/loot/empty области, настоящие squad и tier-dependent loot;
- schema-9 proactive hold и fail-closed provenance;
- пользовательские exact-маркеры, debug UI, census и live watcher;
- scripted self-target для owned ambush squad без `__lock`;
- AER-owned anchors и восстановление открытой зоны после PAW cleanup без повторного spawn;
- сохранения, same-level reload/travel и подтверждённая очистка при настоящем выходе;
- воспроизводимый FOMOD ZIP, SHA-256, публичная документация, лицензия и attribution.

## После RC7

1. Собирать отдельные воспроизводимые отчёты по открытым issues #3 и #5; не смешивать их с исправленным PAW anchor defect #1.
2. Добавить регулируемые размеры приблизительных зон как будущую функцию именно AER. Настройки должны иметь безопасные tier/level defaults, MCM-валидацию, snapshot на начало вылазки и тесты масштаба PDA; существующие значения `32/60/48 px` остаются baseline.
3. Продолжать балансировать counts, радиусы, decoy weights и loot только через версионируемые профили с deterministic regression.
4. При изменении runtime сохранять совместимость RC7 saves, fail-closed поведение и лимит X-Ray main chunk.
5. Публиковать следующую версию только после clean install/update, full suite, field gate затронутой механики и проверки скачанных release assets.

Google Drive mirror и Discord-материалы не входят в GitHub RC7 build и готовятся отдельно с тем же проверенным SHA-256.
