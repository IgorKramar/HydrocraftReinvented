---
kind: game
title: B42.21 inventory, recipes and clothing port checks
game: Project Zomboid
games_also: []
game_version: '42.21.0'
platform: windows
engine: java
route: data
tools: [universal-modder-0.2.0, fal.ai, Python, lupa.lua51, CFR-0.152]
anti_cheat: 'Offline and private localhost with Steam disabled; no anti-cheat bypass'
status: in-progress
agents:
- Codex
humans: [hombrehumor]
date: '2026-10-14'
links:
  - https://steamcommunity.com/sharedfiles/filedetails/?id=3778201332
  - https://github.com/brosseaualex/Hydrocraft/tree/917d37d4ed526f429e1525316c9fab487bbf7257
tags: [lua, recipes, inventory, clothing, multiplayer]
---
# B42.21 inventory, recipes and clothing port checks

Hydrocraft Reinvented received repairs for existing B41 content on native B42.
Actual offline and localhost multiplayer runs complement Lua regressions and
source-backed recipe migrations. This local note is in progress; no release or
knowledge-base pull request has been published.

## Setup
Steam Project Zomboid 42.21.0, Windows, Universal Modder 0.2.0. Separate cachedir
profiles isolate saves/settings. Server binds to localhost with UPnP off. Game
internals were inspected privately; no decompiled source is shipped.

## Route and why
Use native script declarations, craftRecipe and Lua callbacks. Preserve existing
content behaviour and adapt changed APIs. Native livestock and metalworking stay
native; do not reintroduce inventory animals to satisfy a literal-ID audit.

## How the game works (what we had to learn)
- WeaponSprite resolves hand models; WorldStaticModel resolves ground art.
- Clothing XML also needs fileGuidTable registration.
- ItemUser.UseItem suppresses Food.ReplaceOnUse during crafting; Drainable
  depletion still returns empty counterparts. Return food dishes explicitly.
- CraftRecipeData skips FluidContainer consumption without ItemCount. Physical
  empty containers and partial fluid amounts require different treatment.
- B42.21 inventories exist on the dedicated server. Player bags expose leaf IDs;
  nested ground/furniture bags need their packet-addressable root.
- World-object swapItem preserves position and sends its native SWAP_ITEM packet.
- InventoryItem.loadItem recreates the declared class. Changing it under an old
  fullType can invalidate saved records; introduce a new ID and migrate after load.
- InventoryContainer raw capacity differs from effective capacity derived from
  weight. A warning is not evidence that every script should be capped at 49.
- Unknown ItemTag lookups return null; unrelated unknown tags can share a cached
  eligibility group. Register authored namespaced tags before script loading.
- The native Lua runtime lacks global next; use pairs for metadata guards.
- Static TXT model loading can dereference absent skinning data. Actual DirectX
  meshes load through the StaticMesh path; PNG UV orientation must be checked in
  the real game, including which atlas islands colour the blade and housing.

## Build steps
1. Parse current mod and installed vanilla declarations, and pin legacy source.
2. Preserve source evidence in quantity/tool/container migration manifests.
3. Introduce new fullTypes for Java class changes.
4. Run regressions, then actual native crafting and save/reload in private saves.
5. Stage identical files on a local server/client. ACK old IDs before server aging;
   observe successors on the real client rather than synthesising observations.
6. Package common plus 42/mod.info in an external preview and lint the package.

## Verification
Current evidence is in PLAYABILITY_VERIFICATION.md. Crafting uses native input
validation/consumption. Saved normal chainmail was loaded and migrated with custom
name, favorite flag, condition and repair count retained. Initial MP proof covers
nested ground bags, carried nested bags and a standalone pot, with exactly-once
replacement observed independently on the server and client.
Normal mouse input produced OnWeaponSwingHitPoint for the repaired bat. This does
not prove every recipe combination or long-running multiplayer compatibility.

## Gotchas
1. **Food/dishes remained.** Native consumption has special Food/FluidContainer
   rules. Use ItemCount for whole physical inputs, fluid amounts for contents, and
   return only emptied food containers, exactly once.
2. **Only the first slice inherited state.** Legacy callbacks handled one result.
   Copy food state to each output and divide total nutrition.
3. **Old armour disappeared.** A normal ID was changed to Clothing. Keep its
   normal declaration; create a new wearable ID and migrate after native loading.
4. **Nested MP items stayed stale or duplicated.** Root/leaf packet addressing
   differs. Publish at the appropriate level and verify with a real client.
5. **A parser supported a mesh format but the game warned.** Filename discovery
   and model validation also matter. Inspect actual loaded/rendered geometry.
6. **UI clicks missed.** Transitions happen on later frames. Pause briefly between
   clicks, typing and key chords, and verify the resulting UI state.
7. **Generated trap omitted nails.** Inspect geometry, then restore repeated small
   parts deterministically; do not claim the generation reproduced them.

## Assets
Ten textures were edited using fal nano-banana-2 and fitted to existing sprites
and UV masks. Trellis2 generated a trap, processed by a reproducible geometry
pipeline including restored nails. Portable provenance has requests/hashes and
processing details without credentials. Raw generations stay outside the repo.

## Cost and time
Raster estimate: ten requests at $0.08 ($0.80), not a billing statement. Trellis
billing is separate. No exact total API spend is claimed.

## Open questions
The latest fluid/progression and input eligibility checks passed; the new trap
renders after a cold restart. Chainsaw hand rendering and atlas colours also
passed. Verify community mod collections, long-running play, multiple concurrent
clients and trap damage/MP before claiming broad coverage. Native SP placement,
sensor activation and exactly-once device removal passed.
