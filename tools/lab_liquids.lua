-- Private HCRLab only. Explicit HCRLabLiquids.run(player,"HCRLab")
HCRLabLiquids = HCRLabLiquids or {}

local function check(condition, message)
    if not condition then error(message) end
end

local function findRecipe(name)
    local all = getScriptManager():getAllCraftRecipes()
    for i = 0, all:size() - 1 do
        if all:get(i):getName() == name then return all:get(i) end
    end
    error("missing native craftRecipe: " .. name)
end

local function findEligibleType(input)
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local item = all:get(i)
        if input:containsItem(item) then return item:getFullName() end
    end
    error("input has no eligible item types: " .. input:getOriginalLine())
end

local function spawn(inv, fullType, count)
    local items = {}
    for i = 1, count do
        local item = inv:AddItem(fullType)
        check(item ~= nil, "cannot create " .. fullType)
        items[i] = item
    end
    return items
end

local function nativeCraft(player, recipe, groups)
    local logic = HandcraftLogic.new(player, nil, nil)
    local containers = ArrayList.new()
    containers:add(player:getInventory())
    logic:setContainers(containers)
    logic:setRecipe(recipe)
    logic:setManualSelectInputs(true)
    logic:clearManualInputs()
    local inputs = recipe:getInputs()
    check(inputs:size() == #groups, "unexpected input count for " .. recipe:getName())
    for i = 0, inputs:size() - 1 do
        local list = ArrayList.new()
        for _, item in ipairs(groups[i + 1]) do list:add(item) end
        check(logic:setManualInputsFor(inputs:get(i), list), "manual input rejected at line " .. i)
    end
    local data = logic:getRecipeData()
    print("[HCRLabCraft] preflight " .. recipe:getName()
        .. " dark=" .. tostring(player:tooDarkToRead())
        .. " allowDark=" .. tostring(recipe:canBeDoneInDark())
        .. " learned=" .. tostring(player:isRecipeKnown(recipe, true))
        .. " applied=" .. data:getAllInputItems():size())
    local ready = data:canConsumeInputs(logic:getSourceResources())
    print("[HCRLabCraft] native input validation " .. recipe:getName() .. "=" .. tostring(ready))
    check(ready, "native inputs unavailable (see preflight): " .. recipe:getName())
    check(logic:performCurrentRecipe(), "native performCurrentRecipe rejected " .. recipe:getName())
    local created = ArrayList.new()
    logic:getCreatedOutputItems(created)
    for i = 0, created:size() - 1 do player:getInventory():AddItem(created:get(i)) end
    data:luaCallOnCreate(player)
    data:processDestroyAndUsedItems(player)
    return data:getAllCreatedItems()
end

-- Reuse the exact native action order in other explicitly staged lab helpers.
HCRLabCraft.nativeCraft = nativeCraft
HCRLabCraft.findRecipe = findRecipe

local function outputCount(outputs, fullType)
    local count = 0
    for i = 0, outputs:size() - 1 do
        if outputs:get(i):getFullType() == fullType then count = count + 1 end
    end
    return count
end

local function consumed(items)
    for _, item in ipairs(items) do
        check(item:getContainer() == nil, "input retained: " .. item:getFullType())
    end
end

local function sterilisingFluids(player, inv)
    for _, fixture in ipairs({
        {"Disinfect Diaper", "Base.Whiskey", "Hydrocraft.HCDiaper", Fluid.Whiskey, 0.5},
        {"Disinfect Diaper (Variant)", "Base.Disinfectant", "Hydrocraft.HCDiaper", Fluid.Alcohol, 0.15},
    }) do
        local material = spawn(inv, fixture[3], 1)
        local bottle = spawn(inv, fixture[2], 1)
        local fc = bottle[1]:getFluidContainer()
        fc:Empty()
        fc:addFluid(fixture[4], fc:getCapacity())
        local before = fc:getAmount()
        nativeCraft(player, findRecipe(fixture[1]), {material, bottle})
        consumed(material)
        check(bottle[1]:getContainer() == inv, "sterilisation consumed the bottle")
        check(math.abs((before - fc:getAmount()) - fixture[5]) < 0.0001,
            "sterilisation fluid delta incorrect: " .. fixture[1])
    end
end

local function eggnogFluid(player, inv)
    local recipe = findRecipe("Make Eggnog Pot")
    local milk = spawn(inv, "Hydrocraft.HCUHTmilk", 1)
    local egg = spawn(inv, findEligibleType(recipe:getInputs():get(1)), 1)
    local bottle = spawn(inv, "Base.Whiskey", 1)
    local fc = bottle[1]:getFluidContainer()
    fc:Empty()
    fc:addFluid(Fluid.Whiskey, 1)
    local pot = spawn(inv, "Base.Pot", 1)
    pot[1]:getFluidContainer():Empty()
    local outputs = nativeCraft(player, recipe, {milk, egg, bottle, pot})
    consumed(egg)
    consumed(pot)
    check(bottle[1]:getContainer() == inv, "eggnog consumed whiskey bottle")
    check(math.abs(fc:getAmount() - 0.75) < 0.0001, "eggnog must use 0.25L whiskey")
    check(outputCount(outputs, "Hydrocraft.HCEggnogpot") == 1, "one eggnog pot expected")
end
function HCRLabLiquids.run(player, profile)
    check(profile == "HCRLab", "explicit private HCRLab profile token required")
    check(player and not isClient() and not isServer(), "offline lab player required")
    HCRLabCraft.trainCooking(player, profile)
    local inv = player:getInventory()
    local original = {}
    for i = 0, inv:getItems():size() - 1 do original[inv:getItems():get(i):getID()] = true end
    local learned = not player:getKnownRecipes():contains("Make Eggnog Pot")
    if learned then player:getKnownRecipes():add("Make Eggnog Pot") end
    local failed = 0
    for _, scenario in ipairs({{"sterilisation uses measured fluids", sterilisingFluids},
                              {"eggnog uses quarter litre whiskey", eggnogFluid}}) do
        local ok, err = pcall(scenario[2], player, inv)
        if not ok then failed = failed + 1 end
        print("[HCRLabLiquids] " .. scenario[1] .. " " .. (ok and "PASS" or "FAIL: " .. tostring(err)))
        for i = inv:getItems():size() - 1, 0, -1 do
            local item = inv:getItems():get(i)
            if not original[item:getID()] then inv:Remove(item) end
        end
    end
    if learned then player:getKnownRecipes():remove("Make Eggnog Pot") end
    print("[HCRLabLiquids] native regressions: failed=" .. failed)
    return failed
end
