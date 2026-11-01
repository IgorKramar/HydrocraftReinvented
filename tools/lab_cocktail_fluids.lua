-- Только private HCRLab: состав готовых коктейлей, миграция и cold-save.
require 'HCR_CocktailCatalog'
require 'TimedActions/ISDrinkFluidAction'
require 'Fluids/ISFluidTransferAction'
HCRLabCocktails={}
HCRLabCocktailBoot=HCRLabCocktailBoot or tostring(getTimestampMs())
local C,Q,L,F,E=HCRLabCocktails,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRFluidEffects
local function near(a,b,label) assert(math.abs(a-b)<.002,label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) return Q.capture(item,Q.fluid(item)).ledger end
local cases={
    {'Mix Old Fashioned','glassshortwhiskey','HCBitters','Base.Sugar','HCSlicedorange'},
    {'Mix Martini','cocktailglassgin','HCBitters','HCVermouth'},
    {'Mix Manhattan','cocktailglasswhiskey','HCBitters','HCVermouth'},
    {'Mix Daquiri','cocktailglassrum','HCLimemixer','Base.Sugar','HCSlicedlime'},
    {'Mix Bloody Mary','glasstallvodka','HCBloodymarymixer'},
    {'Mix Whiskey Sour','glassshortwhiskey','HCLemonmixer','Base.Sugar'},
    {'Mix Mai Tai','glassshortrum','HCLimemixer','Base.Sugar','HCTriplesec'},
    {'Mix Cosmopolitan','cocktailglassvodka','HCTriplesec','HCLimemixer','HCSlicedlime'},
    {'Mix Tom Collins','glasstallgin','HCLemonmixer','Base.Sugar'},
    {'Mix Long Island Iced Tea','glasstallvodka','HCRum1','HCLemonmixer','HCLimemixer','HCTriplesec','Base.Sugar'},
    {'Mix Gimlet','cocktailglassgin','HCLimemixer','Base.Sugar'},
    {"Mix Planter's Punch",'glassshortrum','HCBitters','HCLemonmixer','Base.Sugar'},
    {'Whiskey and Coke','glasstallwhiskey','HCSodacola'},
    {'Whiskey and Coke (Canned Cola)','glasstallwhiskey','Base.Pop'},
    {'Mix Margarita','HCMargaritaglassempty','HCTequila','HCTriplesec','HCLemonmixer','Base.Salt','HCSlicedlime'},
}
local getters={calories='getCalories',carbohydrates='getCarbohydrates',proteins='getProteins',lipids='getLipids',
    hungChange='getHungerChange',thirstChange='getThirstChange',fatigueChange='getFatigueChange',nativeAlcohol='getAlcohol'}
local keys={'calories','carbohydrates','proteins','lipids','hungChange','thirstChange','fatigueChange','nativeAlcohol','poisonPower'}
local function budget(item)
    local value={};local fluid=Q.fluid(item)
    if fluid then
        local ledger=raw(item);local props=fluid:getProperties()
        for _,key in ipairs(keys) do value[key]=L.budget(ledger,key)+(getters[key] and props[getters[key]](props) or 0) end
    elseif item:IsFood() then
        local snapshot=E.snapshot(item)
        for _,key in ipairs(keys) do value[key]=snapshot[key] or 0 end
    end
    return value
end
local function checkBudgets(output,before,groups,rule)
    local result=raw(output)
    for _,key in ipairs(keys) do
        local consumed=0
        for item,value in pairs(before) do
            local after=item:getContainer() and budget(item) or {}
            consumed=consumed+(value[key] or 0)-(after[key] or 0)
        end
        near(L.budget(result,key),consumed,rule.marker..' '..key)
    end
end
local function source(inv,kind,quality)
    if not kind:find('%.') then kind='Hydrocraft.'..kind end
    local spec=HCRDrinkFamilies[kind]
    if spec and spec.enabled then
        if spec.unitLitres then
            local item=assert(HCRItemMigrations.newReplacement(instanceItem(kind)));inv:AddItem(item);return item
        end
        return HCRLabSpirits.migrated(inv,kind,1,true,quality)
    end
    local item=inv:AddItem(kind)
    if item:IsFood() then item:setAge(0);F.store(item,.125) end
    return item
end
local function one(player,case,manual,quality,native)
    local S=HCRLabSpirits;local holder,inv=S.bag(player);local groups={};local name=case[1]
    local irish=name:find('Brew Irish Coffee')==1;local empty
    if irish then
        local rule=HCRCocktailCatalog.products[name]
        empty=inv:AddItem(rule.target);Q.fluid(empty):Empty();groups[1]={empty}
        local water=inv:AddItem('Base.Whiskey');Q.fluid(water):Empty();Q.fluid(water):addFluid('Water',.6)
        groups[2]={water};groups[3]={source(inv,case[2],quality)}
        groups[4]={source(inv,'Hydrocraft.HCDrinkglassshortwhiskey',quality)}
    else
        if name:find('Mix ')==1 then groups[1]={inv:AddItem('Base.Spoon')} end
        for i=2,#case do
            local kind=case[i]
            if i==2 and kind~='HCMargaritaglassempty' then kind='Hydrocraft.HCDrink'..kind end
            groups[#groups+1]={source(inv,kind,quality)}
        end
    end
    if native then
        for _,group in ipairs(groups) do
            local item=group[1];local fluid=Q.fluid(item)
            if fluid and not fluid:isEmpty() and fluid:getPrimaryFluid()==Fluid.Get('HCRWhiskey') then
                fluid:Empty();fluid:addFluid('Whiskey',.1)
                Q.store(item,fluid,HCRNativeWhiskey.ledger(fluid,{quality=quality,dose=.875,detection=4},1))
            end
        end
    end
    local before={}
    for _,group in ipairs(groups) do for _,item in ipairs(group) do before[item]=budget(item) end end
    local output=S.craft(player,inv,name,groups,manual)[1];local rule=HCRCocktailCatalog.products[name]
    near(Q.rawAmount(Q.fluid(output)),rule.litres,'Cocktail volume')
    assert(output:getFullType()==rule.target and not output:IsFood(),'Legacy output')
    checkBudgets(output,before,groups,rule)
    assert(L.quality(raw(output))==quality,'Cocktail freshness '..name)
    if irish then
        assert(not empty:getContainer() and groups[4][1]:getContainer()==inv and Q.fluid(groups[4][1]):isEmpty(),'Irish vessels')
        near(Q.fluid(output):getCapacity(),rule.target=='Base.Mugl' and .2 or 1.4,'Irish capacity')
    end
    if manual and quality=='stale' then
        holder:getModData().HCRCocktailCold={boot=HCRLabCocktailBoot,id=output:getID(),amount=rule.litres,ledger=L.copy(output:getModData()[Q.key])}
        holder:setName('HCRLab cocktail cold sample')
    else player:getInventory():Remove(holder) end
end
function C.run(player)
    local S=HCRLabSpirits;local count=0
    for kind,spec in pairs(HCRCocktailCatalog.families) do
        local holder,inv=S.bag(player)
        S.inspect(S.migrated(inv,kind,1,false),spec.litres,instanceItem(kind):getCalories(),0,'fresh')
        for _,fraction in ipairs({1,.5,.25}) do S.inspect(S.migrated(inv,kind,fraction,true),spec.litres*fraction,123.5,.875,'rotten') end
        player:getInventory():Remove(holder);count=count+1
    end
    assert(count==16);print('[HCRCocktail160] 16 pristine + 48 changed/partial migrations PASS')
    for _,entry in ipairs({{'Brew Irish Coffee','Base.Coffee2'},{'Brew Irish Coffee (Cup of Irish Coffee)','Base.Coffee2'},
        {'Brew Irish Coffee (Cup of Irish Coffee 2)','Hydrocraft.HCCoffeelarge'},
        {'Brew Irish Coffee (Cup of Irish Coffee 3)','Hydrocraft.HCCoffeelarge'}}) do cases[#cases+1]=entry end
    count=0
    for _,manual in ipairs({true,false}) do for _,case in ipairs(cases) do for _,quality in ipairs({'fresh','stale','rotten'}) do
        one(player,case,manual,quality,false);count=count+1
    end end end
    assert(count==114);print('[HCRCocktail160] 114 manual/auto fresh/stale/rotten actual-volume and full-budget crafts PASS')
    for _,manual in ipairs({true,false}) do for _,index in ipairs({1,14,16,17}) do one(player,cases[index],manual,'stale',true) end end
    print('[HCRCocktail160] 8 native Whiskey + quality trace / native Cola / water crafts PASS')
    C.reuse(player)
end
function C.reuse(player)
    local S=HCRLabSpirits
    for _,manual in ipairs({true,false}) do for kind,spec in pairs(HCRCocktailCatalog.families) do
        if not kind:find('HCCoffeeirish') then
            local holder,inv=S.bag(player);local empty=inv:AddItem(spec.target);local fluid=Q.fluid(empty)
            local name,groups
            if kind=='Hydrocraft.HCDrinkmargarita' then
                name='Mix Margarita';groups={{inv:AddItem('Base.Spoon')},{empty}}
                for _,k in ipairs({'HCTequila','HCTriplesec','HCLemonmixer','Base.Salt','HCSlicedlime'}) do groups[#groups+1]={source(inv,k,'fresh')} end
            else
                local shape=kind:find('oldfashioned') or kind:find('whiskeysour') or kind:find('maitai') or kind:find('planterspunch')
                shape=shape and 'Short' or ((kind:find('bloodymary') or kind:find('tomcollins') or kind:find('longisland') or kind:find('whiskeyandcoke')) and 'Tall' or 'Cocktail')
                name='Pour '..shape..' Glass of Gin';groups={{empty},{source(inv,'HCGin1','fresh')}}
            end
            fluid:addFluid('Water',.01)
            S.craft(player,inv,name,groups,manual,true)
            assert(empty:getContainer()==inv);near(Q.rawAmount(fluid),.01,'Rejected partial glass')
            Q.remove(empty,player,function() fluid:Empty() end,false)
            local result=S.craft(player,inv,name,groups,manual)[1]
            assert(not empty:getContainer(),'Duplicated reused glass')
            near(Q.rawAmount(Q.fluid(result)),kind:find('margarita') and .225 or .1,'Reused glass')
            player:getInventory():Remove(holder)
        end
    end end
    local holder,inv=S.bag(player);local item=S.migrated(inv,'Hydrocraft.HCDrinklongisland',1,false)
    -- Штатное action требует предмет в основном инвентаре; UI сначала
    -- переносит его из сумки. Прямой вызов этого сам не делает.
    inv:Remove(item);player:getInventory():AddItem(item)
    local id=item:getID();local stats=player:getStats();local nutrition=player:getNutrition();local calories=L.budget(raw(item),'calories')
    stats:set(CharacterStat.HUNGER,.8);nutrition:setCalories(0)
    ISDrinkFluidAction:new(player,item,.25):updateEat(1)
    near(nutrition:getCalories(),calories*.25,'Cocktail quarter calories');near(Q.rawAmount(Q.fluid(item)),.425*.75,'Quarter drink')
    ISDrinkFluidAction:new(player,item,1):updateEat(1)
    near(nutrition:getCalories(),calories,'Cocktail whole calories')
    assert(item:getID()==id and item:getContainer()==player:getInventory() and Q.fluid(item):isEmpty(),'Drinking lost/replaced glass')
    near(Q.fluid(item):getCapacity(),.5,'Empty ready capacity')
    -- Множество cold fixtures переполняет основной инвентарь; движок
    -- запрещает долив в его предметы. Проверяем реальную тару внутри сумки.
    player:getInventory():Remove(item);inv:AddItem(item)
    local donor=source(inv,'HCGin1','fresh');local sf,tf=Q.fluid(donor),Q.fluid(item)
    ISFluidTransferAction:new(player,ISFluidContainer:new(sf),sf,ISFluidContainer:new(tf),tf,.1):complete()
    assert(item:getID()==id and item:getContainer()==inv);near(tf:getCapacity(),.5,'Native refill capacity')
    near(Q.rawAmount(tf),.1,'Native refill volume');near(L.budget(raw(item),'poisonPower'),.0875,'Native refill dose')
    player:getInventory():Remove(holder)
    print('[HCRCocktail160] 28 empty reuse + partial refusals; quarter/full drinking + same-ID native refill PASS')
end
function C.verify(player)
    local all=player:getInventory():getItems();local count=0
    for i=0,all:size()-1 do
        local holder=all:get(i);local saved=holder:getModData().HCRCocktailCold
        if saved then
            assert(saved.boot~=HCRLabCocktailBoot,'Not a cold process')
            local item=assert(holder:getItemContainer():getItemById(saved.id));local ledger=assert(item:getModData()[Q.key])
            L.validate(ledger);assert(L.matches(ledger,Q.amounts(Q.fluid(item))))
            near(Q.rawAmount(Q.fluid(item)),saved.amount,'Cold cocktail volume');assert(L.quality(ledger)==L.quality(saved.ledger))
            for _,key in ipairs(keys) do near(L.budget(ledger,key),L.budget(saved.ledger,key),'Cold '..key) end
            count=count+1
        end
    end
    assert(count>=23,'Missing cocktail cold samples');print('[HCRCocktail160] COLD PASS '..count)
end
function C.show(player)
    if HCRLabCocktailTooltip then HCRLabCocktailTooltip:removeFromUIManager() end
    local all=player:getInventory():getItems();local item
    for i=0,all:size()-1 do
        local holder=all:get(i);local record=holder:getModData().HCRCocktailCold
        if record then
            local candidate=holder:getItemContainer():getItemById(record.id)
            if candidate and candidate:getFullType()=='Hydrocraft.HCDrinklongislandFluid' then item=candidate end
        end
    end
    assert(item,'Missing cocktail sample')
    local ui=ISToolTipInv:new(item);ui:initialise();ui:setCharacter(player)
    ui.followMouse=false;ui:setX(40);ui:setY(90);ui:addToUIManager();ui:setVisible(true);HCRLabCocktailTooltip=ui
end
