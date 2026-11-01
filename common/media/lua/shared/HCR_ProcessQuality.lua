-- Качество пищевых полуфабрикатов, чей сохранённый Java-класс остаётся Normal.
require "HCR_FoodQuality"
require "HCR_FluidQuality"
require "HCR_MashCatalog"
HCRProcessQuality={key="HCRProcessQuality160"}
local P,F,L,Q=HCRProcessQuality,HCRFoodQuality,HCRFluidLedger,HCRFluidQuality
local kinds={"HCVatcheese","HCCheesecurd","HCCheesetrayfull","HCCheeserackfull",
    "HCCheeserackaged","HCCurdkneaded","HCCurdcubed","HCCheddarcheesetrayfull",
    "HCCheeserackfullcheddar","HCCheeserackagedcheddar","HCCheeserackfullcheddarwaxed",
    "HCCheeserackagedcheddarwaxed","HCRennet","HCWoodenbucketgrape","HCWoodenbucketgrapegreen",
    "HCBarrelgrape","HCBarrelgrapegreen","HCBarrelwine","HCBarrelwinewhite",
    "HCBarrelhoney","HCBarrelmead","HCBarrelrice","HCBarrelsake","HCBarrelvinegar",
    "HCBarrelpotato","HCBarrelblueagave","HCBarrelapple","HCBarrelpeach",
    "HCBarrelpumpkin","HCBarreljuniper","HCBarrelflour","HCBarrelcorn"}
P.types={}
for _,kind in ipairs(kinds) do P.types["Hydrocraft."..kind]=true end
-- Vanilla оставляет уксус Drainable: сохраняем его craft/evolved интерфейс.
P.types["Base.Vinegar2"]=true
local curds={['Hydrocraft.HCCheesecurd']=true,['Hydrocraft.HCCurdkneaded']=true,['Hydrocraft.HCCurdcubed']=true}

function P.carrier(item) return P.types[item:getFullType()] or false end
local function clock(age,off,max)
    return L.batch("HCRMilk",1,{age=age,offAge=off,offAgeMax=max,canBeFrozen=false},getGameTime():getWorldAgeHours())
end

function P.read(item)
    local saved=item:getModData()[P.key]
    if not saved then return {dose=0,quality="fresh",detection=-1} end
    assert(saved.version==1 and type(saved.dose)=="number" and saved.dose>=0
        and saved.dose<=F.maxDose,"Invalid process poison metadata")
    assert(saved.quality=="fresh" or saved.quality=="stale" or saved.quality=="rotten","Invalid process freshness")
    assert(saved.tainted==nil or type(saved.tainted)=='boolean','Invalid process water safety')
    local result=L.copy(saved)
    if result.clock then
        result.clock=Q.age(item,result.clock,getGameTime():getWorldAgeHours())
        result.quality=F.worst(result.quality,L.quality(result.clock))
    end
    return result
end

function P.capture(data,state)
    state.processInputs={}
    state.clocks={}
    for item,fraction in pairs(HCRFood.getConsumedFractions(data)) do
        if P.carrier(item) then
            local saved=P.read(item)
            state.tracked=true
            state.dose=state.dose+saved.dose*fraction
            state.quality=F.worst(state.quality,saved.quality)
            state.detection=math.max(state.detection,saved.detection or -1)
            state.poisoner=state.poisoner or saved.poisoner
            state.tainted=state.tainted or (fraction>0 and saved.tainted) or false
            if saved.clock then state.clocks[#state.clocks+1]=saved.clock end
            state.processInputs[#state.processInputs+1]={item=item,fraction=fraction,saved=saved}
        elseif item:IsFood() and data:getRecipe():getName()=="Put Cheese on Rack (Cheese Rack with Waxed Cheddar Cheese)" then
            -- Почти испорченная головка продолжает стареть во время выдержки.
            item:updateAge(false)
            state.quality=F.worst(state.quality,F.quality(item))
            state.clocks[#state.clocks+1]=clock(item:getAge(),item:getOffAge(),item:getOffAgeMax())
            state.tracked=true
        end
    end
    -- Новые полуфабрикаты учитывают обычный Food даже без предыдущего sidecar.
    -- Вызов до createOutputs может не иметь экземпляров. Для cheese recipes
    -- достаточно явно известного имени входа в эту цепочку.
    local name=data:getRecipe():getName()
    if name=="Fill Cheese Vat" or HCRMashCatalog.prepare[name] then state.tracked=true end
end

function P.write(item,state,count,character)
    local clocks=L.empty()
    for _,part in ipairs(state.clocks or {}) do clocks=L.mix(clocks,part) end
    if #clocks.lots==0 and curds[item:getFullType()] then clocks=clock(0,10,10) end
    -- Несколько входов могут иметь разные сроки; достаточно самого близкого
    -- к порче clock, без размножения одинаковых часов при каждом объединении.
    if #clocks.lots>1 then
        local worst=clocks.lots[1]
        for _,lot in ipairs(clocks.lots) do
            if lot.age/math.max(.0001,lot.food.offAgeMax or 1e9) > worst.age/math.max(.0001,worst.food.offAgeMax or 1e9) then worst=lot end
        end
        clocks={version=L.VERSION,lots={L.copy(worst)},storage=clocks.storage}
        clocks.lots[1].litres=1;clocks.lots[1].basisLitres=1;clocks.lots[1].units=1
    end
    if #clocks.lots>0 then clocks=Q.age(item,clocks,getGameTime():getWorldAgeHours()) end
    item:getModData()[P.key]={version=1,dose=state.dose/count,quality=state.quality,
        detection=state.detection,poisoner=state.poisoner,tainted=state.tainted or false,
        clock=#clocks.lots>0 and clocks or nil}
    if Q.watch then Q.watch(item,true) end
    F.sync(item,character)
end

function P.checkpoint(item,quiet)
    item:getModData()[P.key]=P.read(item)
    if Q.watch then Q.watch(item,true) end
    if not quiet then Q.syncStorage(item) end
end

function P.remaining(state)
    for _,entry in ipairs(state.processInputs or {}) do
        P.keep(entry.item,entry.saved,1-entry.fraction)
    end
end

function P.keep(item,saved,fraction,character)
    local remaining=fraction>0 and L.copy(saved) or nil
    if remaining then remaining.dose=remaining.dose*fraction end
    item:getModData()[P.key]=remaining
    if remaining and Q.watch then Q.watch(item,true) end
    F.sync(item,character)
end
