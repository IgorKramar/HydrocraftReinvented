-- Только отдельный профиль HCRLab: native крафт, брожение, уксус и питьё.
require "HCR_WineQuality"
require "HCR_ProcessActions"
require "TimedActions/ISGrabItemAction"
HCRLabWine={}
local Q,L,F,P=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRProcessQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..": "..tostring(a).." != "..tostring(b)) end
local function collect(player,item,inv)
    if item:getWorldItem() then
        local world=item:getWorldItem()
        ISGrabItemAction.transferItem({item=world,character=player,destContainer=inv,transactionId=0},world)
    elseif item:getContainer()~=inv then
        if item:getContainer() then item:getContainer():Remove(item) end
        inv:AddItem(item)
    end
end
local function craft(player,inv,name,slots,manual)
    local recipe=HCRLabCraft.findRecipe(name);player:learnRecipe(recipe:getName())
    local logic=HandcraftLogic.new(player,nil,nil)
    local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
    logic:updateFloorContainer(containers)
    if manual then
        logic:clearManualInputs()
        for slot,items in ipairs(slots) do
            local selected=ArrayList.new();for _,item in ipairs(items) do selected:add(item) end
            assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected),"Manual wine selection "..name.." slot="..slot)
        end
    end
    print("[HCRWine160] craft "..name.." native="..tostring(logic:getRecipeData():canConsumeInputs(logic:getSourceResources())))
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    assert(not action.hcrFluidRefused,"Wine action refused: "..name)
    local result={};local created=logic:getRecipeData():getAllCreatedItems()
    assert(created:size()>0,"No wine output: "..name)
    for i=0,created:size()-1 do result[#result+1]=created:get(i);collect(player,created:get(i),inv) end
    return result
end
local function bag(player)
    local item=player:getInventory():AddItem("Base.Bag_Schoolbag")
    item:setName("HCRLab: wine test")
    return item,item:getItemContainer()
end
local function add(inv,kind,count,empty)
    local items={}
    for i=1,count do
        items[i]=inv:AddItem(kind)
        if empty then Q.fluid(items[i]):Empty() end
    end
    return items
end
local function process(item,state,dose)
    P.write(item,{quality=state,dose=dose,detection=6},1,nil)
end
local function grapeCases(player)
    for _,manual in ipairs({true,false}) do
    for _,colour in ipairs({"red","white"}) do
        local holder,inv=bag(player)
        local grapes=add(inv,colour=="red" and "Base.Grapes" or "Hydrocraft.HCGrapesgreen",16)
        for _,item in ipairs(grapes) do F.setQuality(item,"rotten");F.store(item,.125) end
        local bucket=inv:AddItem("Hydrocraft.HCWoodenbucketFluid")
        local juicer=inv:AddItem("Hydrocraft.HCJuicer")
        local name="Juice Grapes Into Wooden Bucket"..(colour=="red" and "" or " (Wooden Bucket with White Grape Juice)")
        local output=craft(player,inv,name,{{bucket},grapes,{juicer}},manual)[1]
        near(P.read(output).dose,2,"Pressed grape dose");assert(P.read(output).quality=="rotten")
        local buckets={output}
        for i=2,5 do buckets[i]=inv:AddItem(output:getFullType());process(buckets[i],"fresh",.25) end
        local barrel=inv:AddItem("Hydrocraft.HCWoodenbarrel")
        local yeast=inv:AddItem("Base.Yeast")
        name="Prepare Wine Barrels"..(colour=="red" and "" or " (Barrel of White Grape Juice)")
        local result=craft(player,inv,name,{{barrel},buckets,{yeast}},manual)[1]
        near(P.read(result).dose,3,"Barrel grape dose");assert(P.read(result).quality=="rotten")
        assert(result:getModData().HCRTimedStart,"New fermentation clock missing")
        for _,item in ipairs(grapes) do assert(not item:getContainer(),"Grape survived whole input") end
        for _,item in ipairs(buckets) do assert(not item:getContainer(),"Grape bucket survived") end
        player:getInventory():Remove(holder)
    end end
    print("[HCRWine160] red/white whole-grape pressing and five-bucket barrels, manual/auto PASS")
end
local function brewCases(player)
    for _,manual in ipairs({true,false}) do
    for _,kind in ipairs({"Honey Brew","Rice Mash"}) do
        local holder,inv=bag(player)
        local pots=add(inv,kind=="Honey Brew" and "Hydrocraft.HCPotofhoneybrewcooked" or "Hydrocraft.HCPotofricemashcooked",3)
        for _,item in ipairs(pots) do F.setQuality(item,"rotten");F.store(item,.875) end
        local barrel=inv:AddItem("Hydrocraft.HCWoodenbarrel")
        local before=player:getInventory():getCountTypeRecurse("Pot")
        local output=craft(player,inv,"Fill Barrel with "..kind,{{barrel},pots},manual)[1]
        near(P.read(output).dose,2.625,"Three whole cooked pots dose")
        assert(P.read(output).quality=="rotten")
        for _,item in ipairs(pots) do assert(not item:getContainer(),"Cooked pot not wholly consumed") end
        near(player:getInventory():getCountTypeRecurse("Pot")-before,3,"Returned three pots")
        player:getInventory():Remove(holder)
    end end
    print("[HCRWine160] honey/rice whole pots and exactly three empty returns PASS")
end
local function bottlingCases(player)
    local routes={
        {"grape","wine","Fill Bottles with Wine","Base.Wine","Base.Wine2"},
        {"grapegreen","winewhite","Fill Bottles with Wine (Variant)","Base.Wine","Base.Wine"},
        {"honey","mead","Make Bottle of Mead","Base.Whiskey","Base.Whiskey",356,"HCRMead"},
        {"rice","sake","Make Bottle of Sake","Base.Whiskey","Base.Whiskey",39,"HCRSake"},
    }
    for _,manual in ipairs({true,false}) do
    for _,state in ipairs({"fresh","stale","rotten"}) do
    for _,route in ipairs(routes) do
        local holder,inv=bag(player)
        local source=inv:AddItem("Hydrocraft.HCBarrel"..route[1]);source:setFavorite(true)
        process(source,state,3.25)
        local now=getGameTime():getWorldAgeHours()
        source:getModData().HCRTimedStart=now-336
        HCRTimed.updateContainer(inv,now,0)
        local barrel=inv:getFirstTypeRecurse("HCBarrel"..route[2])
        assert(barrel and barrel:isFavorite() and not source:getContainer(),"Native fermentation replacement")
        barrel:setFavorite(false) -- Native рецепты не тратят избранные ингредиенты.
        assert(P.read(barrel).quality==state);near(P.read(barrel).dose,3.25,"Fermented poison")
        local empty=add(inv,route[4],20,true)
        local before=player:getInventory():getCountTypeRecurse("HCWoodenbarrel")
        local bottles=craft(player,inv,route[3],{{barrel},empty},manual)
        assert(#bottles==20 and not barrel:getContainer(),"Bottling batch mismatch")
        near(player:getInventory():getCountTypeRecurse("HCWoodenbarrel")-before,1,"One empty barrel")
        local total=0
        for _,item in ipairs(bottles) do
            assert(item:getFullType()==route[5])
            if item:IsFood() then total=total+F.dose(item);assert(F.quality(item)==state)
            else
                local fluid=Q.fluid(item);near(Q.rawAmount(fluid),1,"Bottled litres")
                assert(not item:isSealed(),"Crafted bottle unexpectedly sealed")
                local ledger=Q.capture(item,fluid).ledger
                total=total+L.budget(ledger,"poisonPower");assert(L.quality(ledger)==state)
                near(L.budget(ledger,"calories"),route[6] or 481,"Bottled wine/mead/sake calories")
                near(L.budget(ledger,"nativeAlcohol"),route[6] and 0 or .12,"Bottled wine/mead/sake native alcohol")
                if route[7] then
                    near(fluid:getSpecificFluidAmount(Fluid.Get(route[7])),1,"Brewed alcohol identity")
                    local food=ledger.lots[1].food
                    assert(food.alcoholic and food.alcoholPower==2 and not food.canBeFrozen)
                    near(food.hungChange,-.2,"Brewed alcohol hunger");near(food.baseHunger,-.2,"Brewed alcohol baseline")
                end
            end
        end
        near(total,3.25,"Twenty-bottle poison conservation")
        if route[1]=="grape" then
            local glasses=add(inv,"Hydrocraft.HCWineglass",4)
            local output=craft(player,inv,"Pour Wine (Glass of Red Wine)",{glasses,{bottles[1]}},manual)
            local dose,alcohol,calories=0,0,0
            for _,item in ipairs(output) do
                local ledger=Q.capture(item,Q.fluid(item)).ledger
                dose=dose+L.budget(ledger,"poisonPower");assert(L.quality(ledger)==state)
                alcohol=alcohol+L.budget(ledger,"nativeAlcohol")
                calories=calories+L.budget(ledger,"calories")
                near(Q.rawAmount(Q.fluid(item)),.25,"Glass volume")
            end
            near(dose,3.25/20,"Four glasses exact dose")
            near(alcohol,.12,"Four glasses exact alcohol");near(calories,481,"Four glasses exact calories")
            assert(Q.fluid(bottles[1]):isEmpty() and inv:contains(bottles[1]),"Wine donor lost")
        end
        player:getInventory():Remove(holder)
    end end end
    print("[HCRWine160] 24 native fermentation/bottling batches, 20 bottles, quality, dose, glass pours PASS")
end
local function vinegarCases(player)
    local evolved;local definitions=getScriptManager():getAllEvolvedRecipes()
    for i=0,definitions:size()-1 do
        if definitions:get(i):getFullResultItem()=="Base.Sandwich" then evolved=definitions:get(i);break end
    end
    assert(evolved)
    for _,manual in ipairs({true,false}) do
    for _,ready in ipairs({"wine","winewhite","mead","sake"}) do
        local holder,inv=bag(player)
        local barrel=inv:AddItem("Hydrocraft.HCBarrel"..ready);process(barrel,"rotten",3.25)
        local now=getGameTime():getWorldAgeHours();barrel:getModData().HCRTimedStart=now-336
        HCRTimed.updateContainer(inv,now,0)
        barrel=inv:getFirstTypeRecurse("HCBarrelvinegar");assert(barrel)
        local empty=add(inv,"Hydrocraft.HCVinegarempty",20)
        local bottles=craft(player,inv,"Fill Vinegar Bottles with Vinegar",{{barrel},empty},manual)
        local total=0
        for _,item in ipairs(bottles) do total=total+P.read(item).dose;assert(P.read(item).quality=="rotten") end
        near(total,3.25,"Vinegar bottles dose")
        local source=bottles[1]
        source:setCurrentUses(7);process(source,"rotten",.875)
        local bread=player:getInventory():AddItem("Base.BreadSlices");bread:setAge(0);F.store(bread,.375)
        local action={recipe=evolved,baseItem=bread,usedItem=source,character=player}
        assert(ISAddItemInRecipe.complete(action))
        local sandwich=action.baseItem;collect(player,sandwich,inv)
        near(source:getCurrentUses(),6,"Evolved vinegar one use")
        near(F.dose(sandwich),.5,"Evolved vinegar exact dose")
        near(P.read(source).dose,.75,"Evolved vinegar remainder")
        assert(F.quality(sandwich)=="rotten")
        assert(ISAddItemInRecipe.complete(action)) -- Повторная специя ничего не тратит.
        near(source:getCurrentUses(),6,"Repeated spice uses");near(F.dose(sandwich),.5,"Repeated spice dose")
        player:getInventory():Remove(holder)
    end end
    print("[HCRWine160] four native vinegar transitions, bottling, partial/repeated evolved spice PASS")
end
local function drinkCase(player)
    local holder,inv=bag(player)
    local native=inv:AddItem("Base.Wine2");Q.fluid(native):unseal()
    local tracked=inv:AddItem("Base.Wine2")
    local fluid=Q.fluid(tracked)
    local food=HCRWineQuality.snapshot(fluid,{quality="fresh",dose=0},1)
    fluid:unseal();fluid:Empty();fluid:addFluid("HCRWineRed",1)
    Q.store(tracked,fluid,L.batch("HCRWineRed",1,food,getGameTime():getWorldAgeHours()))
    local stats,body,nutrition=player:getStats(),player:getBodyDamage(),player:getNutrition()
    local function drink(item)
        collect(player,item,player:getInventory())
        for _,name in ipairs({"INTOXICATION","HUNGER","THIRST","BOREDOM","UNHAPPINESS","POISON"}) do stats:set(CharacterStat[name],name=="HUNGER" and .5 or 0) end
        nutrition:setCalories(0);body:setHealthFromFoodTimer(0)
        ISDrinkFluidAction:new(player,item,.25):updateEat(1)
        near(Q.rawAmount(Q.fluid(item)),.75,"Quarter wine sip volume")
        near(nutrition:getCalories(),120.25,"Quarter wine sip calories")
        local result={calories=nutrition:getCalories(),timer=body:getHealthFromFoodTimer()}
        for _,name in ipairs({"INTOXICATION","HUNGER","THIRST","BOREDOM","UNHAPPINESS","POISON"}) do result[name]=stats:get(CharacterStat[name]) end
        collect(player,item,inv)
        return result
    end
    local expected=drink(native);local actual=drink(tracked)
    for key,value in pairs(expected) do near(actual[key],value,"Native wine parity "..key) end
    local target=inv:AddItem("Base.WaterBottle");Q.fluid(target):Empty()
    local a,b=ISFluidContainer:new(fluid),ISFluidContainer:new(Q.fluid(target))
    Q.transfer(a,b,player,function() FluidContainer.Transfer(fluid,Q.fluid(target),.25) end)
    near(L.budget(Q.capture(target,Q.fluid(target)).ledger,"nativeAlcohol"),.03,"Poured wine alcohol")
    near(L.budget(Q.capture(tracked,fluid).ledger,"nativeAlcohol"),.06,"Remaining wine alcohol")
    player:getInventory():Remove(holder)
    stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.INTOXICATION,0)
    print("[HCRWine160] native DrinkFluid parity, quarter-sip and quarter-litre transfer PASS")
end
local function meadSakeMigration(player)
    for _,entry in ipairs({{"HCMead","HCRMead"},{"HCSake","HCRSake"}}) do
    for _,fraction in ipairs({.25,.5,.68,1}) do
        local source=instanceItem("Hydrocraft."..entry[1])
        source:setHungChange(source:getBaseHunger()*fraction)
        source:setCalories(123.5);source:setFavorite(true)
        F.setQuality(source,"rotten");F.store(source,.375)
        local target=assert(HCRItemMigrations.newReplacement(source),"Mead/sake migration refused")
        local fluid=Q.fluid(target);local ledger=Q.capture(target,fluid).ledger
        near(Q.rawAmount(fluid),fraction,"Mead/sake actual remaining volume")
        near(fluid:getSpecificFluidAmount(Fluid.Get(entry[2])),fraction,"Mead/sake native identity")
        near(L.budget(ledger,"calories"),123.5,"Mead/sake modified stock nutrition")
        near(L.budget(ledger,"poisonPower"),.375,"Mead/sake exact stock dose")
        assert(target:isFavorite() and L.quality(ledger)=="rotten" and not ledger.lots[1].food.canBeFrozen)
        near(source:getCalories(),123.5,"Source changed during migration plan")
        near(F.dose(source),.375,"Source dose changed during migration plan")
        assert(not HCRItemMigrations.newReplacement(target),"Mead/sake migrated twice")
    end end
    print("[HCRWine160] mead/sake migration: partial volume, modified nutrition, poison, freshness and idempotence PASS")
end
local function mixedGlassCases(player)
    for _,manual in ipairs({true,false}) do
    for _,mixture in ipairs({"native","mixed","diluted"}) do
        local holder,inv=bag(player)
        local source=inv:AddItem("Base.PopBottle");local fluid=Q.fluid(source);fluid:Empty()
        local native=instanceItem("Base.Wine2")
        local food=HCRWineQuality.snapshot(Q.fluid(native),{quality="fresh",dose=.875},1)
        if mixture~="native" then
            local ledger=L.batch("HCRWineRed",1,food,getGameTime():getWorldAgeHours())
            local _,portion=L.split(ledger,.6,1)
            fluid:addFluid("HCRWineRed",.6)
            fluid:addFluid(mixture=="diluted" and "Water" or "Wine",.4)
            Q.store(source,fluid,L.alignVolumes(portion,Q.amounts(fluid)))
        else fluid:addFluid("Wine",1) end
        local glasses=add(inv,"Hydrocraft.HCWineglassFluid",4)
        local output=craft(player,inv,"Pour Wine (Glass of Red Wine)",{glasses,{source}},manual)
        local calories,alcohol,dose,litres=0,0,0,0
        for _,item in ipairs(output) do
            local f=Q.fluid(item);local ledger=Q.capture(item,f).ledger
            calories=calories+L.budget(ledger,"calories");alcohol=alcohol+L.budget(ledger,"nativeAlcohol")
            dose=dose+L.budget(ledger,"poisonPower");litres=litres+Q.rawAmount(f)
        end
        near(litres,1,"Mixed wine glass litres")
        near(calories,481*(mixture=="diluted" and .6 or 1),"Mixed wine glass calories")
        near(alcohol,.12*(mixture=="diluted" and .6 or 1),"Mixed wine glass alcohol")
        near(dose,mixture=="native" and 0 or .875*.6,"Mixed wine glass poison")
        player:getInventory():Remove(holder)
    end end
    for _,kind in ipairs({"Hydrocraft.HCWineglassfull","Hydrocraft.HCWineglassfull2"}) do
        for _,fraction in ipairs({.25,.5,1}) do
            local source=instanceItem(kind);source:setHungChange(source:getBaseHunger()*fraction)
            source:setCalories(93);F.store(source,.875);F.setQuality(source,"rotten")
            local target=assert(HCRItemMigrations.newReplacement(source))
            local ledger=Q.capture(target,Q.fluid(target)).ledger
            near(Q.rawAmount(Q.fluid(target)),.25*fraction,"Old wine glass remaining volume")
            near(L.budget(ledger,"calories"),93,"Old wine glass actual nutrition")
            near(L.budget(ledger,"poisonPower"),.875,"Old wine glass actual poison")
            assert(L.quality(ledger)=="rotten" and ledger.lots[1].food.alcoholic,"Legacy wine properties")
        end
    end
    local old=instanceItem("Hydrocraft.HCWineglass")
    assert(Q.fluid(assert(HCRItemMigrations.newReplacement(old))):isEmpty())
    print("[HCRWine160] native/mixed/water-diluted wine glasses conserve calories, alcohol and dose; legacy glasses migrate PASS")
end
local function consolidationCases(player)
    local inv=player:getInventory()
    for _,kind in ipairs({"Base.Vinegar2","Hydrocraft.HCRennet"}) do
        local source=inv:AddItem(kind);local target=inv:AddItem(kind)
        local capacity=kind=="Base.Vinegar2" and 10 or 4
        source:setCurrentUses(capacity-1);target:setCurrentUses(1)
        process(source,"rotten",.875);process(target,"fresh",.125)
        local action=ISConsolidateDrainable:new(player,source,target,nil)
        local progress=.51;action.getJobDelta=function() return progress end
        action:update()
        near(source:getCurrentUses()+target:getCurrentUses(),capacity,"Interrupted consolidation uses")
        near(P.read(source).dose+P.read(target).dose,1,"Interrupted consolidation poison")
        assert(P.read(target).quality=="rotten")
        action:stop()
        local resume=ISConsolidateDrainable:new(player,source,target,nil)
        resume.getJobDelta=function() return progress end
        for i=1,10 do
            progress=i/10;resume:update()
            near(source:getCurrentUses()+target:getCurrentUses(),capacity,"Resumed consolidation uses")
            near(P.read(source).dose+P.read(target).dose,1,"Resumed consolidation poison")
        end
        assert(resume:complete())
        assert(not source:getContainer(),"Consolidated donor not removed")
        near(target:getCurrentUses(),capacity,"Consolidated target full")
        near(P.read(target).dose,1,"Consolidated target poison")
        inv:Remove(target)
    end
    print("[HCRWine160] native Drainable update/stop/resume/complete conserves integer uses, quality and poison PASS")
end
local function vinegarFoods(player)
    for _,manual in ipairs({true,false}) do
        local holder,inv=bag(player)
        local vinegar=inv:AddItem("Base.Vinegar2");vinegar:setCurrentUses(7);process(vinegar,"rotten",.875)
        local jar=inv:AddItem("Hydrocraft.HCClayjarsmall")
        local guts=inv:AddItem("Hydrocraft.HCIntestines");guts:setAge(0)
        local coal=inv:AddItem("Base.Charcoal");local fire=inv:AddItem("Base.Lighter")
        local pot=inv:AddItem("Hydrocraft.HCClaycauldronFluid")
        local rennet=craft(player,inv,"Make Rennet",{{jar},{guts},{vinegar},{coal},{fire},{pot}},manual)[1]
        near(P.read(rennet).dose,.125,"Vinegar to rennet poison");assert(P.read(rennet).quality=="rotten")
        near(P.read(vinegar).dose,.75,"Rennet remaining vinegar poison")
        rennet:setCurrentUses(1)
        local second=inv:AddItem("Hydrocraft.HCRennet");second:setCurrentUses(3);process(second,"stale",.375)
        local milk={}
        for i=1,4 do milk[i]=inv:AddItem("Hydrocraft.HCWoodenbucketFluid");Q.fluid(milk[i]):addFluid("CowMilk",4) end
        local vat=inv:AddItem("Hydrocraft.HCVatFluid")
        local result=craft(player,inv,"Fill Cheese Vat",{{rennet,second},milk,{vat}},manual)[1]
        near(P.read(result).dose,.5,"Two partial rennet sources dose");assert(P.read(result).quality=="rotten")
        assert(not rennet:getContainer() and not second:getContainer(),"Partial rennet bottles not consumed")
        player:getInventory():Remove(holder)
    end
    for _,manual in ipairs({true,false}) do
        local holder,inv=bag(player)
        local knife=inv:AddItem("Base.KitchenKnife");local jar=inv:AddItem("Base.EmptyJar")
        local lid=inv:AddItem("Base.JarLid");local veg=add(inv,"Base.BellPepper",6)
        for _,item in ipairs(veg) do item:setAge(0) end
        local vinegar=inv:AddItem("Base.Vinegar2");vinegar:setCurrentUses(7);process(vinegar,"rotten",.875)
        local salt=inv:AddItem("Base.Salt");local water=inv:AddItem("Base.WaterBottle")
        Q.fluid(water):Empty();Q.fluid(water):addFluid("Water",1)
        local canned=craft(player,inv,"MakeJar",{{knife},{jar},{lid},veg,{vinegar},{salt},{water}},manual)[1]
        near(F.dose(canned),.25,"Native jar poison");near(P.read(vinegar).dose,.625,"Native jar vinegar remainder")
        assert(F.quality(canned)=="rotten")
        canned:setHeat(2);canned:setCookingTime(canned:getMinutesToCook()+1);canned:update()
        F.reconcile(canned);assert(canned:isCooked() and F.quality(canned)=="rotten","Preserving revived spoiled jar")
        near(F.dose(canned),.25,"Native preserving poison")
        local opened=craft(player,inv,"OpenJarOfFood",{{canned}},manual)[1]
        near(F.dose(opened),.25,"Native opened jar poison");assert(F.quality(opened)=="rotten")
        player:getInventory():Remove(holder)
    end
    print("[HCRWine160] vinegar->rennet->cheese and native MakeJar->cook->OpenJar preserve worst quality and exact poison PASS")
end
function HCRLabWine.seed(player)
    local holder,inv=bag(player);holder:setName("HCRLab: wine save proof")
    holder:getModData().HCRWineSaveProof=true
    local wine=inv:AddItem("Base.Wine2");local fluid=Q.fluid(wine)
    local food=HCRWineQuality.snapshot(fluid,{quality="stale",dose=.875},1)
    fluid:unseal();fluid:Empty();fluid:addFluid("HCRWineRed",1)
    Q.store(wine,fluid,L.batch("HCRWineRed",1,food,getGameTime():getWorldAgeHours()))
    local vinegar=inv:AddItem("Base.Vinegar2");vinegar:setCurrentUses(7);process(vinegar,"stale",.625)
    local rennet=inv:AddItem("Hydrocraft.HCRennet");rennet:setCurrentUses(2);process(rennet,"rotten",.375)
    local barrel=inv:AddItem("Hydrocraft.HCBarrelgrape");process(barrel,"rotten",3.25)
    barrel:getModData().HCRTimedStart=getGameTime():getWorldAgeHours()-24
    holder:getModData().barrelStart=barrel:getModData().HCRTimedStart
    print("[HCRWine160] four save fixtures SEEDED; cold-load verification pending")
end
function HCRLabWine.verify(player)
    local items=player:getInventory():getItems();local count=0
    for i=0,items:size()-1 do
        local holder=items:get(i)
        if holder:getModData().HCRWineSaveProof then
            count=count+1;local inv=holder:getItemContainer()
            local wine=assert(inv:getFirstTypeRecurse("Wine2"));local ledger=Q.capture(wine,Q.fluid(wine)).ledger
            near(L.budget(ledger,"nativeAlcohol"),.12,"Saved wine alcohol")
            near(L.budget(ledger,"calories"),481,"Saved wine calories")
            near(L.budget(ledger,"poisonPower"),.875,"Saved wine poison");assert(L.quality(ledger)=="stale")
            local vinegar=assert(inv:getFirstTypeRecurse("Vinegar2"));near(vinegar:getCurrentUses(),7,"Saved vinegar uses")
            near(P.read(vinegar).dose,.625,"Saved vinegar poison");assert(P.read(vinegar).quality=="stale")
            local rennet=assert(inv:getFirstTypeRecurse("HCRennet"));near(rennet:getCurrentUses(),2,"Saved rennet uses")
            near(P.read(rennet).dose,.375,"Saved rennet poison");assert(P.read(rennet).quality=="rotten")
            local barrel=assert(inv:getFirstTypeRecurse("HCBarrelgrape"))
            near(barrel:getModData().HCRTimedStart,holder:getModData().barrelStart,"Saved fermentation clock")
            near(P.read(barrel).dose,3.25,"Saved barrel poison");assert(P.read(barrel).quality=="rotten")
        end
    end
    assert(count>0,"Missing wine save fixtures")
    print("[HCRWine160] persisted wine/Drainable quality, dose, uses, native alcohol and fermentation clock PASS")
end
function HCRLabWine.run(player,profile)
    assert(profile=="HCRLab" and not isClient() and not isServer())
    assert(HCRProcessActions,"Process action hooks need a cold boot")
    reloadLuaFile("media/lua/shared/HCR_WineQuality.lua")
    reloadLuaFile("media/lua/shared/HCR_FluidEffects.lua")
    HCRLabCraft.trainCooking(player,profile)
    local carry=player:isUnlimitedCarry();player:setUnlimitedCarry(true)
    local ok,reason=pcall(function()
        grapeCases(player);brewCases(player);bottlingCases(player);vinegarCases(player);drinkCase(player);mixedGlassCases(player)
        meadSakeMigration(player)
        consolidationCases(player);vinegarFoods(player)
    end)
    player:setUnlimitedCarry(carry)
    if not ok then error(reason) end
    print("[HCRWine160] ALL PASS")
end
