-- Private offline HCRLab only; never shipped with the mod.
HCRLabSave = HCRLabSave or {}
local marker = "HCRLabLegacySave42"
function HCRLabSave.prepare(player, profile)
    assert(profile == "HCRLab" and not isClient() and not isServer())
    local item = player:getInventory():AddItem("Hydrocraft.HCArmorchainmail")
    assert(item and item:getCategory() ~= "Clothing", "legacy ID must remain normal")
    item:setCondition(math.floor(item:getConditionMax() * 0.6))
    item:setHaveBeenRepaired(2)
    item:setFavorite(true)
    item:setName("Lab inherited chainmail")
    item:setCustomName(true)
    item:getModData()[marker] = true
    item:getModData().expectedConditionRatio = item:getCondition() / item:getConditionMax()
    print("[HCRLabSave] PREPARED legacy normal item; quit and reload this private world")
end
function HCRLabSave.verify(player, profile)
    assert(profile == "HCRLab" and not isClient() and not isServer())
    HCRTimed.updateContainer(player:getInventory(), getGameTime():getWorldAgeHours(), 0)
    local found, old = 0, 0
    local items = player:getInventory():getItems()
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if item:getModData()[marker] then
            found = found + 1
            if item:getFullType() == "Hydrocraft.HCArmorchainmail" then old = old + 1 end
            assert(item:getFullType() == "Hydrocraft.HCArmorchainmailWearable")
            assert(item:getCategory() == "Clothing" and item:isFavorite())
            assert(item:isCustomName() and item:getName() == "Lab inherited chainmail")
            assert(item:getHaveBeenRepaired() == 2)
            assert(math.abs(item:getCondition()/item:getConditionMax()
                - item:getModData().expectedConditionRatio) < 0.001)
        end
    end
    assert(found == 1 and old == 0, "saved stock missing or duplicated: " .. found)
    print("[HCRLabSave] PASS native save/reload: one wearable, state retained, legacy ID absent")
end
