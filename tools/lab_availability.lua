-- Stage only in disposable HCRLab; no event hooks or recipe validation overrides.
require "HCRLabCraft"
-- Server-side distribution files load normally before the explicit world run.
HCRLabAvailability = HCRLabAvailability or {}
local function check(ok, message) if not ok then error(message) end end
local seeds = {
    {"GigamartCleaning", "Hydrocraft.HCMothballsbox", 0.2},
    {"CrateSodaCans", "Hydrocraft.HCPoppack6", 0.2},
    {"KitchenDishes", "Hydrocraft.HCPlasticplate", 0.2},
    {"KitchenDishes", "Hydrocraft.HCPlasticplate2", 0.2},
    {"JewelrySilver", "Hydrocraft.HCCoinsilver", 0.1},
    {"JewelryGold", "Hydrocraft.HCCoingold", 0.1},
    {"MusicStoreLiterature", "Hydrocraft.HCBooksheetmusic", 0.2},
    {"CrateInstruments", "Hydrocraft.HCPhonograph", 0.1},
    {"CrateInstruments", "Hydrocraft.HCHarp", 0.1},
    {"CrateInstruments", "Hydrocraft.HCUkulele", 0.1},
    {"CrateInstruments", "Hydrocraft.HCGuitar", 0.1},
    {"CrateInstruments", "Hydrocraft.HCClarinet", 0.1},
    {"CrateInstruments", "Hydrocraft.HCTrombone", 0.1},
    {"CrateInstruments", "Hydrocraft.HCDrum", 0.1},
    {"CrateInstruments", "Hydrocraft.HCMaracas", 0.1},
    {"CrateInstruments", "Hydrocraft.HCCowbell", 0.1},
    {"CampingStoreTents", "Hydrocraft.HCTentkit2", 0.2},
    {"CampingStoreTents", "Hydrocraft.HCTentkit3", 0.2},
    {"CampingStoreTents", "Hydrocraft.HCTentkit4", 0.2},
    {"CrateToys", "Hydrocraft.HCMagic8ball", 0.2},
    {"CrateToys", "Hydrocraft.HCWiffleball", 0.2},
    {"CrateToys", "Hydrocraft.HCVolleyball", 0.2},
    {"CrateMetalwork", "Hydrocraft.HCOilpress", 0.1},
}
local function placed(pool, value, seen)
    if type(value) ~= "table" or seen[value] then return false end
    seen[value] = true
    if value.name == pool then return true end
    for _, child in pairs(value) do if placed(pool, child, seen) then return true end end
    return false
end
function HCRLabAvailability.pools()
    for _, seed in ipairs(seeds) do
        local pool = ProceduralDistributions.list[seed[1]]
        check(pool and pool.items, "missing pool " .. seed[1])
        check(placed(seed[1], Distributions, {}), "pool not placed " .. seed[1])
        check(getScriptManager():getItem(seed[2]) ~= nil, "absent loot ID " .. seed[2])
        local count = 0
        for i = 1, #pool.items, 2 do
            if pool.items[i] == seed[2] then
                check(pool.items[i+1] == seed[3], "weight drift " .. seed[2]); count = count + 1
            end
        end
        check(count == 1, "loot missing/duplicated " .. seed[2])
    end
    print("[HCRLabAvailability] 23 registered/placed loot seeds PASS")
    return true
end
local function train(player, perk, target)
    local tries = 0
    while player:getPerkLevel(perk) < target and tries < 20 do
        player:getXp():AddXP(perk, 10000); tries = tries + 1
    end
    check(player:getPerkLevel(perk) >= target, "fixture skill unavailable")
end
function HCRLabAvailability.run(player, profile)
    check(profile == "HCRLab" and player and not isClient() and not isServer(), "explicit offline HCRLab required")
    local inv, original = player:getInventory(), {}
    for i = 0, inv:getItems():size()-1 do original[inv:getItems():get(i):getID()] = true end
    local known = player:getKnownRecipes():contains("Build Trip Hammer")
    if not known then player:getKnownRecipes():add("Build Trip Hammer") end
    train(player, Perks.Woodwork, 8); train(player, Perks.Mechanics, 3)
    local function spawn(name, count)
        local result = {}
        for i = 1, count or 1 do
            local item = inv:AddItem(name); check(item ~= nil, "missing fixture " .. name)
            result[#result+1] = item
        end
        return result
    end
    local ok, err = pcall(function()
        HCRLabAvailability.pools()
        local anvil = spawn("Base.BenchAnvil")
        local hammer, saw = spawn("Base.Hammer"), spawn("Base.Saw")
        local output = HCRLabCraft.nativeCraft(player, HCRLabCraft.findRecipe("Build Trip Hammer"), {
            spawn("Hydrocraft.HCWoodbeam",2), spawn("Base.Sledgehammer2"), anvil,
            spawn("Base.IronIngot",2), spawn("Base.IronBar"), spawn("Base.Rope"),
            spawn("Hydrocraft.HCRopethin"), spawn("Hydrocraft.HCPullyiron"),
            spawn("Hydrocraft.HCCrank"), spawn("Hydrocraft.HCLever"),
            spawn("Base.Plank",4), spawn("Base.Nails",12), hammer, saw,
        })
        check(anvil[1]:getContainer() == nil, "structural native anvil not consumed")
        check(hammer[1]:getContainer() == inv and saw[1]:getContainer() == inv, "kept tools consumed")
        check(output:size() == 1 and output:get(0):getFullType() == "Hydrocraft.HCTriphammer", "unexpected output/legacy anvil duplicate")
    end)
    for i = inv:getItems():size()-1, 0, -1 do
        local item = inv:getItems():get(i)
        if not original[item:getID()] then inv:Remove(item) end
    end
    if not known then player:getKnownRecipes():remove("Build Trip Hammer") end
    print("[HCRLabAvailability] native structural anvil " .. (ok and "PASS" or "FAIL: " .. tostring(err)))
    return ok
end
