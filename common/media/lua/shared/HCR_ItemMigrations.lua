-- Never change the serialized Java class of an existing fullType. Legacy items
-- must first load using their original normal class, then receive a new ID.
require "HCR_FluidMigrations"
require "HCR_DrinkMigrations"
require "HCR_FermentationMigrations"
require "HCR_ItemNames"
HCRItemMigrations = HCRItemMigrations or {}
local replacements = {
    ["Hydrocraft.HCArmorchainmail"] = "Hydrocraft.HCArmorchainmailWearable",
}
local unavailable = {}

function HCRItemMigrations.copyState(source, target)
    target:setConditionFrom(source)
    target:setHaveBeenRepaired(source:getHaveBeenRepaired())
    target:setFavorite(source:isFavorite())
    for key, value in pairs(source:getModData()) do
        target:getModData()[key] = value
    end
    if source:isCustomName() then
        local name=HCRItemNames.custom(source)
        if name then target:setName(name) end
        target:setCustomName(true)
    end
end

function HCRItemMigrations.newReplacement(item)
    if not item then return nil end
    if HCRFermentationMigrations then
        local fermentation=HCRFermentationMigrations.newReplacement(item,HCRItemMigrations.copyState)
        if fermentation then return fermentation end
    end
    if HCRFluidMigrations then
        local fluid = HCRFluidMigrations.newReplacement(item, HCRItemMigrations.copyState)
        if fluid then return fluid end
    end
    if HCRDrinkMigrations then
        local drink = HCRDrinkMigrations.newReplacement(item, HCRItemMigrations.copyState)
        if drink then return drink end
    end
    local targetType = replacements[item:getFullType()]
    if not targetType then return nil end
    local ok, replacement = pcall(instanceItem, targetType)
    if not ok or not replacement or replacement:getCategory() ~= "Clothing" then
        if not unavailable[targetType] then
            print("[HydrocraftReinvented] Item migration unavailable: " .. targetType)
            unavailable[targetType] = true
        end
        return nil -- Keep the loaded original stock intact.
    end
    HCRItemMigrations.copyState(item, replacement)
    return replacement
end

-- Native B42 signature. Also used by the free manual fallback recipe.
function HCRItemMigrations.PrepareChainmail(craftRecipeData, character)
    local inputs = craftRecipeData:getAllConsumedItems()
    local outputs = craftRecipeData:getAllCreatedItems()
    local source
    for i = 0, inputs:size() - 1 do
        if inputs:get(i):getFullType() == "Hydrocraft.HCArmorchainmail" then
            source = inputs:get(i)
            break
        end
    end
    if not source then return end
    for i = 0, outputs:size() - 1 do
        local target = outputs:get(i)
        if target:getFullType() == "Hydrocraft.HCArmorchainmailWearable" then
            HCRItemMigrations.copyState(source, target)
        end
    end
end
