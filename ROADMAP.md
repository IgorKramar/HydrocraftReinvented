# Roadmap / Дорожная карта

*Русский — сверху, English below. Приоритеты живые и меняются от отзывов игроков —
пишите в [обсуждения Мастерской](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332).*

---

## Русский

### 🗺️ План мажорных версий

#### v1.6.0 — «Живая вода» / The Fluids Update

Последний легаси-пласт мода: ~1 000 предметов до сих пор изображают жидкости
парами «пустой/полный», как в B41. Всё переезжает на нативную систему жидкостей B42:

- **Настоящие ёмкости** (`FluidContainer`): наполнение из любого источника,
  переливание, дождь в бочки, честные объёмы — силами движка. Класс
  недостижимых предметов «с водой» исчезает полностью.
- **Винокурня и пивоварня на живой ферментации**: соки (122 рецепта),
  винодельня и дистиллерия переходят с «предмет→предмет» на `-fluid`/`+fluid` —
  брага зреет в чане, самогон капает в бутыль.
- **Молочное хозяйство**: цепочка от ванильной коровы до сыра и йогурта
  на настоящем молоке-жидкости.
- **Панель Sandbox**: множители лута Hydrocraft, отключаемые подсистемы
  (включая наркотики — для серверов), настройка скорости шахт.
- **Миграция сейвов**: конвертер «полных» предметов на загрузке — запасы
  игроков не пропадут.

#### v1.7.0 — «Усадьба» / The Homestead Update

- 86 культур Hydrocraft (хлопок, табак, рис, джут, травы...) — с горшков
  на настоящие грядки B42 (горшки остаются для подоконника).
- Эволюционирующие рецепты: продукты Hydrocraft в ванильных супах, рагу
  и пицце.

#### v1.8.0 — «Индустрия» / The Industry Update

- Ванильные станции варят слитки Hydrocraft и наоборот (расцепить 43 рецепта
  от HC-станций).
- Переплавка устаревшей металлической утвари ванильной кузницей
  (по предложению Crossfit Jesus).
- Junkyard 2.0: свалки с разборкой остовов машин.
- Пересортировка крафт-меню из «Прочего» по человеческим категориям.

### 🔭 За горизонтом

- **Тестирование в мультиплеере** — порт писался в одиночке; отчёты
  с серверов очень welcome.
- **Кросс-совместимость** с кулинарными и производственными модами
  (Vanilla Foods Expanded уже дружит; Sapph's Cooking — как только автор
  починит слоты одежды под B42).
- Судьба вырезанного разведения животных B41 (71 «живой» предмет) — ваниль
  закрывает основное, решаем, что делать с экзотикой.

### ✅ Сделано

- **v1.5.5–1.5.7 «Связная экономика»**: у каждого предмета снова есть источник
  (некрафтуемых рецептов 803 → 101); мост к ванили — рецепты принимают
  ванильные слитки, формы, стекло, молоко, шерсть, перья; 71 новый рецепт
  (разделка дичи, выплавка, ковка, стеклодувство); миграция на новый
  Stats/CharacterStat API движка; русские имена 215 ванильных построек;
  тапервэр наполняется едой. Инструменты аудита достижимости — в `tools/`,
  гоняются перед каждым релизом.
- **v1.5.0 Система обучения**: `TeachedRecipes`→`LearnedRecipes`, 366 дублей
  имён рецептов слиты/переименованы (1 441 вариант вернулся в игру), 346
  мёртвых книжных ссылок вычищено.
- **v1.4.0 Баланс опыта**: 1 569 наград пересчитаны по времени рецепта
  и ванильным медианам.
- **v1.3.0 Ревизия лута**: доля HC ≤30 % во всех списках, мёртвые цели
  перенаправлены.
- **v1.2.0 Миграция `ItemType`**: все предметы на нативных классах B42.

### 🐞 Нашли баг?

Пишите в [тред багрепортов](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332):
что делали, что ожидали, что произошло, текст ошибки из игрового отчёта.
Красные ошибки с упоминанием Hydrocraft чинятся в первую очередь — обычно
день в день.

---

## English

### 🗺️ Major version plan

#### v1.6.0 — The Fluids Update

The mod's last legacy layer: ~1,000 items still emulate liquids with
"empty/full" item pairs, B41-style. Everything moves to native B42 fluids:

- **Real containers** (`FluidContainer`): fill from any source, pour between
  vessels, rain into barrels, honest volumes — engine-driven. The class of
  unobtainable "filled with water" items disappears entirely.
- **Brewery and distillery on live fermentation**: juices (122 recipes),
  winemaking and distilling move from "item→item" to `-fluid`/`+fluid` —
  the mash matures in the vat, the moonshine drips into the jug.
- **Dairy farming**: the chain from a vanilla cow to cheese and yogurt on
  real milk fluid.
- **Sandbox panel**: Hydrocraft loot multipliers, toggleable subsystems
  (including drugs — for servers), mining speed settings.
- **Save migration**: an on-load converter for "full" items — player
  stockpiles survive.

#### v1.7.0 — The Homestead Update

- 86 Hydrocraft crops (cotton, tobacco, rice, jute, herbs...) move from pots
  to real B42 farming plots (pots stay for the windowsill).
- Evolved recipes: Hydrocraft produce in vanilla soups, stews and pizza.

#### v1.8.0 — The Industry Update

- Vanilla stations smelt Hydrocraft ingots and vice versa (decouple 43
  recipes from HC stations).
- Melting down obsolete metalware with vanilla smithing (suggested by
  Crossfit Jesus).
- Junkyard 2.0: scrapyards with car wreck salvage.
- A proper reorganization of the craft menu out of "Miscellaneous".

### 🔭 Beyond the horizon

- **Multiplayer testing** — the port was built in singleplayer; server
  reports are very welcome.
- **Cross-mod compatibility** with cooking/industry mods (Vanilla Foods
  Expanded already works; Sapph's Cooking once its author fixes the B42
  clothing slots).
- The fate of the cut B41 animal husbandry (71 "live animal" items) —
  vanilla covers the basics, deciding what to do with the exotics.

### ✅ Done

- **v1.5.5–1.5.7 "Connected Economy"**: every item has a source again
  (uncraftable recipes 803 → 101); the vanilla bridge — recipes accept
  vanilla ingots, molds, glass, milk, wool, feathers; 71 new recipes (game
  butchering, smelting, forging, glassblowing); migration to the engine's
  new Stats/CharacterStat API; Russian names for 215 vanilla build entities;
  tupperware fills with food. The reachability audit toolchain lives in
  `tools/` and runs before every release.
- **v1.5.0 Learning system**: `TeachedRecipes`→`LearnedRecipes`, 366
  duplicate recipe names merged/renamed (1,441 variants returned to the
  game), 346 dead book references purged.
- **v1.4.0 XP balance**: 1,569 awards recalculated from recipe time and
  vanilla medians.
- **v1.3.0 Loot pass**: HC share ≤30% in every list, dead targets redirected.
- **v1.2.0 `ItemType` migration**: all items on native B42 classes.

### 🐞 Found a bug?

Post in the [bug reports thread](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332):
what you did, what you expected, what happened, the error text from the
in-game report. Red errors mentioning Hydrocraft get fixed first — usually
same-day.
