-- Напиток с авторским питанием рецепта и качеством фактически взятых жидкостей.
require "HCR_DrinkProductRules"
require "HCR_DrinkFluids"
require "HCR_DrinkVessels"
HCRDrinkProducts={}
local P,Q,L,E=HCRDrinkProducts,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects

function P.create(rule,data,character)
    assert(not isClient(),"Drink production belongs to the server")
    local state=assert(HCRFoodTransfers.contexts[data],"Missing craft quality context")
    local script=data:getRecipe():getInputs():get(rule.vesselSlot)
    local applied=assert(data:getDataForInputScript(script),"Missing drink destination")
    assert(applied:getAppliedItemsCount()==1,"Ambiguous drink destination")
    local item=applied:getAppliedItem(0)
    local fluid=Q.fluid(item)
    assert(HCRDrinkVessels.matches(rule.target,item) and fluid and fluid:isEmpty()
        and not Q.active(item,fluid) and fluid:getCapacity()>=rule.litres-.000001,
        "Drink destination is no longer empty")
    local sample=assert(instanceItem(rule.sourceFood),"Missing drink nutrition prototype")
    assert(sample:IsFood(),"Drink nutrition prototype must be Food")
    local F=HCRFoodQuality
    F.setQuality(sample,F.worst(F.quality(sample),state.quality))
    sample:setPoisonDetectionLevel(state.detection)
    F.store(sample,state.dose)
    local ledger=L.batch(rule.fluid,rule.litres,E.snapshot(sample),getGameTime():getWorldAgeHours())
    E.prepare(ledger)
    if HCRFoodTransfers.deferCreate(data,function() P.create(rule,data,character) end) then return end
    fluid:addFluid(rule.fluid,rule.litres)
    assert(math.abs(Q.rawAmount(fluid)-rule.litres)<.00001,"Native drink fill was rejected")
    Q.store(item,fluid,L.alignVolumes(ledger,Q.amounts(fluid)))
    Q.sync(item,character)
end

for token,rule in pairs(HCRDrinkProductRules) do
    local definition=rule
    P["Create_"..token]=function(data,character) return P.create(definition,data,character) end
end
