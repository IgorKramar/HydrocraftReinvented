require "HCR_FluidLedger"
require "HCR_FluidEffects"
require "HCR_FluidCooling"
require "HCR_QualitySync"
require "HCR_FluidSync"
require "HCR_Fermentation"
HCRFluidQuality = HCRFluidQuality or {}
local Q, L = HCRFluidQuality, HCRFluidLedger
Q.key = "HCRFluidQuality"
Q.transport = Q.transport or {} -- populated by the generated drink catalogue
local fridgeFactors = {0.4, 0.3, 0.2, 0.1, 0.03, 0}
local rotSpeeds = {1.7, 1.4, 1, 0.7, 0.4}

function Q.item(owner)
    if not owner then return nil end
    if instanceof(owner, "InventoryItem") then return owner end
    if instanceof(owner, "IsoWorldInventoryObject") then return owner:getItem() end
    return nil
end

function Q.fluid(item)
    if not item then return nil end
    return item:getFluidContainer() or (item:getWorldItem() and item:getWorldItem():getFluidContainer())
end

function Q.amounts(fluid)
    local amounts = {}
    if not fluid then return amounts end
    for name in pairs(Q.transport) do
        local kind = Fluid.Get(name)
        assert(kind, "Missing registered transport fluid: " .. name)
        local amount = fluid:getSpecificFluidAmount(kind)
        if amount > 0 then amounts[name] = amount end
    end
    return amounts
end

-- getAmount() rounds the last 1 ml up to capacity. FluidSample exposes the
-- underlying components, including ordinary vanilla liquids in the mixture.
function Q.rawAmount(fluid)
    if not fluid then return 0 end
    local sample=fluid:createFluidSample()
    local total=sample:getAmount()
    sample:release()
    return total
end

function Q.active(item, fluid)
    if item and item:getModData()[Q.key] then return true end
    -- PZ's Kahlua omits Lua's global next(); pairs is available.
    for _ in pairs(Q.amounts(fluid)) do return true end
    return false
end

function Q.environment(item)
    local container = item:getOutermostContainer()
    local cold = container and (container:isFridge() or container:isFreezer())
    local square = container and container:getSourceGrid()
    local bag = container and container:getContainingItem()
    local world = item:getWorldItem() or (bag and bag:getWorldItem())
    if not square and world then square = world:getSquare() end
    local env = {cold=cold or false, freezer=container and container:isFreezer() or false,
        powered=square and square:haveElectricity() or false,
        operationalPowered=container and container:isPowered() or false,
        gridPowered=container and ItemContainer.isObjectPowered(container:getParent(),false) or false,
        temperature=container and container:getTemperature() or 1}
    if square then env.x, env.y, env.z = square:getX(), square:getY(), square:getZ() end
    return env
end

function Q.age(item, ledger, now)
    local current = Q.environment(item)
    -- Новое питание относится к следующему интервалу. Перепроверка старого
    -- square здесь задним числом охлаждала дни до включения генератора.
    local fridge = fridgeFactors[SandboxVars.FridgeFactor or 3] or 0.2
    local rot = rotSpeeds[SandboxVars.FoodRotSpeed or 3] or 1
    local shutdown = getSandboxOptions():getElecShutModifier() * 24
    -- Native Food.updateAge использует shutdown без поправки, а работа
    -- электросети учитывает месяцы до старта мира. Не объединяем эти часы.
    local gridShutdown = shutdown - (getSandboxOptions():getTimeSinceApo()-1)*30*24
    local unobserved=Q.storageUnobserved and Q.storageUnobserved(item) or false
    return HCRFluidCooling.advance(ledger, now, current, fridge, rot, shutdown, unobserved, gridShutdown)
end

function Q.capture(item, fluid)
    local amounts = Q.amounts(fluid)
    local ledger = item and item:getModData()[Q.key] or nil
    if not ledger then ledger = L.empty() end
    assert(L.matches(ledger, amounts), "Liquid quality does not match native contents")
    assert(item or #ledger.lots == 0, "Tracked liquid requires a portable vessel")
    if item then
        local now=getGameTime():getWorldAgeHours()
        ledger=Q.age(item,ledger,now)
        if not isClient() and HCRFermentation then
            local changed
            ledger,changed=HCRFermentation.refresh(item,fluid,ledger,now)
            if changed then
                -- Созревание — самостоятельное изменение мира. Завершить
                -- его до последующего preflight или частичного native расхода.
                Q.store(item,fluid,ledger);Q.sync(item)
                amounts=Q.amounts(fluid)
            end
        end
    end
    return {item=item, fluid=fluid, ledger=ledger, amounts=amounts, amount=Q.rawAmount(fluid)}
end

function Q.store(item, fluid, ledger)
    assert(not isClient(), "Only the server may change liquid quality")
    L.validate(ledger)
    assert(item and fluid, "Missing quality destination")
    assert(L.matches(ledger, Q.amounts(fluid)), "Liquid result does not match native contents")
    if HCRFermentation then
        -- Перенос в другую тару меняет режим выдержки только с этого момента.
        ledger=HCRFermentation.refresh(item,fluid,ledger,getGameTime():getWorldAgeHours())
    end
    local data = item:getModData()
    -- Открытая/начатая банка больше не считается исходной для перепаковки,
    -- даже если позже в неё вернули тот же объём. Обычное старение не снимает метку.
    local beer=HCRBeerQuality
    if beer and data[beer.key] and not beer.factoryValues(item,fluid,ledger) then data[beer.key]=nil end
    if #ledger.lots > 0 then
        assert(Q.rawAmount(fluid)>0, "Quality cannot remain in an empty vessel")
        ledger.storage = Q.environment(item)
        data[Q.key] = ledger
        if Q.watch then Q.watch(item,true) end
        if data.HCRFluidRainCatcher == nil then data.HCRFluidRainCatcher = fluid:getRainCatcher() end
        -- Native rain can replace part of a full vessel without changing volume.
        fluid:setRainCatcher(0)
    else
        data[Q.key] = nil
        if data.HCRFluidRainCatcher ~= nil then
            fluid:setRainCatcher(data.HCRFluidRainCatcher)
            data.HCRFluidRainCatcher = nil
        end
    end
end

function Q.sync(item, character, fullSnapshot)
    if not isServer() then return end
    local borrowed=Q.craftFluidOwners and Q.craftFluidOwners[item]
    if borrowed then
        borrowed.dirty=true
        borrowed.character=character or borrowed.character
        borrowed.fullSnapshot=fullSnapshot or borrowed.fullSnapshot
        return
    end
    if not fullSnapshot and HCRFluidSync.notify(item) then return end
    HCRQualitySync.bump(item)
    local world = item:getWorldItem()
    if world then
        -- Include the component in the same ordered world snapshot as modData.
        local component = world:getFluidContainer()
        assert(component, "Missing world liquid")
        GameEntityFactory.TransferComponent(world, item, ComponentType.FluidContainer)
        local ok, reason = pcall(function() world:sendObjectChange(IsoObjectChange.SWAP_ITEM) end)
        GameEntityFactory.TransferComponent(item, world, ComponentType.FluidContainer)
        if not ok then error(reason) end
    else
        local container = item:getContainer()
        local owner = container and container:getCharacter()
        if owner and instanceof(owner, "IsoPlayer") then
            item:syncItemFields()
            syncItemModData(owner, item)
        elseif container then
            -- Publish the outer bag, whose native container address is stable.
            -- A nested bag on the ground has no parent IsoObject of its own.
            local published, destination = item, container
            while destination:getContainingItem() do
                published = destination:getContainingItem()
                if published:getWorldItem() then
                    published:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
                    return
                end
                destination = published:getContainer()
                if not destination then return end
            end
            sendReplaceItemInContainer(destination, published, published)
        elseif character then
            syncItemModData(character, item)
        end
    end
end

function Q.syncStorage(item)
    if isServer() and not HCRQualitySync.send(item) then Q.sync(item) end
end

-- После последней tracked порции сосуд остаётся тем же сетевым предметом.
-- Обычная вода не получает ограничений еды, но её изменения внутри вложенной
-- сумки также должны дойти до клиентов (native адреса этого не гарантируют).
function Q.nativeOnly(character, operation, ...)
    local ok,result=pcall(operation)
    for _,item in pairs({...}) do
        if item and item:getModData()[HCRQualitySync.key] then Q.sync(item,character) end
    end
    if not ok then error(result) end
    return result
end

function Q.addNative(item, character, operation, sourceFluid, sourceObject)
    local fluid = Q.fluid(item)
    if not Q.active(item, fluid) then return Q.nativeOnly(character,operation,item) end
    local before = Q.capture(item, fluid)
    local incoming=HCRFermentation and HCRFermentation.active(before.ledger)
        and HCRFermentation.waterComponents(sourceObject) or nil
    assert(not HCRFermentation or HCRFermentation.checkMixture(before.ledger,fluid,sourceFluid,incoming),
        "Liquid mixture has no room for fermentation")
    local ok, result = pcall(operation)
    -- Tap water changes dilution, but cannot replace any tracked portion.
    Q.store(item, fluid, before.ledger)
    Q.sync(item, character)
    if not ok then error(result) end
    return result
end

-- Preflight is also used on the client to disable unsupported destinations.
function Q.checkTransfer(source, target)
    local sourceItem, targetItem = Q.item(source:getOwner()), Q.item(target:getOwner())
    local sf, tf = source:getFluidContainer(), target:getFluidContainer()
    if not Q.active(sourceItem, sf) and not Q.active(targetItem, tf) then return true end
    assert(sourceItem and targetItem and not source:isResource() and not target:isResource(),
        "Tracked drinks cannot enter an automatic machine or fixed fluid tank")
    local a, b = Q.capture(sourceItem, sf), Q.capture(targetItem, tf)
    local mixed=L.mix(a.ledger, b.ledger) -- enforce the lot limit BEFORE native mutation
    assert(not HCRFermentation or HCRFermentation.checkMixture(mixed,tf,sf),
        "Liquid mixture has no room for fermentation")
    return true, a, b
end

function Q.transfer(source, target, character, operation)
    local _, a, b = Q.checkTransfer(source, target)
    if not a then
        return Q.nativeOnly(character,operation,Q.item(source:getOwner()),Q.item(target:getOwner()))
    end
    assert(not isClient(), "Only the server may transfer tracked liquids")
    local ok, result = pcall(operation)
    local removed = math.max(0, a.amount - Q.rawAmount(a.fluid))
    local gained = math.max(0, Q.rawAmount(b.fluid) - b.amount)
    -- Up to eight final traces can be pruned, plus native's 1 ml full snap.
    -- Only marker volume tolerates this rounding; all Food units are conserved.
    assert(math.abs(removed - gained) < 0.002, "Native liquid transfer did not conserve volume")
    local kept, moved = L.withdrawNative(a.ledger,a.amounts,Q.amounts(a.fluid),
        a.amount>0 and math.min(1,removed/a.amount) or 0)
    local mixed=L.mix(b.ledger,moved)
    -- Validate both sides before publishing either. Native float32 volumes are
    -- independent of conserved nutrition/poison portions in the quality ledger.
    mixed = L.alignVolumes(mixed, Q.amounts(b.fluid), 0.00101)
    Q.store(a.item, a.fluid, kept)
    Q.store(b.item, b.fluid, mixed)
    Q.sync(a.item, character)
    Q.sync(b.item, character)
    if not ok then error(result) end
    return result
end

function Q.remove(item, character, operation, consume, useUtensil)
    local fluid = Q.fluid(item)
    if not Q.active(item, fluid) then return Q.nativeOnly(character,operation,item) end
    local before = Q.capture(item, fluid)
    -- Resolve prototypes/getters before mutation; missing definitions fail closed.
    if consume then HCRFluidEffects.prepare(before.ledger) end
    assert(not isClient(), "Only the server may remove tracked liquids")
    local ok, result = pcall(operation)
    local amount = math.max(0, before.amount - Q.rawAmount(fluid))
    local kept, removed = L.withdrawNative(before.ledger,before.amounts,Q.amounts(fluid),
        before.amount>0 and math.min(1,amount/before.amount) or 0)
    Q.store(item, fluid, kept)
    -- Удаление последнего компонента может теряться в float32 общей суммы.
    -- Порция определяется компонентами, а не округлённым суммарным объёмом.
    if consume and #removed.lots > 0 then
        HCRFluidEffects.consume(character, HCRFluidEffects.prepare(removed), useUtensil)
    end
    Q.sync(item, character)
    if not ok then error(result) end
    return result
end
