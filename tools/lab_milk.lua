-- Прежний ранний oracle заменён проверкой окончательной политики Milk/Soy.
-- Stage вместе с lab_unified_milk.lua только в private HCRLab profile.
require "HCRLabUnifiedMilk"
HCRLabMilk={}
function HCRLabMilk.run(player,profile)
    assert(profile=="HCRLab" and not isClient() and not isServer())
    HCRLabUnifiedMilk.run(player)
    return 0
end
