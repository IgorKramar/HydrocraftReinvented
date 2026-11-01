-- Native нагрев остаётся у исходного Food. Pristine ReplaceOnCooked терял
-- остаток и изменённое питание; теперь готовность меняет лишь сроки порчи.
require 'HCR_MashCatalog'
require 'HCR_FoodQuality'
HCRMashCooking={key='HCRMashCooked160'}
local M,F=HCRMashCooking,HCRFoodQuality
function M.OnCooked(item)
    if isClient() then return end
    local spec=HCRMashCatalog.raw[item:getFullType()]
    if not spec or not (item:isCooked() or item:isBurnt()) then return end
    local md=item:getModData()
    if md[M.key] then assert(md[M.key]==1,'Unknown mash cooking boundary');return end
    local ready=assert(instanceItem(spec.readyFood),'Missing original cooked mash')
    local quality=F.quality(item)
    F.reconcile(item) -- Очистка воды следует настоящему native cookingTime.
    item:setOffAge(ready:getOffAge());item:setOffAgeMax(ready:getOffAgeMax());item:setAge(0)
    -- Старые overrides не должны вернуть сырому продукту прежние сроки.
    md[F.qualityKey]=nil;F.setQuality(item,quality)
    md[M.key]=1
end
function M.snapshot(item,spec)
    M.OnCooked(item)
    local food=HCRFluidEffects.snapshot(item)
    food.sourceType=spec.readyFood
    -- Исходный ready-ID не имел native +30% Hunger от cooked=true.
    food.cooked=false;food.dangerousUncooked=false
    return food
end
