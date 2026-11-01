-- Совместимая пустая тара: рецепт сохраняет именно выбранный сосуд.
require "HCR_SoftDrinkCatalog"
HCRDrinkVessels={}
function HCRDrinkVessels.matches(target,item)
    if not item then return false end
    local kind=item:getFullType()
    if kind==target then return true end
    for _,alias in ipairs(HCRSoftDrinkCatalog.emptyAliases[target] or {}) do
        if kind==alias then return true end
    end
    return false
end
