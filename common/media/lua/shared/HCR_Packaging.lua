-- B42 CraftRecipe.OnTestItem invokes OnTest(item, character).
-- Explicit drinks packs unpack factory-fresh contents; accepting partly used
-- or refilled cans would create food or liquid. No blanket ItemIsFluid flag:
-- Hydrocraft beer/pop remain Food, while vanilla soda cans are FluidContainer.
HCRPackaging = HCRPackaging or {}
local templates = {}

function HCRPackaging.IsFullFactoryState(item, character)
    if not item then return false end
    local fullType = item:getFullType()
    local template = templates[fullType]
    if not template then
        template = instanceItem(fullType)
        if not template then return false end
        templates[fullType] = template
    end
    local fluid = item:getFluidContainer()
    if fluid then
        local expected = template:getFluidContainer()
        return expected ~= nil and fluid:isFull() and not fluid:isMixture()
            and not expected:isMixture()
            and fluid:getPrimaryFluid() == expected:getPrimaryFluid()
    end
    if item:IsFood() then
        if not item:isWholeFoodItem() then return false end
        if item:getPoisonPower() ~= template:getPoisonPower() then return false end
        if item:isCooked() ~= template:isCooked() or item:isBurnt() ~= template:isBurnt() then return false end
        if item:haveExtraItems() then return false end
        local spices = item:getSpices()
        if spices and spices:size() > 0 then return false end
        -- Drinks here are shelf-stable. If a perishable food is ever included,
        -- do not allow the factory-fresh unpacking cycle to reset its age.
        if item:getOffAge() < 100000000 and item:getAge() > template:getAge() then return false end
        return true
    end
    return false
end
