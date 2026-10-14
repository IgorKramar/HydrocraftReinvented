# Community progression blockers — 42.21 audit

The audit distinguishes an item declaration from a usable source. In particular, native `Base.CopperIngot` is declared but has no producer or loot entry in the inspected game scripts/Lua. Native copper crafting uses `CopperScrap` instead. Merely accepting the declared ingot did not solve the copper progression reports.

## Corrected routes

| Reported item | Actual route now provided | Compatibility evidence |
| --- | --- | --- |
| Lever | Native/HC steel bar + steel ingot + one screw → `Make Lever` | Pinned `Smithing.txt / Make Lever`, original 1/1/1 materials and one HC output. Native smithing hammer and anvils prevent the HC hammer bootstrap cycle. |
| Large copper sheet | Two native copper scraps → existing `Forge Large Copper Sheet` | Existing counts/output are retained. Copper scrap occurs in native metalwork/electronics loot and native copper-ore smelting. The native smithing hammer is accepted as a kept tool. |
| Copper pipe | One large HC copper sheet + one welding-tool use → `Make Copper Pipe` | Pinned `Smithing.txt / Make Metal Pipe`, copper variant, preserved one-sheet/one-use/one-output semantics. Native BlowTorch is accepted alongside the existing HC welding set. |
| Aluminium ingot | Four empty soda cans + charcoal/fire/mould at an anchored HC smelter → existing recycling recipe | The previously missing smelter producer is restored. This gives a route independent of HC ore/powder drops. No vanilla ingot metallurgy is duplicated. |
| HC smelter | 50 native fired clay bricks + four concrete uses + kept mason's trowel → `Make Smelter`, then existing anchoring recipe | Pinned `Metalurgy.txt / Make Smelter`, concrete variant. Native brick and concrete production replace absent B41 red brick/wooden concrete bucket IDs. Four uses empty one full native concrete bucket. |
| Pruning shears | One steel ingot, kept smithing tools → `Make Steel Pruning Shears` | Pinned `Smithing.txt`, original material/output count and Maintenance 2 gate. Also retains the existing independent ToolStoreFarming loot source. |

The restored recipes are taught by the existing masonry, industrial, welding and steel-working books. The first three book choices follow the pinned source; the steel-working book is an explicit recovery of the untaught pruning-shears recipe. New recipe names are unique. The portable evidence is recorded in `tools/progression_route_migrations.json`.

## Gardening and sewing

The gardening bench accepts current vanilla leather/tarp aprons as alternatives to the HC garden apron. Gloves, shovels, rake, watering can and sprayer have native sources. Mystery seed packets are inserted into the existing `GardenStoreMisc` pool; clay pots have existing `CrateMetalwork` sources; garden hoses occur in existing farming/tool pools. Its ordinary workbench is craftable from planks, nails and sticks with kept native hammer/saw. The restored pruning-shears recipe supplies the last explicitly reported missing tool.

Sewing pins have an independent `CrateTailoring` box source; the existing unboxing recipe yields 100 pins. Both `CrateTailoring` and `ToolStoreFarming` exist in the installed native procedural table and are referenced by its placed distributions. These are actual registered pools, not isolated item strings.

Scissors use the current `base:scissors` tool tag. Tailoring-workbench assembly intentionally consumes scissors as an incorporated part, matching pinned `Sewing.txt`; ordinary sewing tool inputs that were originally kept remain kept. The spinning-wheel chain is present: wooden ring → wooden wheel → spinning wheel; the hand drill is available in existing GarageTools reclamation loot. No extra pins, shears or legacy animals were added to unrelated loot pools.

## Verification

`tools/test_progression_routes.py` checks original restored counts, teaching links, all native IDs, actual distribution names/placements, and the absence of orphan-only hammer/copper paths. Three tests pass. `tools/lab_progression.lua` provides a native crafting chain for the disposable HCRLab profile, including smelter construction/anchoring, aluminium recycling, lever, copper sheet/pipe, pruning shears and gardening bench. The helper uses native XP for genuine skill gates, restores temporary known recipes, and removes only fixture-created inventory items. All nine consecutive crafts passed in the installed 42.21 client, including consumption of the recycled native can and availability of the final gardening workbench.
