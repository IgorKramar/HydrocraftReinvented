-- Stage ONLY in the private HCRLab mod/profile. No automatic event registration.
-- Entry: HCRLabCraft.run(getSpecificPlayer(0), "HCRLab")
-- Uses the same native perform -> add outputs -> OnCreate -> use inputs order
-- as 42.21 ISHandcraftAction.performRecipe. No production recipe overrides.
HCRLabCraft = HCRLabCraft or {}

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

local function pack(player, inv)
    local cans = spawn(inv, "Base.Pop", 6)
    local outputs = nativeCraft(player, findRecipe("Pack Pop"), {cans})
    consumed(cans)
    check(outputCount(outputs, "Hydrocraft.HCPoppack1") == 1, "expected exactly one six-pack")
end

local function corn(player, inv)
    local recipe = findRecipe("Shuck Corn")
    local cobs = spawn(inv, "Base.Corn", 1)
    local knives = spawn(inv, findEligibleType(recipe:getInputs():get(1)), 1)
    local outputs = nativeCraft(player, recipe, {cobs, knives})
    consumed(cobs)
    check(outputCount(outputs, "Hydrocraft.HCCornseeds") == 20, "expected exactly 20 seeds")
    check(knives[1]:getContainer() == inv, "kept knife was consumed")
end

local function smithingTongs(player, inv)
    local recipe = findRecipe("Make Armor")
    local rings = spawn(inv, "Hydrocraft.HCRingsteel", 16)
    local groups = {rings}
    for i = 1, recipe:getInputs():size() - 1 do
        groups[#groups + 1] = spawn(inv, findEligibleType(recipe:getInputs():get(i)), 1)
    end
    local tongs = groups[3][1]
    local uses, condition = tongs:getCurrentUses(), tongs:getCondition()
    local outputs = nativeCraft(player, recipe, groups)
    consumed(rings)
    check(outputCount(outputs, "Hydrocraft.HCArmorchainmailWearable") == 1,
        "expected one wearable chainmail from sixteen rings")
    check(tongs:getContainer() == inv and tongs:getCurrentUses() == uses,
        "smithing consumed or depleted kept tongs")
    check(tongs:getCondition() == condition, "smithing unexpectedly damaged unflagged tongs")
    for i = 2, #groups do
        check(groups[i][1]:getContainer() == inv, "smithing consumed kept tool " .. groups[i][1]:getFullType())
    end
end

local function boxing(player, inv)
    local recipe = findRecipe("Store 50 in a Box")
    -- Do not inject tags: an empty eligibility set must fail this regression.
    local things = spawn(inv, findEligibleType(recipe:getInputs():get(0)), 50)
    local outputs = nativeCraft(player, recipe, {things})
    consumed(things)
    check(outputCount(outputs, "Hydrocraft.BoxOfThings") == 1, "expected one box")
    local box = outputs:get(0)
    check(box:getModData().StoredAmount == 50, "box recorded wrong item count")
    check(box:getModData().StoredFullType == things[1]:getFullType(), "box recorded wrong type")
end

local function splitCheese(player, inv)
    local recipe = findRecipe("Cut Cheese Wheel")
    local wheels = spawn(inv, "Hydrocraft.HCCheesewheel", 1)
    local wheel = wheels[1]
    -- A partly eaten wheel exposes default-value copying and first-output-only bugs.
    wheel:consumeHunger(math.abs(wheel:getHungChange()) / 2)
    wheel:setAge(2)
    local calories, hunger = wheel:getCalories(), wheel:getHungChange()
    local fresh, rotten = wheel:isFresh(), wheel:isRotten()
    local threshold = rotten and wheel:getOffAgeMax() or wheel:getOffAge()
    local relativeAge = wheel:getAge() / threshold
    local knives = spawn(inv, findEligibleType(recipe:getInputs():get(1)), 1)
    local outputs = nativeCraft(player, recipe, {wheels, knives})
    consumed(wheels)
    check(outputCount(outputs, "Base.Cheese") == 8, "expected eight cheese portions")
    local total = 0
    for i = 0, outputs:size() - 1 do
        local item = outputs:get(i)
        if item:IsFood() then
            check(math.abs(item:getCalories() - calories / 8) < 0.01, "piece nutrition differs")
            check(math.abs(item:getHungChange() - hunger / 8) < 0.0001, "piece hunger differs")
            check(item:isFresh() == fresh and item:isRotten() == rotten, "piece freshness state changed")
            local outputThreshold = rotten and item:getOffAgeMax() or item:getOffAge()
            check(math.abs(item:getAge() / outputThreshold - relativeAge) < 0.001,
                "piece relative food age reset")
            total = total + item:getCalories()
        end
    end
    check(math.abs(total - calories) < 0.01, "calories not conserved")
end

local function beer(player, inv)
    local packs = spawn(inv, "Hydrocraft.HCBeercan1pack", 1)
    local outputs = nativeCraft(player, findRecipe("Open Pack of Beer"), {packs})
    consumed(packs)
    check(outputCount(outputs, "Hydrocraft.HCBeercan1") == 6, "expected six beer cans")
end

local function juice(player, inv)
    local recipe = findRecipe("Make Bottle of Juice (Orange Juice)")
    local bottle = spawn(inv, "Base.PopBottle", 1)
    local oranges = spawn(inv, "Base.Orange", 4)
    local juicer = spawn(inv, "Hydrocraft.HCJuicer", 1)
    local outputs = nativeCraft(player, recipe, {bottle, oranges, juicer})
    consumed(bottle)
    consumed(oranges)
    check(outputCount(outputs, "Hydrocraft.HCPopbottleorangejuice") == 1, "expected one orange juice bottle")
    check(juicer[1]:getContainer() == inv, "juicer was consumed")
end

local function smokeMeat(player, inv)
    local recipe = findRecipe("Smoke Meat")
    local smoker = spawn(inv, "Hydrocraft.HCSmokerfull", 1)
    local meat = spawn(inv, "Base.FishFillet", 1)
    local water = spawn(inv, "Base.WaterBottle", 1)
    local fluid = water[1]:getFluidContainer()
    check(fluid ~= nil, "native water bottle has no fluid container")
    fluid:Empty()
    fluid:addFluid(Fluid.Water, 0.5)
    local leaves = spawn(inv, "Hydrocraft.HCHickoryleaves", 1)
    local ignition = spawn(inv, findEligibleType(recipe:getInputs():get(4)), 1)
    local charcoal = spawn(inv, "Base.Charcoal", 1)
    local outputs = nativeCraft(player, recipe, {smoker, meat, water, leaves, ignition, charcoal})
    consumed(meat)
    check(outputCount(outputs, "Hydrocraft.HCSmokedfishfillet") == 1, "expected one smoked fish fillet")
    check(smoker[1]:getContainer() == inv, "smoker was consumed")
end

local function countType(inv, fullType)
    local count = 0
    for i = 0, inv:getItems():size() - 1 do
        if inv:getItems():get(i):getFullType() == fullType then count = count + 1 end
    end
    return count
end

local function bowls(player, inv)
    local recipe = findRecipe("Make Burrito Grande")
    local before = countType(inv, "Base.Bowl")
    local tortilla = spawn(inv, "Hydrocraft.HCTortillaflour", 1)
    local cheese = spawn(inv, "Hydrocraft.HCGratedcheese", 1)
    local beans = spawn(inv, "Hydrocraft.HCCannedrefriedbeansopen", 1)
    local partial = spawn(inv, "Hydrocraft.HCTacosaucebowl", 1)
    local wholeA = spawn(inv, "Hydrocraft.HCGuacamolebowl", 1)
    local wholeB = spawn(inv, "Hydrocraft.HCSalsabowl", 1)
    local cream = spawn(inv, "Hydrocraft.HCSourcream", 1)
    local pan = spawn(inv, "Base.Pan", 1)
    local remainingSauceUses = partial[1]:getCurrentUses()
    check(remainingSauceUses > 1, "sauce fixture needs more than one portion")
    nativeCraft(player, recipe, {tortilla, cheese, beans, partial, wholeA, wholeB, cream, pan})
    consumed(wholeA)
    consumed(wholeB)
    check(partial[1]:getContainer() == inv and partial[1]:getCurrentUses() == remainingSauceUses - 1,
        "partial sauce was emptied or not consumed correctly")
    check(countType(inv, "Base.Bowl") - before == 2, "expected two emptied bowls, not three")
end

local function mashedPotatoPotCycle(player, inv)
    local potatoes = spawn(inv, "Base.Potato", 2)
    local peeler = spawn(inv, "Hydrocraft.HCPotatopeeler", 1)
    local pot = spawn(inv, "Base.Pot", 1)
    local water = spawn(inv, "Base.WaterBottle", 1)
    water[1]:getFluidContainer():Empty()
    water[1]:getFluidContainer():addFluid(Fluid.Water, 0.5)
    local masher = spawn(inv, "Hydrocraft.HCPotatomasher", 1)
    local result = nativeCraft(player, findRecipe("Make Plain Mashed Potatoes"),
        {potatoes, peeler, pot, water, masher})
    consumed(potatoes)
    consumed(pot)
    check(result:size() == 1, "one mashed potato pot expected")
    local emptyBowls = spawn(inv, "Base.Bowl", 2)
    local oldPots = {}
    for i = 0, inv:getItems():size() - 1 do
        local item = inv:getItems():get(i)
        if item:getFullType() == "Base.Pot" then oldPots[item:getID()] = true end
    end
    local portions = nativeCraft(player, findRecipe("Make Bowl of Plain Mashed Potatos"),
        {{result:get(0)}, emptyBowls})
    consumed(emptyBowls)
    check(result:get(0):getContainer() == nil, "mashed potato pot retained")
    check(outputCount(portions, "Hydrocraft.HCMashedpotatosplainbowl") == 2, "two bowls expected")
    local returned = 0
    for i = 0, inv:getItems():size() - 1 do
        local item = inv:getItems():get(i)
        if item:getFullType() == "Base.Pot" and not oldPots[item:getID()] then returned = returned + 1 end
    end
    check(returned == 1, "must return precisely one original pot, got " .. returned)
end

local function missingSkill(player, name)
    local recipe = findRecipe(name)
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local required = recipe:getRequiredSkill(i)
        if player:getPerkLevel(required:getPerk()) < required:getLevel() then
            return tostring(required:getPerk()) .. ":" .. required:getLevel()
        end
    end
end

function HCRLabCraft.run(player, profile)
    check(profile == "HCRLab", "explicit private HCRLab profile token required")
    check(player and not isClient() and not isServer(), "offline lab player required")
    HCRLabCraft.trainCooking(player, profile)
    local inv = player:getInventory()
    local original = {}
    for i = 0, inv:getItems():size() - 1 do original[inv:getItems():get(i):getID()] = true end
    local learned = {}
    for _, name in ipairs({"Shuck Corn", "Cut Cheese Wheel", "Smoke Meat", "Make Burrito Grande", "Make Armor"}) do
        if not player:getKnownRecipes():contains(name) then
            player:getKnownRecipes():add(name)
            learned[#learned + 1] = name
        end
    end
    local scenarios = {{"six cans consumed", pack}, {"one corn gives twenty seeds", corn},
                       {"boxing consumes items", boxing}, {"all cheese portions inherit food", splitCheese},
                       {"beer package consumed once", beer},
                       {"four oranges consumed for juice", juice, "Make Bottle of Juice (Orange Juice)"},
                       {"whole meat consumed by smoker", smokeMeat, "Smoke Meat"},
                       {"only emptied sauce bowls returned", bowls, "Make Burrito Grande"},
                       {"smithing preserves tongs", smithingTongs, "Make Armor"},
                       {"mashed potatoes recycle one pot", mashedPotatoPotCycle}}
    local failed, skipped = 0, 0
    for _, scenario in ipairs(scenarios) do
        local skill = scenario[3] and missingSkill(player, scenario[3])
        if skill then
            failed = failed + 1
            print("[HCRLabCraft] " .. scenario[1] .. " FAIL: actual fixture still requires " .. skill)
        else
            local ok, err = pcall(scenario[2], player, inv)
            if not ok then failed = failed + 1 end
            print("[HCRLabCraft] " .. scenario[1] .. " " .. (ok and "PASS" or "FAIL: " .. tostring(err)))
        end
        -- Only remove newly created lab items, never pre-existing player items.
        for i = inv:getItems():size() - 1, 0, -1 do
            local item = inv:getItems():get(i)
            if not original[item:getID()] then inv:Remove(item) end
        end
    end
    for _, name in ipairs(learned) do player:getKnownRecipes():remove(name) end
    print("[HCRLabCraft] native regressions: total=" .. #scenarios .. " failed=" .. failed .. " skipped=" .. skipped)
    return failed
end

-- Disposable lab character training through normal native XP/level mechanics.
-- No recipe skill flags or validation functions are changed.
function HCRLabCraft.trainCooking(player, profile)
    check(profile == "HCRLab", "explicit private HCRLab profile token required")
    check(player and not isClient() and not isServer(), "offline lab player required")
    local attempts = 0
    while player:getPerkLevel(Perks.Cooking) < 8 and attempts < 20 do
        player:getXp():AddXP(Perks.Cooking, 10000)
        attempts = attempts + 1
    end
    print("[HCRLabCraft] actual Cooking level=" .. player:getPerkLevel(Perks.Cooking))
    check(player:getPerkLevel(Perks.Cooking) >= 8, "native lab XP failed to reach Cooking 8")
end

-- OnGameStart runs at frame zero, before the engine calculates room lighting.
-- Wait for real daylight rather than bypassing the native darkness restriction.
function HCRLabCraft.schedule(player, profile)
    check(profile == "HCRLab", "explicit private HCRLab profile token required")
    check(player and not isClient() and not isServer(), "offline lab player required")
    local attempts = 0
    local function whenReady(updatedPlayer)
        if updatedPlayer ~= player then return end
        attempts = attempts + 1
        if attempts < 60 then return end
        if not player:tooDarkToRead() then
            Events.OnPlayerUpdate.Remove(whenReady)
            HCRLabCraft.run(player, profile)
        elseif attempts >= 1800 then
            Events.OnPlayerUpdate.Remove(whenReady)
            print("[HCRLabCraft] BLOCKED: native player remains too dark to craft; run in a lit lab area")
        end
    end
    Events.OnPlayerUpdate.Add(whenReady)
    print("[HCRLabCraft] waiting for native lighting and player initialization")
end
