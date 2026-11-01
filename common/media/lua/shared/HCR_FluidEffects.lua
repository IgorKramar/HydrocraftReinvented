require "HCR_FluidLedger"
HCRFluidEffects = {}
local E = HCRFluidEffects

-- Raw getters avoid applying stale/rotten modifiers twice after migration.
local fields = {
    age={"getAge", "setAge"}, offAge={"getOffAge", "setOffAge"},
    offAgeMax={"getOffAgeMax", "setOffAgeMax"},
    hungChange={"getHungChange", "setHungChange"},
    baseHunger={"getBaseHunger", "setBaseHunger"},
    thirstChange={"getThirstChangeUnmodified", "setThirstChange"},
    boredomChange={"getBoredomChangeUnmodified", "setBoredomChange"},
    unhappyChange={"getUnhappyChangeUnmodified", "setUnhappyChange"},
    stressChange={"getStressChangeUnmodified", "setStressChange"},
    enduranceChange={"getEnduranceChangeUnmodified", "setEnduranceChange"},
    fatigueChange={"getFatigueChange", "setFatigueChange"},
    calories={"getCalories", "setCalories"}, proteins={"getProteins", "setProteins"},
    lipids={"getLipids", "setLipids"}, carbohydrates={"getCarbohydrates", "setCarbohydrates"},
    poisonPower={"getPoisonPower", "setPoisonPower"},
    poisonDetectionLevel={"getPoisonDetectionLevel", "setPoisonDetectionLevel"},
    useForPoison={"getUseForPoison", "setUseForPoison"},
    poisonLevelForRecipe={"getPoisonLevelForRecipe", "setPoisonLevelForRecipe"},
    foodSicknessChange={"getFoodSicknessChange", "setFoodSicknessChange"},
    painReduction={"getPainReduction", "setPainReduction"},
    fluReduction={"getFluReduction", "setFluReduction"},
    reduceInfectionPower={"getReduceInfectionPower", "setReduceInfectionPower"},
    alcoholPower={"getAlcoholPower", "setAlcoholPower"},
    freezingTime={"getFreezingTime", "setFreezingTime"}, heat={"getHeat", "setHeat"},
    tainted={"isTainted", "setTainted"}, cooked={"isCooked", "setCooked"},
    burnt={"isBurnt", "setBurnt"}, frozen={"isFrozen", "setFrozen"},
    canBeFrozen={"canBeFrozen", "setCanBeFrozen"},
    dangerousUncooked={"isbDangerousUncooked", "setbDangerousUncooked"},
    alcoholic={"isAlcoholic", "setAlcoholic"},
}
E.fields = fields

function E.snapshot(food)
    assert(food and food:IsFood(), "A liquid batch requires a Food source")
    if HCRFoodQuality then HCRFoodQuality.reconcile(food) end
    local result = {sourceType=food:getFullType()}
    for key, methods in pairs(fields) do
        result[key] = food[methods[1]](food)
    end
    if HCRFoodQuality and HCRFoodQuality.active(food) then
        result.poisonPower=HCRFoodQuality.dose(food)
    end
    return result
end

function E.sample(lot)
    local food = instanceItem(lot.food.sourceType or "Hydrocraft.HCRFluidSample")
    assert(food and food:IsFood(), "Missing HCR fluid sample prototype")
    for key, value in pairs(lot.food) do
        if key ~= "sourceType" and key ~= "poisonPower" and key ~= "nativeAlcohol" and key ~= "spoilHunger" then
            local methods = assert(fields[key], "Unknown quality field")
            food[methods[2]](food, value)
        end
    end
    food:setAge(lot.age)
    food:setPoisonPower(0) -- Точная доза применяется отдельно, без integer округления.
    food:setOnEat(nil)
    return food
end

local function neutral()
    local food = instanceItem("Hydrocraft.HCRFluidSample")
    assert(food and food:IsFood(), "Missing HCR fluid carrier prototype")
    food:setOnEat(nil)
    return food
end

function E.poisonCarrier()
    local food=neutral()
    food:setPoisonPower(127)
    return food
end

function E.poison(character,dose,carrier)
    assert(not isClient() and type(dose)=="number" and dose>=0 and dose<=1000000,"Invalid poison dose")
    if dose==0 then return end
    carrier=carrier or E.poisonCarrier()
    local body=character:getBodyDamage()
    local timer=body:getHealthFromFoodTimer()
    -- JustAteFood не ограничивает fraction единицей. Нейтральный carrier
    -- даёт только poison/pain, поэтому даже большая доза — один native вызов.
    body:JustAteFood(carrier,dose/127,false)
    body:setHealthFromFoodTimer(timer)
    if isServer() then
        syncPlayerStats(character,SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.POISON)
            +SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.PAIN))
    end
end

function E.prepare(removed)
    HCRFluidLedger.validate(removed)
    neutral() -- resolve the carrier before any native liquid is consumed
    local portions = {}
    for _, lot in ipairs(removed.lots) do
        if lot.units > 0 then
            portions[#portions + 1] = {sample=E.sample(lot), fraction=lot.units,
                poison=lot.food.poisonPower or 0,nativeAlcohol=lot.food.nativeAlcohol,
                spoilHunger=lot.food.spoilHunger}
        end
    end
    return portions
end

local function eatCarrier(character, carrier, fraction)
    local body = character:getBodyDamage()
    local timer = body:getHealthFromFoodTimer()
    assert(character:Eat(carrier, fraction, false), "Fluid nutrition carrier was rejected")
    -- JustAteFood on the neutral carrier must not round the existing timer.
    body:setHealthFromFoodTimer(timer)
end

-- Native Eat snaps small hunger/thirst portions to 100%. A neutral carrier
-- keeps its fraction exact; native JustAteFood applies quality/traits separately.
-- No client execution: EatFoodPacket already carries nutrition to that client.
function E.consume(character, portions, useUtensil)
    assert(not isClient(), "Only the server may consume tracked liquids")
    local body, stats = character:getBodyDamage(), character:getStats()
    local medicine,nativeAlcohol = 0,0
    for _, part in ipairs(portions) do
        local source, remaining = part.sample, part.fraction
        -- Coalescing identical batches can produce more than one reference
        -- portion. Eat clamps to 1, so split only the application, not the data.
        while remaining > 0 do
            local fraction = math.min(remaining, 1)
            if part.spoilHunger~=nil then
                -- Native DrinkFluid уже дал питание/алкоголь. Для порчи
                -- JustAteFood требует исходный hunger, но повторно насытить
                -- игрока или изменить лечебный таймер эта добавка не должна.
                local timer=body:getHealthFromFoodTimer()
                source:setHungChange(part.spoilHunger)
                body:JustAteFood(source,fraction,useUtensil or false)
                body:setHealthFromFoodTimer(timer)
                E.poison(character,(part.poison or 0)*fraction)
            else
            local carrier = neutral()
            carrier:setEnduranceChange(source:getEnduranceChange())
            carrier:setStressChange(source:getStressChange())
            carrier:setFatigueChange(source:getFatigueChange())
            local nutritionFactor = source:isBurnt() and 0.2 or 1
            carrier:setCalories(source:getCalories() * nutritionFactor)
            carrier:setProteins(source:getProteins() * nutritionFactor)
            carrier:setLipids(source:getLipids() * nutritionFactor)
            carrier:setCarbohydrates(source:getCarbohydrates() * nutritionFactor)
            carrier:setPainReduction(source:getPainReduction())
            carrier:setFluReduction(source:getFluReduction())
            eatCarrier(character, carrier, fraction)
            stats:add(CharacterStat.HUNGER, source:getHungerChange() * fraction)
            stats:add(CharacterStat.THIRST, source:getThirstChange() * fraction)
            local timer=body:getHealthFromFoodTimer()
            body:JustAteFood(source, fraction, useUtensil or false)
            if part.nativeAlcohol~=nil then
                -- Native напиток использует количество алкоголя жидкости,
                -- а не старую формулу Food с удвоением доли hunger.
                body:setHealthFromFoodTimer(math.floor(timer+math.abs(source:getHungerChange())*fraction*13000))
                nativeAlcohol=nativeAlcohol+part.nativeAlcohol*fraction
            end
            E.poison(character,(part.poison or 0)*fraction)
            medicine = medicine + math.min(0, source:getFoodSicknessChange()) * fraction
            end
            remaining = remaining - fraction
        end
    end
    -- Native DrinkFluid применяет алкоголь одной смешанной дозой после hunger.
    -- Разбиение на партии не должно менять пороги голода и лекарственные часы.
    if nativeAlcohol>0 then body:JustDrankBoozeFluid(nativeAlcohol) end
    if medicine < 0 then
        -- One combined dose enters the native medicine cooldown, rather than
        -- the first tiny component blocking all the others in the same sip.
        local carrier = neutral()
        local power = math.ceil(-medicine)
        carrier:setFoodSicknessChange(-power)
        eatCarrier(character, carrier, -medicine / power)
    end
    if isServer() then
        local mask = 0
        for _, name in ipairs({"HUNGER", "THIRST", "ENDURANCE", "STRESS", "FATIGUE",
            "PAIN", "POISON", "FOOD_SICKNESS", "BOREDOM", "UNHAPPINESS", "INTOXICATION"}) do
            mask = mask + SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat[name])
        end
        syncPlayerStats(character, mask)
        sendSyncPlayerFields(character, 8)
    end
end
