-- Брожение сохраняет худшее качество сырья. Питание готового алкоголя
-- определяется исходным рецептом, а не суммой калорий винограда/браги.
require "HCR_DrinkFluids"
require "HCR_NativeWhiskey"
require "HCR_SpiritCatalog"
HCRWineQuality={}
local W,Q,L,E=HCRWineQuality,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects
W.outputs={
    ["Fill Bottles with Wine"]={target="Base.Wine2",marker="HCRWineRed",count=20},
    ["Fill Bottles with Wine (Variant)"]={target="Base.Wine",marker="HCRWineWhite",count=20},
    ["Make Bottle of Mead"]={target="Base.Whiskey",marker="HCRMead",count=20,sourceFood="Hydrocraft.HCMead"},
    ["Make Bottle of Sake"]={target="Base.Whiskey",marker="HCRSake",count=20,sourceFood="Hydrocraft.HCSake"},
    ["Distill Bottle of Whiskey"]={target="Base.Whiskey",count=20,nativeQuality=true},
}
W.rules={
    ["Pour Wine"]={slots={[1]=true},fluids={"Wine","HCRWineWhite"},nativeWine="HCRWineWhite"},
    ["Pour Wine (Glass of Red Wine)"]={slots={[1]=true},fluids={"Wine","HCRWineRed"},nativeWine="HCRWineRed"},
}
for name,rule in pairs(HCRSpiritCatalog and HCRSpiritCatalog.outputs or {}) do W.outputs[name]=rule end
for name,rule in pairs(HCRSpiritCatalog and HCRSpiritCatalog.pours or {}) do W.rules[name]=rule end
local getters={calories="getCalories",carbohydrates="getCarbohydrates",proteins="getProteins",
    lipids="getLipids",hungChange="getHungerChange",thirstChange="getThirstChange",
    stressChange="getStressChange",fatigueChange="getFatigueChange",enduranceChange="getEnduranceChange",
    unhappyChange="getUnhappyChange",nativeAlcohol="getAlcohol"}

function W.snapshot(fluid,state,count)
    local sample=instanceItem("Hydrocraft.HCRFluidSample")
    HCRFoodQuality.setQuality(sample,state.quality)
    local food=E.snapshot(sample)
    local props=fluid:getProperties()
    for key,getter in pairs(getters) do food[key]=props[getter](props) end
    food.baseHunger=food.hungChange;food.boredomChange=food.unhappyChange
    food.canBeFrozen=false;food.alcoholic=false
    food.tainted=state.tainted or food.tainted or false
    food.poisonPower=state.dose/count;food.poisonDetectionLevel=state.detection or -1
    assert(props:getPoison()==0 and props:getPainReduction()==0 and props:getFluReduction()==0
        and props:getFoodSicknessChange()==0,"Unsupported native alcohol effects")
    return food
end

function W.bottledSnapshot(rule,fluid,state)
    if not rule.sourceFood then return W.snapshot(fluid,state,rule.count) end
    -- Mead/Sake сохраняют исходные HC значения, а не заводской Whisky из
    -- временно созданной бутылки B42. E.consume применяет прежнюю Food-формулу.
    local sample=assert(instanceItem(rule.sourceFood),"Missing brewed alcohol prototype")
    assert(sample:IsFood(),"Changed brewed alcohol source class")
    sample:setAge(0)
    HCRFoodQuality.setQuality(sample,state.quality)
    sample:setPoisonDetectionLevel(state.detection or -1)
    HCRFoodQuality.store(sample,state.dose/rule.count)
    local food=E.snapshot(sample)
    food.tainted=state.tainted or food.tainted or false
    return food
end

function W.bottledLedger(rule,fluid,state)
    if rule.nativeQuality then return HCRNativeWhiskey.ledger(fluid,state,rule.count) end
    return L.batch(rule.marker,1,W.bottledSnapshot(rule,fluid,state),getGameTime():getWorldAgeHours())
end

function W.preflight(data)
    local pour=W.rules[data:getRecipe():getName()]
    if pour then
        local item=assert(instanceItem(pour.target or "Hydrocraft.HCWineglassFluid"),"Missing wine glass")
        local fluid=assert(Q.fluid(item),"Missing wine glass component")
        assert(fluid:isEmpty() and fluid:getCapacity()>=(pour.litres or .25)-.000001,"Changed wine glass capacity")
    end
    local rule=W.outputs[data:getRecipe():getName()]
    if not rule then return true end
    local item=assert(instanceItem(rule.target),"Missing bottled alcohol")
    local fluid=assert(Q.fluid(item),"Missing bottled alcohol component")
    assert(math.abs(Q.rawAmount(fluid)-(rule.empty and 0 or 1))<.00001
        and fluid:getCapacity()>=1,"Changed native alcohol bottle volume")
    E.prepare(W.bottledLedger(rule,fluid,{quality="fresh",dose=0}))
    return true
end

function W.preflightSources(data,sources)
    if not W.rules[data:getRecipe():getName()] then return true end
    local ledger=L.empty()
    for _,before in ipairs(sources) do
        if not L.canMix(ledger,before.ledger) then return false end
        ledger=L.mix(ledger,before.ledger)
        if before.nativeWine then
            if not L.canMix(ledger,before.nativeWine) then return false end
            ledger=L.mix(ledger,before.nativeWine)
        end
    end
    E.prepare(ledger)
    return true
end

function W.glasses(state,data,character)
    local rule=W.rules[data:getRecipe():getName()]
    local count,litres,target=rule.count or 4,rule.litres or .25,rule.target or "Hydrocraft.HCWineglassFluid"
    local ledger=L.empty()
    for _,part in ipairs(state.fluids) do ledger=L.mix(ledger,part) end
    assert(math.abs(L.volume(ledger)-count*litres)<.00001,"Wine glass input volume")
    local created=data:getAllCreatedItems()
    assert(created:size()==count,"Wine glass output count")
    local _,portion=L.split(ledger,litres,count*litres)
    E.prepare(portion)
    for i=0,count-1 do
        local item=created:get(i);local fluid=Q.fluid(item)
        assert(item:getFullType()==target and fluid:isEmpty(),"Wine glass output type")
        for _,lot in ipairs(portion.lots) do if lot.litres>0 then fluid:addFluid(lot.fluid,lot.litres) end end
        Q.store(item,fluid,L.alignVolumes(portion,Q.amounts(fluid)))
        Q.sync(item,character)
    end
end

function W.finish(state,data,character)
    if W.rules[data:getRecipe():getName()] then W.glasses(state,data,character);return true end
    local rule=W.outputs[data:getRecipe():getName()]
    if not rule then return false end
    local targets={}
    local created=data:getAllCreatedItems()
    for i=0,created:size()-1 do
        local item=created:get(i)
        if item:getFullType()==rule.target then targets[#targets+1]=item end
    end
    assert(#targets==rule.count,"Bottled alcohol count mismatch")
    local planned={}
    for i,item in ipairs(targets) do
        local fluid=Q.fluid(item)
        assert(math.abs(Q.rawAmount(fluid)-(rule.empty and 0 or 1))<.00001,"Bottled alcohol volume mismatch")
        planned[i]=W.bottledLedger(rule,fluid,state)
        E.prepare(planned[i])
    end
    for i,item in ipairs(targets) do
        local fluid=Q.fluid(item)
        -- Розлив использует уже открытые бутылки. Не выдаём заводскую пробку,
        -- которая потребовала бы разрушительного native Unseal-рецепта.
        -- unseal() немедленно отправляет factory содержимое другим сетевым
        -- каналом. Установить флаг локально, затем опубликовать финальную смесь.
        fluid:setCanPlayerEmpty(true)
        if not rule.nativeQuality then fluid:Empty();fluid:addFluid(rule.marker,1) end
        Q.store(item,fluid,L.alignVolumes(planned[i],Q.amounts(fluid)))
        Q.sync(item,character)
    end
    return true
end
