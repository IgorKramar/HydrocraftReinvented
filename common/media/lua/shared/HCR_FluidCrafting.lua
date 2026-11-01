require "Entity/TimedActions/ISHandcraftAction"
require "HCR_FluidActions"
require "HCR_FluidRecipeQuality"
require "HCR_MilkChains"
HCRFluidCrafting = {}
local C, Q = HCRFluidCrafting, HCRFluidQuality
Q.craftFluidOwners=Q.craftFluidOwners or {}

-- Native consumeInputFromItems читает item-owned FC до проверки кандидата.
-- На земле FC принадлежит world object. Scope заканчивается до следующего tick;
-- итоговая сетевая публикация выполняется после возврата компонента владельцу.
function C.borrowWorldFluids(logic,publish)
    local borrowed,closed={},false
    local function restore()
        if closed then return end
        closed=true
        local errors={}
        for i=#borrowed,1,-1 do
            local entry=borrowed[i]
            local item,world=entry.item,entry.world
            local ok,reason=pcall(function()
                if item:getWorldItem()==world then
                    if item:getFluidContainer()==entry.fluid then
                        GameEntityFactory.TransferComponent(item,world,ComponentType.FluidContainer)
                    end
                    assert(world:getFluidContainer()==entry.fluid and not item:getFluidContainer(),"World fluid restoration failed")
                end
            end)
            Q.craftFluidOwners[item]=nil
            entry.restored=ok
            if not ok then errors[#errors+1]=tostring(reason) end
        end
        -- Ошибка одного предмета/сети не должна оставить остальные компоненты
        -- у временных владельцев. Сначала вернуть ВСЕ, затем опубликовать.
        for _,entry in ipairs(borrowed) do
            if entry.restored and entry.dirty and (entry.item:getWorldItem() or entry.item:getContainer()) then
                local ok,reason=pcall(Q.sync,entry.item,entry.character,entry.fullSnapshot)
                if not ok then errors[#errors+1]=tostring(reason) end
            end
        end
        assert(#errors==0,table.concat(errors,"; "))
    end
    local function inspect(items)
        if not items then return end
        for i=0,items:size()-1 do
            local item=items:get(i)
            local world=item.getWorldItem and item:getWorldItem()
            if world and not Q.craftFluidOwners[item] and not item:getFluidContainer() then
                local fluid=world:getFluidContainer()
                if fluid then
                    -- Native расход обычного молока обходит Q.sync. Его пакет
                    -- адресован временному item-owner, поэтому после perform
                    -- нужен окончательный world snapshot даже без HCR ledger.
                    local entry={item=item,world=world,fluid=fluid,dirty=publish or false}
                    borrowed[#borrowed+1]=entry;Q.craftFluidOwners[item]=entry
                    GameEntityFactory.TransferComponent(world,item,ComponentType.FluidContainer)
                    assert(item:getFluidContainer()==fluid and not world:getFluidContainer(),"World fluid borrowing failed")
                end
            end
        end
    end
    local ok,reason=pcall(function()
        local data=logic:getRecipeData()
        local recipe=data and data:getRecipe()
        if not recipe then return end
        local scripts=recipe:getInputs()
        local consumesFluid=false
        for slot=0,scripts:size()-1 do
            if scripts:get(slot):hasConsumeFromItem() then consumesFluid=true;break end
        end
        if not consumesFluid then return end
        inspect(logic:getAllItems())
        for slot=0,scripts:size()-1 do inspect(data:getInputItems(slot)) end
    end)
    if not ok then restore();error(reason) end
    return restore
end

local function changesContents(script)
    return not script:isKeep() or script:hasConsumeFromItem()
        or script:hasCreateToItem() or script:isReplace()
        or script:hasFlag(InputFlag.Unseal) or script:hasFlag(InputFlag.InheritUsesAndEmpty)
end

local function allowedItem(recipe,slot,script,item)
    -- У лежащего сосуда компонент принадлежит world object, и native IsEmpty
    -- его не видит. Особенно важно для рецептов без -fluid (например, Rum).
    local fluid=Q.fluid(item)
    if script:hasFlag(InputFlag.IsEmpty) and fluid and Q.rawAmount(fluid)>.000001 then return false end
    -- Перепаковка целых заводских банок сохраняет шесть исходных порций.
    -- Это единственный разрешённый расход tracked FC целиком как ItemCount.
    if HCRBeerQuality and HCRBeerQuality.catalog.packing[recipe:getName()] and slot==0 then
        return HCRBeerQuality.packingInput(recipe,slot,script,item)
    end
    if HCRFluidRecipeQuality and HCRFluidRecipeQuality.allowed(recipe,slot,script) then
        return HCRFluidRecipeQuality.compatible(recipe,item,slot)
    end
    return not changesContents(script) or not Q.active(item,Q.fluid(item))
end

function C.prepareSafeInputs(logic)
    local data, saved = logic:getRecipeData(), {}
    local scripts, candidates = data:getRecipe():getInputs(), logic:getAllItems()
    for slot=0,scripts:size()-1 do
        local input, previous, safe = data:getInputItems(slot), {}, {}
        if input then
            for index=0,input:size()-1 do previous[#previous+1]=input:get(index) end
            saved[#saved+1]={input=input,previous=previous,safe=safe}
            for index=0,candidates:size()-1 do
                local item=candidates:get(index)
                -- Не доверяем canUseItem: queued reservations учитываются
                -- только при testOnly. Качество исключается из КАЖДОГО
                -- изменяющего слота до любых native проверок соответствия.
                if allowedItem(data:getRecipe(),slot,scripts:get(slot),item) then
                    safe[#safe+1]=item
                end
            end
        end
    end
    -- Сначала полностью вычислить план: ошибка чтения качества не должна
    -- оставлять частично подменённые списки выбора пользователя.
    for _,entry in ipairs(saved) do
        entry.input:clear()
        for _,item in ipairs(entry.safe) do entry.input:add(item) end
    end
    return function()
        for _,entry in ipairs(saved) do
            entry.input:clear()
            for _,item in ipairs(entry.previous) do entry.input:add(item) end
        end
    end
end

-- Пробная проверка не расходует inputs. applied cache ненадёжен: native
-- softReset может стереть уже выбранный prefix после неподходящего кандидата.
local function check(logic)
    if not logic then return true end
    local data = logic:getRecipeData()
    local recipe = data and data:getRecipe()
    if not recipe then return true end
    local candidates = logic:getAllItems()
    local scripts = recipe:getInputs()
    local checksEmpty=false
    for index=0,scripts:size()-1 do
        if scripts:get(index):hasFlag(InputFlag.IsEmpty) then checksEmpty=true end
    end
    local tracked = false
    local function inspect(items)
        if not items then return end
        for index=0,items:size()-1 do
            local item = items:get(index)
            local fluid=Q.fluid(item)
            if Q.active(item,fluid) or (checksEmpty and fluid and Q.rawAmount(fluid)>.000001) then tracked = true; return end
        end
    end
    inspect(candidates)
    for index=0,scripts:size()-1 do inspect(data:getInputItems(index)) end
    if not tracked and not (HCRFluidRecipeQuality and HCRFluidRecipeQuality.rules[recipe:getName()]) then return true end
    if logic:isManualSelectInputs() then
        for index=0,scripts:size()-1 do
            local script = scripts:get(index)
            -- Инструмент mode:keep без изменения содержимого безопасен.
            if changesContents(script) then
                local selected = data:getInputItems(index)
                if selected then
                    for n=0,selected:size()-1 do
                        local item = selected:get(n)
                        if not allowedItem(recipe,index,script,item) then return false end
                    end
                end
            end
        end
        return true
    end
    local restore=C.prepareSafeInputs(logic)
    local ok,result=pcall(function() return data:canConsumeInputs(logic:getSourceResources()) end)
    restore()
    if not ok then error(result) end
    return result
end

function C.check(logic)
    if not logic then return true end
    local restore=C.borrowWorldFluids(logic)
    local ok,result=pcall(check,logic)
    restore()
    if not ok then error(result) end
    return result
end

HCRFluidActions.guard(ISHandcraftAction, {"performRecipe"}, function(self)
    return C.check(self.logic)
end)

HCRFluidActions.wrap(ISHandcraftAction, "performRecipe", function(self, operation)
    local logic = self.logic
    if not logic then return operation() end
    -- Native performCurrentRecipe заново собирает allItems из контейнеров.
    -- Фильтровать до него недостаточно! Узкий фасад сохраняет нативные проверки
    -- доступности/обновление пола, затем задаёт безопасные списки каждого слота.
    -- Остальной ISHandcraftAction (OnCreate, outputs, расход Food) остаётся native.
    local restoreInputs
    local restoreWorld
    local previousIngredients=self.hcrFluidIngredients
    self.hcrFluidIngredients=nil
    self.logic = setmetatable({performCurrentRecipe=function()
        local containers = logic:getContainers()
        if not logic:isContainersAccessible(containers) then return false end
        logic:updateFloorContainer(containers)
        restoreWorld=C.borrowWorldFluids(logic,true)
        local data = logic:getRecipeData()
        if not logic:isManualSelectInputs() then restoreInputs=C.prepareSafeInputs(logic) end
        if not data:canConsumeInputs(logic:getSourceResources()) then return false end
        if HCRMilkChains and not HCRMilkChains.check(data) then return false end
        -- Проверить Food metadata/суммарную дозу ДО native createOutputs.
        -- Иначе исключение в OnCreate оставляет уже выданный результат
        -- при ещё не израсходованных ингредиентах.
        local bridge=HCRFluidRecipeQuality
        local sources=bridge and bridge.capture(data) or {}
        if HCRFermentationRecipes and not HCRFermentationRecipes.plan(data,sources) then
            return HCRFluidActions.refuse(self,"Too many distinct fermentation batches")
        end
        if HCRBarDrinks and not HCRBarDrinks.plan(data,sources) then
            return HCRFluidActions.refuse(self,"Too many distinct bar ingredient batches")
        end
        if HCRBrewedDrinks and not HCRBrewedDrinks.plan(data,sources) then
            return HCRFluidActions.refuse(self,"Too many distinct brewed drink batches")
        end
        if HCRAlcoholPortions and not HCRAlcoholPortions.plan(data,sources) then
            return HCRFluidActions.refuse(self,"Too many distinct alcoholic cooking batches")
        end
        if HCRWineQuality and not HCRWineQuality.preflightSources(data,sources) then
            return HCRFluidActions.refuse(self,"Too many distinct wine batches or portions")
        end
        if HCRMilkChains and not HCRMilkChains.preflight(data,sources) then
            return HCRFluidActions.refuse(self,"Too many distinct liquid batches or portions")
        end
        local fluidDose=0
        if bridge then
            local allowed,dose=bridge.check(sources)
            if not allowed then return false end
            fluidDose=dose
        end
        if HCRFoodTransfers and not HCRFoodTransfers.checkCraft(data,fluidDose) then return false end
        local function perform() return data:perform(self.character,logic:getSourceResources(),nil,containers) end
        if not bridge then return perform() end
        local result,removed=bridge.perform(data,self.character,perform,sources)
        self.hcrFluidIngredients=removed
        return result
    end}, {__index=function(_, key)
        return function(_, ...) return logic[key](logic, ...) end
    end})
    local ok, result = pcall(operation)
    if restoreInputs then restoreInputs() end
    self.logic = logic
    self.hcrFluidIngredients=previousIngredients
    if restoreWorld then restoreWorld() end
    if not ok then error(result) end
    return result
end)
