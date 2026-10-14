# Hydrocraft Reinvented 1.5.12 — Playability and polish

This update addresses the faults that interrupted everyday play: ingredients
being consumed incorrectly, missing production routes, broken timed processes,
and equipment or plants that failed to display properly.

- Corrected whole-food consumption, fluid quantities, packaging and empty-container
  returns. Food portions retain freshness and share the source nutrition;
  reusable smithing tools are kept.
- Restored timed potted plants, cheese maturation and beehives, with server-authoritative
  updates and checks for nested containers and placed items.
- Repaired production and loot routes, recipe learning, obsolete item references,
  clothing registration and the migration of existing chainmail.
- Repaired weapon models and the existing spike trap model. Filled missing plant,
  chainmail and silicon-powder artwork. New planters use the original Hydrocraft
  box geometry; tomato and both cabbage canopies have clean transparent backgrounds.

Tested on **Project Zomboid 42.21.0**: 88 regression checks passed, alongside
targeted native crafting, save migration, rendering and multiplayer checks.
The full [verification report](PLAYABILITY_VERIFICATION.md) records what was tested
and what remains: broader multiplayer and mod compatibility testing, trap damage
and further review of peripheral production chains. This release does not claim
that every possible combination of recipes and other mods has been tested.

The next priority remains the same: finish making the existing mod reliably
playable before introducing new mechanics. Please report the game version,
recipe or item involved, whether you were playing solo or on a server, and any
relevant errors from `console.txt`.

Original Hydrocraft by Hydromancerx; B41 maintenance by the Hydrocraft Continued
team; B42 port by hombrehumor. Some new artwork was generated through fal.ai
using `fal-ai/nano-banana-2/edit`, `fal-ai/gpt-image-1.5/edit` and
`fal-ai/trellis-2`; [asset provenance](ASSET_PROVENANCE.json) records the processing.
AI-assisted development and verification used OpenAI Codex and Universal Modder.

## Русский

Версия 1.5.12 исправляет ошибки, мешавшие обычной игре: неверный расход продуктов
и жидкостей, возврат тары, упаковку, потерю кузнечных инструментов, отсутствующие
производственные и лут-маршруты. Восстановлены таймеры растений, сыра и ульев;
исправлены обучение рецептам, одежда, миграция кольчуги и модели оружия и ловушки.
Добавлены недостающие ассеты, сохранена исходная геометрия ящиков, заново
перерисованы томат и обе капусты с настоящей прозрачностью.

Проверено на 42.21.0: 88 регрессионных проверок и целевые проверки в самой игре,
включая сохранения и мультиплеер. Оставшиеся ограничения перечислены в отчёте.
Приоритет — надёжная работа существующего мода; новые механики идут следующим этапом.
