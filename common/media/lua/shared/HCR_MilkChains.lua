-- Замкнутая молочная цепь: питание принадлежит партиям, посуда сохраняется.
require "HCR_MilkChainRules"
require "HCR_DrinkFluids"
require "HCR_MilkBowl"
HCRMilkChains={}
local M,Q,L,E=HCRMilkChains,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects
local byName={}
for _,rule in pairs(HCRMilkChainProducts) do byName[rule.name]=rule end

local function destination(rule,data)
    local script=data:getRecipe():getInputs():get(rule.vesselSlot)
    local applied=assert(data:getDataForInputScript(script),"Missing milk destination")
    assert(applied:getAppliedItemsCount()==1,"Ambiguous milk destination")
    local item=applied:getAppliedItem(0)
    assert(item:getFullType()==(rule.vesselType or "Hydrocraft.HCWoodenbucketFluid"),"Wrong milk destination")
    return item
end

function M.check(data)
    local rule=byName[data:getRecipe():getName()]
    if not rule or rule.vesselSlot==nil then return true end
    local item=destination(rule,data)
    local fluid=Q.fluid(item)
    if not fluid or fluid:getCapacity()<rule.litres-.000001 then return false end
    local consuming=false
    for _,slot in ipairs(rule.slots) do consuming=consuming or slot==rule.vesselSlot end
    return math.abs(Q.rawAmount(fluid)-(consuming and rule.litres or 0))<.00001
end

local function addFood(rule,data,ledger)
    if rule.foodSlot~=nil then
        local script=data:getRecipe():getInputs():get(rule.foodSlot)
        local input=data:getDataForInputScript(script)
        local portions=HCRFood.getConsumedFoodFractions(data)
        local selected,seen,total={},{},0
        for i=0,input:getAppliedItemsCount()-1 do
            local source=input:getAppliedItem(i)
            local fraction=portions[source]
            if fraction and not seen[source] then
                seen[source]=true
                local uses=HCRFoodTransfers.consumedUses(data,source,fraction)
                selected[#selected+1]={source=source,fraction=fraction,uses=uses}
                total=total+uses
            end
        end
        assert(#selected>0 and (rule.variableYield or total>0),"Missing legacy milk fraction")
        for _,part in ipairs(selected) do
            local snapshot=HCRFoodTransfers.foodSnapshot(data,part.source)
            local volume
            if rule.variableYield then
                -- ItemCount расходует весь оставшийся Food, но половина
                -- банки не содержит прежние .3 л концентрата.
                local base,current=snapshot.baseHunger,snapshot.hungChange
                assert(base and base<0 and current and current<0,'Missing concentrate remainder')
                local remaining=current/base
                assert(remaining>0 and remaining<=1.000001,'Invalid concentrate remainder')
                volume=rule.foodLitres*math.min(1,remaining)*part.fraction
            else volume=rule.foodLitres*part.uses/total end
            local full=volume/part.fraction
            local original=L.batch("HCRMilk",full,snapshot,getGameTime():getWorldAgeHours())
            local _,used=L.split(original,volume,full)
            ledger=L.mix(ledger,used)
        end
    end
    return ledger
end

function M.preflight(data,sources)
    local rule=byName[data:getRecipe():getName()]
    if not rule then return true end
    -- Проверяем верхнюю границу всех доступных партий. Native testOnly может
    -- сбросить applied prefix после неподходящего кандидата, поэтому нельзя
    -- доверять только его списку источников. Ручной выбор сужает этот набор.
    local ledger=L.empty()
    for _,before in ipairs(sources) do
        if not L.canMix(ledger,before.ledger) then return false end
        ledger=L.mix(ledger,before.ledger)
        if before.nativeMilk then
            if not L.canMix(ledger,before.nativeMilk) then return false end
            ledger=L.mix(ledger,before.nativeMilk)
        end
    end
    ledger=addFood(rule,data,ledger)
    if rule.foodTarget and not HCRMilkBowl.supported(ledger) then return false end
    E.prepare(ledger)
    return true
end

function M.create(rule,data,character)
    assert(not isClient(),"Milk processing belongs to the server")
    local state=assert(HCRFoodTransfers.contexts[data],"Missing milk quality context")
    local ledger=L.empty()
    for _,part in ipairs(state.fluids) do ledger=L.mix(ledger,part) end
    ledger=addFood(rule,data,ledger)
    local litres=L.volume(ledger)
    if rule.variableYield then
        assert(litres>0 and litres<=rule.litres+.0001,'Diluted milk exceeds the full-can yield')
    else assert(math.abs(litres-rule.litres)<.0001,"Milk input volume mismatch") end
    if rule.marker then
        for _,lot in ipairs(ledger.lots) do lot.fluid=rule.marker end
    end
    E.prepare(ledger)
    if rule.foodTarget then return HCRMilkBowl.create(rule,data,ledger) end
    local targets={}
    if rule.vesselSlot~=nil then
        targets[1]=destination(rule,data)
        assert(Q.fluid(targets[1]):isEmpty(),"Milk destination is not empty after consumption")
    else
        local created=data:getAllCreatedItems()
        for i=0,created:size()-1 do
            local item=created:get(i)
            if item:getFullType()==rule.outputTarget then targets[#targets+1]=item end
        end
        assert(#targets==rule.count,"Milk packaging output mismatch")
    end
    local portions={}
    for i,item in ipairs(targets) do
        local fluid=assert(Q.fluid(item),"Missing milk fluid component")
        assert(fluid:getCapacity()>=litres/#targets-.000001,"Milk output exceeds capacity")
        local _,portion=L.split(ledger,litres/#targets,litres)
        E.prepare(portion)
        portions[i]=portion
    end
    if HCRFoodTransfers.deferCreate(data,function() M.create(rule,data,character) end,true) then return end
    for i,item in ipairs(targets) do
        local fluid=Q.fluid(item)
        fluid:Empty() -- Только новая factory тара или опустевшая kept тара.
        for _,lot in ipairs(portions[i].lots) do
            if lot.litres>0 then fluid:addFluid(lot.fluid,lot.litres) end
        end
        assert(math.abs(Q.rawAmount(fluid)-litres/#targets)<.0001,"Milk fill rejected")
        Q.store(item,fluid,L.alignVolumes(portions[i],Q.amounts(fluid)))
        Q.sync(item,character)
    end
end

for token,rule in pairs(HCRMilkChainProducts) do
    local definition=rule
    M["Create_"..token]=function(data,character) return M.create(definition,data,character) end
end
