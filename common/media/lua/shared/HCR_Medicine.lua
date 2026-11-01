-- Старый ReduceFoodSickness не сохранялся движком. Чиним только известную
-- нулевую дозу этого ID, не трогая питание, яд, свежесть и класс предмета.
HCRMedicine={key="HCRLemongrassDose160"}
function HCRMedicine.prepare(item)
    if isClient() or not item or item:getFullType()~="Hydrocraft.HCLemongrassExtract"
        or not item:IsFood() or item:getModData()[HCRMedicine.key] then return false end
    if item:getFoodSicknessChange()==0 then
        -- Getter меняет raw-значение по состоянию Food; ноль у изменённого
        -- препарата не доказывает отсутствие исходной лечебной дозы.
        if item:isCooked() or item:isBurnt() or item:getAge()>=item:getOffAge() then return false end
        local base,hunger=item:getBaseHunger(),item:getHungChange()
        if base~=base or math.abs(base-.001)>.0000001 then return false end
        local fraction=hunger/base
        if fraction~=fraction or fraction<=0 or fraction>1.00001 then return false end
        item:setFoodSicknessChange(-math.floor(50*math.min(1,fraction)+.00001))
    end
    -- Даже новый ненулевой препарат отмечается до первого приёма: native
    -- округляет малый остаток лекарства до нуля, восстанавливать его нельзя.
    item:getModData()[HCRMedicine.key]=true
    return true
end

function HCRMedicine.eat(item,character,operation)
    if isClient() or not item or item:getFullType()~="Hydrocraft.HCLemongrassExtract" then return operation() end
    HCRMedicine.prepare(item)
    local stats=character:getStats()
    local sickness,poison=stats:get(CharacterStat.FOOD_SICKNESS),stats:get(CharacterStat.POISON)
    local ok,result=pcall(operation)
    HCRFoodQuality.sync(item,character)
    if isServer() and (sickness~=stats:get(CharacterStat.FOOD_SICKNESS) or poison~=stats:get(CharacterStat.POISON)) then
        -- Native Eat не включает эти две статистики в свой немедленный пакет.
        syncPlayerStats(character,SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.FOOD_SICKNESS)
            +SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.POISON))
    end
    if not ok then error(result) end
    return result
end
