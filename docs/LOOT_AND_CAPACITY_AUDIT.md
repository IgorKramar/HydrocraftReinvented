# Loot and container capacity audit — Project Zomboid 42.21

The installed game JAR was inspected privately on 2026-10-14. No game classes or decompiled source are included in this repository.

## Capacity: preserve the existing declarations

`InventoryContainer.setCapacity` stores the requested script capacity in its child `ItemContainer` and logs a warning when that capacity exceeds `50 - actualWeight`. It does not replace the stored value with 49. `getCapacity` and `getEffectiveCapacity` instead limit their returned values to the integer part of `50 - actualWeight`.

The factory calls `setCapacity` before applying the item's final weight. The warning therefore often mentions 49 because the temporary default weight is 1. This is not proof that every finished item has capacity 49. For example, a finished weight-10 container reports at most 40; the child container still retains its raw script capacity. Existing anchored storage and its scripts can address that child container directly.

There are 93 container declarations with capacity above 49, including stationary storage, animal packs, wagons and legacy vehicle props. A blanket conversion to 49 would change raw storage capacities and can still differ from the final effective capacity. The declarations remain unchanged. Resolving stationary storage separately requires native gameplay tests and a deliberate compatibility/balance decision.

## Reachable loot registration

`tools/missing_loot_migrations.json` records 20 removed entries: 18 complete item/weight pairs in active distribution registration, plus two unweighted entries in the art-box callback. Every removed full ID is absent from both the installed game scripts and this mod. No substitute items or restored legacy animals were added.

The art-box callback is reached through the current loot recipe's `HCR42.recipe_hclootart` bridge. Its absent styrofoam ball/block entries were removed. The obsolete shoe-box pool is now empty; no arbitrary footwear replacement was chosen.

The runtime Lua registration check also found a malformed singleton `pizza_kitchen_sauce_items` pool containing Alfredo sauce without a numeric weight. It now uses weight 1, matching the same item's existing Gigamart and kitchen dry-food weights. The portable manifest records this correction.

The executed regression covers direct container pools, procedural insertion calls, and the deferred firearm callback. All resulting pools retain alternating item/number pairs, and every resulting ID resolves to a current script declaration. Bare IDs are checked in the default `Base` module; this caught six obsolete crossword/wordsearch magazines. The old `camping.CampingTentKit` entry was also absent and removed.

## Callback material audit

The broad literal-ID audit still reports legacy callbacks. Many animal outputs belong to removed recipes and must not be restored simply to make that audit empty. `PlantsGrowing` also builds IDs by concatenating the literal prefix `Hydrocraft.HC`; that prefix alone is not an item reference.

The separate callback audit restored nine material declarations in `HCR_CallbackMaterials.txt`, without restoring animal items or livestock systems:

- Five feral manure traces retain the original Normal class, mass 0.2 and icons from Hydrocraft `917d37d`, `Animals.txt`. They follow the already-rescued feral pig material. The native game has `Base.Dung_Cow`, `Base.Dung_Pig` and `Base.Dung_Sheep`, confirmed by both generated item scripts and `media/lua/shared/Definitions/animal/*Definitions.lua`. Those are mass-1, non-edible Food items marked `IsDung` and `iscompostable`; substituting them would change the original trace quantities/class. There are no native horse, donkey or goat dung items. None were substituted with dirt or fertilizer.
- `HCRubberscrap` and `HCMusselshell` retain original Normal class and mass 0.1 from upstream `Recycling Rubber.txt` and `Boneworking.txt`; their original icons are already present.
- `HCPlasticscrap` and `HCSiliconpowder` are explicitly inferred definitions: reachable original callbacks name them, but the pinned original script set has no declarations. Mass 0.1 follows current plastic and chemical-powder units. The plastic-scrap icon already exists; silicon temporarily uses the existing generic grey iron-powder icon rather than referencing an absent image.

The two inferred materials have no current script consumers, and no exact native or mod equivalents exist. Refined `HCPlastic` is not scrap plastic; `HCQuartz` is a mineral rather than elemental silicon powder. The callbacks retain their named byproducts and original counts instead of silently upgrading/changing them. Removed processing recipes were not restored in this repair. Downstream processing of these byproducts remains a documented content gap.

The donkey branch originally rolled four outcomes but handled only two, giving XP without a reward in the other two. It now rolls two outcomes, matching its two existing identical reward arms. The lawnmower's malformed `Hydrocraft.HCCablecopper,` reward now names the existing copper cable exactly. Nine material names have Russian translations.

Native `ItemUser.UseItem` suppresses `ReplaceOnUse` during crafting (`bCrafting=true`). The boiled-mussel callback therefore creates one shell, while ordinary consumption can use the same now-resolving `HCMusselshell` replacement without a second crafting shell.

## Verification

`tools/test_missing_loot.py` executes the active Lua distribution registration and art-box callback, checks complete weighted pairs, and validates remaining IDs. All three tests pass. `tools/repair_missing_loot.py --check` confirms the portable migration is already applied. Native reopening is still required to verify registration against the real game's distribution tables.

`tools/test_callback_materials.py` executes nine reachable callbacks against real declared item IDs and checks original reward counts. It exhausts all 4,096 random rolls at skill levels 0–10, both secondary outcomes, in summer and winter (180,224 executions), plus the indoor refusal. Every reward branch creates exactly one valid dung item and awards 10 XP. All three tests pass; these are Lua 5.1 regressions, not a claim of native gameplay verification.
