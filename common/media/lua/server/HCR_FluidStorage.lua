require "HCR_FluidQuality"
if isClient() then return end
local Q = HCRFluidQuality
local watched = {}
local online = {}

local function storedQuality(item)
    if not item then return nil end
    local data=item:getModData()
    if data[Q.key] then return data[Q.key] end
    local process=HCRProcessQuality and data[HCRProcessQuality.key]
    return process and process.clock or nil
end

local function signature(env)
    return tostring(env.cold) .. ":" .. tostring(env.freezer) .. ":" .. tostring(env.powered)
        .. ":" .. tostring(env.operationalPowered) .. ":" .. tostring(env.gridPowered)
        .. ":" .. tostring(env.x) .. ":" .. tostring(env.y) .. ":" .. tostring(env.z)
        .. ":" .. tostring(math.floor(env.temperature * 10))
end

function Q.storageUnobserved(item)
    return watched[item] and watched[item].resuming or false
end

function Q.watch(item,observed)
    if HCRFoodQuality then HCRFoodQuality.reconcile(item) end
    local data=storedQuality(item)
    if data then
        -- swapItem меняет factory ID на ID старого world-предмета. Ключ по
        -- самому объекту не оставляет второй вечный observer под прежним ID.
        local previous=watched[item]
        watched[item] = {item=item, environment=signature(data.storage or Q.environment(item)),
            resuming=not observed and (not previous or previous.resuming) or false}
    end
end

local function scan(container, depth)
    if not container or depth > 8 then return end
    local items = container:getItems()
    for index = 0, items:size()-1 do
        local item = items:get(index)
        Q.watch(item)
        if instanceof(item, "InventoryContainer") then scan(item:getItemContainer(), depth+1) end
    end
end

local function scanSquare(square)
    if not square then return end
    local objects = square:getObjects()
    for index = 0, objects:size()-1 do
        local object = objects:get(index)
        for n = 0, object:getContainerCount()-1 do scan(object:getContainerByIndex(n), 0) end
    end
    local world = square:getWorldObjects()
    for index = 0, world:size()-1 do
        local item = world:get(index):getItem()
        if item then
            Q.watch(item)
            if instanceof(item, "InventoryContainer") then scan(item:getItemContainer(), 0) end
        end
    end
end

local function players(force)
    local present = {}
    local function visit(player)
        if not player then return end
        present[player] = true
        if force or not online[player] then scan(player:getInventory(), 0) end
    end
    if isServer() then
        local list = getOnlinePlayers()
        for index=0,list:size()-1 do visit(list:get(index)) end
    else
        for index=0,getNumActivePlayers()-1 do visit(getSpecificPlayer(index)) end
    end
    online = present
end

local function tick(checkpoint)
    players(false)
    for id, record in pairs(watched) do
        local item = record.item
        local container = item:getOutermostContainer()
        local owner = container and container:getCharacter()
        local bag = container and container:getContainingItem()
        local world = item:getWorldItem() or (bag and bag:getWorldItem())
        local square = world and world:getSquare() or (container and container:getSourceGrid())
        local available = owner and online[owner]
            or (square and getCell():getGridSquare(square:getX(),square:getY(),square:getZ()) == square)
        -- Do not keep Java inventories alive after disconnect/chunk unload or
        -- retain discarded samples forever. Normal load/player scans re-register.
        if not storedQuality(item) or not available then
            watched[id] = nil
        else
            local current = Q.environment(item)
            local changed=signature(current) ~= record.environment
            if changed or record.resuming or checkpoint then
                local quiet=not changed and not record.resuming
                local ok, reason = pcall(function()
                    if not item:getModData()[Q.key] and HCRProcessQuality then
                        HCRProcessQuality.checkpoint(item,quiet)
                        return
                    end
                    local fluid = Q.fluid(item)
                    local state = Q.capture(item, fluid)
                    Q.store(item, fluid, state.ledger)
                    if not quiet then Q.syncStorage(item) end
                end)
                if not ok then
                    print("[HydrocraftReinvented] Liquid storage observation deferred: " .. tostring(reason))
                    watched[id] = nil
                end
            end
        end
    end
end

Events.LoadGridsquare.Add(scanSquare)
Events.OnFillContainer.Add(function(_, _, container) scan(container, 0) end)
Events.OnTick.Add(function() tick(false) end)
Events.EveryTenMinutes.Add(function() players(true);tick(true) end)
-- Сохраняем границу наблюдавшегося интервала без сетевого пакета на каждый
-- десятиминутный checkpoint; переход условий по-прежнему синхронизируется.
Events.OnSave.Add(function() tick(true) end)
