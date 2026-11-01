-- Native 42.21 Drainable stores integer uses, not a fractional usedDelta.
-- Keep the old item until a fully populated, validated replacement exists.
HCRFluidMigrations = HCRFluidMigrations or {}
require "HCR_WaterFamilies"
require "HCR_ItemNames"
local warned = {}

local function reject(kind, reason)
    local key = kind .. ":" .. reason
    if not warned[key] then
        print("[HydrocraftReinvented] Fluid migration deferred: " .. key)
        warned[key] = true
    end
    return nil
end

function HCRFluidMigrations.newReplacement(source, copyState)
    if not source or isClient() then return nil end
    local kind = source:getFullType()
    local definition = HCRWaterFamilies.migrations[kind]
    if not definition then return nil end
    -- Do not race native Equip against inventory replacement across channels.
    -- The normal server scan retries once the player has unequipped the flask.
    if isServer() and source:isEquipped() then return nil end
    local ok, target = pcall(instanceItem, definition.target)
    if not ok or not target then return reject(kind, "missing target") end
    local fluid = target:getFluidContainer()
    if not fluid then return reject(kind, "missing fluid component") end
    local oldFluid = source:getFluidContainer()
    local world = source:getWorldItem()
    if not oldFluid and world then oldFluid = world:getFluidContainer() end
    local amount = 0
    if oldFluid then
        amount = oldFluid:getAmount()
        local water = oldFluid:getSpecificFluidAmount(Fluid.Water)
                    + oldFluid:getSpecificFluidAmount(Fluid.TaintedWater)
        if amount > fluid:getCapacity() + 0.000001 or math.abs(amount - water) > 0.000001 then
            return reject(kind, "incompatible existing contents")
        end
        fluid:copyFluidsFrom(oldFluid)
    elseif definition.unitLitres > 0 then
        -- Do not use getCurrentUsesFloat(): a full .07 item returns .98.
        amount = source:getCurrentUses() * definition.unitLitres
        if amount < 0 or amount > fluid:getCapacity() + 0.000001 then
            return reject(kind, "legacy amount outside capacity")
        end
        -- User-approved policy: 42.21 no longer stores legacy Drainable taint.
        -- Unknown water needs purification; never silently create clean water.
        if amount > 0 then fluid:addFluid(Fluid.TaintedWater, amount) end
    end
    -- FC stores float32; 63.9 L cannot be represented to an absolute 1e-6 L.
    if math.abs(fluid:getAmount() - amount) > math.max(0.000001, amount * 0.000001) then
        return reject(kind, "volume validation failed")
    end
    copyState(source, target)
    -- Надпись хранится отдельно от native имени жидкости и видна в tooltip.
    if source:isCustomName() and not target:getModData().HCRLegacyCustomName then
        target:getModData().HCRLegacyCustomName = HCRItemNames.custom(source)
    end
    target:getModData().HCRMigrationFrom = kind
    target:getModData().HCRMigrationVersion = "1.6.0"
    return target
end

function HCRFluidMigrations.syncWorldReplacement(world)
    if not isServer() then return end
    local item = world:getItem()
    if not item or not (HCRWaterFamilies.targets[item:getFullType()]
        or item:getModData().HCRDrinkMigration) then return end
    local component = world:getFluidContainer()
    assert(component, "Migrated world flask has no fluid component")
    -- swapItem moves FC onto the world entity BEFORE its SWAP_ITEM snapshot.
    -- That first item snapshot therefore omits FC. Send a complete second
    -- snapshot on the SAME reliable ordered channel, temporarily owning FC on
    -- the item during synchronous packet serialization. Unordered object:sync
    -- can arrive before SWAP_ITEM; entity sync cannot find an unregistered world.
    GameEntityFactory.TransferComponent(world, item, ComponentType.FluidContainer)
    assert(item:getFluidContainer() == component, "World flask snapshot transfer failed")
    local ok, reason = pcall(function()
        world:sendObjectChange(IsoObjectChange.SWAP_ITEM)
    end)
    -- Always restore the authoritative component, even if sending throws.
    GameEntityFactory.TransferComponent(item, world, ComponentType.FluidContainer)
    assert(world:getFluidContainer() == component, "World flask component restore failed")
    if not ok then error(reason) end
end
