-- Только private HCRLab: настоящее Food/FC и старые сериализуемые ID.
require "HCR_RetailDrinkFamilies"
HCRLabRetailDrinks={}
local function near(a,b,label) assert(math.abs(a-b)<.0001,label..": "..tostring(a).." != "..tostring(b)) end
function HCRLabRetailDrinks.run(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local Q,L,E,F=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
    local checked=0
    for kind,spec in pairs(HCRRetailDrinkFamilies) do
        for _,fraction in ipairs(spec.empty and {0} or {.25,.5,1}) do
            local old=assert(instanceItem(kind))
            old:setFavorite(true);old:getModData().retailProof="same"
            if not spec.empty then
                old:setHungChange(old:getBaseHunger()*fraction)
                old:setCalories(123.5);old:setAge(20);F.store(old,.375)
            end
            local new=assert(HCRItemMigrations.newReplacement(old),kind)
            assert(new:getFullType()==spec.target and new:isFavorite() and new:getModData().retailProof=="same")
            local fluid=Q.fluid(new)
            near(Q.rawAmount(fluid),spec.litres*fraction,"retail remaining volume")
            if not spec.empty then
                local ledger=Q.capture(new,fluid).ledger
                near(L.budget(ledger,"calories"),123.5,"retail current nutrition")
                near(L.budget(ledger,"poisonPower"),.375,"retail exact poison")
                near(ledger.lots[1].age,20,"retail age")
                assert(ledger.lots[1].food.offAge==old:getOffAge() and ledger.lots[1].food.offAgeMax==old:getOffAgeMax())
                assert(L.quality(ledger)=="fresh","Retail shelf life changed")
                assert(not new:getModData()[F.key],"Food sidecar leaked into fluid vessel")
            else
                assert(not Q.active(new,fluid),"Empty carton gained food quality")
            end
            assert(not HCRItemMigrations.newReplacement(new),"Retail migration repeated")
            checked=checked+1
        end
    end
    assert(checked==30)
    print("[HCRRetail160] 8 retail Food x 3 portions + 6 empty cartons: native volume, nutrition, exact poison, shelf life and same state PASS")
end
