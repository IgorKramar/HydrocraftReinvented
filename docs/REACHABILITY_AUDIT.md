# Reachability audit, Project Zomboid 42.21

The tools run against the installed 42.21 scripts and the current parsed mod model. They are diagnostic graphs, not a full playability certificate. `tools/gaps_variant_b.txt` contains every flagged item and recipe; `tools/gaps_report.txt` contains the broader comparison.

| Model | Flagged items | No modelled producer | Blocked recipes |
|---|---:|---:|---:|
| Variant B: farming assumed available | 79 | 72 | 41 |
| Basic graph: no farming blanket assumption | 417 | 380 | 78 |

Both models now load the actual shared PlantsGrowing path, 265 conditional timer transitions, current item replacement transitions, and literal AddItem/AddItems rewards from callbacks linked to live recipes. All nine HCR_CallbackMaterials items have such callback producers. A timer target becomes reachable only after its source does; an unlinked obsolete callback is not a producer edge. Four regression tests cover these distinctions.

The basic graph initially reported 560 items and 196 recipes. Adding the missing item replacement step reduced these to 453/115: cooked mash and depleted-item transitions had been false negatives. After the reviewed availability patch, the remaining difference from Variant B is 338 items and 37 recipes propagated from its farming assumptions. Of the basic graph's flagged items, 289 are in Gardening and 18 in Trees. Dynamic harvest names and growth state are not established by its literal graph.

## Availability restorations and remaining flags

Before the availability patch, Variant B flagged 115 items and 78 recipes. Of these, 36 active/peripheral items and 37 recipes became reachable through 23 reviewed rare loot seeds and the consumed structural anvil selector in Build Trip Hammer. Their original outputs and quantities are unchanged.

`tools/availability_bootstrap.json` records each seed, its actual placed pool and .1/.2 weight. These weights are conservative inferred availability restorations, **not pinned upstream values**. Seeds cover mothballs, generic pop packs, plastic plates, collectible coins, music equipment, three tent kits, three toys and the unanchored oil press. Only a representative stock item is seeded; existing unpack/stack/anchor/recycle recipes supply related states. Installed pool definitions and placed references are verified in the regression; the registration is idempotent.

Build Trip Hammer accepts a consumed Base.BlacksmithAnvil/BenchAnvil/BlockAnvil structural component in addition to existing legacy stock. It creates the original single HCTriphammer, not a duplicate native/legacy anvil. Woodwork8/Mechanics3, learning, other material counts and kept tools remain unchanged.

The 79 remaining Variant B item flags are fully classified:

- 70 old inventory animals: Hunting52 and Dogs18. These are not native B42 animal sources and were not restored. They account for33 flagged kill-animal recipes.
- Two legacy armour compatibility/helper objects: HCArmorchainmail and HCEquiparmor. Old chainmail intentionally remains loadable as Normal; fresh crafting produces HCArmorchainmailWearable. Its conversion recipe requires existing old stock and accounts for one flag.
- Six retired legacy anvil states: HCAnvil/2, HCAnvillead/2 and HCAnvilstone/2. Native anvils are accepted by repaired active progression. Their three anchor/unanchor compatibility cycles account for six flags; no duplicate anvil loot was introduced.
- One retired old water state: HCClayteapotfull. Its empty original ID and pottery production are absent from the current port; retaining its Drainable class preserves old saves. The purification compatibility recipe accounts for one flag. A future native fluid pottery adaptation must preserve that class rather than changing an existing save ID.

Thus the 41 remaining recipe flags are33 animal recipes, one old-chainmail conversion, six legacy-anvil compatibility recipes and one retired-teapot purification recipe. These are explicit compatibility/retired states, not41 newly discovered active gameplay bugs.

## Limits of the graph

Both tools optimistically seed every declared vanilla ID and matching Lua literals, including some non-source references, rather than proving actual loot or crafting acquisition. They skip kept-tool availability and treat tags/fluids as available. They do not validate item state, skill/learning gates, native eligibility, probabilities, or executable callback branches. The native crafting/tag/packaging/timer tests provide that evidence for their tested scenarios only.

`analyze_gaps.py` finds zero unknown input/output item IDs and zero dangling book recipe names in the parsed model. That is an ID consistency check, not proof that all items can be acquired. `no_source.json` is a review list, not a loot generation instruction. Residual compatibility/retired content was not given new sources solely to eliminate diagnostic counts.

Pinned source: [Hydrocraft 917d37d4](https://github.com/brosseaualex/Hydrocraft/tree/917d37d4ed526f429e1525316c9fab487bbf7257). Native game files and decompiled references remain outside the repository.

## Validation and native follow-up

`test_reachability_support.py`:4 tests pass. `test_availability_bootstrap.py`:3 tests pass, including execution of installed native pool definitions, matching placed references, exact manifest weights, duplicate protection, declared IDs, recipe gates and current callback bindings. `tools/lab_availability.lua` provides the disposable-profile native23-pool assertion and real TripHammer craft; successful game execution must be recorded separately. The static/Lupa regression is not itself a native game run.
