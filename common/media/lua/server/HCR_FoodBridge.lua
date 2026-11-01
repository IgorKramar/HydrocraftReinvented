-- B42 вызывает OnCreate до processDestroyAndUsedItems. Собственные операции
-- переноса питания выполняются после native расхода по сохранённым значениям.
require "HCR_FoodQuality"
HCRFood = HCRFood or {}

local nutritionNames = {
    ["Hydrocraft.OnCreate.GenericFood"] = true,
    ["Hydrocraft.OnCreate.BakePotato"] = true,
    ["Hydrocraft.OnCreate.MakePotatoPancakes"] = true,
    ["Hydrocraft.OnCreate.MakePlainMashedPotatoes"] = true,
    ["Hydrocraft.OnCreate.MakeCreamyMashedPotatoes"] = true,
    ["Hydrocraft.OnCreate.MakeFrenchFries"] = true,
    ["Hydrocraft.OnCreate.MakeBowlofCereal"] = true,
}
local splitNames = {
    ["Hydrocraft.OnCreate.CutIntoTwoPieces"] = true,
    ["Hydrocraft.OnCreate.CutIntoSixPieces"] = true,
    ["Hydrocraft.OnCreate.CutIntoEightPieces"] = true,
}
local values = {
    {"getCalories", "setCalories"},
    {"getCarbohydrates", "setCarbohydrates"},
    {"getLipids", "setLipids"},
    {"getProteins", "setProteins"},
    {"getHungChange", "setHungChange"},
    {"getBaseHunger", "setBaseHunger"},
}

local function foodOutputs(data)
    local foods = {}
    local outputs = data:getAllCreatedItems()
    for i = 0, outputs:size() - 1 do
        local item = outputs:get(i)
        if item and item:IsFood() then foods[#foods + 1] = item end
    end
    return foods
end

local function firstConsumedFood(data)
    local inputs = data:getAllConsumedItems()
    for i = 0, inputs:size() - 1 do
        local item = inputs:get(i)
        if item and item:IsFood() then return item end
    end
end

-- До расхода это только предварительная оценка, для проверки и подготовки.
-- Native HashSet может выбрать другой порядок: питание/яд берут actualFractions
-- после processDestroyAndUsedItems. Food ReplaceOnUse при крафте отключён.
function HCRFood.getConsumedFractions(data)
    local state=HCRFoodTransfers and HCRFoodTransfers.contexts[data]
    if state and state.actualFractions then return state.actualFractions end
    local fractions = {}
    local scripts = data:getRecipe():getInputs()
    local used = {}
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        local applied = data:getDataForInputScript(script)
        if not script:isKeep() and applied then
            local required = script:getIntAmount()
            if script:isVariableAmount() then
                required = required * data:getCalculatedVariableInputRatio()
            end
            for j = 0, applied:getAppliedItemsCount() - 1 do
                local item = applied:getAppliedItem(j)
                if item and required > 0 then
                    local scale = script:getRelativeScale(item:getFullType())
                    local fraction
                    if script:isItemCount() then
                        fraction = 1
                        required = required - 1 / scale
                    else
                        local available = math.max(0, item:getCurrentUses() - (used[item] or 0))
                        local requested = math.ceil(required)
                        local consumed = math.min(available, math.floor(requested * scale), requested)
                        local totalUses = item:getCurrentUses()
                        fraction = totalUses > 0 and consumed / totalUses or 0
                        used[item] = (used[item] or 0) + consumed
                        required = required - consumed / scale
                    end
                    if fraction > 0 then
                        fractions[item] = math.min(1, (fractions[item] or 0) + fraction)
                    end
                end
            end
        end
    end
    return fractions
end

function HCRFood.getConsumedFoodFractions(data)
    local foods={}
    for item,fraction in pairs(HCRFood.getConsumedFractions(data)) do
        if item:IsFood() then foods[item]=fraction end
    end
    return foods
end

function HCRFood.returnContainer(data, character, fullType)
    if not data or not character then return end
    if HCRFoodTransfers and HCRFoodTransfers.deferCreate(data,function()
        HCRFood.returnContainer(data,character,fullType)
    end) then return end
    local shortType = string.match(fullType, "%.([^%.]+)$")
    for item, fraction in pairs(HCRFood.getConsumedFoodFractions(data)) do
        local replacement = item:getReplaceOnUse()
        if fraction >= 1 and (replacement == fullType or replacement == shortType) then
            character:getInventory():AddItem(fullType)
        end
    end
end

local function aggregate(data, outputs)
    local totals = {0, 0, 0, 0, 0, 0}
    local count = 0
    for item, fraction in pairs(HCRFood.getConsumedFoodFractions(data)) do
        count = count + 1
        for k, accessors in ipairs(values) do
            local amount=HCRFoodTransfers and HCRFoodTransfers.consumedValue(data,item,accessors[1],fraction)
                or item[accessors[1]](item)*fraction
            totals[k] = totals[k] + amount
        end
    end
    if count == 0 then
        print("[HydrocraftReinvented] Food recipe has no consumed food: " .. data:getRecipe():getName())
        return
    end
    for _, output in ipairs(outputs) do
        for k, accessors in ipairs(values) do
            output[accessors[2]](output, totals[k] / #outputs)
        end
    end
end

function HCRFood.tryOnCreate(name, data, character)
    if not nutritionNames[name] and not splitNames[name] then return false end
    local outputs = foodOutputs(data)
    if #outputs == 0 then return true end
    if splitNames[name] then
        local source = firstConsumedFood(data)
        if source then
            local fraction=HCRFood.getConsumedFoodFractions(data)[source]
            assert(fraction==1,"Split recipe must consume one whole remaining food")
            local dose=HCRFoodQuality.dose(source)
            for _, output in ipairs(outputs) do
                output:copyFoodFromSplit(source, #outputs)
                -- Native копирует полный integer poison в КАЖДУЮ часть.
                HCRFoodQuality.store(output,dose/#outputs)
                HCRFoodQuality.sync(output,character)
            end
            -- Все текущие split inputs — ItemCount: остаток съеденного ранее
            -- блюда уходит целиком. Не переносить его яд в возвращаемую посуду.
            HCRFoodQuality.store(source,0)
            -- Food ReplaceOnUse is disabled during native crafting; return the
            -- original dish once, independent of the number of output portions.
            local replacement = source:getReplaceOnUse()
            if replacement and replacement ~= "" then
                local fullType = string.find(replacement, "%.") and replacement or "Base." .. replacement
                HCRFood.returnContainer(data, character, fullType)
            end
        end
    else
        if not HCRFoodTransfers or not HCRFoodTransfers.deferCreate(data,function() aggregate(data,outputs) end) then
            aggregate(data, outputs)
        end
    end
    return true
end
