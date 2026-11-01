-- Только одноразовый HCRLab. Настоящие Food, миграции и native HandcraftLogic.
require 'HCR_FermentationRecipes'
require 'HCR_ItemMigrations'
require 'HCR_FluidCrafting'
require 'TimedActions/ISGrabItemAction'
HCRLabFermentationRecipes={}
local M,Q,L,F,B=HCRLabFermentationRecipes,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRFermentation
local function near(a,b,label) assert(math.abs(a-b)<.0001,label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) return assert(item:getModData()[Q.key],'Missing raw fermentation ledger') end
local function craft(player,inv,name,groups,manual,refused)
    local recipes=getScriptManager():getAllCraftRecipes();local recipe
    for i=0,recipes:size()-1 do if recipes:get(i):getName()==name then recipe=recipes:get(i);break end end
    player:learnRecipe(name)
    local logic=HandcraftLogic.new(player,nil,nil);local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(assert(recipe));logic:setManualSelectInputs(manual)
    logic:updateFloorContainer(containers)
    if manual then
        logic:clearManualInputs()
        for slot,group in ipairs(groups) do
            local items=ArrayList.new();for _,item in ipairs(group) do items:add(item) end
            local ok=logic:setManualInputsFor(recipe:getInputs():get(slot-1),items)
            if not ok and refused then return end
            assert(ok,'Manual fermentation slot '..slot..' '..name)
        end
    end
    if not logic:getRecipeData():canConsumeInputs(logic:getSourceResources()) and refused then return end
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    if refused then assert(action.hcrFluidRefused,'Unsafe fermentation craft accepted');return end
    assert(not action.hcrFluidRefused,'Fermentation craft refused: '..name)
    local outputs=logic:getRecipeData():getAllCreatedItems();local result={}
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
local function migrate(kind,quality,dose,elapsed)
    local old=assert(instanceItem(kind));old:setFavorite(true);old:setName('Fermentation keepsake');old:setCustomName(true)
    old:getModData().fermentationProbe='preserved'
    HCRProcessQuality.write(old,{quality=quality,dose=dose,detection=4},1,nil)
    local now=getGameTime():getWorldAgeHours()
    old:getModData().StartTime=now-elapsed
    local new=assert(HCRItemMigrations.newReplacement(old),'Legacy migration '..kind)
    assert(new:isFavorite() and new:getModData().fermentationProbe=='preserved','Migration state')
    assert(new:getModData().HCRLegacyCustomName=='Fermentation keepsake','Migration name')
    near(HCRProcessQuality.read(old).dose,dose,'Original legacy untouched')
    assert(not HCRItemMigrations.newReplacement(new),'Migration repeated')
    near(L.budget(raw(new),'poisonPower'),dose,'Legacy dose')
    assert(L.quality(raw(new))==quality,'Legacy quality')
    new:setFavorite(false)
    return new
end
function M.run(player)
    assert(player and not isClient() and not isServer(),'Disposable offline HCRLab only')
    local now=getGameTime():getWorldAgeHours()
    local n=0
    for kind,stage in pairs(B.stages) do
        if getScriptManager():FindItem(kind) then
        for _,quality in ipairs({'fresh','stale','rotten'}) do
            for _,elapsed in ipairs({0,400,800}) do
                local item=migrate(kind,quality,.875,elapsed)
                local clock=HCRFermentationClock.new(kind,now-elapsed,now,true)
                assert(raw(item).lots[1].fluid==B.stages[clock.kind].marker,'Legacy stage catch-up')
                near(Q.rawAmount(Q.fluid(item)),20,'Legacy cask litres');n=n+1
            end
        end
        end
    end
    for _,kind in ipairs({'Hydrocraft.HCWoodenbucketgrape','Hydrocraft.HCWoodenbucketgrapegreen'}) do
        local item=migrate(kind,'rotten',.875,800)
        near(Q.rawAmount(Q.fluid(item)),4,'Legacy bucket litres')
        near(L.budget(raw(item),'calories'),0,'No invented legacy fruit nutrition')
    end
    local empty=assert(HCRItemMigrations.newReplacement(instanceItem('Hydrocraft.HCWoodenbarrel')))
    assert(Q.fluid(empty):isEmpty() and Q.fluid(empty):getCapacity()==20,'Empty cask migration')
    print('[HCRFermentRecipes] PASS '..n..' old casks, 2 juice buckets, empty cask')
    for _,manual in ipairs({true,false}) do for _,white in ipairs({false,true}) do
        local holder=player:getInventory():AddItem('Base.Bag_Schoolbag');local inv=holder:getItemContainer()
        local bucket=inv:AddItem('Hydrocraft.HCWoodenbucketFluid');local bucketId=bucket:getID()
        local juicer=inv:AddItem('Hydrocraft.HCJuicer');local grapes={}
        for i=1,16 do
            local item=inv:AddItem(white and 'Hydrocraft.HCGrapesgreen' or 'Base.Grapes')
            item:setAge(0);item:setCalories(i);F.store(item,.125)
            if i==1 then F.setQuality(item,'rotten') end
            grapes[#grapes+1]=item
        end
        local name='Juice Grapes Into Wooden Bucket'..(white and ' (Wooden Bucket with White Grape Juice)' or '')
        local out=craft(player,inv,name,{{bucket},grapes,{juicer}},manual)
        assert(#out==0 and bucket:getContainer()==inv and bucket:getID()==bucketId,'Juice vessel identity')
        near(Q.rawAmount(Q.fluid(bucket)),4,'Juice output');near(L.budget(raw(bucket),'calories'),136,'Fruit calories')
        near(L.budget(raw(bucket),'poisonPower'),2,'Fruit poison');assert(L.quality(raw(bucket))=='rotten')
        for _,item in ipairs(grapes) do assert(not item:getContainer(),'Whole grape survived') end
        local buckets={bucket}
        for i=2,5 do
            local old=migrate('Hydrocraft.HCWoodenbucketgrape'..(white and 'green' or ''),'fresh',.25,0)
            inv:AddItem(old);buckets[#buckets+1]=old
        end
        local cask=inv:AddItem('Hydrocraft.HCWoodenbarrelFluid');local yeast=inv:AddItem('Base.Yeast');local caskId=cask:getID()
        local yeastUses=yeast:getCurrentUses()
        name='Prepare Wine Barrels'..(white and ' (Barrel of White Grape Juice)' or '')
        out=craft(player,inv,name,{{cask},buckets,{yeast}},manual)
        assert(#out==0 and cask:getID()==caskId and cask:getContainer()==inv,'Same cask after preparation')
        assert(yeast:getCurrentUses()==yeastUses-1,'One original yeast use not consumed')
        near(Q.rawAmount(Q.fluid(cask)),20,'Prepared cask litres');near(L.budget(raw(cask),'poisonPower'),3,'Prepared poison')
        assert(L.quality(raw(cask))=='rotten','Prepared freshness')
        for _,item in ipairs(buckets) do assert(item:getContainer()==inv and Q.fluid(item):isEmpty(),'Donor bucket lost/not empty') end
        local saved=raw(cask)
        for _,lot in ipairs(saved.lots) do lot.fermentation.startedAt=now-336;lot.fermentation.lastHour=now end
        Q.capture(cask,Q.fluid(cask))
        near(L.budget(raw(cask),'calories'),20*481,'Wine nutrition per litre')
        local bottles={}
        for i=1,20 do local item=inv:AddItem('Base.Wine');Q.fluid(item):setCanPlayerEmpty(true);Q.fluid(item):Empty();bottles[#bottles+1]=item end
        out=craft(player,inv,white and 'Fill Bottles with Wine (Variant)' or 'Fill Bottles with Wine',{{cask},bottles},manual)
        assert(#out==20 and cask:getContainer()==inv and cask:getID()==caskId and Q.fluid(cask):isEmpty(),'Bottling cask preserved')
        local total=0
        for _,item in ipairs(out) do
            local ledger=raw(item);total=total+L.budget(ledger,'poisonPower')
            near(Q.rawAmount(Q.fluid(item)),1,'Bottled litres');near(L.budget(ledger,'calories'),481,'Bottled calories')
            assert(L.quality(ledger)=='rotten' and not item:isSealed(),'Bottled quality/open vessel')
            for _,lot in ipairs(ledger.lots) do assert(not lot.fermentation.barrel,'Bottled clock not paused') end
        end
        near(total,3,'Bottled total poison')
        player:getInventory():Remove(holder)
        print('[HCRFermentRecipes] PASS '..(white and 'white' or 'red')..' juice -> cask -> native wine -> 20 bottles manual='..tostring(manual))
    end end
    for _,manual in ipairs({true,false}) do
        for _,route in ipairs({
            {'mead','Make Bottle of Mead','Base.Whiskey',356},
            {'sake','Make Bottle of Sake','Base.Whiskey',39},
            {'vinegar','Fill Vinegar Bottles with Vinegar','Hydrocraft.HCVinegarempty'},
            {'vinegar','Fill Whiskey Bottles with Vinegar','Base.Whiskey'},
        }) do
            local holder=player:getInventory():AddItem('Base.Bag_Schoolbag');local inv=holder:getItemContainer()
            local cask=migrate('Hydrocraft.HCBarrel'..route[1],'stale',.875,0);inv:AddItem(cask)
            if not route[4] then raw(cask).lots[1].food.tainted=true end
            local bottles={}
            for i=1,20 do
                local item=inv:AddItem(route[3]);local fluid=Q.fluid(item)
                if fluid then fluid:setCanPlayerEmpty(true);fluid:Empty() end
                bottles[#bottles+1]=item
            end
            local out=craft(player,inv,route[2],{{cask},bottles},manual)
            assert(#out==20 and cask:getContainer()==inv and Q.fluid(cask):isEmpty(),'Ready cask retained')
            local dose=0
            for _,item in ipairs(out) do
                if route[4] then
                    local ledger=raw(item);dose=dose+L.budget(ledger,'poisonPower')
                    near(L.budget(ledger,'calories'),route[4],'Mead/sake source nutrition')
                    assert(L.quality(ledger)=='stale' and not ledger.lots[1].fermentation.barrel,'Mead/sake clock/quality')
                else
                    assert(item:getFullType()=='Base.Vinegar2' and item:IsDrainable(),'Vinegar native recipe interface')
                    local state=HCRProcessQuality.read(item);dose=dose+state.dose
                    assert(state.quality=='stale' and state.tainted,'Vinegar quality/taint')
                end
            end
            near(dose,.875,'Ready bottled poison')
            if not route[4] then
                local definitions=getScriptManager():getAllEvolvedRecipes();local evolved
                for i=0,definitions:size()-1 do
                    if definitions:get(i):getFullResultItem()=='Base.Sandwich' then evolved=definitions:get(i);break end
                end
                local bread=player:getInventory():AddItem('Base.BreadSlices');bread:setAge(0)
                local action={recipe=assert(evolved),baseItem=bread,usedItem=out[1],character=player}
                assert(ISAddItemInRecipe.complete(action),'Native vinegar evolved recipe')
                assert(action.baseItem:isTainted(),'Evolved recipe cleared vinegar taint')
                assert(HCRProcessQuality.read(out[1]).tainted,'Remaining vinegar cleared taint')
                near(F.dose(action.baseItem),.875/200,'Evolved vinegar exact dose')
                player:getInventory():Remove(action.baseItem)
            end
            player:getInventory():Remove(holder)
            print('[HCRFermentRecipes] PASS '..route[2]..' manual='..tostring(manual))
        end
    end
    print('[HCRFermentRecipes] ALL PASS')
end
if not HCRLabFermentRecipeWatch then
    HCRLabFermentRecipeWatch=true
    local tick,last=0,nil
    Events.OnTick.Add(function()
        if isClient() or isServer() then return end
        tick=tick+1;if tick%60~=0 then return end
        local reader=getFileReader('HCRLabFermentRecipeCommand.txt',false);if not reader then return end
        local line=reader:readLine();reader:close();if not line or line==last then return end
        last=line
        if line:match('^%d+:run$') then
            local ok,why=pcall(HCRLabFermentationRecipes.run,getSpecificPlayer(0))
            print('[HCRFermentRecipes] '..line..' '..(ok and 'PASS' or 'FAIL '..tostring(why)))
        end
    end)
end
