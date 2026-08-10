# Changelog / История версий

*Русский — сверху, English below.*

---

## Русский

### v1.5.7 — 2026-08-09

**Тапервэр работает — спасибо Crossfit Jesus за отчёт:**
- Пластиковые контейнеры снова наполняются едой: рецепты «Наполнить контейнер»
  (118 видов еды; большой — 4 порции, средний — 2, малый — 1) не пережили порт
  из B41 — восстановлены.
- Крышка больше не может исчезнуть при открытии контейнера: раньше её выдавал
  lua-скрипт (хрупко), теперь она — обычный второй результат рецепта.

### v1.5.6 — 2026-08-09

**Хотфикс по репорту Haase + русское меню строительства:**
- **Починены шахта, сбор флоры и все lua-действия**: B42.20 переписал класс
  Stats — старые `setFatigue`/`setEndurance`/`setHunger` удалены из движка,
  из-за чего добыча в шахте, сбор растений, ловля жуков, пруд и навоз падали
  с ошибкой «Object tried to call nil». Все 38 вызовов в 6 lua-файлах
  переведены на новый API `CharacterStat`. Спасибо Haase за отчёт.
- Учебники бронзового и каменного дела больше не пустые: бронза учит выплавке
  олова и бронзы, камень — карьеру, добыче камня и мраморной скульптуре.
- Русские имена для 215 ванильных построек нового меню строительства B42
  (купольные печи, горны, бревенчатые стены, черепа на столбах...) — у ванили
  42.20 эти ключи ещё не переведены, HCR закрывает пробел самостоятельно.

### v1.5.5 — 2026-08-09

**«Связная экономика» — у каждого предмета снова есть источник:**
- Полный аудит достижимости показал: при порте из B41 осознанно не переносились
  системы, которые B42 закрывает нативно (кузница, гончарка, разделка,
  животноводство) — но их ПРОДУКТЫ остались ингредиентами сотен рецептов.
  Итог на старте: 803 рецепта нельзя было скрафтить, 1 737 предметов — получить.
- **Мост к ванили B42**: слитки, стержни, листы, литейные формы, стекло, пряжа,
  шерсть, перья, молоко, компост и др. теперь принимают ванильные эквиваленты
  (300+ расширений OR-списков) — прогресс ванильной кузницы и фермы работает
  на рецепты Hydrocraft.
- **71 новый рецепт** (файл HCR_Reclamation): разделка туш и птицы по выходам
  оригинального B41 (олень, кабан, медведь, пума, 10 видов мелкой дичи, куры,
  индейки, утки, гуси — мясо, шкуры, кишки, перья); выплавка алюминия, олова,
  бронзы, свинца, магнетита и кокса; ковка листов, стержней, рукояток и колец;
  сплавление стеклянных панелей; лепка форм и табличек; разведение шелкопрядов;
  зарядка солнечного парка; ведро молока через систему жидкостей B42;
  якорение наковален, плавильни, домны и маслопресса.
- **Лут**: 450 предметов, потерявших источники (броня, спасённые материалы,
  инструменты, реагенты...), возвращены в тематические точки спавна с низкими
  весами; самоцветы и 14 пород — в шахты; 13 природных находок — в сбор флоры;
  7 табличек-исследований — в раскопки; бамбук и колокольчик — в луга.
- Учебники металлургии, гончарного дела и стеклодувства учат новым рецептам;
  все 71 имеют русский перевод.
- Итог: некрафтуемых рецептов 803 → 101, недостижимых предметов 1 737 → 138.
  Остаток — осознанный: живые животные вырезанного разведения B41 (71) и
  легаси-ёмкости «с водой» до полной миграции на жидкости B42 (задел на v1.6).

### v1.5.0 — 2026-08-08

**Система обучения рецептам работает — спасибо Haase за отчёт:**
- Книги снова учат: B42 переименовал поле `TeachedRecipes` в `LearnedRecipes`,
  из-за чего все 171 книжная строка молча игнорировалась — ни один рецепт
  нельзя было выучить (и чит-разблокировка тоже не работала). Поле переведено
  на новый формат.
- Вычищены 346 книжных ссылок на рецепты вырезанных систем (кости,
  животноводство и пр.) — треть списков вела в никуда.
- Найдены и обезврежены 366 ДУБЛЕЙ имён рецептов (наследие B41, где варианты
  «сделай из любого» были отдельными рецептами с одним именем): в B42 движок
  хранит рецепты по имени, и из 102 вариантов сока выживал один. 54 группы
  слиты в честные альтернативы «любой из», 1 441 вариант получил уникальное
  имя с уточнением в скобках — и полный русский перевод каждого.
- 17 рецептов-«сирот» (включая меховую и шёлковую одежду из v1.2.0), которых
  не учила ни одна книга, добавлены в тематические учебники.
- Итог: 3 527 уникальных рецептов, 0 битых ссылок, 0 невыучиваемых.

### v1.4.0 — 2026-08-07

**Баланс опыта (xpAward)** — крафт Hydrocraft снова прокачивает:
- Механический порт из B41 награждал почти все 2 045 рецептов плоскими 2 XP —
  на фоне ванильных 30 за сварку или плотницкое качаться крафтом HCR было
  бессмысленно. Пересчитано 1 569 наград.
- Новая шкала пропорциональна времени рецепта и откалибрована по ванильным
  медианам 42.20.2: готовка 3, сварка 30, шитьё 11, плотницкое 30–40,
  электрика 8; потолки — на ванильных p90 (эксплойтов «дешёвый крафт —
  гора опыта» нет). Для навыков без ванильных крафт-аналогов (медицина,
  фермерство, ловушки...) — скромная шкала 5–15.

### v1.3.0 — 2026-08-07

**Ревизия распределения лута** — вещи Hydrocraft больше не вытесняют ванильный лут:
- В 31 списке спавна, где доля HC-предметов доходила до 66 % (все ресторанные
  холодильники, книжные полки, стойки журналов, медицинские шкафы...), веса
  отмасштабированы до целевых ≤30 % — ванильного лута снова большинство везде.
- Починены мёртвые цели: оружие переехало из несуществующего в B42 списка
  ArmyStorageGuns в ArmyStorageAmmunition; 15 видов рыбы и морепродуктов —
  из официально пустого списка Meat к мясникам (ButcherFish, ButcherFreezer),
  раньше они не спавнились вовсе.
- Убрана двойная вставка продуктов в холодильник пекарни.

### v1.2.0 — 2026-08-07

**Полная миграция на нативные классы предметов B42:**
- Все оставшиеся 5 162 предмета переведены с легаси-формата B41 (`Type = Normal/Food/...`)
  на нативный `ItemType = base:*` (normal, food, drainable, literature, container,
  weapon, moveable, clothing, weaponpart). Карта соответствий выверена по ванильным
  скриптам 42.20.2. В моде не осталось ни одной легаси-строки `Type =`.
- Теперь каждый предмет получает свой настоящий Java-класс: еда — Food, напитки
  с алкоголем — с работающими алко-полями, литература — Literature и т.д.
  Это закрывает целый класс редких ошибок `instanceItem` (NPE на предметах
  с алкогольными свойствами) и делает поведение предметов ванильно-корректным.
- 10 предметов одежды, пропущенных в v1.1.0 (шубы, плащи, шёлк, сапоги),
  мигрированы и получили `CanBeEquipped` — теперь их можно носить.

### v1.1.0 — 2026-08-07

**Критическое исправление стабильности:**
- Вся носибельная экипировка (47 предметов: одежда, вьюки, сумки) мигрирована
  с легаси-формата B41 `Type = Clothing/Container` на нативную систему классов
  B42 (`ItemType = base:clothing` / `base:container`). Легаси-формат в B42 не
  создавал настоящий класс одежды, из-за чего гибель зомби в вещах Hydrocraft
  роняла сессию в чёрный экран (NPE в WornItems) и ломала анимации.
  Причина найдена дизассемблированием движка, исправление проверено в игре.

**Оформление:**
- Новый арт: превью, постер и иконка.
- Обновлены описания мода (mod.info и страница Мастерской, RU + EN).

### v1.0.0 — 2026-08-05

- Первый релиз в Мастерской Steam.
- 5 196 предметов, 3 620 рецептов (2 086 уникальных) — полная конвертация
  в систему `craftRecipe` B42.
- 121 схема починки, 233 модели, 5 679 текстур, 38 звуков.
- Полная русская локализация: 100 % предметов и рецептов, все 32 категории
  крафта.
- Исправления мира до релиза: инициализация неймспейсов `Recipe.*` в HCExtra,
  защита распределений лута, вычищены мёртвые ссылки эволюционирующих
  рецептов B41.

---

## English

### v1.5.7 — 2026-08-09

**Tupperware works — thanks to Crossfit Jesus for the report:**
- Plastic containers can be filled with food again: the "Fill Container"
  recipes (118 foods; large — 4 portions, medium — 2, small — 1) did not
  survive the B41 port — restored.
- The lid can no longer vanish when opening a container: it used to be
  granted by a lua script (fragile), now it is a regular second output
  of the recipe.

### v1.5.6 — 2026-08-09

**Hotfix for Haase's report + Russian build menu:**
- **Mining, flora gathering and all lua actions fixed**: B42.20 rewrote the
  Stats class — the old `setFatigue`/`setEndurance`/`setHunger` are gone from
  the engine, so mining, plant gathering, bug catching, pond and dung actions
  crashed with "Object tried to call nil". All 38 calls across 6 lua files
  migrated to the new `CharacterStat` API. Thanks to Haase for the report.
- Bronze Working and Stoneworking textbooks are no longer empty: bronze
  teaches tin and bronze smelting; stone teaches the quarry, stone mining
  and marble sculpture.
- Russian names for 215 vanilla build-menu entities of the new B42
  construction system (dome kilns, forges, log walls, skull poles...) —
  vanilla 42.20 has not translated these keys yet, HCR covers the gap
  on its own.

### v1.5.5 — 2026-08-09

**"Connected Economy" — every item has a source again:**
- A full reachability audit revealed: the B41 port deliberately skipped systems
  B42 covers natively (smithing, pottery, butchering, husbandry) — but their
  PRODUCTS remained ingredients of hundreds of recipes. Starting point: 803
  recipes uncraftable, 1,737 items unobtainable.
- **Vanilla B42 bridge**: ingots, rods, sheets, molds, glass, yarn, wool,
  feathers, milk, compost etc. now accept vanilla equivalents (300+ OR-list
  extensions) — vanilla forge and farm progression feeds Hydrocraft recipes.
- **71 new recipes** (HCR_Reclamation): carcass and bird butchering with
  original B41 yields (deer, boar, bear, cougar, 10 small game species,
  chickens, turkeys, ducks, geese — meat, hides, intestines, feathers);
  smelting of aluminum, tin, bronze, lead, magnetite and coke; forging of
  sheets, rods, cranks and rings; glass pane fusing; clay molds and tablets;
  silkworm breeding; solar park charging; milk bucket via the B42 fluid
  system; anchoring of anvils, smelter, blast furnace and oil press.
- **Loot**: 450 items that lost their sources (armor, rescued materials,
  tools, reagents...) returned to themed spawn points at low weights; gems
  and 14 rock types — into mines; 13 nature finds — into flora gathering;
  7 research tablets — into digging; bamboo and bluebell — into meadows.
- Metallurgy, pottery and glassworking textbooks teach the new recipes;
  all 71 are fully translated to Russian.
- Result: uncraftable recipes 803 → 101, unreachable items 1,737 → 138.
  The remainder is deliberate: live animals of the cut B41 husbandry (71)
  and legacy "filled with water" containers pending the full B42 fluid
  migration (groundwork for v1.6).

### v1.5.0 — 2026-08-08

**The recipe learning system works — thanks to Haase for the report:**
- Books teach again: B42 renamed `TeachedRecipes` to `LearnedRecipes`, so all
  171 book lines were silently ignored — no recipe could be learned (and the
  cheat unlock didn't work either). The field is migrated.
- Purged 346 book references to recipes of the cut systems (boneworking,
  husbandry etc.) — a third of the lists led nowhere.
- Found and defused 366 DUPLICATE recipe names (a B41 legacy where "make from
  any" variants were separate recipes sharing one name): the B42 engine stores
  recipes by name, so only one of 102 juice variants survived. 54 groups are
  merged into proper "any of" alternatives; 1,441 variants received unique
  names with a clarifier in parentheses — each with a full Russian translation.
- 17 orphan recipes (including the fur and silk clothing from v1.2.0) that no
  book taught are now placed into fitting textbooks.
- Result: 3,527 unique recipes, 0 broken references, 0 unlearnable.

### v1.4.0 — 2026-08-07

**XP balance (xpAward)** — Hydrocraft crafting levels you up again:
- The mechanical B41 port awarded a flat 2 XP for nearly all 2,045 recipes —
  next to vanilla's 30 for welding or carpentry, leveling through HCR crafting
  was pointless. 1,569 awards recalculated.
- The new scale is proportional to recipe time and calibrated against vanilla
  42.20.2 medians: cooking 3, welding 30, tailoring 11, carpentry 30-40,
  electrical 8; caps sit at vanilla p90 (no "cheap craft — huge XP" exploits).
  Skills with no vanilla crafting analogues (first aid, farming, trapping...)
  use a modest 5-15 scale.

### v1.3.0 — 2026-08-07

**Loot distribution pass** — Hydrocraft items no longer crowd out vanilla loot:
- In 31 spawn lists where the HC share reached up to 66% (every restaurant
  fridge, bookshelves, magazine racks, medical storage...), weights are scaled
  down to a target of ≤30% — vanilla loot is the majority everywhere again.
- Dead targets fixed: firearms moved from the ArmyStorageGuns list (removed in
  B42) to ArmyStorageAmmunition; 15 kinds of fish and seafood moved from the
  officially deprecated Meat list to the butchers (ButcherFish, ButcherFreezer)
  — they never spawned before.
- Removed a double food insertion into the bakery fridge.

### v1.2.0 — 2026-08-07

**Full migration to native B42 item classes:**
- All remaining 5,162 items converted from the legacy B41 format
  (`Type = Normal/Food/...`) to native `ItemType = base:*` (normal, food,
  drainable, literature, container, weapon, moveable, clothing, weaponpart).
  The mapping was verified against vanilla 42.20.2 scripts. Not a single
  legacy `Type =` line remains in the mod.
- Every item now gets its real Java class: food is Food, alcoholic drinks get
  working alcohol fields, books are Literature, and so on. This closes a whole
  class of rare `instanceItem` errors (NPEs on items with alcohol properties)
  and makes item behavior vanilla-correct.
- 10 clothing items missed in v1.1.0 (fur coats, cloaks, silk, boots) migrated
  and given `CanBeEquipped` — they are wearable now.

### v1.1.0 — 2026-08-07

**Critical stability fix:**
- All wearable gear (47 items: clothing, dog packs, bags) migrated from the
  legacy B41 `Type = Clothing/Container` format to the native B42 item class
  system (`ItemType = base:clothing` / `base:container`). The legacy format
  does not produce a real clothing class in B42, so a zombie dying in
  Hydrocraft gear crashed the session to a black screen (NPE in WornItems)
  and broke animations. Root cause found by disassembling the engine; the fix
  is verified in game.

**Presentation:**
- New artwork: preview, poster and icon.
- Refreshed mod descriptions (mod.info and Workshop page, RU + EN).

### v1.0.0 — 2026-08-05

- Initial Steam Workshop release.
- 5,196 items, 3,620 recipes (2,086 unique) — full conversion to the B42
  `craftRecipe` system.
- 121 fixing schemes, 233 models, 5,679 textures, 38 sounds.
- Full Russian localization: 100% of items and recipes, all 32 craft
  categories.
- Pre-release world fixes: `Recipe.*` namespace initialization in HCExtra,
  loot distribution guards, dead B41 evolved-recipe references removed.
