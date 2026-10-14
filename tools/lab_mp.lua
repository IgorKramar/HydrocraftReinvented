-- Private localhost lab helper; never install this file in the released mod.
-- Both endpoints: HCRLabMP.install(true). Real client: HCRLabMP.begin(getPlayer()).
-- No fake client observations and no automatic fixture creation on player events.
require "HCR_TimedItems"
if isServer() then require "HCR_TimedSystems" end

HCRLabMP = HCRLabMP or {sessions = {}, installed = false}
local MODULE = "HCRLabMP"
local SMALL = "Hydrocraft.HCPottedTomatocherrysmall"
local READY = "Hydrocraft.HCPottedTomatocherryready"
local CHEESE = "Hydrocraft.HCCheeserackfull"
local AGED = "Hydrocraft.HCCheeserackaged"
local MAX_TICKS = 3600

local function log(message) print("[HCRLabMP] " .. message) end
local function findWorld(square, id)
    if not square then return nil end
    local objects = square:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object:getItem() and object:getItem():getID() == id then return object end
    end
end
local function count(container, fullType)
    local total = 0
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == fullType then total = total + 1 end
        if item:getCategory() == "Container" then total = total + count(item:getItemContainer(), fullType) end
    end
    return total
end
local function squareFor(fixture)
    return getCell():getGridSquare(fixture.x, fixture.y, fixture.z)
end
local function observe(fixture, mature, player)
    player = player or getSpecificPlayer(0)
    if not player then return false, "player unavailable" end
    local carried = player:getInventory():getItemWithIDRecursiv(fixture.playerBagId)
    if not carried then return false, "native carried bag not replicated" end
    local carriedItems = carried:getItemContainer()
    if count(carriedItems, mature and READY or SMALL) ~= 1
        or count(carriedItems, mature and AGED or CHEESE) ~= 1
        or count(carriedItems, mature and "Hydrocraft.HCArmorchainmailWearable" or "Hydrocraft.HCArmorchainmail") ~= 1 then
        return false, "carried nested inventory counts differ"
    end
    if mature and (count(carriedItems, SMALL) ~= 0 or count(carriedItems, CHEESE) ~= 0
        or count(carriedItems, "Hydrocraft.HCArmorchainmail") ~= 0) then
        return false, "carried legacy items remain"
    end
    local square = squareFor(fixture)
    local bagObject = findWorld(square, fixture.bagId)
    local potObject = findWorld(square, fixture.potId)
    if not bagObject or not potObject then return false, "world IDs not visible" end
    local bag = bagObject:getItem()
    if bag:getCategory() ~= "Container" then return false, "root is not a bag" end
    local contents = bag:getItemContainer()
    if count(contents, "Base.Bag_Schoolbag") ~= 2 then return false, "nested bag count is not two" end
    if mature then
        if count(contents, READY) ~= 1 or count(contents, AGED) ~= 1
            or count(contents, SMALL) ~= 0 or count(contents, CHEESE) ~= 0 then
            return false, "nested successor/old counts differ"
        end
        if contents:getItemWithIDRecursiv(fixture.tomatoId)
            or contents:getItemWithIDRecursiv(fixture.cheeseId) then
            return false, "old nested IDs still exist"
        end
        if potObject:getItem():getFullType() ~= READY then return false, "standalone pot not transformed" end
    else
        local tomato = contents:getItemWithIDRecursiv(fixture.tomatoId)
        local cheese = contents:getItemWithIDRecursiv(fixture.cheeseId)
        if not tomato or tomato:getFullType() ~= SMALL
            or not cheese or cheese:getFullType() ~= CHEESE
            or potObject:getItem():getFullType() ~= SMALL then
            return false, "initial old IDs/types not visible"
        end
    end
    if math.abs(potObject:getWorldPosX() - fixture.px) > 0.001
        or math.abs(potObject:getWorldPosY() - fixture.py) > 0.001
        or math.abs(potObject:getWorldPosZ() - fixture.pz) > 0.001
        or math.abs(potObject:getItem():getWorldZRotation() - fixture.rotation) > 0.001 then
        return false, "standalone position/rotation changed"
    end
    -- IDs must be unique on the square, including retransmitted world fixtures.
    local seen, fixtureWorldCount = {}, 0
    local objects = square:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local item = objects:get(i):getItem()
        if item then
            if seen[item:getID()] then return false, "duplicate world item ID" end
            seen[item:getID()] = true
            if item:getModData().HCRLabSession == fixture.session then
                fixtureWorldCount = fixtureWorldCount + 1
            end
        end
    end
    if fixtureWorldCount ~= 2 then return false, "fixture world object count is not two" end
    return true, "ground and carried nested bags transformed once; legacy chainmail migrated; pot position preserved"
end

local function createFixture(player)
    local square = player:getCurrentSquare()
    assert(square, "Player square is unavailable")
    local outer = instanceItem("Base.Bag_Schoolbag")
    local middle = instanceItem("Base.Bag_Schoolbag")
    local inner = instanceItem("Base.Bag_Schoolbag")
    local tomato, cheese, pot = instanceItem(SMALL), instanceItem(CHEESE), instanceItem(SMALL)
    assert(outer and middle and inner and tomato and cheese and pot, "Native fixture item creation failed")
    outer:getItemContainer():AddItem(middle)
    middle:getItemContainer():AddItem(inner)
    inner:getItemContainer():AddItem(tomato)
    inner:getItemContainer():AddItem(cheese)
    -- Initially fresh: the normal timer cannot mature fixtures before client ACK.
    local now = getGameTime():getWorldAgeHours()
    for _, item in ipairs({tomato, cheese, pot}) do item:getModData().HCRTimedStart = now end
    local session = tostring(player:getOnlineID()) .. ":" .. tostring(outer:getID())
    outer:getModData().HCRLabSession = session
    pot:getModData().HCRLabSession = session
    local carried = instanceItem("Base.Bag_Schoolbag")
    local carriedInner = instanceItem("Base.Bag_Schoolbag")
    local carriedTomato, carriedCheese = instanceItem(SMALL), instanceItem(CHEESE)
    carriedTomato:getModData().HCRTimedStart = now
    carriedCheese:getModData().HCRTimedStart = now
    carried:getItemContainer():AddItem(carriedInner)
    carriedInner:getItemContainer():AddItem(carriedTomato)
    carriedInner:getItemContainer():AddItem(carriedCheese)
    carriedInner:getItemContainer():AddItem(instanceItem("Hydrocraft.HCArmorchainmail"))
    player:getInventory():AddItem(carried)
    sendAddItemToContainer(player:getInventory(), carried)
    square:AddWorldInventoryItem(outer, 0.21, 0.31, 0.0, true)
    square:AddWorldInventoryItem(pot, 0.73, 0.64, 0.08, true)
    local potObject = pot:getWorldItem()
    assert(potObject and outer:getWorldItem(), "Native world fixture creation failed")
    local fixture = {
        session = session,
        x = square:getX(), y = square:getY(), z = square:getZ(),
        bagId = outer:getID(), potId = pot:getID(),
        playerBagId = carried:getID(), carriedTomatoId = carriedTomato:getID(), carriedCheeseId = carriedCheese:getID(),
        tomatoId = tomato:getID(), cheeseId = cheese:getID(),
        px = potObject:getWorldPosX(), py = potObject:getWorldPosY(), pz = potObject:getWorldPosZ(),
        rotation = pot:getWorldZRotation(),
    }
    return fixture
end

local function onClientCommand(module, command, player, args)
    if not HCRLabMP.enabled or not isServer() or module ~= MODULE then return end
    args = args or {}
    local key = player:getOnlineID()
    local ok, message = pcall(function()
        local state = HCRLabMP.sessions[key]
        if command == "begin" then
            if state then
                log("SERVER ignoring duplicate begin " .. state.fixture.session)
                return
            end
            local fixture = createFixture(player)
            HCRLabMP.sessions[key] = {fixture = fixture, phase = "await_old_ack"}
            sendServerCommand(player, MODULE, "fixture", fixture)
            log("SERVER fixture sent " .. fixture.session)
        elseif command == "old_seen" then
            if not state or args.session ~= state.fixture.session or state.phase ~= "await_old_ack" then return end
            local fixture = state.fixture
            local valid, detail = observe(fixture, false, player)
            assert(valid, "Server old fixture check failed: " .. detail)
            local square = squareFor(fixture)
            local contents = findWorld(square, fixture.bagId):getItem():getItemContainer()
            local now = getGameTime():getWorldAgeHours()
            contents:getItemWithIDRecursiv(fixture.tomatoId):getModData().HCRTimedStart = now - 170
            contents:getItemWithIDRecursiv(fixture.cheeseId):getModData().HCRTimedStart = now - 170
            findWorld(square, fixture.potId):getItem():getModData().HCRTimedStart = now - 170
            local carriedItems = player:getInventory():getItemWithIDRecursiv(fixture.playerBagId):getItemContainer()
            carriedItems:getItemWithIDRecursiv(fixture.carriedTomatoId):getModData().HCRTimedStart = now - 170
            carriedItems:getItemWithIDRecursiv(fixture.carriedCheeseId):getModData().HCRTimedStart = now - 170
            HCRTimed.updateSquare(square, now)
            HCRTimed.updateContainer(player:getInventory(), now, 0)
            valid, detail = observe(fixture, true, player)
            assert(valid, "Server mature fixture check failed: " .. detail)
            -- Repeat the real updater before reporting: terminal/unchanged stages
            -- must not create a second reward or replace the root world bag.
            HCRTimed.updateSquare(square, now)
            HCRTimed.updateContainer(player:getInventory(), now, 0)
            valid, detail = observe(fixture, true, player)
            assert(valid, "Server repeat update failed: " .. detail)
            state.phase = "await_client_report"
            sendServerCommand(player, MODULE, "mutated", {session = fixture.session})
            log("SERVER authoritative mutation/repeat verified " .. fixture.session)
        elseif command == "report" then
            if not state or args.session ~= state.fixture.session or state.phase ~= "await_client_report" then return end
            local valid, detail = observe(state.fixture, true, player)
            assert(valid, "Server final fixture changed: " .. detail)
            state.phase = args.passed == true and "complete" or "failed"
            log("SERVER real client report " .. tostring(args.passed) .. " " .. tostring(args.detail)
                .. " independently checked: " .. detail)
        end
    end)
    if not ok then
        log("SERVER FAIL " .. tostring(message))
        sendServerCommand(player, MODULE, "failed", {detail = tostring(message)})
    end
end

local function onServerCommand(module, command, args)
    if not HCRLabMP.enabled or not isClient() or module ~= MODULE then return end
    if command == "fixture" then
        HCRLabMP.client = {fixture = args, phase = "await_old", ticks = 0, stable = 0}
        log("CLIENT fixture received; waiting for native world replication " .. tostring(args.session))
    elseif command == "mutated" then
        local state = HCRLabMP.client
        if state and args.session == state.fixture.session then state.phase = "await_new"; state.ticks = 0 end
    elseif command == "failed" then
        log("CLIENT FAIL server: " .. tostring(args.detail))
        HCRLabMP.client = nil
    end
end

local function clientTick()
    if not HCRLabMP.enabled or not isClient() then return end
    local state = HCRLabMP.client
    if not state or state.phase == "complete" or state.phase == "failed" then return end
    state.ticks = state.ticks + 1
    local mature = state.phase == "await_new"
    local valid, detail = observe(state.fixture, mature)
    if valid and state.phase == "await_old" then
        log("CLIENT observed initial old IDs/types " .. state.fixture.session)
        state.phase = "await_mutation"
        state.ticks = 0
        sendClientCommand(MODULE, "old_seen", {session = state.fixture.session})
    elseif valid and mature then
        state.stable = state.stable + 1
        -- Observe several rendered ticks so a delayed extra packet cannot be
        -- mistaken for success on the first snapshot.
        if state.stable >= 120 then
            state.phase = "complete"
            log("CLIENT PASS " .. state.fixture.session .. " " .. detail)
            sendClientCommand(MODULE, "report", {session = state.fixture.session, passed = true, detail = detail})
        end
    elseif mature then
        state.stable = 0
    end
    if state.ticks > MAX_TICKS then
        state.phase = "failed"
        log("CLIENT FAIL timeout: " .. detail)
        sendClientCommand(MODULE, "report", {session = state.fixture.session, passed = false, detail = detail})
    end
end

function HCRLabMP.install(privateLabEnabled)
    assert(privateLabEnabled == true, "Explicit private lab opt-in required")
    assert(isServer() or isClient(), "This helper requires a real MP endpoint")
    HCRLabMP.enabled = true
    if HCRLabMP.installed then return end
    HCRLabMP.installed = true
    if isServer() then Events.OnClientCommand.Add(onClientCommand) end
    if isClient() then
        Events.OnServerCommand.Add(onServerCommand)
        Events.OnTick.Add(clientTick)
    end
    log(isServer() and "SERVER helper installed" or "CLIENT helper installed")
end

function HCRLabMP.begin(player)
    assert(HCRLabMP.enabled and isClient(), "Begin must run on the real enabled lab client")
    assert(player and player:isLocalPlayer(), "A local client player is required")
    if HCRLabMP.client or HCRLabMP.beginSent then return end
    HCRLabMP.beginSent = true
    sendClientCommand(player, MODULE, "begin", {})
    log("CLIENT begin sent")
end

return HCRLabMP
