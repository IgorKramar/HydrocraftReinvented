# Roadmap / Дорожная карта

*Русский — сверху, English below. Приоритеты живые и меняются от отзывов игроков —
пишите в [обсуждения Мастерской](https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332).*

---

## Русский

### 🔧 В работе / ближайшее

- **Полная миграция предметов на `ItemType`.** Носибельные уже переведены
  (v1.1.0); остальные ~5 000 предметов пока живут на легаси-формате B41.
  Он работает, но именно он даёт редкие NPE в `instanceItem` (~20 предметов
  с алкогольными свойствами). Миграция закроет этот класс проблем целиком.
- **Ревизия распределения лута** — чтобы вещи Hydrocraft попадались там, где
  им логично лежать, и не вытесняли ванильный лут.
- **Баланс опыта (`xpAward`)** — значения перенесены из B41 механически,
  местами щедро, местами скупо.

### 🗺️ Дальний прицел

- **Интеграция с фермерством B42**: экзотические культуры HC сейчас
  предметы/лут — сделать их полноценными грядками.
- **Продолжение ванильных цепочек**: кузнечество, гончарство и стекло B42
  как источники сырья для рецептов Hydrocraft — не дублируя, а продолжая.
- **Ревизия эволюционирующих рецептов** (супы, рагу, самогон) под текущую
  ваниль.
- **Тестирование в мультиплеере** — порт писался и проверялся в одиночке;
  отчёты с серверов очень welcome.
- **Кросс-совместимость** с другими кулинарными и производственными модами
  (Vanilla Foods Expanded уже дружит; Sapph's Cooking — как только автор
  починит слоты одежды под B42).

### ⚠️ Известные ограничения (кандидаты в задачи)

- Книги, обучавшие рецептам вырезанных систем, ничему не учат.
- Механика «очки/слуховой аппарат лечат черты» отключена: в B42 нет
  TraitFactory.

### 🐞 Нашли баг?

Пишите в обсуждения Мастерской или комментарии: что делали, что ожидали,
что произошло. Если игра выдала ошибку — приложите хвост `console.txt`
(папка Zomboid). Красные ошибки с упоминанием Hydrocraft чинятся
в первую очередь.

---

## English

### 🔧 In progress / next

- **Full `ItemType` migration.** Wearables are done (v1.1.0); the remaining
  ~5,000 items still use the legacy B41 format. It works, but it is the source
  of rare `instanceItem` NPEs (~20 items with alcohol properties). Migration
  kills this whole class of problems.
- **Loot distribution pass** — make Hydrocraft items spawn where they
  logically belong without crowding out vanilla loot.
- **XP balance (`xpAward`)** — values were carried over from B41 mechanically
  and need tuning.

### 🗺️ Long term

- **B42 farming integration**: exotic HC crops are items/loot for now — turn
  them into real farm plants.
- **Continuing vanilla chains**: B42 smithing, pottery and glassmaking as
  material sources for Hydrocraft recipes — extending them, not duplicating.
- **Evolved recipe revision** (soups, stews, moonshine) against current
  vanilla.
- **Multiplayer testing** — the port was built and tested in singleplayer;
  server reports are very welcome.
- **Cross-mod compatibility** with other cooking/industry mods (Vanilla Foods
  Expanded already works; Sapph's Cooking once its author fixes the B42
  clothing slots).

### ⚠️ Known limitations (task candidates)

- Books that taught recipes of the cut systems teach nothing.
- The "glasses / hearing aid cure traits" mechanic is disabled: B42 removed
  TraitFactory.

### 🐞 Found a bug?

Post in the Workshop discussions or comments: what you did, what you
expected, what happened. If the game threw an error, attach the tail of
`console.txt` (Zomboid folder). Red errors mentioning Hydrocraft get fixed
first.
