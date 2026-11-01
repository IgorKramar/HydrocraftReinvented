-- getName() у FluidContainer показывает жидкость, а не надпись игрока.
-- Native SyncItemFields может записать это UI-имя в private name, но передаёт
-- исходный modData.customName целиком. Штатное переименование обновляет оба.
HCRItemNames={}
function HCRItemNames.custom(item)
    if not item or not item:isCustomName() then return nil end
    local data=item:getModData()
    local name=data.customName
    if type(name)~='string' or name=='' then name=item:getDisplayName() end
    if type(name)~='string' or name=='' then name=data.HCRLegacyCustomName end
    if type(name)=='string' and name~='' then return name end
end
