-- Упаковка не восстанавливает выпитое и не очищает изменённый напиток.
require 'HCR_BeerFamilies'
require 'HCR_SoftDrinkCatalog'
require 'HCR_DrinkFluids'
HCRBeerQuality={key='HCRBeerFactory160'}
local B,Q,L,E,C=HCRBeerQuality,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRBeerCatalog
C=L.copy(C)
if HCRSoftDrinkCatalog then
    for _,field in ipairs({'families','vessels','packing','unpacking'}) do
        for key,value in pairs(HCRSoftDrinkCatalog[field]) do C[field][key]=value end
    end
end
B.catalog=C
local templates={}
local ignored={age=true,heat=true}
local function prototype(source)
    if not templates[source] then templates[source]=E.snapshot(instanceItem(source)) end
    return L.copy(templates[source])
end

function B.factoryValues(item,fluid,ledger)
    local source=C.vessels[item:getFullType()]
    local spec=source and C.families[source]
    if not spec or not fluid or math.abs(Q.rawAmount(fluid)-spec.litres)>.000001
        or fluid:isMixture() or fluid:getPrimaryFluid()~=Fluid.Get(spec.fluid) then return false end
    if not L.matches(ledger,Q.amounts(fluid)) or #ledger.lots~=1 or L.quality(ledger)~='fresh' then return false end
    local lot=ledger.lots[1]
    if math.abs(lot.units-1)>.000001 or math.abs(lot.basisLitres-spec.litres)>.000001 then return false end
    local expected=prototype(source)
    for key,value in pairs(expected) do
        if not ignored[key] then
            local actual=lot.food[key]
            if type(value)=='number' then
                if type(actual)~='number' or math.abs(actual-value)>.000001 then return false end
            elseif actual~=value then return false end
        end
    end
    for key in pairs(lot.food) do if expected[key]==nil then return false end end
    return true
end

function B.factory(item)
    if not item or not item:getModData()[B.key] then return false end
    local ledger=item:getModData()[Q.key]
    if not ledger then return false end
    local ok,result=pcall(B.factoryValues,item,Q.fluid(item),ledger)
    return ok and result or false
end

function B.mark(item,source)
    local spices=source and source:getSpices()
    if source and (source:haveExtraItems() or spices and spices:size()>0) then return end
    if B.factoryValues(item,Q.fluid(item),item:getModData()[Q.key]) then item:getModData()[B.key]=true end
end

function B.packingInput(recipe,slot,script,item)
    local target=C.packing[recipe:getName()]
    return target and slot==0 and script:hasFlag(InputFlag.ItemCount)
        and not script:isKeep() and not script:hasConsumeFromItem()
        and not script:hasCreateToItem() and not script:isReplace()
        and item:getFullType()==target and B.factory(item) or false
end

function B.preflight(data)
    local name=data:getRecipe():getName();local target=C.packing[name]
    if target then
        local items=data:getInputItems(0)
        assert(items and items:size()>=6,'Six original beer cans required')
        local count=0
        for i=0,items:size()-1 do
            local item=items:get(i)
            if item:getFullType()==target then
                assert(B.factory(item),'Changed beer cannot be packed')
                count=count+1
            end
        end
        assert(count>=6,'Six original beer cans required')
    end
    local rule=C.unpacking[name]
    if rule then
        local spec=C.families[rule.source]
        local sample=assert(instanceItem(rule.target),'Missing beer vessel')
        local fluid=assert(Q.fluid(sample),'Missing beer fluid component')
        assert(fluid:isEmpty() and math.abs(fluid:getCapacity()-spec.litres)<.000001,'Changed factory vessel capacity')
        E.prepare(L.batch(spec.fluid,spec.litres,prototype(rule.source),getGameTime():getWorldAgeHours()))
    end
    return true
end

function B.finish(state,data,character)
    local rule=C.unpacking[data:getRecipe():getName()]
    if not rule then return false end
    local spec=C.families[rule.source]
    local created=data:getAllCreatedItems();assert(created:size()==6,'Beer pack count mismatch')
    local planned={}
    for i=0,created:size()-1 do
        local item=created:get(i);local fluid=Q.fluid(item)
        assert(item:getFullType()==rule.target and fluid and fluid:isEmpty()
            and math.abs(fluid:getCapacity()-spec.litres)<.000001,'Factory drink output mismatch')
        planned[i+1]=L.batch(spec.fluid,spec.litres,prototype(rule.source),getGameTime():getWorldAgeHours())
        E.prepare(planned[i+1])
    end
    for i=0,created:size()-1 do
        local item=created:get(i);local fluid=Q.fluid(item)
        fluid:addFluid(spec.fluid,spec.litres)
        Q.store(item,fluid,L.alignVolumes(planned[i+1],Q.amounts(fluid)))
        B.mark(item);Q.sync(item,character)
    end
    return true
end
