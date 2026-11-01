-- Нативное виноделие: сосуды-доноры остаются, партия меняет только стадию.
require 'HCR_DrinkRecipes'
require 'HCR_Fermentation'
HCRFermentationRecipes={rules={},products={}}
local R,B,Q,L,E=HCRFermentationRecipes,HCRFermentation,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects
local juices={
    Red={name='Juice Grapes Into Wooden Bucket',marker='HCRJuiceGrape'},
    White={name='Juice Grapes Into Wooden Bucket (Wooden Bucket with White Grape Juice)',marker='HCRJuiceGrapeWhite'},
}
for token,entry in pairs(juices) do
    local rule={target='Hydrocraft.HCWoodenbucketFluid',vesselSlot=0,count=1,litres=4,
        fluid=entry.marker,sourceFood='Hydrocraft.HCRFluidSample',freshDays=3,rottenDays=7}
    R['Test'..token]=function(item) return HCRDrinkRecipes.test(rule,item) end
    R['Juice'..token]=function(data,character) return HCRDrinkRecipes.create(rule,data,character) end
end
R.products={
    ['Prepare Wine Barrels']={slot=1,marker='HCRJuiceGrape',stage='Hydrocraft.HCBarrelgrape'},
    ['Prepare Wine Barrels (Barrel of White Grape Juice)']={slot=1,marker='HCRJuiceGrapeWhite',stage='Hydrocraft.HCBarrelgrapegreen'},
    ['Fill Bottles with Wine']={slot=0,marker='HCRWineRed',target='Base.Wine2'},
    ['Fill Bottles with Wine (Variant)']={slot=0,marker='HCRWineWhite',target='Base.Wine'},
    ['Make Bottle of Mead']={slot=0,marker='HCRMead',target='Base.Whiskey'},
    ['Make Bottle of Sake']={slot=0,marker='HCRSake',target='Base.Whiskey'},
    ['Fill Vinegar Bottles with Vinegar']={slot=0,marker='HCRVinegar',target='Base.Vinegar2',vinegar=true},
    ['Fill Whiskey Bottles with Vinegar']={slot=0,marker='HCRVinegar',target='Base.Vinegar2',vinegar=true},
}
for name,rule in pairs(HCRMashCatalog.products) do R.products[name]=rule end
for name,rule in pairs(R.products) do
    R.rules[name]={inputs={[rule.slot]={fluids={rule.marker},pure=true,unfermented=rule.water~=nil}}}
    if rule.water then R.rules[name].inputs[2]={fluids={'Water'},pure=true,nativeWater=true} end
end
for name,rule in pairs(HCRMashCatalog.consumers) do R.rules[name]=rule end

local function cask(data)
    local script=data:getRecipe():getInputs():get(0)
    local applied=assert(data:getDataForInputScript(script),'Missing fermentation cask')
    assert(applied:getAppliedItemsCount()==1,'Ambiguous fermentation cask')
    local item=applied:getAppliedItem(0);local fluid=Q.fluid(item)
    assert(B.casks[item:getFullType()] and fluid and fluid:isEmpty() and not Q.active(item,fluid)
        and fluid:getCapacity()>=20,'Fermentation needs an empty 20 litre cask')
    return item,fluid
end

function R.combine(parts,rule,now)
    local ledger=L.empty()
    for _,part in ipairs(parts) do
        for _,lot in ipairs(part.lots) do
            assert(lot.fluid==rule.marker or (rule.water and lot.fluid=='Water'),'Wrong fermentation ingredient')
        end
        ledger=L.mix(ledger,part)
    end
    if rule.stage then ledger=B.start(ledger,rule.stage,now) end
    return ledger
end

function R.plan(data,sources)
    local rule=R.products[data:getRecipe():getName()]
    if not rule then return true end
    local parts,ledger={},L.empty()
    for _,before in ipairs(sources) do
        for _,part in ipairs({before.ledger,before.nativeWater or L.empty()}) do
            if not L.canMix(ledger,part) then return false end
            ledger=L.mix(ledger,part);parts[#parts+1]=part
        end
    end
    local now=getGameTime():getWorldAgeHours()
    ledger=R.combine(parts,rule,now);E.prepare(ledger)
    if rule.stage then
        local _,fluid=cask(data)
        if not B.checkMixture(ledger,fluid) then return false end
        -- Все возможные native selected кандидаты, включая тонкие примеси,
        -- должны выдержать и будущий переход до расхода ингредиентов.
        E.prepare(B.plan(ledger,now+336,true,B.snapshot))
        E.prepare(B.plan(ledger,now+672,true,B.snapshot))
    else
        local item=assert(instanceItem(rule.target),'Missing fermentation bottle')
        if rule.vinegar then assert(item:IsDrainable(),'Changed vinegar bottle class')
        else
            local fluid=assert(Q.fluid(item),'Missing fermentation bottle fluid')
            assert(fluid:getCapacity()>=1,'Fermentation bottle too small')
            if not B.checkMixture(ledger,fluid) then return false end
        end
    end
    return true
end

function R.finish(state,data,character)
    local rule=R.products[data:getRecipe():getName()]
    if not rule then return false end
    local ledger=R.combine(state.fluids or {},rule,getGameTime():getWorldAgeHours())
    assert(math.abs(L.volume(ledger)-20)<.0001,'Fermentation input volume mismatch')
    E.prepare(ledger)
    if rule.stage then
        local item,fluid=cask(data)
        fluid:addFluid(B.stages[rule.stage].marker,20)
        assert(math.abs(Q.rawAmount(fluid)-20)<.00001,'Fermentation cask fill rejected')
        Q.store(item,fluid,L.alignVolumes(ledger,Q.amounts(fluid)));Q.sync(item,character)
    else
        local created=data:getAllCreatedItems()
        assert(created:size()==20,'Fermentation bottle count mismatch')
        local _,portion=L.split(ledger,1,20)
        for i=0,created:size()-1 do
            local item=created:get(i)
            assert(item:getFullType()==rule.target,'Fermentation bottle type mismatch')
            if rule.vinegar then
                HCRProcessQuality.write(item,state,20,character)
            else
                local fluid=Q.fluid(item)
                fluid:setCanPlayerEmpty(true);fluid:Empty();fluid:addFluid(rule.marker,1)
                assert(math.abs(Q.rawAmount(fluid)-1)<.00001,'Fermentation bottle fill rejected')
                Q.store(item,fluid,L.alignVolumes(portion,Q.amounts(fluid)));Q.sync(item,character)
            end
        end
    end
    return true
end
