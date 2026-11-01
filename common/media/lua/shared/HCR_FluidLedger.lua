-- Quality belongs to liquid, including liquid poured into a vanilla vessel.
-- This module is deliberately independent of the engine/network. All operations
-- return new saveable tables: a failed preflight cannot mutate either inventory.
require 'HCR_FermentationClock'
HCRFluidLedger = {}
local L = HCRFluidLedger
local EPS = 0.000001
L.VERSION = 1
L.MAX_LOTS = 128
L.MAX_UNITS = 4096 -- Предел native применений за одно действие, проверяется до расхода.
local booleans = {tainted=true, cooked=true, burnt=true, frozen=true, canBeFrozen=true,
    dangerousUncooked=true, alcoholic=true}
local numbers = {age=true, offAge=true, offAgeMax=true, hungChange=true,
    baseHunger=true, thirstChange=true, boredomChange=true, unhappyChange=true,
    stressChange=true, enduranceChange=true, fatigueChange=true, calories=true,
    proteins=true, lipids=true, carbohydrates=true, poisonPower=true,
    poisonDetectionLevel=true, useForPoison=true, poisonLevelForRecipe=true,
    foodSicknessChange=true, painReduction=true, fluReduction=true,
    reduceInfectionPower=true, alcoholPower=true, freezingTime=true, heat=true,
    nativeAlcohol=true, spoilHunger=true}

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end
L.copy = copy

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

function L.empty()
    return {version=L.VERSION, lots={}}
end

-- food is an unmodified Food snapshot for basisLitres, not for the remainder.
-- Доза poisonPower может быть дробной после использования напитка в блюде.
function L.batch(fluid, litres, food, now)
    assert(type(fluid) == "string" and fluid ~= "", "Missing fluid identity")
    assert(finite(litres) and litres > 0, "Invalid batch volume")
    assert(finite(now), "Invalid batch time")
    assert(type(food) == "table", "Missing food quality")
    local result = {version=L.VERSION, lots={{fluid=fluid, litres=litres,
        basisLitres=litres, units=1, food=copy(food), age=food.age or 0, lastHour=now}}}
    L.validate(result)
    return result
end

function L.validate(ledger)
    assert(type(ledger) == "table" and ledger.version == L.VERSION, "Unknown fluid ledger version")
    if ledger.storage ~= nil then
        local storage = ledger.storage
        assert(type(storage) == "table", "Invalid liquid storage")
        for _, key in ipairs({"cold", "freezer", "powered"}) do
            assert(type(storage[key]) == "boolean", "Invalid liquid storage flag: " .. key)
        end
        for _, key in ipairs({"operationalPowered", "gridPowered"}) do
            assert(storage[key]==nil or type(storage[key])=="boolean", "Invalid liquid storage flag: " .. key)
        end
        assert(finite(storage.temperature), "Invalid liquid storage temperature")
        local position = storage.x ~= nil or storage.y ~= nil or storage.z ~= nil
        if position then
            for _, key in ipairs({"x", "y", "z"}) do
                assert(finite(storage[key]) and storage[key] == math.floor(storage[key]),
                    "Invalid liquid storage coordinate: " .. key)
            end
        end
    end
    assert(type(ledger.lots) == "table", "Missing fluid lots")
    local count = 0
    for index in pairs(ledger.lots) do
        assert(finite(index) and index >= 1 and index == math.floor(index), "Invalid lot index")
        count = count + 1
    end
    assert(count <= L.MAX_LOTS, "Too many distinct liquid batches")
    for index = 1, count do assert(ledger.lots[index] ~= nil, "Sparse fluid lots") end
    local totalUnits=0
    for _, lot in ipairs(ledger.lots) do
        if lot.fermentation~=nil then HCRFermentationClock.validate(lot.fermentation) end
        assert(type(lot.fluid) == "string" and lot.fluid ~= "", "Missing lot identity")
        -- Native near-full blending can discard a trace marker. Its conserved
        -- dose remains in the surrounding liquid until consumed or emptied.
        assert(finite(lot.litres) and lot.litres >= 0, "Invalid lot volume")
        assert(finite(lot.basisLitres) and lot.basisLitres > 0, "Invalid reference volume")
        assert(finite(lot.units) and lot.units > 0, "Invalid reference portion")
        totalUnits=totalUnits+math.ceil(lot.units)
        assert(totalUnits<=L.MAX_UNITS,"Liquid batch exceeds application limit")
        assert(finite(lot.age) and lot.age >= 0 and finite(lot.lastHour), "Invalid lot age")
        assert(type(lot.food) == "table", "Missing lot quality")
        for key, value in pairs(lot.food) do
            assert(type(key) == "string", "Invalid quality key")
            assert((booleans[key] and type(value) == "boolean")
                or (numbers[key] and finite(value))
                or (key == "sourceType" and type(value) == "string" and value ~= ""),
                "Invalid quality field: " .. key)
        end
        assert(not lot.food.poisonPower or (lot.food.poisonPower >= 0
            and lot.food.poisonPower <= 1000000), "Invalid poison power")
        assert(not lot.food.nativeAlcohol or (lot.food.nativeAlcohol>=0
            and lot.food.nativeAlcohol<=1000000),"Invalid native alcohol")
    end
    return true
end

function L.volume(ledger, fluid)
    local amount = 0
    for _, lot in ipairs(ledger.lots) do
        if not fluid or lot.fluid == fluid then amount = amount + lot.litres end
    end
    return amount
end

function L.budget(ledger, field)
    local amount = 0
    for _, lot in ipairs(ledger.lots) do
        amount = amount + (lot.food[field] or 0) * lot.units
    end
    return amount
end

-- nativeAmounts contains ONLY registered HCR transport fluid IDs, not vanilla
-- water or other native fluids whose effects remain owned by the engine.
-- Check native transport-fluid amounts individually. Checking only the total
-- would let an untracked poisonous batch hide inside an unrelated water volume.
function L.matches(ledger, nativeAmounts)
    L.validate(ledger)
    local expected = {}
    for _, lot in ipairs(ledger.lots) do
        expected[lot.fluid] = (expected[lot.fluid] or 0) + lot.litres
    end
    for fluid, amount in pairs(nativeAmounts) do
        if not finite(amount) or amount < 0 or math.abs(amount - (expected[fluid] or 0)) > EPS then
            return false
        end
    end
    for fluid, amount in pairs(expected) do
        if math.abs(amount - (nativeAmounts[fluid] or 0)) > EPS then return false end
    end
    return true
end

-- Homogeneous mixing: every source lot contributes the same fraction of its
-- volume, including when the rest of the vessel is untracked vanilla water.
function L.split(ledger, withdrawn, nativeBefore)
    L.validate(ledger)
    assert(finite(nativeBefore) and nativeBefore >= 0, "Invalid native volume")
    assert(finite(withdrawn) and withdrawn >= 0 and withdrawn <= nativeBefore + EPS,
        "Withdrawal exceeds native volume")
    assert(L.volume(ledger) <= nativeBefore + EPS, "Ledger exceeds native volume")
    local kept, removed = L.empty(), L.empty()
    local fraction = nativeBefore > 0 and math.min(1, withdrawn / nativeBefore) or 0
    for _, lot in ipairs(ledger.lots) do
        local amount = lot.litres * fraction
        if fraction > 0 then
            local moved = copy(lot)
            moved.litres = amount
            moved.units = lot.units * fraction
            removed.lots[#removed.lots + 1] = moved
        end
        -- Do not discard small remainders: many tiny sips must conserve poison.
        if fraction < 1 then
            local left = copy(lot)
            left.litres = lot.litres - amount
            left.units = lot.units * (1 - fraction)
            kept.lots[#kept.lots + 1] = left
        end
    end
    return kept, removed
end

-- Account for the actual component removed by B42, including its final-drop
-- pruning below 0.1 ml. A zero-marker trace follows the remaining bulk.
function L.withdrawNative(ledger, before, after, bulkFraction)
    assert(L.matches(ledger,before), "Invalid native withdrawal source")
    assert(finite(bulkFraction) and bulkFraction>=0 and bulkFraction<=1, "Invalid bulk fraction")
    local kept,removed=L.empty(),L.empty()
    for _,lot in ipairs(ledger.lots) do
        local b,a=before[lot.fluid] or 0,after[lot.fluid] or 0
        assert(a<=b+EPS, "Withdrawal added tracked liquid")
        local fraction=b>0 and math.max(0,math.min(1,(b-a)/b)) or bulkFraction
        if fraction>0 then
            local part=copy(lot);part.units=lot.units*fraction;part.litres=lot.litres*fraction
            removed.lots[#removed.lots+1]=part
        end
        if fraction<1 then
            local part=copy(lot);part.units=lot.units*(1-fraction)
            part.litres=b>0 and lot.litres*a/b or 0
            kept.lots[#kept.lots+1]=part
        end
    end
    assert(L.matches(kept,after), "Invalid native withdrawal remainder")
    return kept,removed
end

local function equivalent(a, b)
    return a.fluid == b.fluid and a.basisLitres == b.basisLitres
        and a.age == b.age and a.lastHour == b.lastHour and same(a.food, b.food)
        and same(a.fermentation,b.fermentation)
end

local function merged(first, second)
    L.validate(first)
    L.validate(second)
    local result = copy(first)
    for _, incoming in ipairs(second.lots) do
        local found = false
        for _, present in ipairs(result.lots) do
            if equivalent(present, incoming) then
                present.litres = present.litres + incoming.litres
                present.units = present.units + incoming.units
                found = true
                break
            end
        end
        if not found then result.lots[#result.lots + 1] = copy(incoming) end
    end
    return result
end

function L.canMix(first,second)
    local result=merged(first,second)
    if #result.lots>L.MAX_LOTS then return false end
    local units=0
    for _,lot in ipairs(result.lots) do units=units+math.ceil(lot.units) end
    return units<=L.MAX_UNITS
end

function L.mix(first,second)
    local result=merged(first,second)
    assert(#result.lots <= L.MAX_LOTS, "Too many distinct liquid batches")
    L.validate(result)
    return result
end

function L.transfer(source, target, withdrawn, nativeBefore)
    local kept, removed = L.split(source, withdrawn, nativeBefore)
    return kept, L.mix(target, removed)
end

-- Native volume uses float32. A 64 L -> 0 L pour of .1 L loses .09999847 L
-- from the source but adds .100000001 L to the target. Keep the actual volumes
-- for the next operation while preserving the separately conserved Food units.
function L.alignVolumes(ledger, nativeAmounts, precision)
    L.validate(ledger)
    local totals = {}
    for _, lot in ipairs(ledger.lots) do
        totals[lot.fluid] = (totals[lot.fluid] or 0) + lot.litres
    end
    for fluid, amount in pairs(nativeAmounts) do
        assert(finite(amount) and amount >= 0, "Invalid native fluid amount")
        assert(totals[fluid] or amount == 0, "Native fluid has no quality record")
    end
    local result = copy(ledger)
    for _, lot in ipairs(result.lots) do
        local actual, expected = nativeAmounts[lot.fluid] or 0, totals[lot.fluid]
        assert(math.abs(actual - expected) <= math.max(precision or 0.0001, expected * 0.00001),
            "Quality differs from native contents beyond floating-point precision")
        assert(expected>0 or actual==0, "Untracked native liquid replaced a trace")
        lot.litres = expected>0 and lot.litres * actual / expected or 0
    end
    assert(L.matches(result, nativeAmounts), "Could not reconcile native liquid precision")
    return result
end

-- effectiveHours is supplied by the engine adapter and integrates refrigerator
-- power cut-off/frozen intervals. Updating a timestamp twice adds no age.
function L.advance(ledger, now, effectiveHours)
    L.validate(ledger)
    assert(finite(now), "Invalid ageing time")
    local result = copy(ledger)
    for _, lot in ipairs(result.lots) do
        if now > lot.lastHour then
            local elapsed = effectiveHours(lot.lastHour, now, lot)
            assert(finite(elapsed) and elapsed >= 0, "Invalid ageing interval")
            lot.age = lot.age + elapsed / 24
            lot.lastHour = now
        end
    end
    return result
end

-- Freshness never averages across lots: adding fresh juice cannot rejuvenate
-- the old juice or erase its poison. UI uses the worst state of the mixture.
function L.quality(ledger)
    local state = "fresh"
    for _, lot in ipairs(ledger.lots) do
        if lot.food.offAgeMax and lot.age >= lot.food.offAgeMax then return "rotten" end
        if lot.food.offAge and lot.age >= lot.food.offAge then state = "stale" end
    end
    return state
end
