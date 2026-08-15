# Заметки по API Build 42

*Что изменилось между B41 и B42.20 и как это отражено в моде. Накоплено
за девять релизов порта — чтобы не переоткрывать одни и те же грабли.*

*English abstract: the B41→B42 API differences this port ran into, with the
patterns used to fix each one, plus a list of engine APIs that were removed and
still have leftovers in the code. Written in Russian; code samples speak for
themselves.*

---

## Философия: чего не переносим

B42 нативно закрыл часть систем Hydrocraft. Они **не портированы намеренно** —
дублировать движок нельзя:

| Система B41 | Замена в B42 |
|---|---|
| Кузнечное дело, металлургия | навыки Blacksmith / Melting |
| Гончарство | Pottery |
| Камнеобработка, кладка, бетон | Masonry / Carving |
| Стекло | Glassmaking |
| Костяные изделия | Carving |
| Разделка туш | Butchering |
| Скот как предметы | живые животные (Husbandry) |
| Переплавка металлолома | Melting |
| Розжиг, компост | ванильные механики |

Правило при добавлении контента: если ваниль B42 уже делает это — расширяем
ванильное, а не заводим своё. Пример хорошего расширения: известь и карбид
из известняка (ваниль даёт известняк и бетон, но не даёт им продолжения).

## Рецепты: `recipe` → `craftRecipe`

Грамматика полностью новая: блоки `inputs`/`outputs` вместо плоского списка,
`mode:keep` вместо `keep`, теги инструментов (`base:hammer`, `base:saw`),
жидкости через `-fluid`/`+fluid`, `xpAward` вместо lua-хуков на опыт.

```
craftRecipe Make Something
{
    time = 60,
    Tags = AnySurfaceCraft,
    category = Carpentry,
    timedAction = Making,
    SkillRequired = Woodwork:3,
    xpAward = Woodwork:15,
    inputs
    {
        item 1 [Base.Plank],
        item 1 tags[Hammer] mode:keep,
    }
    outputs
    {
        item 1 Hydrocraft.HCThing,
    }
}
```

## Обучение: `TeachedRecipes` → `LearnedRecipes`

Поле переименовано. Кроме того, имя рецепта стало ключом: два рецепта
с одинаковым именем — второй затирает первый. В v1.5.0 из-за этого пришлось
переименовать 366 дублей, вернув в игру 1 441 вариант.

## Классы предметов: `ItemType`

Строковые типы B41 заменены на неймспейс: `base:normal`, `base:food`,
`base:drainable`, `base:weapon`, `base:clothing`, `base:literature`.
Слоты одежды тоже переехали: `BodyLocation = base:hands`, `CanBeEquipped = base:hands`.

## Переименования ванильных предметов

33 предмета B41 сменили идентификатор. Самые частые в рецептах:

| B41 | B42 |
|---|---|
| `Base.Flour` | `Base.Flour2` |
| `Base.WaterPot` | `Base.Pot` |
| `Base.WhiskeyEmpty` | `Base.Whiskey` |

При правке рецептов сверяйтесь с `tools/analyze_gaps.py` — он ловит ссылки
на несуществующие предметы.

## Статы персонажа

**Снято в 42.20**: `player:getStats():setFatigue()`, `setEndurance()`,
`setHunger()`. Замена — аддитивный API:

```lua
player:getStats():add(CharacterStat.ENDURANCE, -0.01)
player:getStats():add(CharacterStat.FATIGUE, 0.05)
```

В v1.5.6 так переведены 38 вызовов в шести файлах.

⚠️ **Незакрытый случай**: `player:getBodyDamage():setBoredomLevel()` и
`setUnhappynessLevel()` в `HCExtra.lua:2160–2161` тоже сняты, но в ту волну
не попали — волна шла по `getStats()`. Ломает 127 рецептов «поиграть
с игрушкой». См. [FEEDBACK.md](FEEDBACK.md), баг 2.

## Черты: `TraitFactory` удалён

Черты стали скриптами. Механика «очки и слуховой аппарат лечат черты»
(`server/Traits/HCTraits.lua`) обёрнута в guard и не работает:

```lua
if type(TraitFactory)=="table" and TraitFactory.addTrait then -- HCR42_traits_guard
```

Возврат через скриптовые черты — в [VISION.md](VISION.md).

## Таблица `Recipe` удалена

В B41 существовали глобальные `Recipe.OnCreate` и `Recipe.OnTest`, куда
складывали функции рецептов. В B42 их нет, и объявление вида

```lua
function Recipe.OnCreate.Hydrocraft.RecycleBag(items, result, player)  -- ОШИБКА
```

даёт при загрузке `attempted index of non-table` и **обрывает выполнение
остатка файла**. В коде осталось шесть таких мест — см. FEEDBACK, баг 1.

Правильный способ — глобальная функция плюс запись в мост:

```lua
function HCRecycleBag(items, result, player) ... end
-- в zzz_HCR42_RecipeCode.lua:
HCR42["HCRecycleBag"] = wrap("HCRecycleBag")
```

## Сигнатура OnCreate

B41 `fn(items, result, player)` → B42 `fn(craftRecipeData, character)`.
Мод не переписывает функции, а оборачивает их — см.
[ARCHITECTURE.md](ARCHITECTURE.md), раздел про мост. В скриптах ссылка всегда
на обёртку: `OnCreate = HCR42.ИмяФункции`.

## Отображение предметов в руках

`WeaponSprite` — механизм B41. В B42 предмет показывается через меш,
привязанный блоком `model`, и `WorldStaticModel` в самом предмете. В моде
189 объявлений `WeaponSprite` и ни одного `WorldStaticModel` в файлах оружия:
меши лежат, но не подключены, поэтому оружие невидимо в руках. См. FEEDBACK, баг 3.

## Жидкости

B42 умеет настоящие ёмкости (`FluidContainer`) и переносы `-fluid`/`+fluid`
в рецептах. Мод пока держит ~1 000 предметов парами «пустой/полный» из B41 —
миграция запланирована в v1.6, вместе с конвертером сейвов.

## Прочие ловушки

- **`ReplaceOnUseOn = WaterSource-HCTincanwater`** — предмет наполняется
  из источника воды в мире. Формат «источник-предмет»; инструменты аудита
  учитывают это с недавних пор, иначе 43 предмета считались недостижимыми.
- **Регистр полей** движку безразличен, инструментам — нет.
- **Выгрузка чанков**: lua-таймеры на `EveryHours` замирают, когда игрок
  уходит от базы. Решение — сохранять метку времени в `getModData()`
  и досчитывать разницу в `OnLoad`, либо переезжать на компоненты станций B42
  (план v1.8).
- **Порядок загрузки скриптов** — алфавитный по файлам. Отсюда префиксы
  `zzz_` для того, что должно грузиться последним.
- **Номер tiledef** (`hcBuilding 591`) записан в сейвы игроков. Менять нельзя.

## Как проверять

Красные ошибки в игре: `F11` или счётчик ошибок → «copy». В отчёте видно
файл и строку мода — этого обычно достаточно, чтобы найти причину.
Перед релизом гоняется конвейер из `tools/` (см. [RELEASING.md](RELEASING.md)).
