# Vision / Дальние планы

*Замысел за пределами ближайших выпусков. Ближайшие версии — в
[дорожной карте](../ROADMAP.md); здесь то, что дальше: автоматизация,
программируемый компьютер, наука и новые производственные ветки.
Приоритеты живые и меняются от отзывов игроков —
пишите в [обсуждения Мастерской](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332).*

*The long game. The nearest releases live in the [roadmap](../ROADMAP.md); this
document is what comes after: automation, a programmable computer, research and
new production branches. Priorities are alive and shift with player feedback —
post in the [Workshop discussions](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332).*

---

## Русский

### 🗺️ Дальние выпуски

#### v2.0.0 — «Производство» / The Automation Update

Энергия, транспорт и станки — сейчас это разрозненные предметы в четырёх
файлах, а должно быть одной цепочкой. Опирается на слой сущностей из v1.8:
без многотайловых станций автоматизировать нечего.

- **Солнечная энергетика по-настоящему.** Сегодня `HCSolargen` — это 46 строк
  lua, подделывающих ванильный генератор с бесконечным топливом. Взамен:
  панели по тирам (самодельная и заводская), контроллер заряда, аккумуляторные
  банки на существующих батареях пяти типоразмеров, выработка от времени
  суток, сезона и облачности, деградация и чистка панелей, щит со счётчиком.
  Ветряк и беговая дорожка-генератор входят в ту же сеть, биодизель и биогаз
  дают вторую опору рядом с солнцем.
- **Конвейеры и манипуляторы.** Ленты, повороты, разветвители, сортировка
  по фильтру, погрузчики в контейнеры и обратно. Без питания лента стоит —
  логистика становится потребителем сети, а не отдельной игрушкой.
- **Станки с буферами.** Автоматические версии HC-станций (макератор, пресс,
  дробилка, печь): входной и выходной буфер, заданный рецепт, расход энергии,
  остановка по переполнению. Ручной крафт остаётся — автоматизация это
  поздняя игра, а не замена раннему.
- **Панель Sandbox**: скорость лент, аппетит станков, потолок нагрузки на тик,
  выключатель всей подсистемы для серверов.

#### v2.1.0 — «Терминал» / The Computer Update

Весь материальный слой в моде уже есть: `HCComputer` с монитором, клавиатурой,
мышью, блоком питания и вентилятором, чертежи на каждую деталь, книги по
программированию и робототехнике, девять дискет и полная цепочка изготовления
печатных плат (медь → фоторезист → проявка → сверление → печать). Не хватает
того, ради чего это собирают.

- **Компьютер с собственным окном**: своя «ОС» — файловая система внутри
  сейва, редактор, консоль, список задач. Дискеты становятся носителями:
  найденная в луте — готовая программа, чистая — место под свою.
- **Язык автоматизации, а не голый Lua.** Игрок пишет на ограниченном языке,
  который исполняет виртуальная машина мода с бюджетом инструкций на тик.
  Пускать пользовательский Lua внутрь нельзя: на сервере это исполнение
  произвольного кода, а один бесконечный цикл вешает клиент всем.
- **API автоматизации**: датчики (заряд банки, заполнение бункера, состояние
  станка), управление лентами, станками, светом и дверями, расписания
  и условия. Скрипт заменяет ручной обход базы.
- **ЧПУ**: программируемый станок, где задание описывает деталь, а из заготовки
  выходят шестерни, стволы и корпуса. Программа — предмет: пишется на
  компьютере, переносится дискетой, попадается в луте готовой.
- **Мультиплеер с первого дня**: состояние сети и вычислений живёт на сервере,
  клиент только рисует. Иначе подсистема превращается в чит и рассинхрон.

Оба выпуска — исследовательские. В Project Zomboid нет ни транспорта предметов,
ни пользовательских вычислений: и то и другое придётся строить с нуля на
lua-тиках, а самое трудное здесь не механика, а производительность и сетевая
часть. Разумный первый шаг — вертикальный срез: одна панель, одна лента, один
станок и один компьютер, которые работают вместе. На нём и мерить.

#### v2.2.0 — «Лаборатория» / The Research Update

У мода три вида лабораторий, категория `Research` на 60 рецептов и семейство
«Планшеты и исследования» — но вся прогрессия держится на книгах, которые нужно
найти. Лаборатории стоят декорацией.

- **Дерево исследований**: собственное меню — узлы, зависимости, прогресс,
  видно, что открыто и чего не хватает до следующей ветки. Не список рецептов,
  а карта, по которой игрок планирует.
- **Научный цикл**: образец → анализ в лаборатории (микроскоп, реактивы,
  время) → «результат исследования» как предмет-данные → узел дерева.
  Поздние ветки открываются работой, а не удачей в луте.
- **Книги никуда не деваются**: ранние рецепты по-прежнему учатся чтением —
  найденный учебник сразу даёт крафт. Поздние книги переходят в другую роль:
  ускоряют исследование соответствующей ветки. Найти нужный том — по-прежнему
  удача, но теперь это фора, а не единственная дорога.
- **Метеорология**: часов, барометра, термометра и флюгера в моде нет вообще.
  Погода в игре считается честно, поэтому прогноз — настоящая механика:
  барометр падает, значит через сутки шторм; метеостанция даёт прогноз на
  несколько часов, точность растёт от приборов и навыка. Завязано на
  фермерство (когда сеять и убирать) и на солнечную выработку из v2.0.
- **Картография и геодезия**: компас и звёздные карты есть, секстанта,
  теодолита и изготовления карт нет. Съёмка местности → своя карта района
  с отметками, разметка участка под стройку, координаты по звёздам.
  Заодно оживляет астрономию, где сейчас четыре предмета и никакого выхода.

### 🏭 Новые производственные ветки

Не привязаны к версиям — набираются в выпуски по готовности. Все шесть
заполняют дыры в существующем контенте, а не пристраивают новую тему сбоку.

- **Оптика.** В моде есть телескоп с треногой, микроскоп, бинокль (30 рецептов
  держат его инструментом), очки, звёздные карты — и ни одной линзы: всё это
  только из лута. Стеклоделие отдано ванили, и оптика надстраивается над ним,
  ничего не дублируя: ванильная заготовка → шлифовка и полировка на станке
  (сущность из v1.8) → линза → окуляр и объектив → прибор. Оттуда же прицел,
  перископ и замена разбитым очкам.
- **Вода: от скважины до крана.** Есть ручной насос (45 рецептов), таблетки
  для очистки, бочки, пруд — нет ни фильтра, ни водопровода. На жидкостях
  v1.6: песок с углём и тканью → фильтр с ресурсом → колодец или скважина →
  насос (ручной, с v2.0 электрический) → бак и водонапорная башня → раковины
  и душ. Качество воды становится свойством: мутная, фильтрованная, кипячёная.
- **Грибоводство.** Микробиология сейчас тупик: агар, чашки Петри, плесени,
  микроскоп — и всё это ведёт только в пенициллин. Рядом `Food Shrooms`, где
  грибы просто еда. Соединяются напрямую: опилки и солома → стерилизация
  (пароварка уже есть) → инокуляция мицелием из чашки Петри → тёмное
  помещение → урожай волнами, пока субстрат не выдохнется.
- **Аквакультура.** Пруд со своим якорением есть, рыбалка есть, танк
  со спирулиной есть — разведения нет. Мальки → садок → корм из кухонных
  и фермерских отходов → вылов. С v1.7 и v2.0 складывается аквапоника: вода
  из рыбного бака кормит растения, растения чистят воду, насос и свет висят
  на солнечной сети.
- **Полупроводники.** Цепочка печатной платы уже полная (медь → фоторезист →
  проявка → сверление → печать), но микросхема берётся только из лута
  и разборки техники. Кремний с нуля: кварцевый песок → плавка → слиток →
  пластина → фотолитография → чип. Ставит компьютер из v2.1 на свои ноги.
- **Известь и кальциевая химия.** Бетон, раствор, кирпич и известняк ваниль
  B42 делает сама (глина с песком и водой, мешки цемента, месторождения
  известняка) — дублировать это нельзя, философия порта запрещает. Зато
  ванильная известь никуда не ведёт, а у мода уже есть все потребители:
  `HCLimestone` участвует ровно в двух рецептах, известковое молоко — в трёх
  десятках `HCHidelimed*` при выделке шкур. Ветка про обжиг и то, что дальше:
  известняк → негашёная известь (печи и огнеупорный кирпич в моде есть) →
  гашение и известковое молоко → выделка шкур, нейтрализация кислот в химии,
  очистка воды из ветки выше. Отдельный побег — известь с коксом (кокс
  появился в v1.5.5) → карбид кальция → ацетилен для сварки (36 рецептов
  сварки уже есть, а газ для них берётся из воздуха) и карбидная лампа для
  шахты, где сейчас каска с лампой питается иначе.

### 🛠️ Идеи за пределами плана

Не обещания, а направления — что из этого поедет, решат отзывы и то,
насколько больно дастся миграция сейвов в v1.6.

- **«Глубина» — шахта как подземелье.** Сейчас добыча это lua-таймер
  со случайным дропом (`HCMine`, `HCMineStone`, `HCDarkmine`). У мода есть
  свой tiledef-пак и 233 модели: рудные жилы как объекты мира, ярусы
  с ростом ценности и риска, свет как расходуемый ресурс, обвалы, вагонетки.
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

---

## English

### 🗺️ Later releases

#### v2.0.0 — The Automation Update

Power, transport and machines are scattered items across four files today;
they should be one chain. Built on v1.8's entity layer — without multi-tile
stations there is nothing to automate.

- **Solar power for real.** `HCSolargen` is currently 46 lines of Lua faking a
  vanilla generator with infinite fuel. Instead: tiered panels (homemade and
  factory), a charge controller, battery banks on the existing five battery
  sizes, output driven by time of day, season and cloud cover, panel
  degradation and cleaning, a breaker panel with a meter. The windmill and the
  treadmill generator join the same grid, and biodiesel and biogas give it a
  second leg beside the sun.
- **Conveyors and loaders.** Belts, corners, splitters, filtered sorting,
  loaders into and out of containers. An unpowered belt stands still —
  logistics becomes a consumer on the grid, not a separate toy.
- **Machines with buffers.** Automated versions of HC stations (macerator,
  press, crusher, furnace): input and output buffers, an assigned recipe,
  power draw, a stop on overflow. Hand crafting stays — automation is late
  game, not a replacement for the early one.
- **Sandbox panel**: belt speed, machine appetite, a per-tick load ceiling, and
  a kill switch for the whole subsystem on servers.

#### v2.1.0 — The Computer Update

The physical layer already exists in the mod: `HCComputer` with monitor,
keyboard, mouse, PSU and fan, blueprints for every part, books on programming
and robotics, nine floppies and a complete circuit board fabrication chain
(copper → photoresist → developing → drilling → printing). What's missing is
the reason to assemble it.

- **A computer with its own window**: an "OS" of its own — a filesystem inside
  the save, an editor, a console, a task list. Floppies become media: one
  found in loot is a finished program, a blank one is room for yours.
- **An automation language, not raw Lua.** The player writes in a restricted
  language executed by the mod's own VM with a per-tick instruction budget.
  Letting player Lua inside is not an option: on a server that is arbitrary
  code execution, and a single infinite loop freezes everyone's client.
- **An automation API**: sensors (bank charge, hopper level, machine state),
  control over belts, machines, lights and doors, schedules and conditions.
  A script replaces walking the base by hand.
- **CNC**: a programmable machine where the job describes the part and the
  blank comes out as gears, barrels and casings. The program is an item:
  written on the computer, carried on a floppy, occasionally found ready-made.
- **Multiplayer from day one**: grid and computation state live on the server,
  the client only draws. Otherwise the subsystem becomes a cheat and a desync.

Both releases are exploratory. Project Zomboid has neither item transport nor
user computation: both have to be built from scratch on Lua ticks, and the hard
part is not the mechanics but performance and networking. The sane first step is
a vertical slice — one panel, one belt, one machine and one computer working
together — and measuring on that.

#### v2.2.0 — The Research Update

The mod has three kinds of laboratory, a `Research` category with 60 recipes and
a "tablets and research" item family — yet all progression rests on books you
have to find. The labs are set dressing.

- **A research tree**: its own menu — nodes, dependencies, progress, a clear
  view of what is unlocked and what the next branch still needs. A map to plan
  by, not another recipe list.
- **The research cycle**: sample → analysis in a lab (microscope, reagents,
  time) → a "research result" data item → a node on the tree. Late branches
  open through work, not through luck in loot.
- **Books stay**: early recipes are still learned by reading — a found textbook
  grants the craft outright. Late books change role instead: they speed up
  research in their branch. Finding the right volume is still luck, but now
  it is a head start rather than the only road.
- **Meteorology**: the mod has no clock, barometer, thermometer or weather
  vane at all. The game simulates weather honestly, so forecasting is a real
  mechanic: a falling barometer means a storm within a day; a weather station
  forecasts hours ahead, with accuracy scaling off instruments and skill. Ties
  into farming (when to sow and harvest) and v2.0's solar output.
- **Cartography and surveying**: there is a compass and there are star charts,
  but no sextant, no theodolite, no map-making. Survey the terrain → your own
  annotated district map, plot layout for construction, position from the
  stars. It also gives astronomy — currently four items and a dead end —
  somewhere to go.

### 🏭 New production branches

Not tied to versions — they go into releases as they are ready. All six fill
holes in existing content rather than bolting on a new theme.

- **Optics.** The mod has a telescope with tripod, a microscope, binoculars
  (30 recipes hold them as a tool), glasses and star charts — and not one lens:
  all of it comes from loot only. Glassmaking went to vanilla, and optics build
  on top of it without duplicating anything: a vanilla blank → grinding and
  polishing at a station (a v1.8 entity) → a lens → eyepiece and objective →
  the instrument. Rifle scopes, a periscope and replacements for broken
  glasses come from the same chain.
- **Water: from the well to the tap.** There is a hand pump (45 recipes),
  purification tablets, barrels and a pond — but no filter and no plumbing. On
  v1.6 fluids: sand, charcoal and cloth → a filter with a lifespan → a well or
  borehole → a pump (hand-driven, electric from v2.0) → a tank and water tower
  → sinks and a shower. Water quality becomes a property: murky, filtered,
  boiled.
- **Mushroom cultivation.** Microbiology is a dead end today: agar, petri
  dishes, molds, a microscope — and all of it leads only to penicillin. Next
  door sits `Food Shrooms`, where mushrooms are merely food. They join
  directly: sawdust and straw → sterilization (the steam pot already exists) →
  inoculation with mycelium from a petri dish → a dark room → harvest in
  flushes until the substrate is spent.
- **Aquaculture.** The pond has its own anchoring recipe, fishing exists, the
  spirulina tank exists — breeding does not. Fry → a cage → feed from kitchen
  and farm waste → harvest. With v1.7 and v2.0 it closes into aquaponics: tank
  water feeds the plants, the plants clean the water, pump and lights hang off
  the solar grid.
- **Semiconductors.** The circuit board chain is already complete (copper →
  photoresist → developing → drilling → printing), but the chip itself only
  comes from loot and salvage. Silicon from scratch: quartz sand → melt →
  ingot → wafer → photolithography → chip. It puts v2.1's computer on its own
  feet.
- **Lime and calcium chemistry.** Concrete, mortar, brick and limestone are
  vanilla B42's own (clay with sand and water, cement bags, limestone
  deposits) — duplicating them is off the table, the port's philosophy forbids
  it. But vanilla lime leads nowhere, while the mod already has every consumer:
  `HCLimestone` appears in exactly two recipes, and milk of lime feeds three
  dozen `HCHidelimed*` items in hide tanning. The branch is about burning and
  what follows: limestone → quicklime (kilns and refractory brick are already
  in the mod) → slaking and milk of lime → hide tanning, acid neutralization
  in chemistry, water treatment from the branch above. A separate offshoot is
  lime with coke (coke arrived in v1.5.5) → calcium carbide → acetylene for
  welding (36 welding recipes exist, and their gas comes from nowhere) and a
  carbide lamp for the mine, where the helmet lamp currently runs on something
  else.

### 🛠️ Ideas beyond the plan

Directions, not promises — what actually ships depends on feedback and on how
painful the v1.6 save migration turns out to be.

- **"The Deep" — the mine as a dungeon.** Mining is currently a Lua timer with
  a random drop (`HCMine`, `HCMineStone`, `HCDarkmine`). The mod has its own
  tiledef pack and 233 models: ore veins as world objects, tiers trading value
  against risk, light as a consumable, cave-ins, mine carts.
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
