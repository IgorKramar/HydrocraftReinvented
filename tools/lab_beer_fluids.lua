-- Только отдельный HCRLab: реальная миграция, упаковка, evolved и cold-save.
require 'HCR_BeerQuality'
require 'TimedActions/ISGrabItemAction'
HCRLabBeer={}
HCRLabBeerBoot=HCRLabBeerBoot or tostring(getTimestampMs())
local B,Q,L,F=HCRBeerQuality,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..': '..tostring(a)..' != '..tostring(b)) end
local function bag(player)
    local holder=player:getInventory():AddItem('Base.Bag_Schoolbag')
    return holder,holder:getItemContainer()
end
local function migrated(inv,kind,fraction,changed,state)
    local old=instanceItem(kind);old:setAge(0)
    old:setHungChange(old:getBaseHunger()*fraction)
    old:setCalories(changed and 123.5 or old:getCalories())
    if changed then F.store(old,.375);F.setQuality(old,state or 'rotten') end
    old:setFavorite(true)
    local item=assert(HCRItemMigrations.newReplacement(old),'Beer migration '..kind)
    inv:AddItem(item)
    assert(item:isFavorite() and not HCRItemMigrations.newReplacement(item),'Beer migration identity')
    item:setFavorite(false)
    return item
end
local function craft(player,inv,name,groups,manual,refused)
    local recipe=HCRLabCraft.findRecipe(name);local logic=HandcraftLogic.new(player,nil,nil)
    local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
    logic:updateFloorContainer(containers)
    if manual then
        logic:clearManualInputs()
        for slot,group in ipairs(groups) do
            local selected=ArrayList.new();for _,item in ipairs(group) do selected:add(item) end
            local accepted=logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected)
            if not accepted and refused then return nil end
            assert(accepted,'Beer manual input '..name..' slot='..slot)
        end
    end
    local ready=logic:getRecipeData():canConsumeInputs(logic:getSourceResources())
    if not ready and refused then return nil end
    assert(ready,'Beer native inputs '..name)
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    if refused then assert(action.hcrFluidRefused,'Unsafe beer recipe accepted');return nil end
    assert(not action.hcrFluidRefused,'Beer recipe refused '..name)
    local outputs=logic:getRecipeData():getAllCreatedItems();local result={}
    assert(outputs:size()>0,'Beer outputs missing '..name)
    for i=0,outputs:size()-1 do
        local item=outputs:get(i);result[#result+1]=item
        if item:getWorldItem() then
            local world=item:getWorldItem()
            ISGrabItemAction.transferItem({item=world,character=player,destContainer=inv,transactionId=0},world)
        elseif item:getContainer()~=inv then
            if item:getContainer() then item:getContainer():Remove(item) end
            inv:AddItem(item)
        end
    end
    return result
end
local function inspect(item,calories,dose,amount,state)
    local ledger=Q.capture(item,Q.fluid(item)).ledger
    near(Q.rawAmount(Q.fluid(item)),amount,'Beer litres')
    near(L.budget(ledger,'calories'),calories,'Beer calories')
    near(L.budget(ledger,'poisonPower'),dose,'Beer exact dose')
    assert(L.quality(ledger)==state,'Beer freshness')
end
function HCRLabBeer.run(player)
    assert(not isClient() and not isServer())
    local carry=player:isUnlimitedCarry();player:setUnlimitedCarry(true)
    local ok,reason=pcall(function()
        local count=0
        for kind,spec in pairs(HCRBeerCatalog.families) do
            local holder,inv=bag(player)
            local pristine=migrated(inv,kind,1,false)
            inspect(pristine,215,0,.3,'fresh');assert(B.factory(pristine),'Pristine beer mark '..kind)
            for _,fraction in ipairs({1,.5,.25}) do
                local item=migrated(inv,kind,fraction,true)
                inspect(item,123.5,.375,.3*fraction,'rotten');assert(not B.factory(item),'Modified beer packable')
                count=count+1
            end
            player:getInventory():Remove(holder)
        end
        assert(count==54);print('[HCRBeer160] 18 pristine + 54 modified/full/partial legacy migrations PASS')
        for _,manual in ipairs({true,false}) do
        for name,rule in pairs(HCRBeerCatalog.unpacking) do
            local holder,inv=bag(player);local pack=inv:AddItem(rule.source..'pack')
            local cans=craft(player,inv,name,{{pack}},manual)
            assert(#cans==6 and not pack:getContainer(),'Beer unpack count/source')
            local packName
            for candidate,target in pairs(HCRBeerCatalog.packing) do if target==rule.target then packName=candidate end end
            for _,item in ipairs(cans) do inspect(item,215,0,.3,'fresh');assert(B.factory(item)) end
            local poisoned=migrated(inv,rule.source,1,true)
            local empty=inv:AddItem(rule.target)
            local output=craft(player,inv,packName,{cans},manual)
            assert(#output==1 and poisoned:getContainer()==inv and empty:getContainer()==inv,'Auto packing used poisoned/empty candidate')
            for _,item in ipairs(cans) do assert(not item:getContainer(),'Packed beer survived') end
            local again=craft(player,inv,name,{output},manual)
            local calories,litres=0,0
            for _,item in ipairs(again) do
                inspect(item,215,0,.3,'fresh');assert(B.factory(item))
                calories=calories+L.budget(item:getModData()[Q.key],'calories');litres=litres+Q.rawAmount(Q.fluid(item))
            end
            near(calories,1290,'Beer roundtrip calories');near(litres,1.8,'Beer roundtrip litres')
            player:getInventory():Remove(holder)
        end end
        print('[HCRBeer160] 20 ten-brand manual/auto six-pack cycles, poisoned auto candidate excluded PASS')
        for _,mutation in ipairs({'partial','refilled','poison','mixture'}) do
            local holder,inv=bag(player);local cans={}
            for i=1,6 do cans[i]=migrated(inv,'Hydrocraft.HCBeercan1',1,mutation=='poison' and i==1) end
            local item=cans[1];local fluid=Q.fluid(item)
            if mutation=='partial' or mutation=='refilled' then
                Q.remove(item,player,function() fluid:adjustAmount(.15) end,false)
                if mutation=='refilled' then
                    local donor=migrated(inv,'Hydrocraft.HCBeercan1',1,false)
                    ISFluidTransferAction:new(player,ISFluidContainer:new(Q.fluid(donor)),Q.fluid(donor),
                        ISFluidContainer:new(fluid),fluid,.15):complete()
                    inv:Remove(donor)
                end
            elseif mutation=='mixture' then
                Q.remove(item,player,function() fluid:adjustAmount(.15) end,false)
                Q.addNative(item,player,function() fluid:addFluid('Water',.15) end)
            end
            assert(not B.factory(item),'Changed beer mark '..mutation)
            local volume=Q.rawAmount(fluid);local budget=L.budget(item:getModData()[Q.key],'calories')
            craft(player,inv,'Pack Beer',{cans},true,true)
            for _,can in ipairs(cans) do assert(can:getContainer()==inv,'Rejected pack consumed a can') end
            near(Q.rawAmount(fluid),volume,'Rejected pack volume');near(L.budget(item:getModData()[Q.key],'calories'),budget,'Rejected pack nutrition')
            player:getInventory():Remove(holder)
        end
        print('[HCRBeer160] partial/refilled/poisoned/mixed native packing refuses without consumption PASS')
        HCRLabCraft.trainCooking(player,'HCRLab')
        for i=1,20 do if player:getPerkLevel(Perks.Cooking)>=10 then break end;player:getXp():AddXP(Perks.Cooking,10000) end
        for _,manual in ipairs({true,false}) do
        for _,resultType in ipairs({'Base.PotOfSoupRecipe','Base.PotOfStew'}) do
        for _,state in ipairs({'fresh','stale','rotten'}) do
            local holder,inv=bag(player);local source=migrated(inv,'Hydrocraft.HCBeer1',1,true,state)
            local stein=inv:AddItem('Hydrocraft.HCAlestienFluid');Q.fluid(stein):Empty()
            local portion=craft(player,inv,'Prepare Beer for Cooking',{{source},{stein}},manual)[1]
            near(portion:getCalories(),123.5,'Beer cooking calories');near(F.dose(portion),.375,'Beer cooking dose')
            near(portion:getBaseHunger(),-.05,'Beer original hunger baseline')
            assert(F.quality(portion)==state and not stein:getContainer(),'Beer cooking freshness/vessel')
            near(Q.rawAmount(Q.fluid(source)),0,'Beer cooking consumed volume')
            local recipes=getScriptManager():getAllEvolvedRecipes();local evolved
            for i=0,recipes:size()-1 do if recipes:get(i):getFullResultItem()==resultType then evolved=recipes:get(i);break end end
            assert(evolved and evolved:getItemRecipe(portion),'Beer evolved registration')
            inv:Remove(portion);player:getInventory():AddItem(portion)
            local pot=player:getInventory():AddItem('Base.Pot');Q.fluid(pot):Empty();Q.fluid(pot):addFluid('Water',1.5)
            local action={recipe=evolved,baseItem=pot,usedItem=portion,character=player}
            assert(ISAddItemInRecipe.complete(action),'Beer evolved completion')
            print('[HCRBeer160] evolved '..resultType..' retained='..tostring(portion:getContainer()~=nil)
                ..' uses='..portion:getCurrentUses()..' hung='..portion:getHungChange()..' calories='..portion:getCalories()
                ..' portionDose='..F.dose(portion)..' resultDose='..F.dose(action.baseItem)..' use='..evolved:getItemRecipe(portion):getUse())
            local legacy=player:getInventory():AddItem('Hydrocraft.HCBeer1');legacy:setAge(0);legacy:setCalories(123.5)
            -- Старый WhiskeyEmpty не существует; здесь сравнивается расход Food,
            -- а отсутствие лишней посуды отдельно проверяется ниже.
            legacy:setReplaceOnUse(nil)
            F.store(legacy,.375);F.setQuality(legacy,state)
            local oldPot=player:getInventory():AddItem('Base.Pot');Q.fluid(oldPot):Empty();Q.fluid(oldPot):addFluid('Water',1.5)
            local reference={recipe=evolved,baseItem=oldPot,usedItem=legacy,character=player}
            assert(ISAddItemInRecipe.complete(reference),'Legacy beer evolved completion')
            assert((portion:getContainer()~=nil)==(legacy:getContainer()~=nil),'Beer evolved retained state differs from original')
            near(portion:getCalories(),legacy:getCalories(),'Beer evolved remaining nutrition')
            near(F.dose(portion),F.dose(legacy),'Beer evolved remaining exact dose')
            near(action.baseItem:getCalories(),reference.baseItem:getCalories(),'Beer evolved original result nutrition')
            near(F.dose(action.baseItem),F.dose(reference.baseItem),'Beer evolved original result dose')
            near(F.dose(action.baseItem)+F.dose(portion),.375,'Beer evolved total exact dose')
            assert(F.quality(action.baseItem)==state,'Beer evolved freshness')
            if portion:getContainer() then player:getInventory():Remove(portion) end
            if legacy:getContainer() then player:getInventory():Remove(legacy) end
            player:getInventory():Remove(reference.baseItem)
            player:getInventory():Remove(action.baseItem);player:getInventory():Remove(holder)
        end end end
        print('[HCRBeer160] 12 manual/auto Soup/Stew fresh/stale/rotten portions match legacy consumption/nutrition and preserve dose/freshness PASS')
        HCRLabBeer.vessels(player)
        local holder,inv=bag(player);holder:setName('HCRLab: beer cold save');holder:getModData().HCRBeerSave=HCRLabBeerBoot
        local fresh=migrated(inv,'Hydrocraft.HCBeercan1',1,false);fresh:getModData().beerProof='factory'
        local changed=migrated(inv,'Hydrocraft.HCBeer8',.5,true);changed:getModData().beerProof='changed'
        local partial=migrated(inv,'Hydrocraft.HCBeercan2',1,false)
        Q.remove(partial,player,function() Q.fluid(partial):adjustAmount(.15) end,false);partial:getModData().beerProof='partial'
        print('[HCRBeer160] three save samples SEEDED; cold verification pending')
    end)
    player:setUnlimitedCarry(carry)
    if not ok then error(reason) end
end
function HCRLabBeer.vessels(player)
    local inv=player:getInventory();local evolved
    local recipes=getScriptManager():getAllEvolvedRecipes()
    for i=0,recipes:size()-1 do if recipes:get(i):getFullResultItem()=='Base.PotOfSoupRecipe' then evolved=recipes:get(i);break end end
    local function count(kind)
        local n=0;local all=inv:getItems()
        for i=0,all:size()-1 do if all:get(i):getFullType()==kind then n=n+1 end end
        return n
    end
    for _,family in ipairs({{'HCBeer1','HCRBeer','Beer','Hydrocraft.HCAlestienFluid'},
        {'HCMead','HCRMead','Mead','Hydrocraft.HCAlestienFluid'},
        {'HCGin3','HCRGin','Spirit','Base.GlassTumbler'}}) do
        local holder,inside=bag(player)
        local sample=instanceItem('Hydrocraft.'..family[1]);sample:setAge(0);F.store(sample,.875);F.setQuality(sample,'rotten')
        local litres=family[3]=='Beer' and .3 or 1
        local donor=inside:AddItem('Base.Whiskey');local fluid=Q.fluid(donor);fluid:setCanPlayerEmpty(true);fluid:Empty();fluid:addFluid(family[2],litres)
        Q.store(donor,fluid,L.batch(family[2],litres,HCRFluidEffects.snapshot(sample),getGameTime():getWorldAgeHours()))
        local empty=inside:AddItem(family[4]);Q.fluid(empty):Empty()
        local portion=craft(player,inside,'Prepare '..family[3]..' for Cooking',{{donor},{empty}},true)[1]
        inside:Remove(portion);inv:AddItem(portion)
        local initial=count(family[4]);local dose=F.dose(portion);local transferred=0;local iterations=0
        while portion:getContainer() do
            iterations=iterations+1;assert(iterations<40,'Cooking portion never depleted')
            local pot=inv:AddItem('Base.Pot');Q.fluid(pot):Empty();Q.fluid(pot):addFluid('Water',1.5)
            local action={recipe=evolved,baseItem=pot,usedItem=portion,character=player}
            assert(ISAddItemInRecipe.complete(action))
            transferred=transferred+F.dose(action.baseItem)
            near(transferred+F.dose(portion),dose,'Repeated cooking total poison '..family[3])
            assert(count(family[4])-initial==(portion:getContainer() and 0 or 1),'Repeated cooking duplicated/lost vessel '..family[3])
            inv:Remove(action.baseItem)
        end
        assert(iterations>1,'Retained vessel regression did not exercise partial uses')
        player:getInventory():Remove(holder)
        print('[HCRBeer160] '..family[3]..' repeated rotten evolved uses='..iterations..': exactly one final vessel, conserved dose PASS')
    end
end
function HCRLabBeer.verify(player)
    local items=player:getInventory():getItems();local count=0
    for i=0,items:size()-1 do
        local holder=items:get(i);local boot=holder:getModData().HCRBeerSave
        if boot then
            assert(boot~=HCRLabBeerBoot,'Beer cold check requires process restart')
            local contents=holder:getItemContainer():getItems()
            for j=0,contents:size()-1 do
                local item=contents:get(j);local kind=item:getModData().beerProof
                if kind=='factory' then inspect(item,215,0,.3,'fresh');assert(B.factory(item));ISFluidContainerMenu.showInfo(player,Q.fluid(item))
                elseif kind=='changed' then inspect(item,123.5,.375,.15,'rotten');assert(not B.factory(item))
                elseif kind=='partial' then inspect(item,107.5,0,.15,'fresh');assert(not B.factory(item))
                else error('Unknown beer saved sample') end
                count=count+1
            end
        end
    end
    assert(count>=3 and count%3==0,'Beer saved samples absent/incomplete')
    print('[HCRBeer160] cold-save litres/nutrition/poison/freshness/factory history PASS count='..count)
end
