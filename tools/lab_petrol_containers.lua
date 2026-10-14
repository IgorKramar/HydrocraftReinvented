-- Stage only in private HCRLab. Explicit entry, no events or production hooks.
-- Requires tools/lab_crafting.lua staged first; uses its genuine native action.
HCRLabPetrol = HCRLabPetrol or {}

local function check(value, message)
    if not value then error("HCRLabPetrol: " .. message) end
end

local function add(inv, kind)
    local item = inv:AddItem(kind)
    check(item, "missing item " .. kind)
    return item
end

local function configure(player, recipe, groups)
    local logic = HandcraftLogic.new(player, nil, nil)
    local containers = ArrayList.new()
    containers:add(player:getInventory())
    logic:setContainers(containers)
    logic:setRecipe(recipe)
    logic:setManualSelectInputs(true)
    logic:clearManualInputs()
    local inputs = recipe:getInputs()
    check(inputs:size() == #groups, "unexpected native input count")
    for i = 0, inputs:size() - 1 do
        local items = ArrayList.new()
        for _, item in ipairs(groups[i + 1]) do items:add(item) end
        if not logic:setManualInputsFor(inputs:get(i), items) then return nil end
    end
    return logic
end

local function available(player, recipe, groups)
    local logic = configure(player, recipe, groups)
    return logic ~= nil and logic:getRecipeData():canConsumeInputs(logic:getSourceResources())
end

local function petrol(inv, amount)
    local item = add(inv, "Base.PetrolCan")
    local fluid = item:getFluidContainer()
    fluid:adjustAmount(0)
    if amount > 0 then fluid:addFluid(Fluid.Petrol, amount) end
    return item
end

function HCRLabPetrol.run(player, profile)
    check(profile == "HCRLab", "private profile guard")
    check(HCRLabCraft and HCRLabCraft.nativeCraft, "stage lab_crafting first")
    local inv = player:getInventory()
    -- Twenty legacy charges = 25 L, pooled from three physical 10 L cans.
    local recipe = HCRLabCraft.findRecipe("Fill Empty Metal Barrel With Gasoline")
    local cans = {petrol(inv, 10), petrol(inv, 10), petrol(inv, 10)}
    local barrel = add(inv, "Hydrocraft.HCBarrelmetalempty")
    local funnel = add(inv, "Hydrocraft.HCFunnel")
    local groups = {cans, {barrel}, {funnel}}
    check(available(player, recipe, groups), "25 L pooling unavailable")
    HCRLabCraft.nativeCraft(player, recipe, groups)
    local remaining = 0
    for _, can in ipairs(cans) do
        check(inv:contains(can), "fuel use removed original physical can")
        remaining = remaining + can:getFluidContainer():getAmount()
    end
    check(math.abs(remaining - 5) < 0.0001, "25 L not conserved: " .. remaining)
    groups[2] = {add(inv, "Hydrocraft.HCBarrelmetalempty")}
    check(not available(player, recipe, groups), "remaining 5 L allows a second 25 L craft")
    print("[HCRLabPetrol] PASS 25L pooled fuel; 3 can identities retained; repeat denied")

    -- A single macerator/electrolyzer charge is 1.25 L, never a whole can.
    recipe = HCRLabCraft.findRecipe("Use Electrolyzer")
    player:learnRecipe(recipe:getName())
    local machine = add(inv, "Hydrocraft.HCElectrolyzer")
    local partial = petrol(inv, 2.5)
    local powders = {}
    for i = 1, 12 do powders[i] = add(inv, "Hydrocraft.HCObsidianpowder") end
    groups = {{machine}, {partial}, powders}
    check(available(player, recipe, groups), "partial fuel unavailable")
    HCRLabCraft.nativeCraft(player, recipe, groups)
    check(inv:contains(partial), "partial fuel consumed can identity")
    check(math.abs(partial:getFluidContainer():getAmount() - 1.25) < 0.0001,
        "partial charge not 1.25 L")
    print("[HCRLabPetrol] PASS 1.25L charge; original partial can retained")

    -- Empty can is physically replaced when storing biodiesel. Filled cans fail.
    recipe = HCRLabCraft.findRecipe("Store Biodiesel")
    player:learnRecipe(recipe:getName())
    local wash = add(inv, "Hydrocraft.HCWashtubwashedbiodiesel")
    local can = petrol(inv, 1)
    groups = {{wash}, {can}, {funnel}}
    check(not available(player, recipe, groups), "filled can passes empty-shell input")
    can:getFluidContainer():adjustAmount(0)
    check(available(player, recipe, groups), "empty physical can rejected")
    HCRLabCraft.nativeCraft(player, recipe, groups)
    check(not inv:contains(can), "empty physical can survived consumption")
    check(inv:contains(funnel), "kept funnel consumed")
    print("[HCRLabPetrol] PASS empty-can eligibility; shell consumed once; tool retained")
end
