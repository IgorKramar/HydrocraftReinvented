-- Native HashSet определяет порядок расхода. Снимок и измерение после него
-- надёжнее Lua-симуляции getCurrentUses, особенно при дробном raw hunger.
HCRFoodConsumption={}
local C=HCRFoodConsumption
C.values={"getCalories","getCarbohydrates","getLipids","getProteins","getHungChange","getBaseHunger"}

local function present(item)
    local container=item:getContainer()
    if container and container:contains(item) then return true end
    local world=item:getWorldItem()
    return world and world:getWorldObjectIndex()>=0 or false
end

function C.capture(data,candidates)
    local entries={}
    local scripts=data:getRecipe():getInputs()
    for slot=0,scripts:size()-1 do
        local script=scripts:get(slot)
        local applied=data:getDataForInputScript(script)
        if not script:isKeep() and applied then
            local selected=candidates and data:getInputItems(slot) or nil
            local count=selected and selected:size() or applied:getAppliedItemsCount()
            for i=0,count-1 do
                local item=selected and selected:get(i) or applied:getAppliedItem(i)
                if item and not entries[item] then
                    local entry={item=item,uses=item:getCurrentUses(),present=present(item)}
                    if item:IsFood() then
                        item:updateAge(false)
                        HCRFoodQuality.reconcile(item)
                        entry.values={}
                        for _,getter in ipairs(C.values) do entry.values[getter]=item[getter](item) end
                        local F=HCRFoodQuality
                        entry.dose=F.dose(item);entry.quality=F.quality(item)
                        entry.tainted=F.tainted(item);entry.taint=item:getModData()[F.taintKey]
                        entry.floor=item:getModData()[F.qualityKey]
                        entry.tracked=F.active(item)
                        local saved=item:getModData()[F.key]
                        entry.detection=saved and saved.detection or item:getPoisonDetectionLevel()
                        entry.poisoner=item:getModData().addedPoisonBy
                    end
                    entries[item]=entry
                end
            end
        end
    end
    return entries
end

function C.measure(entries)
    local fractions={}
    for item,entry in pairs(entries) do
        local removed=entry.present and not present(item)
        local used=removed and entry.uses or math.max(0,entry.uses-item:getCurrentUses())
        local fraction=entry.uses>0 and used/entry.uses or 0
        if removed then fraction=1
        elseif entry.values and entry.values.getBaseHunger~=0 and math.abs(entry.values.getHungChange)>.00000001 then
            fraction=(entry.values.getHungChange-item:getHungChange())/entry.values.getHungChange
            -- Float32 может превратить оставшиеся 2 uses в 1 при truncation.
            -- Реально снятое число порций определяется изменением raw hunger.
            used=math.min(entry.uses,math.max(0,math.abs(entry.values.getHungChange)*fraction*100))
        end
        entry.fraction=math.max(0,math.min(1,fraction))
        entry.used=used
        if entry.fraction>0 then fractions[item]=entry.fraction end
        if entry.values then
            entry.consumedValues={}
            for _,getter in ipairs(C.values) do
                -- BaseHunger native не масштабирует. У retained Food без
                -- hunger не масштабируются и nutrients: их расход равен нулю.
                if removed or getter=="getBaseHunger" then
                    entry.consumedValues[getter]=entry.values[getter]*entry.fraction
                else
                    entry.consumedValues[getter]=entry.values[getter]-item[getter](item)
                end
            end
        end
    end
    return fractions
end

function C.clearFood(entries)
    local F=HCRFoodQuality
    for item,entry in pairs(entries) do
        if entry.values then
            F.store(item,0)
            item:getModData()[F.qualityKey]=nil
            item:getModData()[F.taintKey]=nil
        end
    end
end

function C.restoreFood(entries,character)
    local F=HCRFoodQuality
    for item,entry in pairs(entries) do
        if entry.values then
            item:getModData()[F.qualityKey]=entry.fraction<1 and entry.floor or nil
            item:getModData()[F.taintKey]=entry.fraction<1 and entry.taint or nil
            F.store(item,entry.dose*(1-entry.fraction))
            F.reconcile(item)
            F.sync(item,character)
        end
    end
end
