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

### 🛠️ Идеи за пределами плана (v2.0+)

Не обещания, а направления — что из этого поедет, решат отзывы и то,
насколько больно дастся миграция сейвов в v1.6.

- **«Глубина» — шахта как подземелье.** Сейчас добыча это lua-таймер
  со случайным дропом (`HCMine`, `HCMineStone`, `HCDarkmine`). У мода есть
  свой tiledef-пак и 233 модели: рудные жилы как объекты мира, ярусы
  с ростом ценности и риска, свет как расходуемый ресурс, обвалы, вагонетки.
- **Энергосеть.** После v1.6 складывается цепочка, которой не хватает
  звена: биодизель и биогаз → генератор → батареи и солнечный парк →
  освещение и промышленные потребители. Сегодня это разрозненные предметы
  из четырёх файлов.
- **Профессии, черты, ожившие книги.** В B42 черты стали скриптами —
  можно вернуть отключённую механику «очки и слуховой аппарат лечат черты».
  Плюс профессии (пасечник, шахтёр, химик, старьёвщик) — у мода 32 категории
  крафта и ни одной точки входа в билд персонажа. Книги, которые сейчас
  не учат ничему, становятся книгами ванильных навыков: кузнечное дело,
  гончарство, кладка, стекло — тематика совпадает один в один.
- **Живность.** `HCR_Dogs` (42 КБ), кошки и питомцы — пока предметы, а B42
  умеет живых животных с поведением. Собака, которая ходит за игроком,
  охраняет базу и помогает на охоте, — то, ради чего в B41 ставили
  Hydrocraft. Сюда же решается судьба 71 вырезанного «живого» предмета,
  а пасека цепляется за ванильное опыление грядок из v1.7.
- **Мир, в котором это водится.** Тайлы есть, точек на карте нет: вход
  в шахту, карьер, пасечная ферма, свалка, лаборатория — инфраструктура,
  которую находят, а не крафтят с нуля. Дешёвый вариант того же —
  тематические зомби-аутфиты (шахтёр, пасечник, дезинсектор) с профильным
  лутом.
- **Инженерная гигиена.** Инструменты в `tools/` написаны, но запускаются
  руками. CI на push, валящий сборку на переопределениях предметов, битых
  ссылках, недостижимых предметах и пропусках перевода, ловил бы такие
  вещи сам. Туда же: аудит мультиплеера и профилирование загрузки
  при 5 196 предметах и 5 679 текстурах.

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

### 🛠️ Ideas beyond the plan (v2.0+)

Directions, not promises — what actually ships depends on feedback and on how
painful the v1.6 save migration turns out to be.

- **"The Deep" — the mine as a dungeon.** Mining is currently a Lua timer with
  a random drop (`HCMine`, `HCMineStone`, `HCDarkmine`). The mod has its own
  tiledef pack and 233 models: ore veins as world objects, tiers trading value
  against risk, light as a consumable, cave-ins, mine carts.
- **A power grid.** After v1.6 one link completes the chain: biodiesel and
  biogas → generator → batteries and solar farm → lighting and industrial
  consumers. Today those are unrelated items across four files.
- **Professions, traits, books that teach again.** B42 turned traits into
  scripts, so the disabled "glasses and hearing aid cure traits" mechanic can
  come back. Plus professions (beekeeper, miner, chemist, scrapper) — the mod
  has 32 craft categories and no entry point in character creation. And the
  books that currently teach nothing become vanilla skill books: smithing,
  pottery, masonry, glassmaking — the subject matter already matches.
- **Livestock.** `HCR_Dogs` (42 KB), cats and pets are still items, while B42
  has live animals with behavior. A dog that follows you, guards the base and
  helps on the hunt is what people installed Hydrocraft for in B41. This also
  settles the fate of the 71 cut "live animal" items, and the apiary hooks
  into v1.7's vanilla pollination.
- **A world to find it in.** The tiles exist, the map spots do not: a mine
  entrance, quarry, apiary farm, scrapyard, laboratory — infrastructure you
  find rather than craft from scratch. The cheap version of the same idea:
  themed zombie outfits (miner, beekeeper, exterminator) with matching loot.
- **Engineering hygiene.** The `tools/` audit suite exists but runs by hand.
  CI on push, failing the build on item redefinitions, broken references,
  unreachable items and missing translations, would catch these by itself.
  Same bucket: a multiplayer audit and load profiling at 5,196 items and
  5,679 textures.

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
