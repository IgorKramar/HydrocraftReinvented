# Contributing / Как участвовать

*Русский — сверху, English below.*

---

## Русский

Мод открыт для правок. Самое ценное — багрепорты: почти каждый релиз вырос
из чужого сообщения в [треде](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332).

### Хороший багрепорт

1. Что делали и что произошло вместо ожидаемого.
2. Текст ошибки из игрового отчёта (`F11` или красный счётчик → «copy»).
3. Окружение: мод отдельно или со сборкой, новый мир или старый сейв.

Один точный репорт обычно разматывает целый пласт: сообщение про книги вернуло
в игру 1 441 рецепт, сообщение про шахту починило шесть систем сразу.

### Прежде чем писать код

Прочитайте два документа — они экономят день:

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — где что лежит и кто кого вызывает;
- [docs/B42_API.md](docs/B42_API.md) — чем B42 отличается от B41 и какие
  API движка сняты.

Главное правило порта: **дополнять, не дублировать**. Если ваниль B42 умеет
это сама (кузница, гончарка, кладка, стекло, разделка, животноводство) — мы
расширяем ванильное, а не заводим своё.

### Соглашения

**Именование.** Предметы — префикс `HC` (`HCHoneybee`), файлы скриптов —
`HCR_<Тема>.txt`, модуль всегда `Hydrocraft`. Имена рецептов уникальны
по всему моду: перед добавлением проверьте, что имя не занято.

**Поля предметов** пишутся в `CamelCase` (`Icon`, `Weight`, `DisplayName`).
Исторически в файлах есть и `icon` в нижнем регистре — движку всё равно,
но инструменты аудита читают регистр буквально, поэтому в новом коде так
не делайте.

**Каждый новый предмет обязан иметь:**

- `ItemType` из неймспейса B42 (`base:normal`, `base:food`, …);
- `DisplayName` — это и есть английское название, отдельный EN-словарь
  почти не используется;
- `DisplayCategory` — вкладка инвентаря из уже существующих 83 значений;
- `Icon` и файл `textures/Item_<Icon>.png`;
- русское имя в `lua/shared/Translate/RU/ItemName.json` — RU-локализация
  покрывает 100 % предметов, разрывов быть не должно;
- источник: рецепт, лут или lua. Предмет, который нельзя получить, поймает
  `tools/variant_b.py`.

**Каждый новый рецепт:**

- уникальное имя + перевод в `Translate/RU/Recipes.json`;
- `category` из существующих 32;
- OR-списки в квадратных скобках через `;` там, где подойдёт и ванильный
  аналог, — так работает мост к ванили;
- `xpAward`, соразмерный `time` (шкала откалибрована в v1.4.0 по ванильным
  медианам);
- если нужна книга — `NeedToBeLearn = true` плюс имя рецепта
  в `LearnedRecipes` обучающего предмета.

**Новая OnCreate-функция** обязана быть заведена в мост
`lua/server/zzz_HCR42_RecipeCode.lua`:

```lua
HCR42["HCMyFunction"] = wrap("HCMyFunction")
```

В скрипте ссылка идёт на обёртку: `OnCreate = HCR42.HCMyFunction`. Прямой
вызов не сработает — сигнатуры B41 и B42 разные. И никогда не объявляйте
функции через `Recipe.OnCreate.*`: в B42 этой таблицы нет, файл упадёт
при загрузке.

**Модель** без блока `model` в скриптах в игре не появится: одного меша
в `models/` недостаточно.

### Перед коммитом

```sh
python3 tools/parse_hcr.py --game "<путь к Project Zomboid>"
python3 tools/variant_b.py
python3 tools/analyze_gaps.py
```

Смотрим на три вещи: нет ли новых переопределений предметов, не выросло ли
число недостижимых предметов и некрафтуемых рецептов, нет ли битых ссылок.
Подробности — в [tools/README.md](tools/README.md).

### Git

Работаем в ветках, коммиты — с внятным телом: что сломано, чем чинится,
какие числа изменились. История релизов ведётся в
[CHANGELOG.md](CHANGELOG.md) на двух языках, планы — в
[ROADMAP.md](ROADMAP.md) и [docs/VISION.md](docs/VISION.md).

### Переводы

Переводы приветствуются: девять языков, кроме русского, содержат базовый
машинный перевод разного качества. Правки — прямо в
`lua/shared/Translate/<ЯЗЫК>/*.json`, ключи брать из русского файла как
эталона полноты.

---

## English

The mod is open to contributions. The most valuable ones are bug reports —
nearly every release grew out of somebody's post in the
[Workshop thread](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332).

### A good bug report

1. What you did and what happened instead.
2. The error text from the in-game report (`F11` or the red counter → copy).
3. Your setup: the mod alone or in a pack, a new world or an existing save.

One precise report usually unravels a whole family of fixes: a report about
books returned 1,441 recipes to the game, one about mining fixed six systems
at once.

### Before writing code

Read these two first — they save you a day:

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — the internal map;
- [docs/B42_API.md](docs/B42_API.md) — what B42 changed and which engine APIs
  are gone.

The port's core rule: **complement, don't duplicate**. If vanilla B42 does it
natively (smithing, pottery, masonry, glass, butchering, husbandry), we extend
vanilla instead of shipping our own copy.

### Conventions

**Naming.** Items are `HC`-prefixed (`HCHoneybee`), script files are
`HCR_<Theme>.txt`, the module is always `Hydrocraft`. Recipe names are unique
mod-wide — check before adding one.

**Item fields** use `CamelCase` (`Icon`, `Weight`, `DisplayName`). Lowercase
`icon` exists in legacy files; the engine does not care, but the audit tools
read case literally, so do not add new ones.

**Every new item needs:** a B42 `ItemType`; a `DisplayName` (this *is* the
English name — there is almost no separate EN dictionary); a `DisplayCategory`
from the existing 83; an `Icon` plus `textures/Item_<Icon>.png`; a Russian name
in `Translate/RU/ItemName.json` (RU covers 100% of items — keep it that way);
and a source — recipe, loot or Lua. Unobtainable items are caught by
`tools/variant_b.py`.

**Every new recipe needs:** a unique name plus a Russian translation in
`Translate/RU/Recipes.json`; a `category` from the existing 32; OR-lists in
brackets where a vanilla equivalent would do (that is how the vanilla bridge
works); an `xpAward` proportional to `time`; and, if it must be learned,
`NeedToBeLearn = true` plus the recipe name in the teaching item's
`LearnedRecipes`.

**Every new OnCreate function** must be registered in the bridge
`lua/server/zzz_HCR42_RecipeCode.lua` as `HCR42["Name"] = wrap("Name")`, and
referenced from scripts as `OnCreate = HCR42.Name`. Never declare functions via
`Recipe.OnCreate.*` — that table is gone in B42 and the file will fail to load.

**A mesh without a `model` block** in the scripts will not show up in game.

### Before committing

```sh
python3 tools/parse_hcr.py --game "<path to Project Zomboid>"
python3 tools/variant_b.py
python3 tools/analyze_gaps.py
```

Check three things: no new item redefinitions, no growth in unreachable items
or uncraftable recipes, no broken references. See [tools/README.md](tools/README.md).

### Translations

Translations are very welcome: the nine non-Russian languages carry a base
machine translation of varying quality. Edit
`lua/shared/Translate/<LANG>/*.json` directly, using the Russian files as the
completeness reference.
