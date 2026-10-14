require "HCR_TimedItems"
require "HCR_ItemMigrations"

-- Состояние принадлежит серверу. Клиент не создаёт вторую копию урожая.
if isClient() then return end

local watchedSquares = {}

local function successor(item, now)
    if not HCRTimed.initialize(item, now) then return nil end
    local data = item:getModData()
    local target, started = HCRTimed.resolve(item:getFullType(), data.HCRTimedStart, now)
    if target == item:getFullType() then
        data.HCRTimedStart = started
        return nil
    end
    -- Не удаляем старый предмет до успешного создания нового.
    local replacement = instanceItem(target)
    if not replacement then
        print("[HydrocraftReinvented] Timed item unavailable: " .. target)
        return nil
    end
    for key, value in pairs(data) do replacement:getModData()[key] = value end
    replacement:getModData().HCRTimedStart = started
    replacement:setFavorite(item:isFavorite())
    return replacement
end

local function updateContainer(container, now, depth)
    if not container or depth > 8 then return false end
    local character = container:getCharacter()
    local playerOwned = character and instanceof(character, "IsoPlayer")
    -- Native packets address nested player bags by ID. Furniture and floor bags
    -- only expose the root container; publish their changed child bags there.
    local publishChanges = playerOwned or depth == 0
    local items = container:getItems()
    local pending, changed = false, false
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item then
            if item:getCategory() == "Container" then
                local childPending, childChanged = updateContainer(item:getItemContainer(), now, depth + 1)
                pending = childPending or pending
                if childChanged then
                    changed = true
                    -- Do not replace worn/carried player bags: their leaf packets
                    -- preserve equipment references. Other roots publish once.
                    if isServer() and depth == 0 and not playerOwned then
                        sendReplaceItemInContainer(container, item, item)
                    end
                end
            end
            local previousStart = item:getModData().HCRTimedStart
            local replacement = HCRItemMigrations.newReplacement(item)
            local timed = HCRTimed.initialize(item, now)
            if timed then
                pending = true
                replacement = replacement or successor(item, now)
            end
            if replacement or timed then
                if replacement then
                    container:AddItem(replacement)
                    container:Remove(item)
                    changed = true
                    if isServer() and publishChanges then
                        sendReplaceItemInContainer(container, item, replacement)
                    end
                elseif previousStart ~= item:getModData().HCRTimedStart then
                    changed = true
                    if isServer() then
                        if playerOwned then
                            syncItemModData(character, item)
                        elseif publishChanges then
                            sendReplaceItemInContainer(container, item, item)
                        end
                    end
                end
            end
        end
    end
    return pending, changed
end

local function updateSquare(square, now)
    if not square then return false end
    local pending = false
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        for j = 0, object:getContainerCount() - 1 do
            pending = updateContainer(object:getContainerByIndex(j), now, 0) or pending
        end
    end
    local worldItems = square:getWorldObjects()
    for i = worldItems:size() - 1, 0, -1 do
        local object = worldItems:get(i)
        local item = object:getItem()
        if item then
            if item:getCategory() == "Container" then
                pending = updateContainer(item:getItemContainer(), now, 0) or pending
            end
            local previousStart = item:getModData().HCRTimedStart
            local replacement = HCRItemMigrations.newReplacement(item)
            local timed = HCRTimed.initialize(item, now)
            if timed then
                pending = true
                replacement = replacement or successor(item, now)
            end
            if replacement or timed then
                if replacement then
                    -- Нативная замена сохраняет высоту, поворот, масштаб и ID.
                    -- Сервер рассылает её как SWAP_ITEM, без скачка в центр клетки.
                    object:swapItem(replacement)
                elseif isServer() and previousStart ~= item:getModData().HCRTimedStart then
                    -- Publish initial/normalized age before a client picks it up.
                    object:swapItem(item)
                end
            end
        end
    end
    return pending
end

local function watch(square)
    if not square then return end
    local now = getGameTime():getWorldAgeHours()
    if updateSquare(square, now) then
        local x, y, z = square:getX(), square:getY(), square:getZ()
        watchedSquares[x .. ":" .. y .. ":" .. z] = {x, y, z}
    end
end

local function updatePlayer(player, now)
    updateContainer(player:getInventory(), now, 0)
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    -- Только маленькая область около игроков. Координаты, а не ссылки на чанки.
    for dx = -5, 5 do
        for dy = -5, 5 do watch(getCell():getGridSquare(x + dx, y + dy, z)) end
    end
end

local function tick()
    local now = getGameTime():getWorldAgeHours()
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do updatePlayer(players:get(i), now) end
    else
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then updatePlayer(player, now) end
        end
    end
    for key, position in pairs(watchedSquares) do
        local square = getCell():getGridSquare(position[1], position[2], position[3])
        if not square or not updateSquare(square, now) then watchedSquares[key] = nil end
    end
end

-- Точка входа для повторяемых проверок в отдельном игровом профиле.
HCRTimed.updateContainer = updateContainer
HCRTimed.updateSquare = updateSquare

Events.LoadGridsquare.Add(watch)
Events.EveryTenMinutes.Add(tick)
Events.OnGameStart.Add(tick)
