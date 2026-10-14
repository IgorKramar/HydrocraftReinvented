-- B42 availability review; inferred rare weights, not upstream loot values.
require "Items/ProceduralDistributions"

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

for _, seed in ipairs(seeds) do
    local pool = ProceduralDistributions.list[seed[1]]
    if pool and pool.items then
        local present = false
        for i = 1, #pool.items, 2 do
            if pool.items[i] == seed[2] then present = true; break end
        end
        if not present then
            table.insert(pool.items, seed[2])
            table.insert(pool.items, seed[3])
        end
    end
end
