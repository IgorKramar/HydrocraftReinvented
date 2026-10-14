# B42 input tags and safe generic boxing

Native 42.21 `ResourceLocation.of` lowercases both name and namespace and defaults unqualified names to `base`. Case alone was not the potato bug. The native potato has only `base:isseed`; the mod's potato varieties used an unregistered `Potato` tag.

`Registry.get` returns null for an unknown tag. `ItemTags` indexes items by that returned object, so different unknown tags can share one null group. An unknown Box50 selector could therefore appear eligible because it matched an unrelated HC potato, roasting pan or nylon bag. A nonempty candidate pool alone did not prove correct eligibility.

Native `ModRegistries.init` loads `media/registries.lua` before script loading on both the client and dedicated server. The mod now uses that entry point to register nine author-assigned groups under `hydrocraft:`. Item assignments, input selectors and legacy `getItemsTag` lookups use the same namespaced IDs. Potato recipes combine the explicit native potato with the registered HC potato group. Registry-valid native tags, including `Egg`, remain unchanged.

The unassigned `BucketConcrete` selector is replaced by named native full concrete buckets. The pinned recipes consumed four or eight drainable uses; the old port's keep mode neither selected a correct group nor spent the concrete. The native replacements retain those source quantities and return depleted buckets through the engine.

No Box12/25/50/100 member assignments exist in the current mod or pinned historical source. Generic boxing remains available through an explicitly authorised conservative recovery: the same 35 nonfluid Normal materials for each quantity, derived from existing authored Box/Pack recipe inputs. `tools/boxing_materials.json` records that evidence. This is not described as an upstream whitelist restoration.

Packing sets the native `IsExclusive` input flag, which rejects mixed fullTypes during selection and consumption. `OnTest` also rejects nonmaterials, fluid containers and any stock whose metadata, condition, repairs, favourite status, custom name/weight, wetness, uses, display category or colour would be lost by the existing type/count-only box representation. `BoxOfThings`, Food, Clothing, Weapons and Drainables cannot enter the reviewed list.

`tools/test_input_tags.py` covers independent/idempotent registration, migrated selectors/lookups, reviewed lists and state rejection. `tools/lab_input_tags.lua` performs real `scriptInput.containsItem` checks once per unique selector while separately checking registry resolution. `tools/lab_boxing.lua` supplies a native packing/unpacking roundtrip and negative mixed, food, tool, box, foreign-tag and stateful-stock cases. A full game restart is required to validate the new early registry and rebuilt script caches.
