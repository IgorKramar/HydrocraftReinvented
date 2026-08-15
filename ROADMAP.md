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

#### v1.8.0 — «Мастерская» / The Workshop Update

Самый крупный неиспользованный слой B42. Сегодня все 3 590 рецептов мода
крафтятся на `AnySurfaceCraft`, а «станции» — это предметы в рюкзаке: титановый
молот на 91 рецепт, макератор на 43, стеклянная воронка на 107. Плавка титана
на парковке — прямое наследие B41. B42 умеет многотайловые сущности, и мод
не использует их ни разу (`entity`-скриптов в моде: 0).

- **Станции становятся сущностями**: пары «предмет / закреплённый предмет»
  (30 рецептов якорения — от наковален до шахты, пруда, лабораторий
  и свалки) переезжают в многотайловые объекты B42 с визуальными
  состояниями и собственным списком рецептов. Собственные, без ванильного
  двойника: макератор, винокурня, маслопресс, ткацкий станок и прялка,
  три лаборатории, электронный и портновский верстаки, коптильня, шахта,
  карьер, пруд, свалка.
- **Расцепление — только там, где ваниль дублирует механику**: наковальни
  трёх видов (228 упоминаний в рецептах) уходят к ванильной кузнице B42,
  плавильня, домна, электро- и промышленная печь — к ванильной выплавке.
  Держать свою копию того, что движок теперь умеет сам, незачем: это
  философия порта, применённая к станциям.
- **Переплавка устаревшей металлической утвари** ванильной кузницей
  (по предложению Crossfit Jesus).
- **Junkyard 2.0**: свалки с разборкой остовов машин.
- Крафт-меню разгружается само: станция показывает свои рецепты, и «Прочее»
  худеет без ручной пересортировки.

Дальше v1.8 план перестаёт быть расписанием и становится замыслом:
автоматизация производства, программируемый компьютер, дерево исследований
и шесть новых производственных веток вынесены в отдельный документ —
[Дальние планы](docs/VISION.md).

### 🔭 За горизонтом

- **Тестирование в мультиплеере** — порт писался в одиночке; отчёты
  с серверов очень welcome.
- **Кросс-совместимость** с кулинарными и производственными модами
  (Vanilla Foods Expanded уже дружит; Sapph's Cooking — как только автор
  починит слоты одежды под B42).

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

#### v1.8.0 — The Workshop Update

B42's largest untouched layer. Today all 3,590 recipes craft on
`AnySurfaceCraft`, and the "stations" are items in your backpack: a titanium
hammer gates 91 recipes, a macerator 43, a glass funnel 107. Smelting titanium
in a parking lot is B41 legacy. B42 supports multi-tile entities, and the mod
uses them exactly zero times (`entity` scripts in the mod: 0).

- **Stations become entities**: the "item / anchored item" pairs (30 anchoring
  recipes — from anvils to the mine, pond, labs and scrapyard) move to
  multi-tile B42 objects with visual states and their own recipe lists. The
  ones with no vanilla counterpart stay ours: macerator, distillery, oil
  press, loom and spinning wheel, three labs, electronics and tailor's
  benches, smoker, mine, quarry, pond, scrapyard.
- **Decoupling only where vanilla duplicates the mechanic**: the three anvil
  types (228 recipe references) move to B42's vanilla smithing, and the
  smelter, blast furnace, arc and industrial furnaces to vanilla melting.
  Keeping our own copy of what the engine now does natively makes no sense —
  it is the port's philosophy applied to stations.
- **Melting down obsolete metalware** with vanilla smithing (suggested by
  Crossfit Jesus).
- **Junkyard 2.0**: scrapyards with car wreck salvage.
- The craft menu unloads itself: a station lists its own recipes, so
  "Miscellaneous" shrinks without a manual re-sort.

Past v1.8 the plan stops being a schedule and becomes intent: production
automation, a programmable computer, a research tree and six new production
branches live in a separate document — [Vision](docs/VISION.md).

### 🔭 Beyond the horizon

- **Multiplayer testing** — the port was built in singleplayer; server
  reports are very welcome.
- **Cross-mod compatibility** with cooking/industry mods (Vanilla Foods
  Expanded already works; Sapph's Cooking once its author fixes the B42
  clothing slots).

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
