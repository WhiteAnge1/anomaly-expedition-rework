# Аудит пулов артефактов — 2026-10-20

Статус: read-only исследование фактической сборки GRA 2.5. Runtime, конфиг, баланс и установленная MO2-копия не изменялись.

## Краткий вывод

- АЭР-система текущей сборки классифицирует **223 самостоятельные секции артефактов**: 52 мусорных, 51 низкого, 55 среднего, 51 высокого облучения и 14 уникальных.
- Штатные настоящие артефакты infected-вылазок GRA Bolt выбираются не из всей этой номенклатуры, а из отдельной локальной таблицы `raid_groups_artifacts`. На трёх используемых тирах в ней суммарно только **63 уникальные секции**: 30 возможны на T1, 29 на T2, 27 на T3; списки пересекаются.
- Anomaly Expedition Rework **не меняет** этот штатный выбор настоящих артефактов. Он меняет количество, защищает позицию, отслеживает ID и добавляет поисковые области, но сохраняет выбранную GRA Bolt секцию.
- Редкая награда наших loot-зон уже использует широкую официальную классификацию `raid_artefacts_tiers_by_dop`: T1 — группы 1–5 (103 секции), T2 — 5–6 (106), T3 — 6–7 (106). Поэтому через loot-зоны вылазок уже достижимы **209 из 223** классифицированных секций. Группа 8 из 14 уникальных намеренно не включена.
- Пользовательский «Осколок грави» по названию и радиации `+7 мЗв` соответствует настоящему артефакту `af_vyve`, локализованному в сборке как **«Обломок грави»**. Это low/group-5 артефакт с классами и мутациями, но его нет ни в одном T1–T3 true-field списке. Не путать с `af_gravi` (`+12 мЗв`, medium/group 6) и расходным материалом `item_raid_art_fragment_gravi` — «Гравитационной А-Фракцией».
- Расширить настоящий anomaly-field pool технически возможно, но это **не простая правка таблицы нашего конфига**: исходная таблица GRA Bolt локальна внутри Lua. Для отдельного MO2-мода потребуется новый проверяемый hook, политика весов и полевые проверки совместно с классами/мутациями, spawn guard, rescue и save/load. Рекомендация — оставить текущий stock curated pool как `Recommended`, а опциональный `expanded_compatible` реализовать после основной стабильной версии.

## Проверенные источники

1. `GRA Bolt/gamedata/scripts/raid_anomalys.script`
   - `raid_groups_artifacts` около строки 697;
   - `spawn_artefact_in_zone` около строк 1182–1195;
   - выбор `raid_groups_artifacts[typ_zone][level_tier]` происходит непосредственно перед `alife_create_item`;
   - уровни вылазок используют T1 `y04_pole`, T2 `k01_darkscape`, T3 `l09_deadcity`.
2. `GRA Rojok Artifact System/gamedata/scripts/raid_artefacts.script`
   - `raid_artefacts_tiers_by_dop` около строки 173: восемь групп, 223 уникальные секции;
   - wrapper `raid_anomalys.spawn_artefact_in_zone` около строк 1039–1049 ставит уже созданный exact ID в `addToQueuedArtefacts`, сохраняя классы и мутации.
3. `Deanons_Artefact_Pack v1.2.4/gamedata/configs/items/settings/artefacts.ltx`
   - полная привязка секций к элементу и категориям АЭР;
   - UI-фильтры: мусорные, низкого, среднего, высокого облучения и уникальные.
4. `GRA Bolt/gamedata/scripts/raid_psi_emitter_gui.script` и `ui_st_raid_psi_emitter.xml`
   - фильтры АЭР используют `junk`, `1`, `2`, `3`, `4`;
   - русское название `4` — «Уникальные»;
   - АЭР заполняет каталог из `items/settings/artefacts.ltx`, а не по всем секциям с префиксом `af_`.
5. `Deanons_Artefact_Pack v1.2.4/gamedata/configs/plugins/spawner_blacklist.ltx`
   - подтверждённые debug-spawner exclusions: `af_gimlet`, `af_geliy`, `af_vaselisk`, `af_quest_b14_twisted`, `jup_b1_half_artifact` и их служебные варианты.
6. `GRA Bolt/gamedata/scripts/raid_simulation_lab.script`
   - уникальные секции группы 8 используются как редкие special rewards лабораторных областей; это отдельная экономика, а не обычный пул вылазки.

## Что именно означает каталог АЭР

Категории непересекающейся основной классификации:

| Внутренняя группа Rojok | Фильтр АЭР | Секций |
|---|---|---:|
| 1–4 | Мусорные | 52 |
| 5 | Низкого облучения | 51 |
| 6 | Среднего облучения | 55 |
| 7 | Высокого облучения | 51 |
| 8 | Уникальные | 14 |
| **Итого** |  | **223** |

В `artefacts.ltx` также есть шесть самостоятельных artifact-like секций вне этой классификации:

- `af_geliy`, `af_gimlet`, `af_vaselisk` — прямо занесены Deanons в `spawner_blacklist` и отсутствуют в каталоге/тирах Rojok;
- `af_quest_b14_twisted`, `jup_b1_half_artifact` — исходные story/quest-варианты, прямо занесены в `spawner_blacklist`; каталог использует отдельные варианты `af_quest_b14_twisted2` и `jup_b1_half_artifact2`;
- `af_misery_bread` — отдельный `af_base_mlr`, отсутствует и в классификации АЭР, и в `raid_artefacts_tiers_by_dop`; при неизвестном tier Rojok применил бы общий fallback. Без отдельного доказательства происхождения и категории автоматически включать его нельзя.

Absorbation-секции, `*_lead_box`, `*_af_iam`, `*_af_aac`, `*_af_aam`, базы и маркеры не являются самостоятельными world-spawn кандидатами. Автоматический сбор всех заголовков `af_*` поэтому небезопасен.

## Штатный настоящий pool GRA Bolt

`fuzz` дублирует химический список, `psy` — электрический, `mosquito` — гравитационный. Ниже показаны четыре уникальных семейства.

### T1 — Поляна (`y04_pole`)

- Хим: `af_skull_miser`, `af_kislushka`, `af_peas`, `af_serofim`, `af_zhelch`, `af_blood`, `af_soul`.
- Электро: `af_signet`, `af_ball`, `af_kogot`, `af_moh`, `af_fonar`, `af_dummy_battery`, `af_electra_sparkler`.
- Термо: `af_ear`, `af_atom`, `af_dragon_eye`, `af_fire_loop`, `af_sun`, `af_itcher`, `af_dummy_glassbeads`, `af_pin`.
- Грави: `af_repei`, `af_fountain`, `af_tapeworm`, `af_cocoon`, `af_chelust`, `af_cristall_flower`, `af_medusa`, `af_night_star`.

Итого 30 уникальных. По категориям АЭР: 20 мусорных, 7 низкого и 3 среднего облучения. Это состав объединения четырёх семейств, а не непосредственные вероятности: сначала выбирается семейство аномалии, затем равномерный список именно этого семейства.

### T2 — Тёмная Лощина (`k01_darkscape`)

- Хим: `af_blood`, `af_soul`, `af_mincer_meat`, `af_bracelet`, `af_sponge`, `af_fuzz_kolobok`.
- Электро: `af_elektron`, `af_lighthouse`, `af_dummy_battery`, `af_electra_sparkler`, `af_ring`, `af_electra_moonlight`, `af_dummy_dummy`.
- Термо: `af_sandstone`, `af_sun`, `af_bat`, `af_itcher`, `af_dummy_glassbeads`, `af_pin`, `af_eye`, `af_cristall`.
- Грави: `af_grapes`, `af_spaika`, `af_cristall_flower`, `af_medusa`, `af_night_star`, `af_lobster_eyes`, `af_vyvert`, `af_gravi`.

Итого 29 уникальных. По категориям АЭР: 7 мусорных, 9 низкого, 12 среднего и 1 высокого облучения. Единственный high — `af_lobster_eyes` в гравитационном семействе; в других T2-семействах high отсутствует.

### T3 — Мёртвый город (`l09_deadcity`)

- Хим: `af_star_phantom`, `af_mincer_meat`, `af_bracelet`, `af_sponge`, `af_fuzz_kolobok`, `af_baloon`, `af_glass`.
- Электро: `af_generator`, `af_ring`, `af_electra_moonlight`, `af_dummy_dummy`, `af_black_spray`, `af_ice`, `af_electra_flash`.
- Термо: `af_medallion`, `af_black_angel`, `af_eye`, `af_cristall`, `af_fireball`, `af_fire`.
- Грави: `af_cell`, `af_lobster_eyes`, `af_vyvert`, `af_gravi`, `af_empty`, `af_full_empty`, `af_gold_fish`.

Итого 27 уникальных. По категориям АЭР: 5 мусорных, 2 низкого, 10 среднего и 10 высокого облучения. Junk присутствует в каждом из четырёх семейств, поэтому полностью исключить мусорный результат на T3 текущий алгоритм не может.

Следствие: stock pool — ручная компактная выборка, а не правило «все категории до тира». Отдельного blacklist-прохода при выборе нет: доказуемая причина отсутствия большинства секций — их просто нет в локальной таблице `raid_groups_artifacts`.

## Как фактически выбирается true-field артефакт

Порядок в `raid_anomalys.script` двухступенчатый и зависит от уже создаваемой аномальной зоны:

1. `spawner_anomals_zones()` выбирает прямоугольник местности приблизительно пропорционально его площади и получает тип поверхности `road`, `grass`, `forest` либо `build`.
2. `get_rand_anomal_zone()` при первом обращении один раз на рейд выбирает для каждого типа поверхности вариант из `terrain_zone_anomalies` и сохраняет его в `curr_version_terranes`. Поэтому семейства зон внутри одного рейда коррелированы, а не бросаются полностью заново для каждого артефакта. Малый cumulative roll иногда заменяет основное семейство на extra-зону.
3. Префикс созданной зоны (`chem`, `electr`, `therm`, `gravi`, `mosquito`, `fuzz`, `psy`) становится `typ_zone`. `fuzz` использует химический список, `psy` — электрический, `mosquito` — гравитационный.
4. Берётся ровно `raid_groups_artifacts[typ_zone][level_tier]`.
5. Глобальный `random_key_table()` собирает все ключи списка и делает `math.random(#keys)`. Для обычного последовательного массива это **равномерный выбор одной секции внутри семейства**, без внутренних весов.
6. История предыдущих результатов не проверяется. Каждый вызов независим на уровне секции, поэтому одинаковый артефакт может выпасть несколько раз в одном рейде.

Rojok подключается уже после создания exact ID: ставит предмет в штатную очередь классов/мутаций и сохранения. Качество базовой секции не гарантирует итоговую полезность конкретного экземпляра — класс добавляет положительные свойства, а мутация может инвертировать отдельное свойство, — но это не меняет вероятность выбора самой секции.

### Точные вероятности внутри семейства

В терминах пользовательской радиационной градации Rojok: low — примерно `+7 мЗв`, medium — `+12 мЗв`, high — `+23 мЗв`; junk — без штатной радиационной нагрузки, unique — отдельная группа 8.

| Tier | Семейство зоны | Junk | Low | Medium | High | Unique |
|---|---|---:|---:|---:|---:|---:|
| T1 | chem/fuzz | 71,43% | 14,29% | 14,29% | 0% | 0% |
| T1 | electr/psy | 71,43% | 28,57% | 0% | 0% | 0% |
| T1 | therm | 62,50% | 25,00% | 12,50% | 0% | 0% |
| T1 | gravi/mosquito | 62,50% | 25,00% | 12,50% | 0% | 0% |
| T2 | chem/fuzz | 0% | 50,00% | 50,00% | 0% | 0% |
| T2 | electr/psy | 28,57% | 28,57% | 42,86% | 0% | 0% |
| T2 | therm | 37,50% | 25,00% | 37,50% | 0% | 0% |
| T2 | gravi/mosquito | 25,00% | 25,00% | 37,50% | 12,50% | 0% |
| T3 | chem/fuzz | 14,29% | 28,57% | 28,57% | 28,57% | 0% |
| T3 | electr/psy | 14,29% | 0% | 42,86% | 42,86% | 0% |
| T3 | therm | 33,33% | 0% | 33,33% | 33,33% | 0% |
| T3 | gravi/mosquito | 14,29% | 0% | 42,86% | 42,86% | 0% |

Отсюда пользовательские наблюдения подтверждаются непосредственно таблицами:

- на Поляне high (`+23` по пользовательской градации) и unique невозможны: их вероятность строго 0%;
- в Мёртвом городе junk возможен при любом семействе зоны: условная вероятность составляет от 14,29% до 33,33%;
- unique на всех трёх используемых тирах имеет вероятность 0%; `af_death_lamp` добавлен лишь в неиспользуемые здесь tier-4 списки.

Единой абсолютно точной map-wide вероятности только из статических таблиц нет. На неё влияют случайно и один раз выбранные варианты поверхности, порядок `pairs()` при cumulative extra-roll, а также отказы реального level/nav размещения. Если усреднить варианты поверхности и площади прямоугольников исходного скрипта **до runtime-отказов размещения**, получается полезная аналитическая оценка, но не полевая гарантия:

| Локация | Junk | Low | Medium | High | Unique |
|---|---:|---:|---:|---:|---:|
| T1 Поляна | ≈67,35% | ≈24,20% | ≈8,45% | 0% | 0% |
| T2 Тёмная Лощина | ≈19,55% | ≈32,84% | ≈42,20% | ≈5,41% | 0% |
| T3 Мёртвый город | ≈16,72% | ≈6,98% | ≈38,15% | ≈38,15% | 0% |

Таким образом, даже номинальный T3 в среднем отдаёт junk примерно в одном случае из шести, а T2 high зависит только от попадания в гравитационное семейство и потому остаётся редким.

### Какие полезные свойства вообще представлены

По `dop_parameters` секций текущих списков:

- T1 уже содержит переносимый вес, восстановление здоровья/выносливости/кровотечения и защиты от радиации, огня, химии, электричества и взрыва;
- T2 содержит тот же набор и дополнительно `fire_wound_immunity`;
- T3 содержит всё перечисленное и дополнительно `telepatic_immunity`.

Это лишь множество доступных типов эффекта, не их сила и не вероятность: алгоритм не выбирает «полезное свойство», а равномерно выбирает секцию из семейного списка.

## Широкий пул loot-зон Anomaly Expedition Rework

Rare slot независим от обычного наполнения: `rare_slot_chance=4%`, затем `rare_artifact_chance=70%`. Итоговая вероятность артефакта для одного созданного loot-контейнера — 2,8% при текущем конфиге.

| Вылазка | Группы Rojok | Пул | Секций |
|---|---|---|---:|
| T1 Поляна | 1–4 + 5 | все мусорные + низкое облучение | 103 |
| T2 Лощина | 5 + 6 | низкое + среднее облучение | 106 |
| T3 Мёртвый город | 6 + 7 | среднее + высокое облучение | 106 |

Объединение — группы 1–7, то есть 209 секций. Перед выбором код проверяет `ini_sys:section_exist`, удаляет повторы, а после создания вызывает штатную `raid_artefacts.addToQueuedArtefacts`. Поэтому редкая награда получает обычный случайный класс/мутации и переживает save/load через штатную очередь Rojok.

## Что исключено из настоящих anomaly fields

Из 223 классифицированных секций 160 не входят в T1–T3 true-field union (63 входят). Для групп 1–7 это не признак технической несовместимости: 146 таких секций уже допускаются нашим rare-loot путём. Причина исключения из настоящих полей одна и доказуема — исходная curated-таблица GRA Bolt их не перечисляет.

<details>
<summary>Полный список исключённых из true fields по группам АЭР</summary>

### Мусорные, группа 1 — 6

`af_ameba_sli`, `af_ameba_slu`, `af_dummy_glassbeads3`, `af_dummy_spri`, `af_electra_spar`, `af_vedsleza3`.

### Мусорные, группа 2 — 4

`af_itching_low`, `af_med`, `af_raibloko3`, `af_sverlo`.

### Мусорные, группа 3 — 7

`af_black`, `af_itching1`, `af_joker`, `af_ledenec`, `af_midi`, `af_nigh_sta`, `amk_ice_s`.

### Мусорные, группа 4 — 4

`af_arhara_globus`, `af_crist_flower`, `af_dummy_glassbe`, `af_soul2`.

### Низкого облучения, группа 5 — 42

`af_absorbent`, `af_ameba_slime`, `af_armor_1`, `af_armor_2`, `af_armor_3`, `af_armor_4`, `af_babka_1`, `af_blood3`, `af_brain`, `af_crystal_blood`, `af_crystal_generator`, `af_drops`, `af_dummy_battery3`, `af_dummy_dummy2`, `af_dummy_pellicle`, `af_electra_fla`, `af_electra_flash2`, `af_electra_flash3`, `af_eye3`, `af_fire3`, `af_fire_ba`, `af_fireball3`, `af_glass3`, `af_gubka3`, `af_ice3`, `af_indeikam3`, `af_klaksa`, `af_mahovik`, `af_mayatnik`, `af_mincer_meat2`, `af_night_star2`, `af_oblivion3`, `af_oreh`, `af_pendulum`, `af_raibloko`, `af_rusty_thorn`, `af_simbion`, `af_vereteno`, `af_vyve`, `af_vyvert2`, `af_water_flower`, `af_wish`.

### Среднего облучения, группа 6 — 42

`af_ameba_mi`, `af_ameba_slug`, `af_babka_2`, `af_baloon3`, `af_bloo`, `af_blood2`, `af_chertyaico`, `af_cristal_drops`, `af_cristall2`, `af_cristall3`, `af_cristall_flower2`, `af_cristall_flower3`, `af_crystal_glassbeads`, `af_crystal_gravi`, `af_crystal_ice`, `af_dik_1`, `af_dik_2`, `af_dik_3`, `af_dik_4`, `af_dummy_battery_red`, `af_dummy_spring`, `af_electra_moon`, `af_electra_sparkler2`, `af_fuzz_kolobok3`, `af_gravi2`, `af_kashtan`, `af_kol_4`, `af_lifekam3`, `af_mayatnik3`, `af_mincer_me`, `af_padshi_angel`, `af_pudd_1`, `af_pudd_2`, `af_pudd_3`, `af_pudd_4`, `af_pulsar`, `af_rusty_kristall`, `af_seaej`, `af_swivel`, `af_vedsleza`, `af_water_flower1`, `af_zelonka`.

### Высокого облучения, группа 7 — 41

`af_ameba_mica`, `af_babka_3`, `af_best_compass`, `af_blood_green`, `af_clear_sky`, `af_crystal_oko`, `af_crystal_vyvert`, `af_dark_soul`, `af_deformer`, `af_dummy_dummy3`, `af_dummy_glassbeads2`, `af_dummy_pellicle_red`, `af_dummy_spring_red`, `af_electra_moonlight2`, `af_electra_sparkler3`, `af_electro_crystal_thorn`, `af_fireball2`, `af_fuzz_kolobok2`, `af_gold_fish2`, `af_life_heart`, `af_lifekam`, `af_magnito`, `af_medusa_green`, `af_microb`, `af_morf`, `af_oasis_heart2`, `af_propeller`, `af_prujina`, `af_rusty_sea_urchin`, `af_skripka`, `af_slizen`, `af_spirit_1`, `af_spirit_2`, `af_spirit_3`, `af_spirit_4`, `af_volchok`, `af_vyvert3`, `af_vyvert_green`, `af_water_flower2`, `amk_yoyo`, `jup_b1_half_artifact2`.

### Уникальные, группа 8 — 14

`amk_snezhok`, `af_bumerang`, `af_compass`, `af_oblivion`, `af_pero`, `af_poipruz`, `af_monolith`, `af_caterpillar`, `af_oko`, `af_karusel`, `af_oasis_heart`, `af_part_monolit`, `af_quest_b14_twisted2`, `af_death_lamp`.

</details>

### Почему группа 8 требует отдельного решения

Эти 14 секций не входят и в rare-loot пул. Они классифицированы Rojok как максимальная группа 8 (`mult=0.29`), UI АЭР называет их «Уникальные», а GRA выдаёт большинство из них как special rewards тяжёлых областей лаборатории. `af_oasis_heart` дополнительно имеет отдельный scripted world spawn/cleanup. `af_death_lamp` присутствует только в неиспользуемом sortie tier 4 исходной таблицы. Поэтому массовое добавление группы 8 изменило бы ценность специальных источников; это не техническая «починка пропущенного списка».

Названия с `quest` не означают автоматически поломку квеста: например, классифицированный `af_quest_b14_twisted2` является отдельной Rojok/Deanons-секцией и используется в special rewards. Опасен именно исходный `af_quest_b14_twisted`, который находится вне каталога и в `spawner_blacklist`.

## «Обломок грави», «Грави» и А-Фракция — три разных предмета

Исправленная идентификация пользовательского примера:

| Предмет | Section | Radiation в конфиге | Категория Rojok | Статус в вылазках |
|---|---|---:|---|---|
| **«Обломок грави»** (назван пользователем «Осколком грави») | `af_vyve` | `0.00013`, отображаемые `+7 мЗв` | low, группа 5 | отсутствует во всех T1–T3 true fields; доступен в rare-loot T1/T2 |
| **«Грави»** | `af_gravi` | `0.00025`, отображаемые `+12 мЗв` | medium, группа 6 | входит в гравитационные true-field пулы T2 и T3; доступен в rare-loot T2/T3 |
| **«Гравитационная А-Фракция»** | `item_raid_art_fragment_gravi` | неприменимо | не артефакт (`tch_junk`, `kind=i_misc`) | материал АЭР-разборки; уже входит в обычный loot всех тиров |

`af_vyve` наследует `af_base`, имеет `tier=1`, `radiation_restore_speed=0.00013` и `dop_parameters=additional_inventory_weight`; после создания штатно получает класс/мутации Rojok. Именно это настоящий носимый артефакт из пользовательского примера. Его отсутствие в true fields вызвано только тем, что `raid_groups_artifacts` его не перечисляет, а не blacklist или технической несовместимостью.

А-Фракция — отдельная мелкодисперсная субстанция. Интерфейс АЭР выдаёт `item_raid_art_fragment_<element>` при разборке; Anomaly Expedition Rework также включает все четыре А-Фракции в `loot_ordinary` и `loot_fragments` пачками 1–3 / 2–5 / 3–7 по тирам. Классы и мутации к ней неприменимы, и добавлять её в anomaly artifact pool нельзя.

## Оценка расширенного true-field профиля

### Безопасная граница состава

Для первого опционального профиля разумна только классифицированная часть групп 1–7:

- T1: мусорные группы 1–4 + низкое облучение 5;
- T2: низкое 5 + среднее 6;
- T3: среднее 6 + высокое 7;
- всегда сохранять соответствие типу аномалии: gravi/mosquito → gravi, electr/psy → electro, chem/fuzz → chem, therm → thermo;
- группа 8, шесть неклассифицированных секций, контейнерные формы, absorbation/base/marker-секции — вне профиля.

Это даёт широкое разнообразие без автоматического вторжения в special/quest economy. Повторы одной секции в разных полях следует оставить разрешёнными, как в stock; нужен лишь dedupe при построении таблицы, а не уникальность дропа на рейд.

### Почему это не одна строка конфига

`raid_groups_artifacts` объявлена `local` в `raid_anomalys.script`. Отдельный MO2-мод не может переопределить её LTX-файлом или обычным global assignment. Возможны только два аккуратных варианта:

1. найти и строго проверить именованный upvalue исходной функции, временно подменить exact tier/family list на время одного вызова и безусловно восстановить его при success/error;
2. расширить уже существующий узкий environment-intercept spawn guard так, чтобы он заменял только аргумент `section` у exact `alife_create_item` вызова после собственного выбора.

Оба варианта затрагивают хрупкую Lua/X-Ray цепочку `GRA Bolt → Rojok wrapper → AER wrapper`. Второй не должен перехватывать другие `alife_create_item`; первый зависит от upvalue-структуры фактической версии. Простое редактирование исходного `GRA Bolt` запрещено требованиями проекта.

### Политика и конфиг

Предлагаемая архитектура:

- `artifact_pool_profile = stock` — Recommended/default, полностью сохраняет текущий GRA Bolt pool;
- `artifact_pool_profile = expanded_compatible` — отдельная экспертная опция;
- таблицы брать из фактического `items/settings/artefacts.ltx` по элементу и группе, проверять `ini_sys:section_exist`, отсутствие blacklist/технических суффиксов и exact ожидаемую структуру;
- категории выбирать отдельным weighted roll, затем равномерно внутри категории. Иначе большой список автоматически и непрозрачно меняет экономику;
- при любой несовместимости структуры — fail-closed возврат к stock с одной диагностической ошибкой;
- не связывать профиль с количеством артефактов: count policy и section policy должны оставаться независимыми.

Если понадобится FOMOD, он должен лишь выбрать стартовое значение `stock`/`expanded_compatible`; runtime-конфиг остаётся источником истины. Recommended — `stock`.

### Необходимые классы изменений

1. Boundary/parser для фактической классификации и element/tier mapping.
2. Строгий hook выбора секции с restoration/reentrancy guards.
3. Конфиг профиля и category weights.
4. Диагностика выбранного family/category/section и stock fallback.
5. Статические проверки blacklist, секций, дубликатов и tier leakage.
6. Исполняемые Lua 5.1/LuaJIT тесты wrapper-chain на success/error/repeated callback.
7. Полевые T1/T2/T3 тесты: тип аномалии, секция, класс/мутации, save/load, cleanup, spawn guard и rescue.

Это умеренная новая подсистема, а не косметическая правка. Совмещать её первую полевую проверку с текущей обязательной выборкой `af_night_star` нежелательно: изменение пула резко снижает вероятность нужной Night Star и смешивает две независимые причины ошибок.

## Решение для текущей альфы

- Ничего не менять до закрытия текущей rescue-приёмки.
- Считать широкий редкий пул loot-зон уже реализованным и соответствующим исходному требованию «все мусорные+T1 / T1+T2 / T2+T3».
- После основной стабильной версии отдельно решить, нужен ли игрокам расширенный pool именно **настоящих anomaly fields**.
- Если реализовывать: stock оставить Recommended, `expanded_compatible` сделать opt-in; уникальные группы 8 не включать в первый вариант.
- Нерешённую design/balance задачу вести в [GitHub issue #4](https://github.com/WhiteAnge1/anomaly-expedition-rework/issues/4); точные веса и allowlist пока не утверждены.
