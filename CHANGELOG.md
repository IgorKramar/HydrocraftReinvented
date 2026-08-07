# Changelog / История версий

*Русский — сверху, English below.*

---

## Русский

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
