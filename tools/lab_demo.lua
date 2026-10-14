-- Disposable offline profile only. This deliberately clears test fixture stock.
HCRLabDemo = HCRLabDemo or {}
function HCRLabDemo.showCleanPlants(player, profile)
    assert(profile == "HCRLab" and player and not isClient() and not isServer())
    local square=player:getCurrentSquare()
    for i,name in ipairs({"Hydrocraft.HCPottedtomatoready","Hydrocraft.HCPottedCabbageredready","Hydrocraft.HCPottedCabbagewhiteready"}) do
        local target=getCell():getGridSquare(square:getX()+i*2,square:getY(),square:getZ())
        assert(target)
        target:AddWorldInventoryItem(instanceItem(name),0.5,0.5,0)
    end
    print("[HCRLabDemo] three regenerated RGBA plants placed at ground offset 0")
end
function HCRLabDemo.showPlanterScale(player, profile)
    assert(profile == "HCRLab" and player and not isClient() and not isServer())
    local square=player:getCurrentSquare()
    for i,name in ipairs({"Hydrocraft.HCPottedpotatoready","Hydrocraft.HCPottedCabbageredready"}) do
        local target=getCell():getGridSquare(square:getX()+1+i,square:getY(),square:getZ())
        assert(target)
        target:AddWorldInventoryItem(instanceItem(name),0.5,0.5,0)
    end
    print("[HCRLabDemo] corrected potato/cabbage placed at ground offset 0; original atlas comparison is pixel-based")
end
function HCRLabDemo.prepare(player, profile)
    assert(profile == "HCRLab" and not isClient() and not isServer())
    player:setPrimaryHandItem(nil)
    player:setSecondaryHandItem(nil)
    local inv = player:getInventory()
    for i = inv:getItems():size()-1, 0, -1 do
        local item = inv:getItems():get(i)
        if string.sub(item:getFullType(), 1, 11) == "Hydrocraft."
            and item:getCategory() ~= "Clothing" then inv:Remove(item) end
    end
    local bat = inv:AddItem("Hydrocraft.HCHomemadebatwrench")
    player:setPrimaryHandItem(bat)
    player:setSecondaryHandItem(bat)
    local square = player:getCurrentSquare()
    local objects = square:getWorldObjects()
    for i = objects:size()-1, 0, -1 do
        local object = objects:get(i)
        if object:getItem() and string.sub(object:getItem():getFullType(), 1, 11) == "Hydrocraft." then
            object:removeFromWorld()
            object:removeFromSquare()
        end
    end
    for _, entry in ipairs({
        {"Hydrocraft.spanishRider", 0.5, 0.5, 1, 0},
        {"Hydrocraft.HCPottedtomatoready", 0.5, 0.5, -1, 1},
        {"Hydrocraft.HCPottedorangetreeready", 0.5, 0.5, -2, 0},
    }) do
        local target = getCell():getGridSquare(square:getX()+entry[4], square:getY()+entry[5], square:getZ())
        assert(target, "demo ground tile is not loaded")
        target:AddWorldInventoryItem(instanceItem(entry[1]), entry[2], entry[3], 0)
    end
    if not HCRLabDemo.observer then
        HCRLabDemo.observer = function(character, weapon)
            if character == player and weapon and weapon:getFullType() == "Hydrocraft.HCHomemadebatwrench" then
                print("[HCRLabDemo] PASS native bat swing reached hit point: " .. weapon:getFullType())
            end
        end
        Events.OnWeaponSwingHitPoint.Add(HCRLabDemo.observer)
    end
    print("[HCRLabDemo] prepared low-load character, bat, unarmed ground spike model and plants")
end

-- Actual native placement/sensor check, confined to the disposable offline lab.
function HCRLabDemo.testArmedTrap(player, profile)
    assert(profile == "HCRLab" and player and not isClient() and not isServer())
    require "TimedActions/ISPlaceTrap"
    local previousGod = player:isGodMod()
    player:setGodMod(true)
    local weapon = player:getInventory():AddItem("Hydrocraft.spanishRider")
    assert(weapon, "armed trap fixture missing")
    local id, explosions, captured = weapon:getID(), 0, nil
    local observer
    observer = function(trap, square)
        local item = trap:getHandWeapon()
        if item and item:getID() == id then
            explosions = explosions + 1
            captured = trap
        end
    end
    Events.OnThrowableExplode.Add(observer)
    local action = ISPlaceTrap:new(player, weapon)
    assert(action:isValid(), "native placement rejected fixture")
    assert(action:complete(), "native placement failed")
    assert(not player:getInventory():contains(weapon), "placement retained its input")
    local frames = 0
    local finish
    finish = function()
        frames = frames + 1
        if frames < 180 then return end
        Events.OnTick.Remove(finish)
        Events.OnThrowableExplode.Remove(observer)
        player:setGodMod(previousGod)
        local ok = explosions == 1 and captured and captured:getObjectIndex() == -1
        print("[HCRLabDemo] native placement/sensor/removal " .. (ok and "PASS" or "FAIL")
            .. " explosions=" .. explosions .. " inputConsumed=" .. tostring(weapon:getContainer() == nil))
    end
    Events.OnTick.Add(finish)
end
