-- Restricted recovery of generic packing from current explicit packing recipes.
-- No historical Box12/25/50/100 assignments existed in the available source.
HCRBox = HCRBox or {}
HCRBox.materialTypes = {
    "Base.Crayons", "Base.LogStacks4", "Base.RubberBand",
    "Hydrocraft.HCBolt", "Hydrocraft.HCChalk", "Hydrocraft.HCCigarettepack",
    "Hydrocraft.HCCigarettepacklights", "Hydrocraft.HCCigarettepackmenthol",
    "Hydrocraft.HCClothespin", "Hydrocraft.HCCoffeefilterdry", "Hydrocraft.HCCork",
    "Hydrocraft.HCDiaper", "Hydrocraft.HCDirt", "Hydrocraft.HCEmptyballoon",
    "Hydrocraft.HCGlasspipe", "Hydrocraft.HCGlasspipeelbow", "Hydrocraft.HCGlasstesttube",
    "Hydrocraft.HCHotgluestick", "Hydrocraft.HCLumberstack", "Hydrocraft.HCMREbox",
    "Hydrocraft.HCMenstrualpad", "Hydrocraft.HCMothballs", "Hydrocraft.HCNailgunammo",
    "Hydrocraft.HCNut", "Hydrocraft.HCPurifyingtablets", "Hydrocraft.HCRatpoison",
    "Hydrocraft.HCRazorblade", "Hydrocraft.HCResistor", "Hydrocraft.HCRubberbung",
    "Hydrocraft.HCSewingpin", "Hydrocraft.HCStaples", "Hydrocraft.HCStraw",
    "Hydrocraft.HCTampon", "Hydrocraft.HCTesttubebrush", "Hydrocraft.HCZipperbag",
}
local allowed, templates = {}, {}
for _, name in ipairs(HCRBox.materialTypes) do allowed[name] = true end

function HCRBox.addMaterialTypes(scriptItems)
    for _, name in ipairs(HCRBox.materialTypes) do
        local item = getScriptManager():getItem(name)
        if item then scriptItems:add(item) end
    end
end

-- B42 OnTest receives one inventory item and character. IsExclusive on the
-- input independently rejects mixed fullTypes before native consumption.
function HCRBox.IsStatelessMaterial(item, character)
    -- InventoryItem's native category is "Item"; "Normal" is its script type.
    if not item or not allowed[item:getFullType()] or item:getCategory() ~= "Item"
       or item:getFluidContainer() ~= nil or item:isCustomName() or item:isFavorite()
       or item:isCustomWeight() or item:isWet()
       or item:getCondition() ~= item:getConditionMax() or item:getHaveBeenRepaired() ~= 0 then return false end
    -- PZ Kahlua exposes pairs, but not Lua's usual global next.
    for _, _ in pairs(item:getModData()) do return false end
    local name = item:getFullType()
    local template = templates[name]
    if not template then
        template = instanceItem(name)
        if not template then return false end
        templates[name] = template
    end
    if item:getActualWeight() ~= template:getActualWeight() or item:getName() ~= template:getName()
       or item:getCurrentUses() ~= template:getCurrentUses()
       or item:getDisplayCategory() ~= template:getDisplayCategory() then return false end
    local actual, original = item:getColor(), template:getColor()
    return actual:getR() == original:getR() and actual:getG() == original:getG()
       and actual:getB() == original:getB() and actual:getAlphaFloat() == original:getAlphaFloat()
end
