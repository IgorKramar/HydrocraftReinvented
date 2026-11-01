-- Перенос точного яда при штатном handcraft и добавлении Food в evolved recipe.
-- Питание и кулинарные бонусы по-прежнему вычисляет движок.
require "HCR_FoodQuality"
require "HCR_ProcessQuality"
require "HCR_FoodConsumption"
require "HCR_BeerQuality"
require "Entity/TimedActions/ISHandcraftAction"
require "TimedActions/ISAddItemInRecipe"
HCRFoodTransfers={contexts={}}
local T,F=HCRFoodTransfers,HCRFoodQuality
local C=HCRFoodConsumption

local function facade(object,overrides)
    return setmetatable(overrides,{__index=function(_,key)
        return function(_,...) return object[key](object,...) end
    end})
end

function T.captureCraft(data,force,captureAll)
    local portions=HCRFood.getConsumedFoodFractions(data)
    local state={inputs={},dose=0,tracked=force or false,detection=-1,quality="fresh"}
    for item,fraction in pairs(portions) do
        local dose=F.dose(item)
        state.tracked=state.tracked or F.active(item)
        state.inputs[#state.inputs+1]={item=item,dose=dose,fraction=fraction}
        state.dose=state.dose+dose*fraction
        state.quality=F.worst(state.quality,F.quality(item))
        state.tainted=state.tainted or (fraction>0 and F.tainted(item)) or false
        state.tracked=state.tracked or state.tainted
        if dose>0 then
            local saved=item:getModData()[F.key]
            state.detection=math.max(state.detection,saved and saved.detection or item:getPoisonDetectionLevel())
            state.poisoner=state.poisoner or item:getModData().addedPoisonBy
        end
    end
    if HCRProcessQuality then HCRProcessQuality.capture(data,state) end
    return (state.tracked or captureAll) and state or nil
end

function T.checkCraft(data,additionalDose)
    if HCRBeerQuality then HCRBeerQuality.preflight(data) end
    if HCRWineQuality then HCRWineQuality.preflight(data) end
    T.captureCraft(data,true) -- Проверить metadata до начала native расхода.
    -- Верхняя граница ДО расхода: выбранный native порядок может отличаться
    -- от предсказанного порядка applied lists.
    local total=0
    for _,entry in pairs(C.capture(data,true)) do
        total=total+(entry.dose or 0)
        if HCRProcessQuality and HCRProcessQuality.carrier(entry.item) then
            total=total+HCRProcessQuality.read(entry.item).dose
        end
    end
    return total+(additionalDose or 0)<=F.maxDose
end

function T.deferCreate(data,operation,snapshots)
    local state=T.contexts[data]
    if not state or state.phase~="create" then return false end
    if snapshots then
        for item,entry in pairs(state.entries) do
            if entry.values and not entry.snapshot then entry.snapshot=HCRFluidEffects.snapshot(item) end
        end
    end
    state.deferred[#state.deferred+1]=operation
    return true
end

function T.foodSnapshot(data,item)
    local state=T.contexts[data]
    local entry=state and state.entries and state.entries[item]
    return entry and entry.snapshot and HCRFluidLedger.copy(entry.snapshot) or HCRFluidEffects.snapshot(item)
end

function T.consumedValue(data,item,getter,fraction)
    local state=T.contexts[data]
    local entry=state and state.entries and state.entries[item]
    return entry and entry.consumedValues and entry.consumedValues[getter] or item[getter](item)*fraction
end

function T.consumedUses(data,item,fraction)
    local state=T.contexts[data]
    local entry=state and state.entries and state.entries[item]
    return entry and entry.used or item:getCurrentUses()*fraction
end

function T.actualCraft(state,data)
    state.actualFractions=C.measure(state.entries)
    state.inputs={};state.dose=0;state.quality="fresh";state.detection=-1;state.poisoner=nil;state.tainted=false
    for item,fraction in pairs(state.actualFractions) do
        local entry=state.entries[item]
        if entry.values then
            state.inputs[#state.inputs+1]={item=item,dose=entry.dose,fraction=fraction}
            state.tracked=state.tracked or entry.tracked or entry.dose>0
            state.dose=state.dose+entry.dose*fraction
            state.quality=F.worst(state.quality,entry.quality)
            state.tainted=state.tainted or (fraction>0 and entry.tainted) or false
            state.tracked=state.tracked or state.tainted
            if entry.dose>0 then
                state.detection=math.max(state.detection,entry.detection)
                state.poisoner=state.poisoner or entry.poisoner
            end
        end
    end
    if HCRProcessQuality then HCRProcessQuality.capture(data,state) end
    T.addFluids(state,state.fluids)
end

function T.addFluids(state,ledgers)
    state.fluids=ledgers or {}
    for _,ledger in ipairs(ledgers or {}) do
        state.dose=state.dose+HCRFluidLedger.budget(ledger,"poisonPower")
        state.quality=F.worst(state.quality,HCRFluidLedger.quality(ledger))
        for _,lot in ipairs(ledger.lots) do
            state.tainted=state.tainted or lot.food.tainted or false
            if (lot.food.poisonPower or 0)>0 then
                state.detection=math.max(state.detection,lot.food.poisonDetectionLevel or -1)
            end
        end
    end
end

function T.finishCreate(state,data,character)
    if not state then return end
    if HCRFermentationRecipes and HCRFermentationRecipes.finish(state,data,character) then return end
    if HCRBeerQuality and HCRBeerQuality.finish(state,data,character) then return end
    if HCRAlcoholPortions and HCRAlcoholPortions.finish(state,data,character) then return end
    if HCRWineQuality and HCRWineQuality.finish(state,data,character) then return end
    local foods={}
    local created=data:getAllCreatedItems()
    for i=0,created:size()-1 do
        local item=created:get(i)
        local process=HCRProcessQuality and HCRProcessQuality.carrier(item)
        if process then state.tracked=true end
        if item:IsFood() or process then foods[#foods+1]=item end
    end
    if not state.tracked then return end
    -- Сюда входят и рецепты без OnCreate. Сок записывает свои Food-порции
    -- в ledger kept-сосудов внутри OnCreate; Food outputs у него отсутствуют.
    for _,food in ipairs(foods) do
        if HCRProcessQuality and HCRProcessQuality.carrier(food) then
            HCRProcessQuality.write(food,state,#foods,character)
        else
        F.setQuality(food,F.worst(state.quality,F.quality(food)))
        if state.tainted then F.setTainted(food) end
        food:setPoisonDetectionLevel(state.detection)
        if state.poisoner then food:getModData().addedPoisonBy=state.poisoner end
        F.store(food,state.dose/#foods)
        F.fullSnapshot(food,character)
        end
    end
end

function T.remaining(state,character)
    if not state then return end
    if HCRProcessQuality then HCRProcessQuality.remaining(state) end
    for _,entry in ipairs(state.inputs) do
        if entry.fraction>=1 then entry.item:getModData()[F.qualityKey]=nil end
        F.store(entry.item,entry.dose*(1-entry.fraction))
        F.sync(entry.item,character)
    end
end

local perform=ISHandcraftAction.performRecipe
ISHandcraftAction.performRecipe=function(self,...)
    if isClient() or not self.logic then return perform(self,...) end
    local logic=self.logic
    local data=logic:getRecipeData()
    if not data then return perform(self,...) end
    local state
    local wrapped=facade(data,{
        luaCallOnCreate=function(_,character)
            -- Native применённые Food ещё не израсходованы; callbacks видят
            -- исходные значения. После них задаётся точный бюджет результатов.
            local ledgers=self.hcrFluidIngredients
            local recipeRule=HCRFluidRecipeQuality and HCRFluidRecipeQuality.rules[data:getRecipe():getName()]
            state=T.captureCraft(data,(ledgers and #ledgers>0) or recipeRule,true)
            state.entries=C.capture(data,false)
            state.deferred={};state.phase="create"
            if state then T.addFluids(state,ledgers) end
            assert(not state or state.dose<=F.maxDose,"Craft poison budget exceeds supported limit")
            assert(not T.contexts[data],"Recursive craft quality context")
            T.contexts[data]=state
            local ok,reason=pcall(function() data:luaCallOnCreate(character) end)
            if not ok then error(reason) end
        end,
        processDestroyAndUsedItems=function(_,character)
            if not state then return data:processDestroyAndUsedItems(character) end
            C.clearFood(state.entries)
            local ok,reason=pcall(function() data:processDestroyAndUsedItems(character) end)
            T.actualCraft(state,data)
            C.restoreFood(state.entries,character)
            if not ok then error(reason) end
            state.phase="complete"
            for _,operation in ipairs(state.deferred) do operation() end
            T.finishCreate(state,data,character)
            if HCRProcessQuality then HCRProcessQuality.remaining(state) end
        end,
    })
    self.logic=facade(logic,{getRecipeData=function() return wrapped end})
    local ok,result=pcall(perform,self,...)
    self.logic=logic
    T.contexts[data]=nil
    if not ok then error(result) end
    return result
end

local nutrients={"getCalories","getProteins","getCarbohydrates","getLipids"}
function T.usedFraction(item,before,spice)
    if not item:getContainer() then return 1 end
    for _,getter in ipairs(nutrients) do
        local previous=before[getter]
        if previous and math.abs(previous)>0.000001 then
            return math.max(0,math.min(1,(previous-item[getter](item))/previous))
        end
    end
    if math.abs(before.hunger)>0.000001 then
        local fraction=math.abs((item:getHungChange()-before.hunger)/before.hunger)
        -- Native cooked Food уменьшает raw hunger на /1.3 после вычисления
        -- пищевой доли. Для специй такой поправки в движке нет.
        if before.cooked and not spice then fraction=fraction*1.3 end
        return math.max(0,math.min(1,fraction))
    end
    return 0
end

function T.canAddIngredient(recipe,used)
    -- Старые запасы могут ждать миграции: native evolved делит на raw hunger.
    -- Нулевое насыщение агуардиенте даёт 0/0 и портит питание всего блюда.
    if not used or used:getFullType()~="Hydrocraft.HCAguaardiente" or not used:IsFood()
        or used:getHungChange()~=0 then return true end
    local definition=recipe:getItemRecipe(used)
    return not definition or definition:getUse()<0
end

function T.addIngredient(recipe,base,used,character)
    if not T.canAddIngredient(recipe,used) then return base end
    local P=HCRProcessQuality
    local process=P and P.carrier(used) and used:getModData()[P.key] and P.read(used)
    local alcohol=HCRAlcoholPortions and HCRAlcoholPortions.isPortion(used)
    if isClient() or not (F.active(base) or F.active(used) or process or alcohol) then
        return recipe:addItem(base,used,character)
    end
    F.reconcile(base);F.reconcile(used)
    local baseDose=base:IsFood() and F.dose(base) or 0
    local baseDetection=base:IsFood() and base:getPoisonDetectionLevel() or -1
    local basePoisoner=base:getModData().addedPoisonBy
    local baseQuality=base:IsFood() and F.quality(base) or "fresh"
    local baseTainted=F.tainted(base)
    local usedTainted=process and process.tainted or F.tainted(used)
    local usedQuality=process and process.quality or (used:IsFood() and F.quality(used) or "fresh")
    local baseFloor=base:getModData()[F.qualityKey]
    local usedFloor=used:getModData()[F.qualityKey]
    local baseTaint=base:getModData()[F.taintKey]
    local usedTaint=used:getModData()[F.taintKey]
    local dose=process and process.dose or (used:IsFood() and F.dose(used) or 0)
    assert(baseDose+dose<=F.maxDose,"Evolved poison budget exceeds supported limit")
    local prototype=instanceItem(recipe:getFullResultItem())
    assert(prototype and prototype:IsFood(),"Tracked evolved recipe must produce Food")
    local definition=recipe:getItemRecipe(used)
    local poisonOnly=not definition or definition:getUse()<0
    local before={uses=process and used:getCurrentUses() or 0,hunger=used:IsFood() and used:getHungChange() or 0,
        cooked=used:IsFood() and used:isCooked() or false,
        baseHunger=alcohol and used:getBaseHunger() or nil}
    if used:IsFood() then
        for _,getter in ipairs(nutrients) do before[getter]=used[getter](used) end
    end
    local spice=used:IsFood() and used:isSpice() or false
    local detection=process and (process.detection or -1) or (used:IsFood() and used:getPoisonDetectionLevel() or -1)
    -- UseAndSync внутри native addItem может создать пустую посуду.
    -- Временно убрать metadata ДО него, не позволив копировать полную дозу.
    if used:IsFood() then F.store(used,0) end
    if base:IsFood() then F.store(base,0) end
    used:getModData()[F.qualityKey]=nil
    base:getModData()[F.qualityKey]=nil
    used:getModData()[F.taintKey]=nil
    base:getModData()[F.taintKey]=nil
    if process then used:getModData()[P.key]=nil end
    local ok,result=pcall(function()
        local function add() return recipe:addItem(base,used,character) end
        if alcohol then return HCRAlcoholPortions.evolved(used,add) end
        return add()
    end)
    -- Native evolved уменьшает также baseHunger. Для отмеренного алкоголя
    -- это знаменатель исходной бутылки: его изменение усиливает остаток.
    if before.baseHunger then used:setBaseHunger(before.baseHunger) end
    if not ok then
        used:getModData()[F.qualityKey]=usedFloor
        base:getModData()[F.qualityKey]=baseFloor
        used:getModData()[F.taintKey]=usedTaint
        base:getModData()[F.taintKey]=baseTaint
        if used:IsFood() then F.store(used,dose) end
        if base:IsFood() then F.store(base,baseDose) end
        if process then used:getModData()[P.key]=process end
        error(result)
    end
    assert(result and result:IsFood(),"Tracked evolved recipe must return Food")
    local fraction=used:IsFood() and (poisonOnly and 1 or T.usedFraction(used,before,spice)) or 0
    if process then
        fraction=before.uses>0 and math.max(0,math.min(1,(before.uses-used:getCurrentUses())/before.uses)) or 0
        local world=used.getWorldItem and used:getWorldItem()
        if not used:getContainer() and not (world and world:getWorldObjectIndex()>=0) then fraction=1 end
        P.keep(used,process,1-fraction,character)
    end
    local transferred=dose*fraction
    local quality=fraction>0 and F.worst(baseQuality,usedQuality) or baseQuality
    if result==base then
        result:getModData()[F.qualityKey]=baseFloor
        result:getModData()[F.taintKey]=baseTaint
    end
    F.setQuality(result,F.worst(quality,F.quality(result)))
    if (baseTainted and result~=base) or (fraction>0 and usedTainted) then F.setTainted(result) end
    if baseDose>0 then result:setPoisonDetectionLevel(baseDetection) end
    if baseDose>0 and basePoisoner then result:getModData().addedPoisonBy=basePoisoner end
    if transferred>0 then
        local previous=math.max(0,result:getPoisonDetectionLevel())
        result:setPoisonDetectionLevel(math.min(10,previous+math.max(0,detection)))
        result:getModData().addedPoisonBy=character:getFullName()
    end
    F.store(result,baseDose+transferred)
    if used:IsFood() then
        -- Poison-only добавление может отдать всю дозу без расхода продукта.
        -- Его прежняя свежесть должна пережить последующее сохранение.
        if fraction<1 or used:getContainer() then
            used:getModData()[F.qualityKey]=usedFloor
            used:getModData()[F.taintKey]=usedTaint
        end
        F.store(used,dose-transferred);F.sync(used,character)
    end
    if result==base then F.sync(result,character) end
    return result
end

local complete=ISAddItemInRecipe.complete
ISAddItemInRecipe.complete=function(self,...)
    if not T.canAddIngredient(self.recipe,self.usedItem) then return false end
    local recipe=self.recipe
    local originalBase=self.baseItem
    self.recipe=facade(recipe,{addItem=function(_,base,used,character)
        return T.addIngredient(recipe,base,used,character)
    end})
    local ok,result=pcall(complete,self,...)
    self.recipe=recipe
    if not ok then error(result) end
    -- Native complete сначала задаёт итоговое имя и температуру блюда.
    if self.baseItem~=originalBase then F.fullSnapshot(self.baseItem,self.character) end
    return result
end

for _,name in ipairs({"isValidStart","isValid"}) do
    local original=ISAddItemInRecipe[name]
    ISAddItemInRecipe[name]=function(self,...)
        return T.canAddIngredient(self.recipe,self.usedItem) and original(self,...)
    end
end
