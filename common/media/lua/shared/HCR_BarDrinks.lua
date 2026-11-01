-- Смешивание сохраняет реальные порции, включая растворённые продукты.
require "HCR_BarCatalog"
require "HCR_CocktailCatalog"
require "HCR_MilkCocktailCatalog"
require "HCR_BrewedDrinks"
HCRBarDrinks={}
local B,Q,L,E=HCRBarDrinks,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects

function B.waterSnapshot(fluid)
    -- Здесь допустимы только нейтральный HCR-напиток и чистая вода.
    -- Все native свойства такого сосуда принадлежат именно воде.
    local food=E.snapshot(instanceItem("Hydrocraft.HCRFluidSample"))
    food.thirstChange=fluid:getProperties():getThirstChange()
    food.canBeFrozen=false
    return food
end

function B.compose(parts,solids,marker,litres)
    local ledger=L.empty()
    for _,part in ipairs(parts) do ledger=L.mix(ledger,part) end
    for _,lot in ipairs(ledger.lots) do lot.fluid=marker end
    -- Native удаляет хвост компонента <=0,0001 л. Сохраняем его Food units,
    -- согласуя только физические объёмы с выходом рецепта.
    ledger=L.alignVolumes(ledger,{[marker]=litres},.0001*math.max(1,#ledger.lots))
    for _,solid in ipairs(solids) do
        ledger=L.mix(ledger,HCRBrewedDrinks.solid(solid.food,solid.fraction,marker))
    end
    return ledger
end

function B.solidSnapshot(data,item,food)
    local rule=HCRBarCatalog.products[data:getRecipe():getName()]
    if rule.safeEggSlot and data:getRecipe():getInputs():get(rule.safeEggSlot):containsItem(item:getScriptItem()) then
        -- Исходный эггног не нёс отдельного raw-egg штрафа. Не добавляем
        -- его при переносе на жидкости; порча и индивидуальный яд остаются.
        food=L.copy(food);food.dangerousUncooked=false
    end
    return food
end

function B.plan(data,sources)
    local rule=HCRBarCatalog.products[data:getRecipe():getName()]
    if not rule then return true end
    local target=assert(instanceItem(rule.target),"Missing bar vessel")
    assert(Q.fluid(target) and Q.fluid(target):isEmpty()
        and Q.fluid(target):getCapacity()>=rule.litres/(rule.count or 1)-.000001,"Bar vessel too small or not empty")
    -- До расхода проверяем верхнюю границу числа партий: native selection
    -- может взять любой подходящий Food из выбранного списка.
    local ledger=L.empty()
    for _,before in ipairs(sources) do
        for _,part in ipairs({before.ledger,before.nativeMilk or L.empty(),before.nativeWine or L.empty(),before.nativeWater or L.empty()}) do
            if not L.canMix(ledger,part) then return false end
            ledger=L.mix(ledger,part)
        end
    end
    local seen={}
    for slot,allowed in pairs(rule.foodSlots or {}) do
        local items=data:getInputItems(slot)
        if items then for i=0,items:size()-1 do
            local item=items:get(i)
            local eligible=allowed[item:getFullType()] or allowed.nativeTags
                and data:getRecipe():getInputs():get(slot):containsItem(item:getScriptItem())
            if not seen[item] and item:IsFood() and eligible then
                seen[item]=true;item:updateAge(false)
                local part=HCRBrewedDrinks.solid(B.solidSnapshot(data,item,E.snapshot(item)),1,rule.marker)
                if not L.canMix(ledger,part) then return false end
                ledger=L.mix(ledger,part)
            end
        end end
    end
    E.prepare(ledger)
    return true
end

function B.create(data,character)
    local rule=assert(HCRBarCatalog.products[data:getRecipe():getName()],"Missing bar recipe")
    local T=HCRFoodTransfers
    if T.deferCreate(data,function() B.create(data,character) end,true) then return end
    local state=assert(T.contexts[data],"Missing bar quality context")
    local solids={}
    for item,fraction in pairs(state.actualFractions) do
        if item:IsFood() and fraction>0 then
            solids[#solids+1]={food=B.solidSnapshot(data,item,T.foodSnapshot(data,item)),fraction=fraction}
        end
    end
    local ledger=B.compose(state.fluids or {},solids,rule.marker,rule.litres)
    E.prepare(ledger)
    local outputs=data:getAllCreatedItems()
    local count=rule.count or 1;local litres=rule.litres/count
    assert(outputs:size()==count,"Bar output count mismatch")
    local _,portion=L.split(ledger,litres,rule.litres)
    for index=0,count-1 do
        local target=outputs:get(index);local fluid=Q.fluid(target)
        assert(target:getFullType()==rule.target and fluid and fluid:isEmpty(),"Bar output must be the empty target")
        fluid:addFluid(rule.marker,litres)
        assert(math.abs(Q.rawAmount(fluid)-litres)<.00001,"Bar fill rejected")
        Q.store(target,fluid,L.alignVolumes(portion,Q.amounts(fluid)))
        Q.sync(target,character)
    end
end
