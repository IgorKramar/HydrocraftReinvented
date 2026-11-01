-- Food остаётся на плите до явного завершения заваривания: native нагрев
-- и подгорание продолжаются. Затем свойства принадлежат отмеряемой жидкости.
require "HCR_DrinkFluids"
require "HCR_BrewedDrinkRules"
require "HCR_BreweryCatalog"
for name,rule in pairs(HCRBreweryCatalog and HCRBreweryCatalog.rules or {}) do HCRBrewedDrinkRules[name]=rule end
HCRBrewedDrinks={rules=HCRBrewedDrinkRules}
local B,Q,L,E=HCRBrewedDrinks,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects

local function input(data,slot)
    local script=data:getRecipe():getInputs():get(slot)
    local applied=assert(data:getDataForInputScript(script),"Missing brewed drink input")
    assert(applied:getAppliedItemsCount()==1,"Ambiguous brewed drink input")
    return applied:getAppliedItem(0)
end

function B.TestCooked(item)
    return item and item:IsFood() and (item:isCooked() or item:isBurnt()) or false
end

function B.TestCookedOrNotFood(item)
    return item and (not item:IsFood() or B.TestCooked(item)) or false
end

local function startFermentation(rule,ledger)
    if not rule.ferment then return ledger end
    return HCRFermentation.start(ledger,rule.ferment,getGameTime():getWorldAgeHours())
end

function B.portion(rule,snapshot)
    local base,current=snapshot.baseHunger,snapshot.hungChange
    assert(base and base<0 and current and current<0,"Missing brewed drink portion")
    local fraction=current/base
    assert(fraction>0 and fraction<=1.000001,"Invalid brewed drink portion")
    if rule.cookable then
        assert(snapshot.cooked or snapshot.burnt,"Brew the drink before finishing")
    end
    return L.batch(rule.marker,rule.litres*math.min(1,fraction),snapshot,getGameTime():getWorldAgeHours())
end

function B.combine(parts,marker,litres)
    local ledger=L.empty()
    for _,part in ipairs(parts) do ledger=L.mix(ledger,part) end
    assert(math.abs(L.volume(ledger)-litres)<.00001,"Milk coffee volume mismatch")
    -- Смена названия состава не меняет отдельных порций/их сроки и дозы.
    for _,lot in ipairs(ledger.lots) do lot.fluid=marker end
    return ledger
end

function B.solid(snapshot,fraction,marker)
    local part=L.batch(marker,1,snapshot,getGameTime():getWorldAgeHours())
    -- Растворённый сахар несёт питание и качество, но не создаёт воду.
    part.lots[1].litres=0;part.lots[1].units=fraction
    return part
end

local function addSolids(data,rule,ledger,actual)
    if rule.foodSlot==nil then return ledger end
    local T=HCRFoodTransfers
    local portions={}
    if actual then portions=T.contexts[data].actualFractions
    else
        -- Applied testOnly prefix может отличаться от реального HashSet.
        -- До расхода учитываем всех возможных Food кандидатов целиком.
        local candidates=data:getInputItems(rule.foodSlot)
        for i=0,candidates:size()-1 do
            local item=candidates:get(i)
            if item:IsFood() and item:getFullType()==rule.foodType then
                item:updateAge(false);portions[item]=1
            end
        end
    end
    for item,fraction in pairs(portions) do
        if item:IsFood() and fraction>0 then
            local snapshot=actual and T.foodSnapshot(data,item) or E.snapshot(item)
            local part=B.solid(snapshot,fraction,rule.marker)
            if not L.canMix(ledger,part) then return nil end
            ledger=L.mix(ledger,part)
        end
    end
    return ledger
end

function B.plan(data,sources)
    local rule=B.rules[data:getRecipe():getName()]
    if not rule then return true end
    if rule.brew then
        local target=input(data,rule.vesselSlot)
        assert(Q.fluid(target) and Q.fluid(target):isEmpty(),"Brewing requires an empty vessel")
        local script=data:getRecipe():getInputs():get(rule.waterSlot)
        local applied=data:getDataForInputScript(script)
        for i=0,applied:getAppliedItemsCount()-1 do
            local item=applied:getAppliedItem(i);local fluid=Q.fluid(item)
            assert(item~=target and fluid and not Q.active(item,fluid)
                and math.abs(Q.rawAmount(fluid)-fluid:getSpecificFluidAmount(Fluid.Water))<.000001,
                "Brewing requires pure clean water")
        end
    elseif rule.finish then
        local source=input(data,0)
        assert(source:getFullType()==rule.source,"Wrong brewing intermediate")
        local ledger=startFermentation(rule,B.portion(rule,E.snapshot(source)))
        E.prepare(ledger)
        local target=assert(instanceItem(rule.target),"Missing brewed drink vessel")
        assert(Q.fluid(target) and Q.fluid(target):getCapacity()>=L.volume(ledger)-.000001,
            "Brewed drink exceeds vessel capacity")
        if rule.ferment then
            if not HCRFermentation.checkMixture(ledger,Q.fluid(target)) then return false end
            local hours=HCRFermentationClock.transition(rule.ferment).hours
            E.prepare(HCRFermentation.plan(ledger,getGameTime():getWorldAgeHours()+hours,false,HCRFermentation.snapshot))
        end
    else
        local target=input(data,rule.vesselSlot)
        local fluid=Q.fluid(target)
        local validAmount=fluid and (rule.inPlace and math.abs(Q.rawAmount(fluid)-rule.litres)<.00001
            or not rule.inPlace and fluid:isEmpty() and not Q.active(target,fluid))
        assert(target:getFullType()==rule.target and validAmount and fluid:getCapacity()>=rule.litres-.000001,
            "Brewed drink destination has the wrong amount")
        local ledger=L.empty()
        for _,before in ipairs(sources) do
            assert(rule.inPlace or before.item~=target or before.amount==0,
                "Brewed drink destination is also an ingredient")
            for _,part in ipairs({before.ledger,before.nativeMilk or L.empty(),before.nativeWine or L.empty()}) do
                if not L.canMix(ledger,part) then return false end
                ledger=L.mix(ledger,part)
            end
        end
        ledger=addSolids(data,rule,ledger,false)
        if not ledger then return false end
        E.prepare(ledger)
    end
    return true
end

function B.create(data,character)
    local rule=assert(B.rules[data:getRecipe():getName()],"Missing brewed drink rule")
    if HCRFoodTransfers.deferCreate(data,function() B.create(data,character) end,true) then return end
    local state=assert(HCRFoodTransfers.contexts[data],"Missing brewing quality context")
    local ledger,target
    if rule.finish then
        local source=input(data,0)
        ledger=startFermentation(rule,B.portion(rule,HCRFoodTransfers.foodSnapshot(data,source)))
        local outputs=data:getAllCreatedItems()
        assert(outputs:size()==1 and outputs:get(0):getFullType()==rule.target,"Brewed drink output mismatch")
        target=outputs:get(0)
        HCRItemMigrations.copyState(source,target)
        target:getModData()[HCRFoodQuality.key]=nil
        target:getModData()[HCRFoodQuality.qualityKey]=nil
    else
        target=input(data,rule.vesselSlot)
        ledger=B.combine(state.fluids or {},rule.marker,rule.litres)
        ledger=assert(addSolids(data,rule,ledger,true),"Too many sweet coffee batches")
    end
    E.prepare(ledger)
    local fluid=Q.fluid(target)
    if rule.finish then fluid:setCanPlayerEmpty(true);fluid:Empty() end
    assert(fluid:isEmpty(),"Brewed drink destination changed before filling")
    fluid:addFluid(rule.marker,L.volume(ledger))
    assert(math.abs(Q.rawAmount(fluid)-L.volume(ledger))<.00001,"Brewed drink fill rejected")
    Q.store(target,fluid,L.alignVolumes(ledger,Q.amounts(fluid)))
    Q.sync(target,character,rule.finish)
end
