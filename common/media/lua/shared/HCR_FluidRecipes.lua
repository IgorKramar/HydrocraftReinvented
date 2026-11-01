require "HCR_WaterRecipeRules"
require "HCR_FluidQuality"
HCRFluidRecipes = {}
local R, Q = HCRFluidRecipes, HCRFluidQuality

local function resolve(name)
    local fn = _G
    for part in name:gmatch("[^%.]+") do fn = fn and fn[part] end
    return assert(type(fn) == "function" and fn, "Missing previous water callback: " .. name)
end

local function waterOnly(fluid)
    if not fluid or fluid:getAmount() <= 0 then return false end
    local water = fluid:getSpecificFluidAmount(Fluid.Water) + fluid:getSpecificFluidAmount(Fluid.TaintedWater)
    return math.abs(fluid:getAmount() - water) < 0.000001
end

function R.test(rule, item, character)
    if not item then return false end
    if rule.previousTest and not resolve(rule.previousTest)(item, character) then return false end
    local kind, fluid = item:getFullType(), Q.fluid(item)
    -- Native IsEmpty handles item-owned components but misses ground-owned FC.
    -- Do not reject a full inventory provider selected by a different -fluid slot.
    if item:getWorldItem() and fluid and fluid:getAmount() > 0 then
        for _, target in ipairs(rule.empty) do if kind == target then return false end end
    end
    local water = rule.water[kind]
    if water then
        if not waterOnly(fluid) or Q.active(item, fluid) then return false end
        if water.minimum and fluid:getAmount() < water.minimum then return false end
        if water.exact and math.abs(fluid:getAmount()-water.exact) > 0.00001 then return false end
    end
    if rule.addWater and rule.addWater.target == kind then
        if not fluid or Q.active(item, fluid) then return false end
        if fluid:getAmount() > 0 and not waterOnly(fluid) then return false end
        if fluid:getCapacity()-fluid:getAmount() < rule.addWater.litres-0.000001 then return false end
    end
    return true
end

function R.create(rule, data, character)
    local inputs = data:getAllInputItems()
    for index = 0, inputs:size()-1 do
        local item = inputs:get(index)
        local fluid = Q.fluid(item)
        if rule.purify and rule.water[item:getFullType()] then
            assert(waterOnly(fluid) and not Q.active(item, fluid), "Purification input changed")
            local amount = fluid:getAmount()
            fluid:Empty()
            fluid:addFluid(Fluid.Water, amount)
            item:syncItemFields()
            Q.sync(item, character)
        elseif rule.fill == item:getFullType() then
            assert(fluid and fluid:isEmpty(), "Pump vessel is no longer empty")
            fluid:addFluid(Fluid.TaintedWater, fluid:getCapacity())
            item:syncItemFields()
            Q.sync(item, character)
        elseif rule.addWater and rule.addWater.target == item:getFullType() then
            assert(R.test(rule, item, character), "Eyedropper destination changed")
            fluid:addFluid(Fluid.Water, rule.addWater.litres)
            item:syncItemFields()
            Q.sync(item, character)
        end
    end
    if rule.previousCreate then resolve(rule.previousCreate)(data, character) end
end

for token, rule in pairs(HCRWaterRecipeRules) do
    local definition = rule
    R["Test_"..token] = function(item, character) return R.test(definition, item, character) end
    if definition.purify or definition.fill or definition.addWater then
        R["Create_"..token] = function(data, character) return R.create(definition, data, character) end
    end
end
