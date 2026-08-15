# Архитектура мода

*Как устроен Hydrocraft Reinvented изнутри: где что лежит, кто кого вызывает,
какие связи легко сломать. Рабочий документ для разработки.*

*English abstract: this is the internal map of the mod — directory layout, the
script grammar actually used here, the three Lua layers, the B41→B42 OnCreate
bridge, loot, localization and assets. Written in Russian; the file/line
references and code samples are language-neutral. For the B42 API notes see
[B42_API.md](B42_API.md), for conventions [CONTRIBUTING.md](../CONTRIBUTING.md).*

---

## Раскладка

Репозиторий — это и есть мод: содержимое `common/` копируется в
`%USERPROFILE%\Zomboid\mods\HydrocraftReinvented\`.

| Путь | Объём | Что внутри |
|---|---|---|
| `common/mod.info` | — | манифест: id, версия, `pack`, `tiledef` |
| `common/media/scripts/HydrocraftReinvented/` | 157 файлов | предметы, рецепты, схемы починки, модели |
| `common/media/lua/server/` | 24 файла, 11 283 строки | OnCreate-функции, лут, XP, черты |
| `common/media/lua/client/` | 8 файлов, 1 191 строка | UI-логика: солнечные панели, ловушки, сейфы, путешествия |
| `common/media/lua/shared/Translate/` | 59 файлов | локализация, 9 языков |
| `common/media/textures/` | 5 679 файлов | иконки и текстуры |
| `common/media/models/`, `models_X/` | 51 + 138 | меши оружия, предметов, одежды |
| `common/media/clothing/clothingItems/` | 32 файла | XML носимых вещей |
| `common/media/sound/` | 38 файлов | звуки |
| `common/media/AnimSets/` | 69 файлов | анимации |
| `common/media/hcBuilding.tiles` | — | tiledef, объявлен в `mod.info` как `hcBuilding 591` |
| `common/media/texturepacks/hcBuilding2x.pack` | — | текстур-пак тайлов |
| `tools/` | 6 скриптов | аудит и генерация документации |
| `docs/` | — | база предметов, диаграммы, эта документация |

## Скрипты

Все 157 файлов открываются одинаково:

```
module Hydrocraft
{
    imports { Base }
    ...
}
```

Файлы называются `HCR_<Тема>.txt` и группируют предметы по смыслу — от
`HCR_Apiculture` до `HCR_Winemaking`. Три файла выбиваются: `Books.txt`,
`APhcmodels.txt`, `DETOX_Models.txt` (наследие оригинала).

Внутри встречаются четыре типа блоков:

| Блок | Количество | Назначение |
|---|---|---|
| `item` | 5 204 определения на 5 196 уникальных | предметы |
| `craftRecipe` | 3 590 | рецепты |
| `model` | 233 | привязка меша и текстуры к предмету |
| `fixing` | 121 | схемы починки (в 11 файлах) |

Расхождение 5 204 против 5 196 — это восемь предметов, объявленных дважды
с расходящимся содержимым. Движок оставляет последнее по алфавиту файлов,
`tools/parse_hcr.py` печатает список. Это баг, не приём.

### Предмет

```
item HCHoneybee
{
    Weight          = 0.1,
    ItemType        = base:normal,
    DisplayName     = Honeybee,
    Icon            = HCHoneybee,
    DisplayCategory = SurApi,
}
```

- `ItemType` — всегда неймспейс B42 (`base:normal`, `base:food`, `base:drainable`,
  `base:weapon`, `base:clothing`). Классов B41 в моде не осталось.
- `DisplayName` — источник английского названия. Отдельного EN-словаря
  на предметы почти нет (в `Translate/EN/ItemName.json` всего 179 ключей —
  это точечные переопределения).
- `DisplayCategory` — 83 значения, вкладка в инвентаре (`SurFarm`, `FoodP`,
  `CraftChem`…). Не путать с категорией рецепта.
- Регистр полей движку безразличен: в моде соседствуют `Icon` (2 934 раза)
  и `icon` (2 271). Инструменты в `tools/` читают регистр буквально — при
  добавлении полей держитесь `CamelCase`.

### Рецепт

```
craftRecipe Make Wicker Basket
{
    time = 15,
    Tags = AnySurfaceCraft,
    category = Weaving,
    timedAction = Making,
    NeedToBeLearn = true,
    inputs
    {
        item 10 [Base.Twigs],
    }
    outputs
    {
        item 1 Hydrocraft.HCWickerbasket,
    }
}
```

- Имя рецепта — ключ. Все 3 590 имён уникальны (до v1.5.0 было 366 коллизий,
  из-за которых часть рецептов не доезжала до игры).
- `category` — 32 значения, вкладка в меню крафта (`Cooking` — 881 рецепт,
  `Chemistry` — 439, `Farming` — 395…).
- `Tags`: 2 270 рецептов на `AnySurfaceCraft`, 1 320 на
  `AnySurfaceCraft;CanBeDoneFromFloor`. То есть станций в понимании B42 у мода
  пока нет — см. план v1.8 в [ROADMAP](../ROADMAP.md).
- Списки в квадратных скобках через `;` — это OR: подойдёт любой из предметов.
  Именно через них сделан мост к ванили (рецепты принимают ванильные слитки,
  стекло, молоко, шерсть).
- `mode:keep` — вход не расходуется, де-факто инструмент.
- `NeedToBeLearn = true` требует книги: 1 341 рецепт, все привязаны
  к обучающим предметам через `LearnedRecipes`.

## Три слоя Lua

**`server/`** — вся игровая логика: 282 OnCreate-функции (шахта, охота, сбор
флоры, жуки, пруд, навоз), распределения лута, XP, черты. Файлы называются
по темам: `RockHCExtra.lua`, `HuntingHCExtra.lua`, `FloraHCExtra.lua`.

**`client/`** — то, что рисует или требует контекстного меню: солнечные
генераторы, ловушки, сейфы с кодовым замком, быстрое путешествие, рост
растений, русские имена ванильных построек.

**`shared/`** — только `Translate/`, кода нет.

### Мост OnCreate (`server/zzz_HCR42_RecipeCode.lua`)

Ключевой узел порта. В B41 функция рецепта имела сигнатуру
`fn(items, result, player)`, в B42 — `fn(craftRecipeData, character)`.
Вместо переписывания 282 функций сделана обёртка:

```lua
local function wrap(name)
    return function(craftRecipeData, character)
        local fn = _G[...]                       -- ищем функцию по имени
        local results = craftRecipeData:getAllCreatedItems()
        local result  = results and results:get(0)
        local items   = craftRecipeData:getAllConsumedItems()
        local ok, err = pcall(fn, items, result, character)
        if not ok then print("[HydrocraftReinvented] OnCreate " .. name .. " error: " .. err) end
    end
end
HCR42["HCMine"] = wrap("HCMine")
```

Скрипты ссылаются на обёртку, а не на функцию напрямую:

```
OnCreate = HCR42.HC_ToyStatModifier,
```

Отсюда важное следствие: **новая OnCreate-функция должна быть заведена
в `HCR42[...]`**, иначе рецепт молча не сработает. Префикс `zzz_` в имени файла
нужен, чтобы мост грузился после самих функций.

Самые нагруженные обёртки: `HC_ToyStatModifier` (127 рецептов),
`recipe_NDPlantsHarvest` (87), `recipe_hcpot` (41), `HCRecipeBowls` (38).

## Лут

Три файла в `server/Items/`:

- `Distributions_HC.lua` — привязка к конкретным контейнерам;
- `ProceduralDistributions_HC.lua` — процедурные списки B42;
- `zzz_ReclamationLoot_HC.lua` — добавлен в v1.5.5 для предметов, потерявших
  источник после отказа от вырезанных систем.

Плюс `HCDistributionFunctions.lua` и `HCLoot.lua` — вспомогательная логика.

Формат — пары «предмет, вес»:

```lua
"Hydrocraft.HCBatterysmall", 1.5,
```

Ревизия v1.3.0 держит долю HC ≤30 % в каждом списке. Обратная сторона:
по части предметов веса упали до 0.1 и ниже, и игроки их не находят —
см. [FEEDBACK.md](FEEDBACK.md).

## Локализация

`shared/Translate/<ЯЗЫК>/*.json`, ключи вида `"Hydrocraft.HCHoneybee": "Медоносная пчела"`.

| Язык | Ключей | Состояние |
|---|---|---|
| RU | 10 736 | 100 % предметов и рецептов, все категории |
| FR | 7 523 | базовый машинный перевод |
| DE | 6 448 | базовый |
| TR | 6 381 | базовый |
| CN | 5 699 | базовый |
| ES | 4 667 | базовый |
| AR | 4 078 | базовый |
| IT | 1 671 | частичный |
| EN | 179 | только переопределения, основное — в `DisplayName` |

Файлы по назначению: `ItemName.json`, `Recipes.json`, `IG_UI.json` (категории
крафта), `ContextMenu.json`, `Farming.json`, `Tooltip.json`, `Sandbox.json`, `UI.json`.

## Ассеты

- **Иконки**: `textures/Item_<Icon>.png`, имя после `Item_` = значение `Icon`
  в предмете.
- **Модели**: меш в `models/` или `models_X/`, привязка — блоком `model`
  в скриптах:
  ```
  model HC_GlowstickBlueAZ
  {
      mesh    = Weapons/1Handed/HC_AZGlowstick,
      texture = Items/GlowstickBlue,
  }
  ```
  Меш без `model`-блока в игре не появится — именно так сейчас потеряно
  оружие (см. FEEDBACK, баг 3).
- **Одежда**: XML в `clothing/clothingItems/`, ссылается на FBX
  в `models_X/Skinned/Clothes/` и текстуру. Регистр расширения в XML должен
  совпадать с файлом — на linux-сервере иначе будет «файл не найден».
- **Тайлы**: `hcBuilding.tiles` + `texturepacks/hcBuilding2x.pack`, оба
  объявлены в `mod.info`. Номер `591` — идентификатор набора, менять нельзя:
  он записан в сейвы игроков.

## Инструменты

```
tools/parse_hcr.py   →  model.json  →  variant_b.py     (достижимость)
                                    →  analyze_gaps.py  (битые ссылки)
                                    →  build_xlsx.py    (docs/HCR_Database.xlsx)
                                    →  gen_flowcharts.py(docs/FLOWCHARTS.md)
```

Каталог установки игры нужен для списка ванильных предметов и их переводов,
берётся из `--game <путь>` или `PZ_GAME_DIR`. Подробности — `tools/README.md`.
