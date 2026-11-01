-- Private HCRLab only. Native handcraft/heat/transfer and cold-save oracle.
-- Load after HCRLabCraft.lua and HCRLabSpirits.lua; never ship in common/.
HCRLabBreweryBoot=HCRLabBreweryBoot or tostring(getTimestampMs())
HCRLabBrewery={}
local M,Q,L,F,B=HCRLabBrewery,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRBrewedDrinks
local function log(s) print('[HCRBrewery160] '..s) end
local function near(a,b,label) assert(a and math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) return assert(item:getModData()[Q.key],'Missing brewery ledger') end
local function bag(p)
    local b=p:getInventory():AddItem('Base.Bag_Schoolbag');return b,b:getItemContainer()
end
local function craft(p,inv,name,groups,manual,refused)
    return HCRLabSpirits.craft(p,inv,name,groups,manual,refused)
end
local function remember(b,item)
    local row={id=item:getID(),litres=Q.rawAmount(Q.fluid(item)),ledger=L.copy(raw(item))}
    local rows=b:getModData().HCRBrewerySaved.rows;rows[#rows+1]=row
end
local function liquid(item,volume,dose,state)
    local ledger=Q.capture(item,Q.fluid(item)).ledger
    near(Q.rawAmount(Q.fluid(item)),volume,'Volume');near(L.budget(ledger,'poisonPower'),dose,'Dose')
    assert(L.matches(ledger,Q.amounts(Q.fluid(item))),'Native ledger mismatch')
    assert(L.quality(ledger)==state,'Quality '..L.quality(ledger)..' / '..state)
    return ledger
end
local function finish(p,inv,food,yeast,manual)
    local before=yeast:getCurrentUses()
    local made=craft(p,inv,'Start Wheat Beer Fermentation',{{food},{yeast}},manual)
    assert(#made==1 and made[1]:getFullType()=='Base.Pot','Exactly one returned pot')
    near(yeast:getCurrentUses(),before-1,'One yeast use')
    assert(not food:getContainer(),'Wort Food was not consumed')
    return made[1]
end
function M.run(p)
    assert(not isClient() and not isServer())
    local saved,stock=bag(p);saved:setName('HCRLab: brewery cold proof')
    saved:getModData().HCRBrewerySaved={boot=HCRLabBreweryBoot,rows={}}
    M.saved=saved
    local prepared={}
    for _,manual in ipairs({true,false}) do
        local holder,inv=bag(p)
        local pot=inv:AddItem('Base.Pot');Q.fluid(pot):Empty()
        local water=inv:AddItem('Base.PopBottle');Q.fluid(water):Empty();Q.fluid(water):addFluid('Water',2)
        local wheat={};for i=1,30 do wheat[i]=inv:AddItem('Hydrocraft.HCWheat') end
        local hops=inv:AddItem('Hydrocraft.HCHops')
        local made=craft(p,inv,'Prepare Wheat Wort',{{pot},{water},wheat,{hops}},manual)
        assert(#made==1 and made[1]:getFullType()=='Hydrocraft.HCRWheatWortPot','Wort output')
        assert(not pot:getContainer() and not hops:getContainer(),'Ingredients not debited')
        for _,item in ipairs(wheat) do assert(not item:getContainer(),'Wheat not consumed') end
        near(Q.rawAmount(Q.fluid(water)),.5,'Water remainder')
        local food=made[1];assert(not food:isCooked(),'Wort must need heating')
        local yeast=inv:AddItem('Base.Yeast');local uses=yeast:getCurrentUsesFloat()
        craft(p,inv,'Start Wheat Beer Fermentation',{{food},{yeast}},manual,true)
        near(yeast:getCurrentUsesFloat(),uses,'Rejected raw consumed yeast')
        assert(food:getContainer()==inv,'Rejected raw consumed wort')
        inv:Remove(food);stock:AddItem(food);prepared[#prepared+1]=food
        p:getInventory():Remove(holder)
    end
    log('PREPARE PASS native manual/auto ingredients, water remainder and raw refusal')
    local count=0
    for _,manual in ipairs({true,false}) do for _,fraction in ipairs({1,.5,.01}) do
    for _,quality in ipairs({'fresh','stale','rotten'}) do
        local holder,inv=bag(p);local food=inv:AddItem('Hydrocraft.HCRWheatWortPot')
        food:setAge(0);food:setCooked(true);food:setHungChange(food:getBaseHunger()*fraction)
        food:setCalories(137*fraction);F.store(food,.625*fraction);F.setQuality(food,quality)
        local yeast=inv:AddItem('Base.Yeast');local result=finish(p,inv,food,yeast,manual)
        local ledger=liquid(result,1.5*fraction,.625*fraction,quality)
        near(L.budget(ledger,'calories'),137*fraction,'Wort calories')
        local now=getGameTime():getWorldAgeHours()
        for _,lot in ipairs(raw(result).lots) do lot.fermentation.startedAt=now-167.999;lot.fermentation.lastHour=now end
        ledger=Q.capture(result,Q.fluid(result)).ledger
        assert(ledger.lots[1].fluid=='HCRBeerWort','Early fermentation')
        for _,lot in ipairs(raw(result).lots) do lot.fermentation.startedAt=now-168;lot.fermentation.lastHour=now end
        ledger=liquid(result,1.5*fraction,.625*fraction,quality)
        assert(ledger.lots[1].fluid=='HCRBeer','Not beer at 168 hours')
        local native=HCRFermentation.snapshot('Hydrocraft.HCRWheatBeerBatch',quality)
        near(L.budget(ledger,'calories'),native.calories*1.5*fraction,'Native beer nutrition')
        near(L.budget(ledger,'nativeAlcohol'),native.nativeAlcohol*1.5*fraction,'Native beer alcohol')
        assert(ledger.lots[1].food.offAge==14 and ledger.lots[1].food.offAgeMax==30,'Beer shelf life')
        inv:Remove(result);stock:AddItem(result);remember(saved,result)
        p:getInventory():Remove(holder);count=count+1
    end end end
    log('PORTIONS PASS '..count..' manual/auto full/half/1% fresh/stale/rotten; 168h boundary, nutrition/alcohol/dose')
    M.heat(p,prepared)
end
function M.heat(p,foods)
    local square=p:getSquare();local crate=IsoObject.new(getCell(),square,'carpentry_01_16')
    local inv=ItemContainer.new('crate',square,crate);inv:setCapacity(100);inv:setCustomTemperature(2)
    crate:setContainer(inv);square:AddTileObject(crate)
    for _,item in ipairs(foods) do
        assert(item:getMinutesToCook()==60 and item:getMinutesToBurn()==120,'Original cooking durations')
        item:getContainer():Remove(item);inv:AddItem(item);item:setHeat(2)
    end
    local control=p:getInventory():AddItem('Hydrocraft.HCRWheatWortPot')
    M.heating={inv=inv,foods=foods,player=p,started=getTimestampMs(),speed=getGameSpeed(),control=control}
    setGameSpeed(3);log('HEAT START native 60/120 minutes; no cookingTime or world-time injection')
end
function M.heatTick()
    local s=M.heating;if not s then return end
    assert(getTimestampMs()-s.started<600000,'Heat timeout')
    assert(not s.control:isCooked(),'Unheated control cooked')
    local food=s.foods[1]
    if not s.cooked and food:isCooked() then
        s.cooked=true;log('HEAT cooked '..food:getCookingTime()..' hunger '..food:getHungChange()..'/'..food:getBaseHunger())
        local b,inv=bag(s.player);s.inv:Remove(food);inv:AddItem(food)
        local result=finish(s.player,inv,food,inv:AddItem('Base.Yeast'),true)
        liquid(result,1.5,0,'fresh')
        inv:Remove(result);M.saved:getItemContainer():AddItem(result);remember(M.saved,result)
        s.player:getInventory():Remove(b)
    end
    food=s.foods[2]
    if s.cooked and food:isBurnt() then
        log('HEAT burnt '..food:getCookingTime()..' hunger '..food:getHungChange()..'/'..food:getBaseHunger())
        local b,inv=bag(s.player);s.inv:Remove(food);inv:AddItem(food)
        F.store(food,.75);local result=finish(s.player,inv,food,inv:AddItem('Base.Yeast'),false)
        local ledger=Q.capture(result,Q.fluid(result)).ledger
        near(Q.rawAmount(Q.fluid(result)),1.5,'Burnt volume');near(L.budget(ledger,'poisonPower'),.75,'Burnt dose')
        assert(ledger.lots[1].food.burnt,'Lost burnt marker')
        inv:Remove(result);M.saved:getItemContainer():AddItem(result);remember(M.saved,result)
        s.player:getInventory():Remove(b)
        s.inv:setCustomTemperature(1);setGameSpeed(s.speed);M.heating=nil
        M.saved:getModData().HCRBrewerySaved.complete=true
        log('HEAT PASS natural cook/burn, one yeast use, one pot, cold control')
    end
end
function M.extra(p)
    assert(M.saved and M.saved:getModData().HCRBrewerySaved.complete,'Finish heating first')
    local holder,inv=bag(p);local pots={}
    for i=1,2 do
        local food=inv:AddItem('Hydrocraft.HCRWheatWortPot');food:setCooked(true);food:setAge(0)
        food:setHungChange(food:getBaseHunger()*(i==1 and .5 or 1));food:setCalories(137*i)
        F.store(food,.625*i);F.setQuality(food,'rotten');F.setTainted(food)
        pots[i]=finish(p,inv,food,inv:AddItem('Base.Yeast'),true)
    end
    local a,b=pots[1],pots[2];local now=getGameTime():getWorldAgeHours()
    for i,item in ipairs(pots) do for _,lot in ipairs(raw(item).lots) do
        lot.fermentation.startedAt=now-(i==1 and 167 or 157);lot.fermentation.lastHour=now
    end end
    local bucket=inv:AddItem('Hydrocraft.HCWoodenbucketFluid');Q.fluid(bucket):Empty()
    Q.transfer(ISFluidContainer:new(Q.fluid(b)),ISFluidContainer:new(Q.fluid(bucket)),p,
        function() FluidContainer.Transfer(Q.fluid(b),Q.fluid(bucket),1.5) end)
    b=bucket;pots[2]=bucket
    Q.transfer(ISFluidContainer:new(Q.fluid(a)),ISFluidContainer:new(Q.fluid(b)),p,
        function() FluidContainer.Transfer(Q.fluid(a),Q.fluid(b),.25) end)
    local ledger=liquid(b,1.75,.625/3+1.25,'rotten');assert(#ledger.lots==2,'Mixed ages collapsed')
    for _,lot in ipairs(raw(b).lots) do if lot.litres<.5 then lot.fermentation.startedAt=now-168 end end
    ledger=Q.capture(b,Q.fluid(b)).ledger
    near(Q.fluid(b):getSpecificFluidAmount(Fluid.Get('HCRBeer')),.25,'Older lot ready')
    near(Q.fluid(b):getSpecificFluidAmount(Fluid.Get('HCRBeerWort')),1.5,'Younger lot still wort')
    for _,lot in ipairs(raw(b).lots) do if lot.fluid=='HCRBeerWort' then lot.fermentation.startedAt=now-168 end end
    ledger=liquid(b,1.75,.625/3+1.25,'rotten')
    near(Q.fluid(b):getSpecificFluidAmount(Fluid.Get('HCRBeer')),1.75,'Both matured')
    for _,lot in ipairs(ledger.lots) do assert(lot.food.tainted,'Mix cleared taint') end
    near(L.budget(ledger,'poisonPower')+L.budget(raw(a),'poisonPower'),1.875,'Total dose after split')
    for _,item in ipairs(pots) do inv:Remove(item);M.saved:getItemContainer():AddItem(item);remember(M.saved,item) end
    log('MIX PASS real native pour, independent clocks, separate maturity, exact total dose and taint')
    for name,target in pairs(HCRBeerCatalog.packing) do
        local cans={}
        for i=1,6 do
            local can=inv:AddItem(target);local fluid=Q.fluid(can);fluid:setCanPlayerEmpty(true);fluid:Empty()
            fluid:addFluid('HCRBeer',fluid:getCapacity())
            local volume=Q.rawAmount(fluid)
            Q.store(can,fluid,L.batch('HCRBeer',volume,HCRFermentation.snapshot('Hydrocraft.HCRWheatBeerBatch','fresh'),now))
            assert(not HCRBeerQuality.factory(can),'Homebrew marked factory')
            cans[i]=can
        end
        craft(p,inv,name,{cans},true,true);craft(p,inv,name,{cans},false,true)
        for _,can in ipairs(cans) do assert(can:getContainer()==inv,'Rejected packing consumed a can');inv:Remove(can) end
    end
    p:getInventory():Remove(holder);log('PACK PASS all branded six-packs refuse homebrew manual/auto')
end
function M.forage(p)
    require 'Foraging/ISForageAction'
    local def=assert(forageSystem.itemDefs['Hydrocraft.HCHops'],'Missing native forage definition')
    assert(def.skill==4 and forageSystem.isValidMonth(def,9) and not forageSystem.isValidMonth(def,1),'Forage season/skill')
    while p:getPerkLevel(Perks.PlantScavenging)<4 do p:LevelPerk(Perks.PlantScavenging) end
    local manager=ISSearchManager.getManager(p);local square=p:getSquare()
    local zone=manager:getAndActivateZoneAtXY(square:getX(),square:getY())
    assert(zone,'Move to a real forage zone first')
    local old={};for id in pairs(manager.forageIcons) do old[id]=true end
    manager:createSpecificIcon(square,'Hydrocraft.HCHops',zone,false,false,1)
    local icon
    for id,row in pairs(manager.forageIcons) do if not old[id] and row.itemType=='Hydrocraft.HCHops' then icon=row end end
    assert(icon and icon.itemList:size()>=1,'Native forage spawn produced no hops')
    local expected={};for i=0,icon.itemList:size()-1 do expected[#expected+1]=icon.itemList:get(i) end
    local action=ISForageAction:new(p,icon.iconID,{},p:getInventory(),'Hydrocraft.HCHops')
    assert(action:isValid(),'Forage location invalid');assert(action:complete(),'Native forage pickup failed')
    forageSystem.actionComplete(p,icon.iconID)
    for _,item in ipairs(expected) do assert(item:getFullType()=='Hydrocraft.HCHops' and item:getContainer()==p:getInventory(),'Hops pickup missing') end
    assert(not manager.forageIcons[icon.iconID],'Picked icon remains')
    log('FORAGE PASS native icon generation and ISForageAction pickup '..#expected..' hops; season/skill')
end
function M.verify(p)
    local bags=p:getInventory():getItems();local count=0
    for i=0,bags:size()-1 do local bag=bags:get(i);local saved=bag:getModData().HCRBrewerySaved
        if saved and saved.complete then
            assert(saved.boot~=HCRLabBreweryBoot,'Requires cold restart')
            for _,row in ipairs(saved.rows) do
                local found;local contents=bag:getItemContainer():getItems()
                for j=0,contents:size()-1 do local item=contents:get(j);if item:getID()==row.id then assert(not found);found=item end end
                assert(found,'Lost saved beer')
                local current=raw(found);L.validate(current)
                near(Q.rawAmount(Q.fluid(found)),row.litres,'Cold volume')
                near(L.budget(current,'poisonPower'),L.budget(row.ledger,'poisonPower'),'Cold dose')
                near(L.budget(current,'calories'),L.budget(row.ledger,'calories'),'Cold nutrition')
                assert(L.quality(current)==L.quality(row.ledger),'Cold quality')
                assert(#current.lots==#row.ledger.lots,'Cold lots')
                assert(L.matches(current,Q.amounts(Q.fluid(found))),'Cold native composition')
                near(L.budget(current,'nativeAlcohol'),L.budget(row.ledger,'nativeAlcohol'),'Cold alcohol')
                for j,lot in ipairs(current.lots) do local before=row.ledger.lots[j]
                    assert(lot.fluid==before.fluid,'Cold marker')
                    assert(lot.food.tainted==before.food.tainted and lot.food.burnt==before.food.burnt,'Cold quality flags')
                    if before.fermentation then
                        assert(lot.fermentation and lot.fermentation.kind==before.fermentation.kind,'Cold fermentation stage')
                        near(lot.fermentation.startedAt,before.fermentation.startedAt,'Cold fermentation start')
                    end
                end
                count=count+1
            end
        end
    end
    assert(count>=20,'Incomplete saved brewery scenario');log('COLD PASS '..count..' samples')
end
if not HCRLabBreweryWatcher then
    HCRLabBreweryWatcher=true;local ticks=0
    Events.OnTick.Add(function()
        ticks=ticks+1;if ticks%30~=0 or not HCRLabBrewery.heating then return end
        local ok,why=pcall(HCRLabBrewery.heatTick)
        if not ok then setGameSpeed(1);HCRLabBrewery.heating=nil;log('HEAT FAIL '..tostring(why)) end
    end)
end
