-- Только для отдельного HCRLab профиля: в релизную папку не копируется.
require "HCRLabCraft"
local function smoke()
    local all = getScriptManager():getAllItems()
    local total, failed = 0, 0
    for i = 0, all:size() - 1 do
        local scriptItem = all:get(i)
        local name = scriptItem:getFullName()
        if string.sub(name, 1, 11) == "Hydrocraft." then
            total = total + 1
            local ok, item = pcall(instanceItem, name)
            if not ok or not item or not scriptItem:getItemType() then
                failed = failed + 1
                print("[HCRLab] FAIL " .. name .. " " .. tostring(item))
            end
        end
    end
    print("[HCRLab] item smoke: total=" .. total .. " failed=" .. failed)
end
Events.OnGameBoot.Add(smoke)

local function gameplaySmoke()
    local player = getSpecificPlayer(0)
    if not player then return end
    local inv = player:getInventory()
    local now = getGameTime():getWorldAgeHours()
    local scenarios = {
        {"Hydrocraft.HCPottedtomatosmall", 170, "Hydrocraft.HCPottedtomatoready"},
        {"Hydrocraft.HCCheeserackfull", 168, "Hydrocraft.HCCheeserackaged"},
        {"Hydrocraft.HCBeehive3bActive", 168, "Hydrocraft.HCBeehive3bfull"},
    }
    for _, scenario in ipairs(scenarios) do
        local item = inv:AddItem(scenario[1])
        item:getModData().HCRTimedStart = now - scenario[2]
        HCRTimed.updateContainer(inv, now, 0)
        local found = inv:FindAndReturn(scenario[3])
        print("[HCRLab] timed " .. scenario[1] .. " " .. (found and "PASS" or "FAIL"))
    end
    local stats = player:getStats()
    local bag = inv:AddItem("Base.Bag_Schoolbag")
    local plant = bag:getItemContainer():AddItem("Hydrocraft.HCPottedtomatosmall")
    plant:getModData().HCRTimedStart = now - 170
    HCRTimed.updateContainer(inv, now, 0)
    print("[HCRLab] nested growth "
        .. (bag:getItemContainer():FindAndReturn("Hydrocraft.HCPottedtomatoready") and "PASS" or "FAIL"))
    inv:Remove(bag)
    local square = player:getCurrentSquare()
    local placed = instanceItem("Hydrocraft.HCPottedtomatosmall")
    placed:getModData().HCRTimedStart = now - 170
    square:AddWorldInventoryItem(placed, 0.23, 0.67, 0.12)
    local object = placed:getWorldItem()
    HCRTimed.updateSquare(square, now)
    local preserved = object:getItem():getFullType() == "Hydrocraft.HCPottedtomatoready"
        and math.abs(object:getOffX() - 0.23) < 0.001
        and math.abs(object:getOffY() - 0.67) < 0.001
        and math.abs(object:getOffZ() - 0.12) < 0.001
    print("[HCRLab] placed growth preserves offsets " .. (preserved and "PASS" or "FAIL"))
    stats:set(CharacterStat.BOREDOM, 50)
    stats:set(CharacterStat.UNHAPPINESS, 50)
    HCDoStats(player, 10, 6, 0)
    print("[HCRLab] stats b=" .. stats:get(CharacterStat.BOREDOM)
        .. " u=" .. stats:get(CharacterStat.UNHAPPINESS))
    for _, name in ipairs({"Hydrocraft.HCHomemadebatwrench", "Hydrocraft.HCQuarterstaff", "Hydrocraft.HCLegarmorbronze", "Hydrocraft.HCArmorchainmailWearable"}) do
        local item = inv:AddItem(name)
        print("[HCRLab] equipment " .. name .. " " .. (item and "PASS" or "FAIL"))
        if item and item:getCategory() == "Clothing" then
            local asset = item:getClothingItem()
            print("[HCRLab] clothing asset " .. name .. " "
                .. (asset and asset:isReady() and item:getVisual() and "PASS" or "FAIL"))
            if asset and asset:isReady() and item:getVisual() then
                player:setWornItem(item:getBodyLocation(), item)
                print("[HCRLab] wear " .. name .. " PASS")
            end
        end
    end
    local bat = inv:FindAndReturn("Hydrocraft.HCHomemadebatwrench")
    player:setPrimaryHandItem(bat)
    player:setSecondaryHandItem(bat)
    print("[HCRLab] equip bat PASS")
    HCRLabCraft.schedule(player, "HCRLab")
end
Events.OnGameStart.Add(gameplaySmoke)
