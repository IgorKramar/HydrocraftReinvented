-- Stage only as HCRLabProgression.lua in the disposable HCRLab mod/profile.
require "HCRLabCraft"
HCRLabProgression = HCRLabProgression or {}

local function check(ok, message) if not ok then error(message) end end
local function spawn(inv, name, count)
    local list = {}
    for i = 1, count or 1 do
        local item = inv:AddItem(name)
        check(item ~= nil, "cannot create fixture ingredient: " .. name)
        list[#list + 1] = item
    end
    return list
end
local function result(outputs, name)
    local found
    for i = 0, outputs:size() - 1 do
        if outputs:get(i):getFullType() == name then
            check(not found, "unexpected duplicate output: " .. name)
            found = outputs:get(i)
        end
    end
    check(found ~= nil, "missing output: " .. name)
    return {found}
end
local function consumed(items)
    for _, item in ipairs(items) do check(item:getContainer() == nil, "retained ingredient: " .. item:getFullType()) end
end
local function craft(player, name, groups)
    local outputs = HCRLabCraft.nativeCraft(player, HCRLabCraft.findRecipe(name), groups)
    print("[HCRLabProgression] " .. name .. " native craft PASS")
    return outputs
end
local function train(player, perk, level)
    local attempts = 0
    while player:getPerkLevel(perk) < level and attempts < 20 do
        player:getXp():AddXP(perk, 10000)
        attempts = attempts + 1
    end
    check(player:getPerkLevel(perk) >= level, "native fixture skill gate not reached: " .. tostring(perk))
end

local function runChain(player, inv)
    local trowel = spawn(inv, "Base.MasonsTrowel")
    local concrete = spawn(inv, "Base.BucketConcreteFull")
    local bricks = spawn(inv, "Base.ClayBrick", 50)
    local smelter = result(craft(player, "Make Smelter", {bricks, concrete, trowel}), "Hydrocraft.HCSmelter")
    consumed(bricks); consumed(concrete)
    check(trowel[1]:getContainer() == inv, "smelter consumed kept trowel")
    local anchored = result(craft(player, "Anchor Smelter", {smelter}), "Hydrocraft.HCSmelter2")
    consumed(smelter)

    local hammer = spawn(inv, "Base.SmithingHammer")
    local tongs = spawn(inv, "Base.Tongs")
    local anvil = spawn(inv, "Base.StoneAnvil")
    local gloves = spawn(inv, "Base.Gloves_LeatherGloves")
    local scrap = spawn(inv, "Base.CopperScrap", 2)
    local sheet = result(craft(player, "Forge Large Copper Sheet", {scrap, hammer, tongs, anvil}), "Hydrocraft.HCCoppersheetlarge")
    consumed(scrap)
    local torch = spawn(inv, "Base.BlowTorch")
    local torchUses = torch[1]:getCurrentUses()
    local mask = spawn(inv, "Base.WeldingMask")
    local pipe = result(craft(player, "Make Copper Pipe", {sheet, torch, gloves, mask}), "Hydrocraft.HCCopperpipe")
    consumed(sheet)
    check(torch[1]:getCurrentUses() == torchUses - 1, "copper pipe needs exactly one native torch use")
    check(pipe[1]:getContainer() == inv, "missing usable copper pipe")

    local bar = spawn(inv, "Base.SteelBar")
    local ingot = spawn(inv, "Base.SteelIngot")
    local screw = spawn(inv, "Base.Screws")
    result(craft(player, "Make Lever", {bar, ingot, screw, hammer, tongs, gloves, anvil}), "Hydrocraft.HCLever")
    consumed(bar); consumed(ingot); consumed(screw)

    local cans = spawn(inv, "Base.PopEmpty", 4)
    local coal = spawn(inv, "Base.Charcoal")
    local lighter = spawn(inv, "Base.Lighter")
    local mold = spawn(inv, "Base.ClayIngotMold")
    result(craft(player, "Recycle Aluminum Cans", {cans, coal, lighter, mold, tongs, gloves, anchored}), "Hydrocraft.HCAluminumingot")
    consumed(cans)
    check(anchored[1]:getContainer() == inv, "recycling consumed kept smelter")

    local steel = spawn(inv, "Base.SteelIngot")
    local shears = result(craft(player, "Make Steel Pruning Shears", {steel, hammer, tongs, gloves, anvil}), "Hydrocraft.HCPruningsheers")
    consumed(steel)
    local planks, nails = spawn(inv, "Base.Plank", 10), spawn(inv, "Base.Nails", 10)
    local sticks = spawn(inv, "Base.WoodenStick2", 2)
    local carpentryHammer, saw = spawn(inv, "Base.Hammer"), spawn(inv, "Base.Saw")
    local bench = result(craft(player, "Make Workbench", {planks, nails, sticks, carpentryHammer, saw}), "Hydrocraft.HCWorkbench")
    local wateringCan = spawn(inv, "Base.WateredCan")
    local spray = spawn(inv, "Base.GardeningSprayEmpty")
    local compost = spawn(inv, "Base.CompostBag")
    local amount = HCRLabCraft.findRecipe("Make Gardening Workbench"):getInputs():get(13):getIntAmount()
    while #compost * compost[1]:getCurrentUses() < amount do
        compost[#compost + 1] = spawn(inv, "Base.CompostBag")[1]
    end
    local garden = result(craft(player, "Make Gardening Workbench", {
        spawn(inv,"Base.Notebook",3), spawn(inv,"Hydrocraft.HCClayflowerpot",3),
        spawn(inv,"Hydrocraft.HCMysteryseedspacket",3), spawn(inv,"Hydrocraft.HCDirt"),
        gloves, spawn(inv,"Base.Apron_Leather"), spawn(inv,"Base.HandShovel"), shears,
        spawn(inv,"Base.Rake"), spawn(inv,"Base.Shovel"), wateringCan, spray,
        spawn(inv,"Hydrocraft.HCGardenhose",10), compost, bench,
    }), "Hydrocraft.HCGardenbench")
    consumed(wateringCan); consumed(spray); consumed(shears); consumed(bench)
    check(garden[1]:getContainer() == inv, "gardening bench unavailable")
end

function HCRLabProgression.run(player, profile)
    check(profile == "HCRLab" and player and not isClient() and not isServer(), "explicit offline HCRLab required")
    train(player, Perks.MetalWelding, 6)
    train(player, Perks.Maintenance, 2)
    train(player, Perks.Woodwork, 4)
    train(player, Perks.Farming, 1)
    local inv, original, learned = player:getInventory(), {}, {}
    for i = 0, inv:getItems():size() - 1 do original[inv:getItems():get(i):getID()] = true end
    for _, name in ipairs({"Make Smelter", "Forge Large Copper Sheet", "Make Copper Pipe", "Make Lever",
                           "Recycle Aluminum Cans", "Make Steel Pruning Shears", "Make Gardening Workbench"}) do
        if not player:getKnownRecipes():contains(name) then
            player:getKnownRecipes():add(name); learned[#learned + 1] = name
        end
    end
    local ok, err = pcall(runChain, player, inv)
    for i = inv:getItems():size() - 1, 0, -1 do
        local item = inv:getItems():get(i)
        if not original[item:getID()] then inv:Remove(item) end
    end
    for _, name in ipairs(learned) do player:getKnownRecipes():remove(name) end
    print("[HCRLabProgression] chained community blockers " .. (ok and "PASS" or "FAIL: " .. tostring(err)))
    return ok
end
