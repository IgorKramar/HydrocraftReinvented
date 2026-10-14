-- Stage only as HCRLabMilk.lua in the disposable, offline HCRLab profile.
require "HCRLabCraft"
HCRLabMilk = HCRLabMilk or {}
local function check(ok, message) if not ok then error(message) end end
local function spawn(inv, name)
    local item = inv:AddItem(name)
    check(item ~= nil, "cannot create milk fixture " .. name)
    return {item}
end
local function testCoffee(player, inv)
    local carton = spawn(inv, "Base.Milk")
    local fluid = carton[1]:getFluidContainer()
    local before = fluid:getAmount()
    check(math.abs(before - 1.0) < 0.0001, "native Milk fixture must contain one litre")
    local recipe = HCRLabCraft.findRecipe("Add Milk From Carton")
    HCRLabCraft.nativeCraft(player, recipe, {spawn(inv,"Hydrocraft.HCCoffeeblacksugar"),carton})
    check(carton[1]:getContainer() == inv, "partial coffee recipe destroyed its carton")
    check(math.abs(fluid:getAmount() - (before - 0.1)) < 0.0001, "coffee must consume 0.1 litre")
end
local function testWholeNative(player, inv)
    local carton = spawn(inv, "Base.Milk")
    local recipe = HCRLabCraft.findRecipe("Make Cup of Hot Chocolate (Carton Milk)")
    local outputs = HCRLabCraft.nativeCraft(player, recipe, {spawn(inv,"Base.Mugl"),carton,spawn(inv,"Hydrocraft.HCCoco")})
    check(carton[1]:getContainer() == inv, "whole milk volume recipe destroyed reusable carton")
    check(carton[1]:getFluidContainer():getAmount() < 0.0001, "hot chocolate must consume all one litre")
    local template = instanceItem("Hydrocraft.HCCococup")
    local result = outputs:get(0)
    check(result and result:getFullType() == "Hydrocraft.HCCococup", "hot chocolate output missing")
    for _, getter in ipairs({"getCalories", "getCarbohydrates", "getLipids", "getProteins", "getHungChange"}) do
        check(math.abs(result[getter](result) - template[getter](template)) < 0.0001,
            "native milk route changed existing scripted nutrition: " .. getter)
    end
end
local function testLegacyFood(player, inv)
    local milk = spawn(inv,"Hydrocraft.HCUHTmilk")
    local uses = milk[1]:getCurrentUses()
    check(uses > 1,"legacy milk must have multiple hunger-unit portions")
    HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe("Make Cup of Hot Chocolate"),
        {spawn(inv,"Base.Mugl"),milk,spawn(inv,"Hydrocraft.HCCoco")})
    check(milk[1]:getContainer() == inv and milk[1]:getCurrentUses() == uses - 1,
        "legacy HC Food milk portion changed")
end
local function testEmptyCarton(player, inv)
    local carton = spawn(inv,"Base.Milk")
    local outputs = HCRLabCraft.nativeCraft(player,HCRLabCraft.findRecipe("Pour Out Milk"),{carton})
    check(carton[1]:getContainer() == nil,"pour-out duplicated the full native carton")
    check(outputs:size() == 1 and outputs:get(0):getFullType() == "Hydrocraft.HCMilkempty",
        "pour-out must create exactly one legacy empty carton")
end

function HCRLabMilk.run(player, profile)
    check(profile == "HCRLab" and player and not isClient() and not isServer(),"explicit offline HCRLab required")
    local inv, original = player:getInventory(), {}
    for i = 0, inv:getItems():size() - 1 do original[inv:getItems():get(i):getID()] = true end
    local scenarios={{"partial carton milk",testCoffee},{"whole carton milk volume",testWholeNative},
                     {"legacy food milk portion",testLegacyFood},{"whole empty carton conversion",testEmptyCarton}}
    local failures = 0
    for _, scenario in ipairs(scenarios) do
        local ok, err = pcall(scenario[2],player,inv)
        if not ok then failures = failures + 1 end
        print("[HCRLabMilk] " .. scenario[1] .. " " .. (ok and "PASS" or "FAIL: " .. tostring(err)))
        for i = inv:getItems():size() - 1, 0, -1 do
            local item = inv:getItems():get(i)
            if not original[item:getID()] then inv:Remove(item) end
        end
    end
    print("[HCRLabMilk] native regressions total=4 failures=" .. failures)
    return failures
end
