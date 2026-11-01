-- Пищевая порция для native evolved recipes, которые не умеют расходовать FC.
require "HCR_FoodQuality"
HCRMilkBowl={}
local B,L,E,F=HCRMilkBowl,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
local extensive={"calories","carbohydrates","proteins","lipids","hungChange",
    "baseHunger","thirstChange","boredomChange","unhappyChange","stressChange",
    "enduranceChange","fatigueChange","foodSicknessChange","painReduction",
    "fluReduction","reduceInfectionPower","alcoholPower"}

function B.supported(ledger)
    for _,lot in ipairs(ledger.lots) do
        -- Эти runtime-поля не сериализуются Food либо округляются до int.
        -- Обычное молоко имеет нули. Изменённую другим модом партию оставить
        -- жидкостью, а не терять её свойства при создании пищевой миски.
        for _,key in ipairs({"reduceInfectionPower","alcoholPower","nativeAlcohol","fluReduction","foodSicknessChange"}) do
            if (lot.food[key] or 0)~=0 then return false end
        end
        -- Native не сохраняет tainted/canBeFrozen. Порция использует постоянный
        -- CantBeFrozen; иначе после загрузки могла бы навсегда остаться льдом.
        if lot.food.tainted or lot.food.alcoholic or lot.food.frozen
            or (lot.food.freezingTime or 0)>0 then return false end
    end
    return true
end

function B.properties(ledger,shelfLife)
    L.validate(ledger)
    assert(B.supported(ledger),"Milk bowl cannot preserve these modified effects")
    local values={canBeFrozen=false,cooked=true,burnt=false,tainted=false,
        dangerousUncooked=false,alcoholic=false,poisonDetectionLevel=-1,
        useForPoison=0,poisonLevelForRecipe=0,heat=0,freezingTime=0}
    for _,key in ipairs(extensive) do values[key]=L.budget(ledger,key) end
    local fresh,rotten,weight=(shelfLife and shelfLife[1] or 4),(shelfLife and shelfLife[2] or 7),0
    for _,lot in ipairs(ledger.lots) do
        local food=lot.food
        fresh=math.min(fresh,(food.offAge or 1000000000)-lot.age)
        rotten=math.min(rotten,(food.offAgeMax or 1000000000)-lot.age)
        values.cooked=values.cooked and food.cooked==true
        for _,key in ipairs({"burnt","tainted","dangerousUncooked","alcoholic"}) do
            values[key]=values[key] or food[key]==true
        end
        for _,key in ipairs({"poisonDetectionLevel","useForPoison","poisonLevelForRecipe"}) do
            values[key]=math.max(values[key],food[key] or values[key])
        end
        weight=weight+lot.litres
        values.heat=values.heat+(food.heat or 1)*lot.litres
        values.freezingTime=values.freezingTime+(food.freezingTime or 0)*lot.litres
    end
    values.heat=weight>0 and values.heat/weight or 1
    values.freezingTime=weight>0 and values.freezingTime/weight or 0
    values.frozen=values.canBeFrozen and values.freezingTime>=100
    if rotten<=0 then
        values.offAge,values.offAgeMax,values.age=0,1,1.001
    elseif fresh<=0 then
        values.offAge,values.offAgeMax=0,math.ceil(rotten)+1
        values.age=values.offAgeMax-rotten
    else
        -- Native сроки целочисленные. Точно сохраняем ближайший переход
        -- fresh→stale; конец годности округляем только в безопасную сторону.
        -- Одинаковые сроки партий сохраняются без округления.
        values.offAge=math.ceil(fresh)
        values.age=values.offAge-fresh
        values.offAgeMax=math.floor(values.age+rotten+.000001)
    end
    values.poisonPower=L.budget(ledger,"poisonPower")
    return values
end

function B.create(rule,data,ledger)
    local values=B.properties(ledger)
    local output=data:getAllCreatedItems()
    assert(output:size()==1 and output:get(0):getFullType()==rule.foodTarget,"Missing milk bowl")
    if HCRFoodTransfers.deferCreate(data,function() B.create(rule,data,ledger) end) then return end
    local food=output:get(0)
    for key,value in pairs(values) do
        if key~="poisonPower" then food[E.fields[key][2]](food,value) end
    end
    F.store(food,values.poisonPower)
    -- Общая FoodTransfers завершит перенос худшего качества и синхронизацию.
end
