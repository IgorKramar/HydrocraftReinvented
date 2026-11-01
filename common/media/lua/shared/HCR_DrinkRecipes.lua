require "HCR_JuiceRecipeRules"
require "HCR_DrinkFluids"
require "HCR_DrinkVessels"
HCRDrinkRecipes = {}
local R, Q, L, E = HCRDrinkRecipes, HCRFluidQuality, HCRFluidLedger, HCRFluidEffects

function R.test(rule, item)
    if not item then return false end
    if not HCRDrinkVessels.matches(rule.target,item) then return true end
    local fluid = Q.fluid(item)
    return fluid and fluid:isEmpty() and not Q.active(item, fluid)
        and fluid:getCapacity() >= rule.litres - .000001 or false
end

-- Новый сок: 3 дня свежести / 7 до порчи. Относительная свежесть каждого
-- фрукта переносится отдельно, старое/испорченное сырьё не омолаживается.
function R.juiceAge(age, fresh, rotten, newFresh, newRotten)
    if age < fresh and fresh > 0 then return age / fresh * newFresh end
    if rotten > fresh and age < rotten then
        return newFresh + (age-fresh)/(rotten-fresh)*(newRotten-newFresh)
    end
    return newRotten + math.max(0, age-rotten)
end

function R.create(rule, data, character)
    assert(not isClient(), "Drink production belongs to the server")
    local script = data:getRecipe():getInputs():get(rule.vesselSlot)
    local applied = assert(data:getDataForInputScript(script), "Missing juice vessel slot")
    local count = rule.count or 1
    local totalLitres = rule.batchLitres or rule.litres*count
    assert(applied:getAppliedItemsCount() == count, "Ambiguous juice vessels")
    local vessels, seen = {}, {}
    for index=0,count-1 do
        local vessel = applied:getAppliedItem(index)
        assert(not seen[vessel] and HCRDrinkVessels.matches(rule.target,vessel)
            and R.test(rule, vessel), "Juice vessel is no longer empty")
        seen[vessel] = true
        vessels[#vessels+1] = vessel
    end
    local portions = HCRFood.getConsumedFoodFractions(data)
    local total = 0
    for _, fraction in pairs(portions) do total = total + fraction end
    assert(total > 0, "Juice requires actual consumed fruit")
    local ledger = L.empty()
    for food, fraction in pairs(portions) do
        local snapshot = HCRFoodTransfers.foodSnapshot(data,food)
        snapshot.sourceType = rule.sourceFood
        snapshot.age = R.juiceAge(snapshot.age, snapshot.offAge, snapshot.offAgeMax,
            rule.freshDays, rule.rottenDays)
        snapshot.offAge, snapshot.offAgeMax = rule.freshDays, rule.rottenDays
        snapshot.canBeFrozen = false -- Сохранено upstream CantBeFrozen для соков.
        snapshot.frozen, snapshot.freezingTime = false, 0
        local batch = L.batch(rule.fluid, totalLitres*fraction/total, snapshot, getGameTime():getWorldAgeHours())
        batch.lots[1].units = fraction
        ledger = L.mix(ledger, batch)
    end
    E.prepare(ledger) -- Проверить все Food-прототипы до изменения сосуда.
    if HCRFoodTransfers.deferCreate(data,function() R.create(rule,data,character) end,true) then return end
    for index, vessel in ipairs(vessels) do
        local fluid = Q.fluid(vessel)
        local litres = math.min(rule.litres,totalLitres-(index-1)*rule.litres)
        local _, portion = L.split(ledger, litres, totalLitres)
        fluid:addFluid(rule.fluid, litres)
        assert(math.abs(Q.rawAmount(fluid)-litres) < .00001, "Native juice fill was rejected")
        portion = L.alignVolumes(portion, Q.amounts(fluid))
        Q.store(vessel, fluid, portion)
        Q.sync(vessel, character)
    end
end

for token, rule in pairs(HCRJuiceRecipeRules) do
    local definition = rule
    R["Test_"..token] = function(item) return R.test(definition, item) end
    R["Create_"..token] = function(data, character) return R.create(definition, data, character) end
end
