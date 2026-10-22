# RC staging 0.3.0-rc3

`rc3` исправляет блокеры чистой установки `rc2`; игровая логика вылазок не меняется.

Обязательные доказательства перед публикацией:

- русский MCM string-table совпадает с рабочими файлами установленной GRA/Anomaly: Windows-1251, без BOM, XML declaration `windows-1251`;
- английский string-table остаётся UTF-8 без BOM с declaration `utf-8`;
- все вычисляемые MCM 1.7.2 menu, submenu, control, tooltip и list-value ID существуют в RU и EN;
- тест запрещает raw fallback для `ui_mcm_menu_*` и `*_lst_*`, replacement characters и восстанавливаемый UTF-8→CP1251 mojibake;
- весь пользовательский текст FOMOD русский; `Required` остаётся только внутренним значением схемы;
- корни архива только `gamedata/` и `fomod/`, поэтому MO2 автоматически распознаёт структуру;
- две независимые сборки из чистого HEAD дают байт-в-байт одинаковый ZIP;
- распакованный ZIP проходит полный release suite с установленным Anomaly MCM 1.7.2.

MO2 и Google Drive при подготовке не изменяются. `v0.3.0-rc2` помечается superseded, `v0.3.0-rc3` публикуется только как prerelease.
