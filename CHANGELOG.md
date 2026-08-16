# Changelog / История версий

*Русский — сверху, English below.*

---

## Русский

### v1.5.11 — 2026-08-16

**Иконки:**
- **Четыре предмета получили обратно свои иконки**: в поле `Icon` было
  записано имя файла с расширением (`HCCloth.png` вместо `HCCloth`), и движок
  такую иконку не находил — предметы висели пустыми квадратами. Нашлось
  аудитом нового инструмента `tools/make_icon.py`.
- **Ещё пять предметов остались без иконок из-за кривых ссылок**: где-то
  разошёлся регистр, где-то опечатка в имени файла (`HCPlasticspoonkbox`),
  где-то лишняя буква. Файлы всё это время лежали на месте. Найдено тем же
  аудитом.
- **Четыре предмета получили новые иконки**: полицейская дубинка, кирка,
  звонок на стойке и обёртка от батончика. Стол для вскрытия получил
  недостающие состояния — с телом и в крови. Осталось восемь. Промпты для остальных собраны в `docs/ICON_PROMPTS.md`.
- Инструмент `tools/make_icon.py` для иконок новых предметов: перекраска
  в другой материал по палитрам, снятым с самого мода (деревянные рукояти
  при этом остаются деревянными), сборка «предмет в коробке», приведение
  сторонней картинки к палитре мода и аудит ссылок на иконки.

### v1.5.10 — 2026-08-15

**Предложения игроков — спасибо kaio.mafra за подробный список:**
- **Питательность еды**: у 96 съедобных предметов вообще не было калорий,
  углеводов, белков и жиров — съедаешь, голод падает, а система питания B42
  этого не видит. Пробелы закрыты по медиане своей же категории: сыры считаются
  как сыры, приправы как приправы, браги как браги. Больше всего досталось
  приправам (61 предмет), брагам винокурни (14) и сырам (4). Десять предметов
  оставлены без питательности сознательно: это лекарства и наркотики, у которых
  голод −1 побочен.
- **Рыболовный набор собирается с нуля** (по предложению kaio.mafra): удочка,
  две лески или бечёвки, крючок любого металла и пять любых наживок, включая
  искусственные. Раньше набор можно было только найти сломанным и починить —
  тем, кто живёт с земли, взять его было негде. Рецепту учит тот же учебник
  рыбалки.

### v1.5.9 — 2026-08-15

**Оружие, рукавицы и птицы — по репортам Asteraaaaaki и kaio.mafra:**
- **Невидимое оружие в руках** (репорт Asteraaaaaki про биту с гаечным ключом
  в мультиплеере): в B41 предмет показывался по полю `WeaponSprite`, в B42
  нужен меш, подключённый блоком `model`, и ссылка `WorldStaticModel`. Из 187
  предметов мода на старом механизме сидели все. Семь предметов, у которых
  в моде есть и меш, и текстура, подключены полностью: арбалет, длинный лук,
  узи, канцелярский нож, шест с колючей проволокой, шест с обмоткой,
  самодельная бита с триммером. Остальным 180 меш никогда не поставлялся —
  они ссылались на ванильные спрайты B41 (`Knife`, `Shovel`, `Plank`).
  Для них добавлен инструмент `tools/weapon_models.py`: при установленной игре
  он сверяет имена с ванильными моделями B42 и печатает готовые строки.
- **Кухонные рукавицы** (репорт kaio.mafra): в описании одежды модель была
  записана как `HC_OvenMitts.FBX`, а файл называется `.fbx` — на linux-сервере
  это отсутствующий файл. Убраны и маски от шляпы, случайно скопированные
  в описание перчаток. Поток ошибок при взятии рукавиц воспроизвести без игры
  не удалось: если он останется, нужен текст ошибки.
- **«Покормить птиц»** (репорт kaio.mafra): рецепт требовал рабочую
  поверхность, а птиц кормят на улице, где поверхности нет. Получался тупик —
  в помещении пункт виден, но lua отказывается («нет птиц в помещении»),
  на улице пункта нет вовсе. Добавлен `CanBeDoneFromFloor`: теперь рецепт
  доступен на земле под открытым небом.

### v1.5.8 — 2026-08-15

**Ошибки загрузки и статы — спасибо Crossfit Jesus и Haase за отчёты:**
- **Красные ошибки при старте игры** (`attempted index of non-table`
  в `Functions.lua` и `HCExtra.lua`): мод дописывал свои функции в глобальную
  таблицу `Recipe`, которой в B42 больше нет в прежнем виде. Ошибка обрывала
  выполнение файла на середине. Все 47 обращений переведены на собственный
  неймспейс мода `HCRecipe` — чужие глобальные таблицы больше не трогаем.
- **`Object tried to call nil in HCDoStats`** при рецептах «поиграть
  с игрушкой» (йо-йо, шашки, кубик Рубика — 127 рецептов): B42.20 снял
  сеттеры `setBoredomLevel` и `setUnhappynessLevel` у `BodyDamage`. Волна
  исправлений v1.5.6 шла по `getStats()` и это место не задела. Теперь скука
  и уныние меняются через тот API, который есть в движке, а если нет ни одного —
  рецепт просто не меняет статы вместо падения. Заодно заработал стресс:
  вызывающий код его передавал, а прежняя сигнатура теряла.
- **Лут: батарейки, бур и пила по дереву** снова находятся. После ревизии
  v1.3.0 веса ушли в 0.1–0.2 даже там, где предмет уместен: батарейки
  в магазинах электроники и гаражах подняты до 1–2, бур в ящиках
  с инструментом — до 0.4–0.6. Пила по дереву стояла в единственном списке
  (деревянные ящики, вес 0.4) — вес поднят до 1.5 и добавлены ящики
  с инструментом и магазины инструментов, где её и искали. Спасибо Haase
  за проверку на восьмичасовом забеге и Crossfit Jesus за сверку
  через ItemSpawner.

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

### v1.5.11 — 2026-08-16

**Icons:**
- **Four items got their icons back**: the `Icon` field held a filename with
  an extension (`HCCloth.png` instead of `HCCloth`), which the engine cannot
  resolve — those items showed as blank squares. Found by the audit in the new
  `tools/make_icon.py`.
- **Five more items had broken icon references**: a case mismatch, a typo in
  the filename (`HCPlasticspoonkbox`), a stray letter. The files were there
  all along. Found by the same audit.
- **Four items got new icons**: police baton, pickaxe, desk bell and candy bar
  wrapper. The dissection table got its missing states — with a corpse and
  bloodied. Eight to go. Prompts for the rest live in `docs/ICON_PROMPTS.md`.
- A `tools/make_icon.py` helper for new item icons: recolouring into another
  material using palettes lifted from the mod itself (wooden handles stay
  wooden), composing "item in a box", snapping outside artwork to the mod's
  palette, and auditing icon references.

### v1.5.10 — 2026-08-15

**Player suggestions — thanks to kaio.mafra for the detailed list:**
- **Food nutrition**: 96 edible items had no calories, carbs, proteins or
  lipids at all — you eat them, hunger drops, and B42's nutrition system never
  notices. The gaps are filled from each item's own category median: cheeses
  count as cheeses, condiments as condiments, mashes as mashes. The bulk of it
  was condiments (61 items), distillery mashes (14) and cheeses (4). Ten items
  were deliberately left alone: medicine and drugs, where the −1 hunger is
  incidental.
- **The fishing kit can be built from scratch** (kaio.mafra's suggestion): a
  rod, two lines or twine, a hook of any metal and five baits of any kind,
  artificial included. Previously the kit could only be found broken and
  repaired — living off the land had no entry point. The same fishing textbook
  teaches the new recipe.

### v1.5.9 — 2026-08-15

**Weapons, mitts and birds — from reports by Asteraaaaaki and kaio.mafra:**
- **Weapons invisible in hand** (Asteraaaaaki's report about the wrench bat in
  multiplayer): B41 displayed items via `WeaponSprite`; B42 needs a mesh wired
  through a `model` block plus a `WorldStaticModel` reference. All 187 weapon
  items were still on the old mechanism. Seven items that ship both a mesh and
  a texture are now fully wired: crossbow, longbow, uzi, box cutter, barbed-wire
  quarterstaff, gripped quarterstaff, homemade trimmer bat. The other 180 never
  shipped a mesh — they pointed at B41 vanilla sprites (`Knife`, `Shovel`,
  `Plank`). For those there is now `tools/weapon_models.py`: with the game
  installed it matches the names against vanilla B42 models and prints
  ready-to-paste lines.
- **Oven mitts** (kaio.mafra): the clothing definition spelled the model
  `HC_OvenMitts.FBX` while the file is `.fbx` — a missing file on a Linux
  server. The hat masks accidentally copied into a glove definition are gone
  too. The error spam on picking them up could not be reproduced without the
  game: if it persists, the error text would help.
- **"Feed the Birds"** (kaio.mafra): the recipe required a crafting surface,
  but birds are fed outdoors where there is none. A catch-22 — indoors the
  option shows and the Lua refuses ("there are no birds indoors"), outdoors the
  option never appears. Added `CanBeDoneFromFloor`: the recipe now works on the
  ground outside.

### v1.5.8 — 2026-08-15

**Load errors and stats — thanks to Crossfit Jesus and Haase for the reports:**
- **Red errors on game start** (`attempted index of non-table` in
  `Functions.lua` and `HCExtra.lua`): the mod was writing its functions into the
  global `Recipe` table, which no longer exists in that form in B42. The error
  aborted the file halfway through. All 47 references now live in the mod's own
  `HCRecipe` namespace — we no longer touch foreign globals.
- **`Object tried to call nil in HCDoStats`** on "play with toy" recipes
  (yo-yo, checkers, Rubik's cube — 127 recipes): B42.20 removed the
  `setBoredomLevel` and `setUnhappynessLevel` setters from `BodyDamage`. The
  v1.5.6 fix pass swept `getStats()` and missed this one. Boredom and
  unhappiness now go through whichever API the engine actually exposes, and if
  neither exists the recipe simply leaves stats alone instead of crashing.
  Stress works too now: the calling code passed it and the old signature
  dropped it.
- **Loot: batteries, auger and lumber saw** can be found again. After the
  v1.3.0 pass the weights had fallen to 0.1–0.2 even where the item belongs:
  batteries in electronics stores and garages are back up to 1–2, the auger in
  tool crates to 0.4–0.6. The lumber saw sat in a single list (wood crates,
  weight 0.4) — raised to 1.5 and added to tool crates and tool stores, where
  players were looking for it. Thanks to Haase for the eight-hour test run and
  to Crossfit Jesus for the ItemSpawner cross-check.

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
