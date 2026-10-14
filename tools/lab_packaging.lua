-- Explicit offline HCRLab only: HCRLabPackaging.run(player, "HCRLab").
require "HCRLabCraft"
require "HCR_Packaging"
HCRLabPackaging = HCRLabPackaging or {}
local function check(ok, message) if not ok then error(message) end end
local function cans(inv, name)
    local result = {}
    for i = 1, 6 do
        result[i] = inv:AddItem(name)
        check(result[i] ~= nil, "cannot create packaging fixture " .. name)
    end
    return result
end
local function total(items, fluid)
    local result = 0
    for _, item in ipairs(items) do
        result = result + (fluid and item:getFluidContainer():getAmount() or item:getCalories())
    end
    return result
end
local function cycle(player, inv, name, packName, unpackName, fluid)
    local recipe = HCRLabCraft.findRecipe(packName)
    local inputs = cans(inv, name)
    local half = inputs[1]
    if fluid then
        local fc = half:getFluidContainer()
        fc:adjustAmount(fc:getAmount() / 2)
    else
        half:setCurrentUses(half:getCurrentUses() - 1)
    end
    check(not recipe:OnTestItem(half, player), "native OnTest accepted partly consumed " .. name)
    local accepted = pcall(HCRLabCraft.nativeCraft, player, recipe, {inputs})
    check(not accepted, "native recipe packed partly consumed " .. name)
    for _, item in ipairs(inputs) do check(item:getContainer() == inv, "rejected pack consumed input") end
    local complete = cans(inv, name)
    for _, item in ipairs(complete) do check(recipe:OnTestItem(item, player), "full factory can rejected") end
    local before = total(complete, fluid)
    local pack = HCRLabCraft.nativeCraft(player, recipe, {complete})
    check(pack:size() == 1, "one pack expected")
    local output = HCRLabCraft.nativeCraft(player, HCRLabCraft.findRecipe(unpackName), {{pack:get(0)}})
    local restored = {}
    for i = 0, output:size() - 1 do restored[#restored + 1] = output:get(i) end
    check(#restored == 6, "six unpacked cans expected")
    check(math.abs(total(restored, fluid) - before) < 0.001,
        "pack/unpack gained liquid or calories: " .. name)
end
function HCRLabPackaging.run(player, profile)
    check(profile == "HCRLab" and player and not isClient() and not isServer(), "explicit offline HCRLab required")
    local inv, original = player:getInventory(), {}
    for i = 0, inv:getItems():size() - 1 do original[inv:getItems():get(i):getID()] = true end
    local failed = 0
    for _, fixture in ipairs({{"Base.Pop", "Pack Pop", "Unpack Pop", true},
                              {"Hydrocraft.HCBeercan1", "Pack Beer", "Open Pack of Beer", false}}) do
        local ok, err = pcall(cycle, player, inv, fixture[1], fixture[2], fixture[3], fixture[4])
        if not ok then failed = failed + 1 end
        print("[HCRLabPackaging] " .. fixture[1] .. " " .. (ok and "PASS" or "FAIL: " .. tostring(err)))
        for i = inv:getItems():size() - 1, 0, -1 do
            local item = inv:getItems():get(i)
            if not original[item:getID()] then inv:Remove(item) end
        end
    end
    print("[HCRLabPackaging] native conservation regressions total=2 failures=" .. failed)
    return failed
end
