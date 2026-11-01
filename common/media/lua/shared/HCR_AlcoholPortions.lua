-- Native evolved recipes принимают Food. Отмеренная порция сохраняет
-- свойства жидкости, включая прежнюю Food-формулу опьянения Hydrocraft.
require "HCR_MilkBowl"
HCRAlcoholPortions={}
local A,L,E,B=HCRAlcoholPortions,HCRFluidLedger,HCRFluidEffects,HCRMilkBowl
A.rules={
    ["Prepare Spirit for Cooking"]={inputs={[0]={fluids={"HCRGin","HCRWhiskey","HCRVodka","HCRWhiskeyCorn","HCRRum","HCRTequila",
        "HCRMezcal","HCRApplejack","HCRPeachSchnapps","HCRFlip","HCRSake"},nativeWine="HCRGin"}},
        litres=.2,target="Hydrocraft.HCRCookingSpirit"},
    ["Prepare Mead for Cooking"]={inputs={[0]={fluids={"HCRMead"},nativeWine="HCRMead"}},
        litres=.4,target="Hydrocraft.HCRCookingMead"},
    ["Prepare Beer for Cooking"]={inputs={[0]={fluids={"HCRBeer"},nativeWine="HCRBeer"}},
        litres=.3,target="Hydrocraft.HCRCookingBeer"},
    ["Prepare Herbal Spirit for Cooking"]={inputs={[0]={fluids={"HCRAbsinthe","HCRHerbalLiqueur"},
        sourceTypes={["Hydrocraft.HCAbsinth"]=true,["Hydrocraft.HCHerballiqueur"]=true}}},
        litres=.8,target="Hydrocraft.HCRCookingHerbalSpirit"},
}
-- Домашняя водка и старые полные бокалы не имели EvolvedRecipe.
-- Проверяется происхождение КАЖДОЙ партии, также после смешивания/переливания.
A.rules["Prepare Spirit for Cooking"].inputs[0].sourceTypes={
    ["Hydrocraft.HCGin1"]=true,["Hydrocraft.HCGin2"]=true,["Hydrocraft.HCGin3"]=true,
    ["Hydrocraft.HCWhiskey1"]=true,["Hydrocraft.HCWhiskey2"]=true,
    ["Hydrocraft.HCWhiskey3"]=true,["Hydrocraft.HCWhiskey4"]=true,
    ["Hydrocraft.HCWhiskeycorn"]=true,["Hydrocraft.HCVodka1"]=true,["Hydrocraft.HCVodka2"]=true,
    ["Hydrocraft.HCTequila"]=true,["Hydrocraft.HCMezcal"]=true,["Hydrocraft.HCApplejack"]=true,
    ["Hydrocraft.HCPeachschnapps"]=true,["Hydrocraft.HCFlip"]=true,["Hydrocraft.HCSake"]=true,
    ["Hydrocraft.HCBourbon1"]=true,["Hydrocraft.HCBourbon2"]=true,
    ["Hydrocraft.HCScotch1"]=true,["Hydrocraft.HCRum1"]=true,
}

function A.isPortion(item)
    local name=item:getFullType()
    return name=="Hydrocraft.HCRCookingSpirit" or name=="Hydrocraft.HCRCookingMead" or name=="Hydrocraft.HCRCookingBeer" or name=="Hydrocraft.HCRCookingHerbalSpirit"
end

function A.evolved(item,operation)
    -- B42.21 UseAndSync возвращает ReplaceOnUse даже после ОДНОЙ Food-use.
    -- У порции с остатком посуда всё ещё занята. Вернуть её только при удалении.
    local replacement=item:getReplaceOnUse()
    if not replacement then return operation() end
    local container=assert(item:getContainer(),"Cooking portion must be in an inventory")
    local empty=assert(instanceItem(item:getReplaceOnUseFullType()),"Missing cooking vessel")
    assert(not empty:IsFood() and empty:getFluidContainer() and empty:getFluidContainer():isEmpty(),
        "Cooking vessel must be empty")
    empty:copyConditionStatesFrom(item)
    item:setReplaceOnUse(nil)
    local ok,result=pcall(operation)
    item:setReplaceOnUse(replacement)
    if not ok then error(result) end
    if not item:getContainer() and item:getCurrentUses()<=0 then
        container:AddItem(empty)
        if isServer() then sendAddItemToContainer(container,empty) end
    end
    return result
end

function A.properties(ledger)
    L.validate(ledger)
    local clean=L.copy(ledger)
    local alcohol=0
    for _,lot in ipairs(clean.lots) do
        local food=lot.food
        -- Food не сохраняет произвольные medicinal/alcohol runtime поля.
        -- Разрешены исходные спиртные HC; изменённая партия остаётся в сосуде.
        assert((food.nativeAlcohol or 0)==0,"Native alcohol needs a different cooking bridge")
        assert(not food.burnt,"Burnt alcohol cannot be represented as one cooking portion")
        assert((food.alcoholPower or 0)==0 or food.alcoholPower==2,"Modified alcohol power")
        if food.alcoholic then
            local base=food.baseHunger or 0
            local fraction=base~=0 and 2*(food.hungChange or 0)/base or 1
            assert(fraction>=0,"Unsupported alcoholic hunger ratio")
            alcohol=alcohol+fraction*lot.units
        end
        food.alcoholic=false;food.alcoholPower=0
    end
    assert(alcohol>0,"Missing alcoholic cooking portion")
    local values=B.properties(clean,{1000000000,1000000000})
    assert(values.hungChange<0,"Alcoholic portion requires food hunger")
    -- JustDrankBooze использует 2*currentHunger/baseHunger. Уменьшение обоих
    -- полей при разливе сделало бы каждый маленький стакан целой бутылкой.
    values.baseHunger=2*values.hungChange/alcohol
    values.alcoholic=true;values.alcoholPower=2
    return values
end

function A.plan(data,sources)
    local rule=A.rules[data:getRecipe():getName()]
    if not rule then return true end
    local ledger=L.empty()
    for _,before in ipairs(sources) do
        if not L.canMix(ledger,before.ledger) then return false end
        ledger=L.mix(ledger,before.ledger)
        if before.nativeWine then
            if not L.canMix(ledger,before.nativeWine) then return false end
            ledger=L.mix(ledger,before.nativeWine)
        end
    end
    A.properties(ledger)
    local item=assert(instanceItem(rule.target),"Missing alcoholic cooking portion")
    assert(item:IsFood() and item:isAlcoholic() and not item:canBeFrozen(),"Changed alcoholic cooking prototype")
    return true
end

function A.finish(state,data,character)
    local rule=A.rules[data:getRecipe():getName()]
    if not rule then return false end
    local ledger=L.empty()
    for _,part in ipairs(state.fluids) do ledger=L.mix(ledger,part) end
    assert(math.abs(L.volume(ledger)-rule.litres)<.00001,"Alcohol cooking volume mismatch")
    local values=A.properties(ledger)
    local outputs=data:getAllCreatedItems()
    assert(outputs:size()==1 and outputs:get(0):getFullType()==rule.target,"Alcohol cooking output mismatch")
    local item=outputs:get(0)
    for key,value in pairs(values) do
        if key~="poisonPower" then item[E.fields[key][2]](item,value) end
    end
    HCRFoodQuality.setQuality(item,L.quality(ledger))
    HCRFoodQuality.store(item,values.poisonPower)
    HCRFoodQuality.fullSnapshot(item,character)
    return true
end
