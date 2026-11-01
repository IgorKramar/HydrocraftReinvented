-- Вход native молока в явную переработку. Снимок свойств всего сосуда,
-- а не значений на литр: FluidContainer переиспользует свой mutable cache.
require "HCR_FluidEffects"
HCRNativeMilk={}
local N=HCRNativeMilk
local getters={calories="getCalories",carbohydrates="getCarbohydrates",
    proteins="getProteins",lipids="getLipids",hungChange="getHungerChange",
    thirstChange="getThirstChange",stressChange="getStressChange",
    fatigueChange="getFatigueChange",enduranceChange="getEnduranceChange",
    unhappyChange="getUnhappyChange"}

function N.snapshot(fluid)
    local props=fluid:getProperties()
    local food=HCRFluidEffects.snapshot(instanceItem("Hydrocraft.HCRFluidSample"))
    for key,getter in pairs(getters) do food[key]=props[getter](props) end
    -- Native DrinkFluid использует UnhappyChange также для скуки.
    food.boredomChange=food.unhappyChange
    food.baseHunger=food.hungChange
    -- В vanilla молоке нет возраста. Первая переработка начинает явный срок
    -- HC молока 4/7 дней; никакое существующее качество HCR не перезаписывается.
    food.age,food.offAge,food.offAgeMax=0,4,7
    food.canBeFrozen=false
    assert(props:getAlcohol()==0 and props:getPoison()==0
        and props:getPainReduction()==0 and props:getFluReduction()==0
        and props:getFoodSicknessChange()==0,"Unsupported native milk effects")
    return food
end
