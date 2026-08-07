# Changelog / История версий

*Русский — сверху, English below.*

---

## Русский

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
