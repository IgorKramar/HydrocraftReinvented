# Petrol and empty-container migration, native 42.21

86 reviewed input lines are recorded in `tools/petrol_container_migrations.json`:
64 petrol portions and 22 whole empty physical containers. The migration tool
checks each recipe/input before changing it and rejects unexpected concurrent
changes. Repeat application preserves the current scripts unchanged.

The pinned Hydrocraft `917d37d4ed526f429e1525316c9fab487bbf7257` recipes
distinguish `EmptyPetrolCan` from `PetrolCan=N`. Original source files, names,
input lines and recipe line numbers are recorded individually. Chemistry
recipes come from the original `Alchemy.txt`; converted output aliases include
`Flour` → `Flour2` and `Cornflour` → `Cornflour2`. The added current aluminium
recycling recipe has no upstream counterpart and is explicitly marked
`current_added_recipe`, with an empty `legacy_input`.

B41's PetrolCan has [UseDelta .125 in the script-data reference](https://undeniable.info/pz/wiki/item.php?Name=PetrolCan).
Native 42.21 `generated/items/normal.txt` declares PetrolCan as `base:normal`
with a FluidContainer capacity of 10 L. Therefore one source charge becomes
1.25 L, twenty charges become 25 L, and sixteen become 20 L. The recipes use
the named native can as a kept provider followed by `-fluid ... [Petrol]`.
Native `CraftRecipeManager.consumeInputItemList` uses the child fluid quantity
as its target and pools available fluid over eligible item resources, so amounts
larger than one can's capacity can be collected from several cans.

Whole empty cans, buckets, jars, bottles and ClayMug alternatives use
`ItemCount;ItemIsFluid;IsEmpty`. Native `CraftRecipeData.processDestroyAndUsedItems`
otherwise skips FluidContainer items. `InputScript` checks `IsEmpty` against
the fluid contents when a fluid component exists; the named nonfluid
Hydrocraft clay mug alternatives remain eligible. `ItemIsFluid` supplies fluid
filtering for wildcard inputs, and does not exclude explicitly named alternatives.

No output, callback or machine ingredient was changed. In particular, the
upstream "Add Gasoline to Biodiesel" returns a fresh PetrolCan while consuming
a fuel charge; its output behaviour remains the pinned source behaviour.

Validation: four offline regressions verify manifest application, repeat-run
idempotence, original petrol quantities, resource conservation, rejection of
empty/wrong-fluid providers, physical shell eligibility and review conflicts.
The fourteen existing playability regressions also pass. These checks are not
an engine execution claim.

`tools/lab_petrol_containers.lua` is an explicit private-lab helper, without
events. Stage it after `lab_crafting.lua` and call
`HCRLabPetrol.run(player, "HCRLab")`. It exercises real native 25 L pooling,
1.25 L partial use and whole empty-can replacement; checks original can
identities, depleted/filled rejection and remaining fluid. All three scenarios
passed in the installed 42.21 client: 25 L pooled fuel retained three can IDs,
partial use spent exactly 1.25 L, and biodiesel accepted only an empty physical
can, consumed it once and retained the funnel.
