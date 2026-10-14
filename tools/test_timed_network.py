"""Exercise real timed-item Lua with native B42 container addressability mocks.

These checks verify publication and client tree results, not a live MP session.
Run with lupa installed (the isolated modding lab provides it).
"""
from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
function require() end
function isClient() return false end
function isServer() return true end
function instanceof(value, name) return value and value.class == name end
Events = {LoadGridsquare = {}, EveryTenMinutes = {}, OnGameStart = {}}
for _, event in pairs(Events) do event.Add = function() end end
HCRTimedDefinitions = {Seed = {hours = 1, target = "Plant"},
    CycleA = {hours = 2, target = "CycleB"},
    CycleB = {hours = 3, target = "CycleA"}}
local nextId = 0
function newItem(kind, child)
    nextId = nextId + 1
    local item = {id = nextId, kind = kind, child = child, data = {}, favorite = false}
    function item:getFullType() return self.kind end
    function item:getCategory() return self.child and "Container" or "Normal" end
    function item:getModData() return self.data end
    function item:getItemContainer() return self.child end
    function item:getContainer() return self.container end
    function item:isFavorite() return self.favorite end
    function item:setFavorite(value) self.favorite = value end
    return item
end
function instanceItem(kind) return newItem(kind) end
function newContainer(rootKind, depth)
    local container = {entries = {}, rootKind = rootKind, depth = depth or 0}
    function container:getCharacter()
        return self.rootKind == "player" and {class = "IsoPlayer"} or nil
    end
    function container:getItems()
        local entries = self.entries
        return {size = function() return #entries end,
                get = function(_, index) return entries[index + 1] end}
    end
    function container:AddItem(item)
        item.container = self
        table.insert(self.entries, item)
    end
    function container:Remove(item)
        for i, candidate in ipairs(self.entries) do
            if candidate == item then table.remove(self.entries, i); return end
        end
        error("Removing absent item")
    end
    return container
end
function cloneItem(item)
    local copy = newItem(item.kind, item.child and cloneContainer(item.child) or nil)
    copy.id = item.id
    copy.favorite = item.favorite
    for key, value in pairs(item.data) do copy.data[key] = value end
    return copy
end
function cloneContainer(container)
    local copy = newContainer(container.rootKind, container.depth)
    for _, item in ipairs(container.entries) do copy:AddItem(cloneItem(item)) end
    return copy
end
function findContainerByBagId(container, id)
    if id == nil then return container end
    for _, item in ipairs(container.entries) do
        if item.child then
            if item.id == id then return item.child end
            local found = findContainerByBagId(item.child, id)
            if found then return found end
        end
    end
end
function setBagIds(container)
    for _, item in ipairs(container.entries) do
        if item.child then
            item.child.bagId = item.id
            setBagIds(item.child)
        end
    end
end
packets = {}
modPackets = {}
function syncItemModData(character, item)
    assert(character.class == "IsoPlayer" and item.container.rootKind == "player")
    local data = {}
    for key, value in pairs(item.data) do data[key] = value end
    table.insert(modPackets, {bagId = item.container.bagId, itemId = item.id, data = data})
end
function sendReplaceItemInContainer(container, oldItem, replacement)
    assert(container.rootKind == "player" or container.depth == 0,
           "Native ContainerID cannot address this nested world/furniture container")
    table.insert(packets, {bagId = container.bagId, oldId = oldItem.id,
                          replacement = cloneItem(replacement),
                          wholeBag = oldItem == replacement})
end
function applyPackets(client)
    for _, packet in ipairs(packets) do
        local target = findContainerByBagId(client, packet.bagId)
        assert(target, "Client cannot resolve packet container")
        local old
        for _, item in ipairs(target.entries) do
            if item.id == packet.oldId then old = item; break end
        end
        assert(old, "Replacement must remove an existing old ID, avoiding duplicate inserts")
        target:Remove(old)
        target:AddItem(cloneItem(packet.replacement))
    end
    for _, packet in ipairs(modPackets) do
        local target = findContainerByBagId(client, packet.bagId)
        assert(target, "Cannot address timestamp sync container")
        local found
        for _, item in ipairs(target.entries) do
            if item.id == packet.itemId then found = item; break end
        end
        assert(found, "Timestamp sync must update an existing item")
        found.data = packet.data
    end
end
function countKind(container, kind)
    local count = 0
    for _, item in ipairs(container.entries) do
        if item.kind == kind then count = count + 1 end
        if item.child then count = count + countKind(item.child, kind) end
    end
    return count
end
function scenario(rootKind, nested, expectedPackets)
    packets = {}
    modPackets = {}
    local server = newContainer(rootKind, 0)
    local leaf = server
    local outerBag
    if nested then
        local child = newContainer(rootKind, 1)
        outerBag = newItem("Bag", child)
        server:AddItem(outerBag)
        local grandchild = newContainer(rootKind, 2)
        child:AddItem(newItem("Bag", grandchild))
        leaf = grandchild
    end
    -- Two leaves catch accidentally sending one bag snapshot per matured item.
    for i = 1, 2 do
        local seed = newItem("Seed")
        seed.data.HCRTimedStart = 0
        seed.favorite = true
        leaf:AddItem(seed)
    end
    setBagIds(server)
    local client = cloneContainer(server)
    setBagIds(client)
    local wornBag = nested and client.entries[1] or nil
    local pending, changed = HCRTimed.updateContainer(server, 2, 0)
    assert(changed and pending)
    assert(#packets == expectedPackets, "Unexpected packet count")
    for _, packet in ipairs(packets) do
        assert(not (rootKind == "player" and packet.wholeBag),
               "Player bag replacement invalidates worn/hand references")
    end
    applyPackets(client)
    assert(countKind(server, "Seed") == 0 and countKind(client, "Seed") == 0)
    assert(countKind(server, "Plant") == 2 and countKind(client, "Plant") == 2)
    if rootKind == "player" and nested then
        assert(client.entries[1] == wornBag, "Worn bag object identity changed")
    end
    if nested and rootKind ~= "player" then
        assert(client.entries[1].id == outerBag.id, "Root bag ID changed")
    end
    local previousPackets = #packets
    HCRTimed.updateContainer(server, 3, 0)
    assert(#packets == previousPackets, "Mature terminal items published twice")
end
function timestampScenario(rootKind, scenarioName)
    packets, modPackets = {}, {}
    local kind = scenarioName == "first_init" and "Seed" or "CycleA"
    local initial = scenarioName == "cycle" and 0 or
                    scenarioName == "rollback" and 100 or nil
    local now = scenarioName == "cycle" and 10.25 or
                scenarioName == "rollback" and 50 or 10
    local expected = scenarioName == "cycle" and 10 or now
    local item = newItem(kind)
    item.data.HCRTimedStart = initial
    item.data.ownerNote = "preserve me"
    local client, server, originalClientItem, world, worldPackets
    if rootKind == "world_item" then
        originalClientItem = cloneItem(item)
        worldPackets = {}
        world = {item = item}
        function world:getItem() return self.item end
        function world:swapItem(replacement)
            assert(replacement == self.item, "Same-type timestamp sync must preserve server item identity")
            table.insert(worldPackets, cloneItem(replacement))
        end
        local function list(entries)
            return {size = function() return #entries end,
                    get = function(_, index) return entries[index + 1] end}
        end
        server = {getObjects = function() return list({}) end,
                  getWorldObjects = function() return list({world}) end}
        assert(HCRTimed.updateSquare(server, now))
        assert(#worldPackets == 1, "Ground timestamp must publish once")
        client = worldPackets[1]
        assert(client.id == originalClientItem.id)
    else
        server = newContainer(rootKind)
        local child = newContainer(rootKind, 1)
        local grandchild = newContainer(rootKind, 2)
        server:AddItem(newItem("Bag", child))
        child:AddItem(newItem("Bag", grandchild))
        grandchild:AddItem(item)
        setBagIds(server)
        client = cloneContainer(server)
        setBagIds(client)
        originalClientItem = client.entries[1].child.entries[1].child.entries[1]
        local pending, changed = HCRTimed.updateContainer(server, now, 0)
        assert(pending and changed)
        assert(#packets + #modPackets == 1, "Timestamp must publish once")
        assert(rootKind ~= "player" or (#packets == 0 and #modPackets == 1),
               "Player timestamps need mod-data packets, not item replacement")
        applyPackets(client)
        client = client.entries[1].child.entries[1].child.entries[1]
        if rootKind == "player" then assert(client == originalClientItem) end
    end
    assert(item.kind == kind and client.kind == kind, "Timestamp normalization changed item type")
    assert(item.data.HCRTimedStart == expected and client.data.HCRTimedStart == expected)
    assert(client.data.ownerNote == "preserve me", "Timestamp sync lost unrelated mod data")
    assert(item.id == originalClientItem.id, "Timestamp normalization replaced server item")
    local before = #packets + #modPackets + (worldPackets and #worldPackets or 0)
    if rootKind == "world_item" then
        HCRTimed.updateSquare(server, now + 0.1)
    else
        HCRTimed.updateContainer(server, now + 0.1, 0)
    end
    assert(#packets + #modPackets + (worldPackets and #worldPackets or 0) == before,
           "Unchanged normalized timestamp was published again")
end
''')
lua.execute((ROOT / "common/media/lua/shared/HCR_TimedItems.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "common/media/lua/shared/HCR_ItemMigrations.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "common/media/lua/server/HCR_TimedSystems.lua").read_text(encoding="utf-8-sig"))

for kind, nested, expected in [
    ("player", False, 2),
    ("player", True, 2),
    ("furniture", True, 1),
    ("ground_bag", True, 1),
]:
    lua.globals().scenario(kind, nested, expected)
    print(f"PASS {kind}, nested={nested}: {expected} addressable packets, exactly once")

for kind in ["player", "furniture", "ground_bag", "world_item"]:
    for scenario in ["first_init", "cycle", "rollback"]:
        lua.globals().timestampScenario(kind, scenario)
        print(f"PASS {kind}, {scenario}: timestamp replicated once, identity and mod data preserved")
