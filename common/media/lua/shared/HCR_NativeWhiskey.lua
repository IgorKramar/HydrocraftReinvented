-- У native Whiskey свои питание и алкоголь. Нулевая по объёму партия
-- переносит только качество, как растворённая добавка, не заменяя жидкость.
require "HCR_FluidQuality"
require "HCR_FoodQuality"
HCRNativeWhiskey={}
local N,Q,L,E,F=HCRNativeWhiskey,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality

function N.ledger(fluid,state,count)
    local sample=assert(instanceItem("Hydrocraft.HCRFluidSample"))
    F.setQuality(sample,state.quality)
    local food=E.snapshot(sample)
    food.canBeFrozen=false;food.alcoholic=false;food.alcoholPower=0
    food.tainted=state.tainted or food.tainted or false
    food.poisonPower=state.dose/count;food.poisonDetectionLevel=state.detection or -1
    food.spoilHunger=fluid:getProperties():getHungerChange()
    local result=L.batch("Whiskey",1,food,getGameTime():getWorldAgeHours())
    result.lots[1].litres=0
    return result
end

function N.medical(item)
    local fluid=Q.fluid(item)
    if not Q.active(item,fluid) then return true end
    if not item or not fluid then return false end
    for _,lot in ipairs(Q.capture(item,fluid).ledger.lots) do
        if lot.fluid~="Whiskey" or lot.litres~=0 or lot.food.spoilHunger==nil then return false end
    end
    return true
end

-- Только проверенные расходующие слоты. Прочие жидкости, которыми можно
-- пользоваться в vanilla medical/trap рецептах, остаются разрешены как раньше.
function N.install(rules)
    local entries={
        {"DisinfectRag",1,{"RubbingAlcohol","Vodka","Whiskey"}},
        {"DouseCottonInAlcohol",1,{"RubbingAlcohol","Vodka","Whiskey"}},
        {"MakeMolotovCocktail",0,{"RubbingAlcohol","Petrol","Tequila","Vodka","Whiskey"}},
        {"Disinfect Diaper",1,{"Whiskey"}},
        {"Disinfect Menstrual Pad",1,{"Whiskey"}},
        {"Make Eggnog Pot",2,{"Whiskey"}},
    }
    for _,entry in ipairs(entries) do
        local previous=rules[entry[1]]
        local rule={inputs={}}
        if previous then
            if previous.inputs then rule=L.copy(previous)
            else
                for slot in pairs(previous.slots) do rule.inputs[slot]=L.copy(previous) end
            end
        end
        assert(not rule.inputs[entry[2]],"Native whiskey slot collides with an existing rule")
        rule.inputs[entry[2]]={fluids=entry[3],nativeSink=entry[1]=="DisinfectRag"
            or entry[1]=="DouseCottonInAlcohol" or entry[1]=="MakeMolotovCocktail"}
        rules[entry[1]]=rule
    end
end
