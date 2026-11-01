-- Частная проверка настоящих B42 рецептов молочной цепочки.
require "HCR_MilkChains"
require "HCR_ProcessQuality"
require "TimedActions/ISGrabItemAction"
HCRLabMilkChains={}
local function near(a,b,label) assert(math.abs(a-b)<.001,label..": "..tostring(a).." != "..tostring(b)) end
local function collect(player,item,inv)
    local world=item:getWorldItem()
    if world then
        ISGrabItemAction.transferItem({item=world,character=player,destContainer=inv,transactionId=0},world)
    elseif item:getContainer()~=inv then
        if item:getContainer() then item:getContainer():Remove(item) end
        inv:AddItem(item)
    end
end
local function craft(player,inv,name,slots,manual,refused)
    local recipe=HCRLabCraft.findRecipe(name)
    player:learnRecipe(recipe:getName())
    local logic=HandcraftLogic.new(player,nil,nil)
    local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
    logic:updateFloorContainer(containers)
    if manual then
        local ground=false
        for _,items in ipairs(slots) do for _,item in ipairs(items) do ground=ground or item:getWorldItem()~=nil end end
        local restore
        if ground then
            -- Проверяем исполнение manual ground recipe отдельно от UI:
            -- vanilla setManualInputsFor тоже ожидает item-owned FC.
            logic:updateFloorContainer(containers)
            restore=HCRFluidCrafting.borrowWorldFluids(logic)
        end
        logic:clearManualInputs()
        for slot,items in ipairs(slots) do
            local selected=ArrayList.new()
            for _,item in ipairs(items) do selected:add(item) end
            assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected),"Manual milk selection "..name)
        end
        if restore then restore() end
    end
    print("[HCRMilk160] craft "..name.." native="..tostring(logic:getRecipeData():canConsumeInputs(logic:getSourceResources())).." gate="..tostring(HCRFluidCrafting.check(logic)))
    if not manual and name=="Fill Wooden Bucket with Milk" then
        local candidates=logic:getAllItems()
        for i=0,candidates:size()-1 do
            local item=candidates:get(i);local f=HCRFluidQuality.fluid(item)
            if f then print("[HCRMilk160] candidate "..item:getFullType().." world="..tostring(item:getWorldItem()~=nil).." ownFC="..tostring(item:getFluidContainer()~=nil).." litres="..HCRFluidQuality.rawAmount(f)) end
        end
    end
    local action={logic=logic,character=player}
    ISHandcraftAction.performRecipe(action)
    if refused then
        assert(action.hcrFluidRefused,"Unsafe milk action was not refused: "..name)
        assert(logic:getRecipeData():getAllCreatedItems():size()==0,"Refused milk action created outputs")
        return {}
    end
    assert(not action.hcrFluidRefused,"Milk action refused: "..name)
    local output={};local native=logic:getRecipeData():getAllCreatedItems()
    for i=0,native:size()-1 do
        local item=native:get(i)
        output[#output+1]=item;collect(player,item,inv)
    end
    return output
end
local function bucket(inv,fluid,calories,poison,state)
    local Q,L,E,F=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
    local item=inv:AddItem("Hydrocraft.HCWoodenbucketFluid")
    local f=Q.fluid(item);f:Empty();f:addFluid(fluid,4)
    if Q.transport[fluid] then
        local sample=instanceItem("Hydrocraft.HCWoodenbucketmilk")
        sample:setCalories(calories or 220);sample:setAge(0)
        F.store(sample,poison or 0);F.setQuality(sample,state or "fresh")
        Q.store(item,f,L.batch(fluid,4,E.snapshot(sample),getGameTime():getWorldAgeHours()))
    end
    return item
end
local function runCases(player,profile)
    assert(profile=="HCRLab" and not isClient() and not isServer())
    getGameTime():setTimeOfDay(12.25)
    HCRLabCraft.trainCooking(player,profile)
    local Q,L,F,P=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRProcessQuality
    for kind,spec in pairs(HCRMilkFamilies) do
        for _,fraction in ipairs(spec.normalStage and {1} or {.25,.5,.68,1}) do
            local source=instanceItem(kind)
            source:setFavorite(true);source:getModData().milkMigrationProof=true
            if not spec.normalStage then
                source:setHungChange(source:getBaseHunger()*fraction)
                source:setAge(9);source:setCalories(137);F.store(source,.875)
            end
            local target=assert(HCRItemMigrations.newReplacement(source),kind)
            local ledger=Q.capture(target,Q.fluid(target)).ledger
            near(Q.rawAmount(Q.fluid(target)),spec.litres*fraction,"Legacy milk migration litres")
            near(L.budget(ledger,"calories"),spec.normalStage and 0 or 137,"Legacy milk migration current nutrition")
            near(L.budget(ledger,"poisonPower"),spec.normalStage and 0 or .875,"Legacy milk migration exact poison")
            if not spec.normalStage then
                near(ledger.lots[1].age,source:getAge(),"Legacy milk age")
                assert(ledger.lots[1].food.canBeFrozen==source:canBeFrozen(),"Legacy milk freeze policy")
            end
            assert(target:isFavorite() and target:getModData().milkMigrationProof)
            assert(not HCRItemMigrations.newReplacement(target),"Repeated milk migration")
        end
    end
    print("[HCRMilk160] legacy Food remaining volumes and two Normal stages: migration identity, nutrition and exact poison PASS")
    for _,manual in ipairs({true,false}) do
    for _,state in ipairs({"fresh","stale","rotten"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local milk=bucket(inv,"HCRMilk",1234,3.25,state)
        local id=milk:getID();milk:setFavorite(true)
        local cauldron=inv:AddItem("Hydrocraft.HCClaycauldronFluid")
        local fuel=inv:AddItem("Base.Charcoal");local fire=inv:AddItem("Base.Lighter")
        craft(player,inv,"Heat Milk",{{milk},{cauldron},{fuel},{fire}},manual)
        near(Q.fluid(milk):getSpecificFluidAmount(Fluid.Get("HCRMilkHeated")),4,"heated milk volume")
        assert(milk:getID()==id and milk:isFavorite(),"Milk bucket replaced")
        local stem=inv:AddItem("Hydrocraft.HCChilipepperstem")
        craft(player,inv,"Ferment Milk",{{milk},{stem}},manual)
        near(Q.fluid(milk):getSpecificFluidAmount(Fluid.Get("HCRMilkFermented")),4,"cultured milk volume")
        local ledger=Q.capture(milk,Q.fluid(milk)).ledger
        near(L.budget(ledger,"calories"),1234,"processing nutrition")
        near(L.budget(ledger,"poisonPower"),3.25,"processing exact poison")
        assert(L.quality(ledger)==state,"Milk processing cleared freshness")
        local jars={};for i=1,4 do jars[i]=inv:AddItem("Hydrocraft.HCJar") end
        local result=craft(player,inv,"Jar Homemade Yogurt",{{milk},jars},manual)
        assert(#result==4,"Yogurt output count")
        local dose=0
        for _,food in ipairs(result) do dose=dose+F.dose(food);assert(F.quality(food)==state) end
        near(dose,3.25,"Yogurt exact poison");near(Q.rawAmount(Q.fluid(milk)),0,"Yogurt empties kept bucket")
        assert(milk:getContainer()==inv,"Yogurt destroyed bucket")
        player:getInventory():Remove(bag)
    end
    end
    print("[HCRMilk160] manual/auto x fresh/stale/rotten: milk -> heat -> culture -> yogurt, same bucket, nutrition and exact poison PASS")
    for _,kind in ipairs({"CowMilk","SheepMilk","AnimalMilk"}) do
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,kind)
        local calories=Q.fluid(source):getProperties():getCalories()
        local target=inv:AddItem("Hydrocraft.HCWoodenbucketFluid")
        craft(player,inv,"Fill Wooden Bucket with Milk",{{target},{source}},manual)
        near(Q.rawAmount(Q.fluid(source)),0,"native milk consumed volume")
        near(Q.rawAmount(Q.fluid(target)),4,"native milk filled volume")
        near(L.budget(Q.capture(target,Q.fluid(target)).ledger,"calories"),calories,"native milk ingress calories")
        local cartons={};for i=1,4 do cartons[i]=inv:AddItem("Hydrocraft.HCMilkempty") end
        local results=craft(player,inv,"Bottle Milk",{{target},cartons},manual)
        assert(#results==4,"Milk carton count")
        local actual=0
        for _,item in ipairs(results) do
            near(Q.rawAmount(Q.fluid(item)),1,"Milk carton volume")
            actual=actual+L.budget(Q.capture(item,Q.fluid(item)).ledger,"calories")
        end
        near(actual,calories,"Milk bottling nutrition")
        player:getInventory():Remove(bag)
    end
    end
    print("[HCRMilk160] 3 native milk fluids x manual/auto: fill4L -> four1L cartons, exact native calories PASS")
    for _,name in ipairs({"Pour into Carton","Dilute Evaporated Milk"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=inv:AddItem(name=="Pour into Carton" and "Hydrocraft.HCMilkjug" or "Hydrocraft.HCEvaporatedmilkopen")
        source:setCalories(800);F.store(source,3.25);F.setQuality(source,"rotten")
        if name=="Pour into Carton" then
            local replacement=assert(HCRItemMigrations.newReplacement(source))
            inv:Remove(source);source=inv:AddItem(replacement)
        end
        local carton=inv:AddItem("Hydrocraft.HCMilkempty")
        local slots={{source},{carton}}
        if name=="Dilute Evaporated Milk" then
            local water=inv:AddItem("Base.WaterBottle");Q.fluid(water):Empty();Q.fluid(water):addFluid(Fluid.Water,1)
            slots={{source},{water},{carton}}
        end
        local result=craft(player,inv,name,slots,true)
        assert(#result==(name=="Dilute Evaporated Milk" and 2 or 1),"Legacy milk recipe output")
        local cartonOutput
        for _,item in ipairs(result) do if item:getFullType()=="Base.Milk" then assert(not cartonOutput);cartonOutput=item end end
        local ledger=Q.capture(assert(cartonOutput),Q.fluid(cartonOutput)).ledger
        local fraction=name=="Pour into Carton" and .5 or 1
        near(L.budget(ledger,"calories"),800*fraction,"Legacy milk current nutrition")
        near(L.budget(ledger,"poisonPower"),3.25*fraction,"Legacy milk exact poison")
        assert(L.quality(ledger)=="rotten","Legacy milk freshness reset")
        if fraction<1 then near(L.budget(Q.capture(source,Q.fluid(source)).ledger,"poisonPower"),1.625,"Migrated jug remaining poison") end
        player:getInventory():Remove(bag)
    end
    print("[HCRMilk160] legacy jug partial1L and whole evaporated concentrate+.7L, quality preserved PASS")
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local a=inv:AddItem("Hydrocraft.HCMilkjug");local b=inv:AddItem("Hydrocraft.HCMilkjug")
        a:setCurrentUses(5);a:setCalories(123);F.store(a,.75);F.setQuality(a,"stale")
        b:setCurrentUses(5);b:setCalories(234);F.store(b,1.5);F.setQuality(b,"rotten")
        assert(a:getCurrentUses()==5 and b:getCurrentUses()==5,"Partial jug test setup")
        local oldA,oldB=a,b
        a=assert(HCRItemMigrations.newReplacement(oldA));b=assert(HCRItemMigrations.newReplacement(oldB))
        inv:Remove(oldA);inv:Remove(oldB);inv:AddItem(a);inv:AddItem(b)
        local carton=inv:AddItem("Hydrocraft.HCMilkempty")
        local result=craft(player,inv,"Pour into Carton",{{a,b},{carton}},manual)
        assert(#result==1,"Combined partial jugs output")
        local ledger=Q.capture(result[1],Q.fluid(result[1])).ledger
        near(L.budget(ledger,"calories"),357,"Combined partial jug nutrition")
        near(L.budget(ledger,"poisonPower"),2.25,"Combined partial jug dose")
        assert(L.quality(ledger)=="rotten","Combined partial jug worst freshness")
        player:getInventory():Remove(bag)
    end
    print("[HCRMilk160] manual/auto two partially used jugs -> 1L carton, combined nutrition, exact poison and worst freshness PASS")
    for _,kind in ipairs({"CowMilk","HCRMilk"}) do
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,kind,999,1.75,"stale")
        local expected=Q.fluid(source):getProperties():getCalories()
        if kind=="HCRMilk" then expected=999 end
        inv:Remove(source);player:getSquare():AddWorldInventoryItem(source,.4,.4,0)
        local world=source:getWorldItem();local component=world:getFluidContainer()
        assert(component and not source:getFluidContainer(),"Ground milk test setup")
        local target=inv:AddItem("Hydrocraft.HCWoodenbucketFluid")
        craft(player,inv,"Fill Wooden Bucket with Milk",{{target},{source}},manual)
        assert(source:getWorldItem()==world and world:getFluidContainer()==component and not source:getFluidContainer(),"Ground source FC owner changed")
        near(Q.rawAmount(component),0,"Ground milk consumed")
        local ledger=Q.capture(target,Q.fluid(target)).ledger
        near(L.budget(ledger,"calories"),expected,"Ground milk exact nutrition")
        if kind=="HCRMilk" then
            near(L.budget(ledger,"poisonPower"),1.75,"Ground milk exact dose")
            assert(L.quality(ledger)=="stale")
        end
        collect(player,source,inv);player:getInventory():Remove(bag)
    end
    end
    print("[HCRMilk160] native/tracked ground milk x manual/auto, original world component restored, contents and quality conserved PASS")
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,"CowMilk");local fluid=Q.fluid(source)
        fluid:Empty();fluid:addFluid("CowMilk",3);fluid:addFluid("TaintedWater",1)
        local target=inv:AddItem("Hydrocraft.HCWoodenbucketFluid")
        craft(player,inv,"Fill Wooden Bucket with Milk",{{target},{source}},manual,true)
        near(Q.rawAmount(fluid),4,"Mixed milk refused before consumption")
        near(Q.rawAmount(Q.fluid(target)),0,"Mixed milk refused before fill")
        player:getInventory():Remove(bag)
    end
    print("[HCRMilk160] native milk+TaintedWater x manual/auto: refused before any mutation PASS")
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local sources={}
        for n=1,2 do
            local source=inv:AddItem("Hydrocraft.HCWoodenbucketFluid");local fluid=Q.fluid(source)
            fluid:Empty();fluid:addFluid("HCRMilk",2)
            local ledger=L.empty()
            for i=1,80 do ledger=L.mix(ledger,L.batch("HCRMilk",.025,{calories=n*100+i},getGameTime():getWorldAgeHours())) end
            Q.store(source,fluid,L.alignVolumes(ledger,Q.amounts(fluid)));sources[n]=source
        end
        local target=inv:AddItem("Hydrocraft.HCWoodenbucketFluid")
        craft(player,inv,"Fill Wooden Bucket with Milk",{{target},sources},manual,true)
        near(Q.rawAmount(Q.fluid(target)),0,"Over-limit milk refused before fill")
        for _,source in ipairs(sources) do
            near(Q.rawAmount(Q.fluid(source)),2,"Over-limit milk refused before debit")
            assert(#Q.capture(source,Q.fluid(source)).ledger.lots==80)
        end
        player:getInventory():Remove(bag)
    end
    print("[HCRMilk160] two legal80-lot sources x manual/auto: merge limit refused BEFORE consumption/output PASS")
end

local function runCheeseCases(player,profile)
    local Q,L,F,P=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRProcessQuality
    local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
    local milk={};for i=1,4 do milk[i]=bucket(inv,"HCRMilk",220,.875,"rotten") end
    local rennet=inv:AddItem("Hydrocraft.HCRennet");local vat=inv:AddItem("Hydrocraft.HCVatFluid")
    local full=craft(player,inv,"Fill Cheese Vat",{{rennet},milk,{vat}},true)
    assert(#full==1,"Cheese vat output");near(P.read(full[1]).dose,3.5,"Cheese vat poison")
    local curds=craft(player,inv,"Harvest Cheese Curds",{{full[1]}},true)
    assert(#curds==16,"Cheese curds count")
    local trays={}
    for i=1,4 do
        local tray=inv:AddItem("Hydrocraft.HCCheesetray")
        trays[i]=craft(player,inv,"Fill Cheese Trays",{{curds[(i-1)*4+1],curds[(i-1)*4+2],curds[(i-1)*4+3],curds[(i-1)*4+4]},{tray}},true)[1]
    end
    local rack=inv:AddItem("Hydrocraft.HCCheeserack")
    local fullrack=craft(player,inv,"Put Cheese on Rack",{trays,{rack}},true)[1]
    near(P.read(fullrack).dose,3.5,"Cheese rack poison")
    assert(P.read(fullrack).quality=="rotten","Cheese rack cleared spoilage")
    -- Native timer successor копирует modData; переход времени проверяется
    -- отдельно без семидневного перематывания всего private мира.
    local target=HCRTimed.resolve(fullrack:getFullType(),0,168)
    assert(target=="Hydrocraft.HCCheeserackaged")
    local aged=inv:AddItem(target)
    for key,value in pairs(fullrack:getModData()) do aged:getModData()[key]=value end
    inv:Remove(fullrack)
    local wheels=craft(player,inv,"Remove Cheese from Rack",{{aged}},true)
    assert(#wheels==4,"Cheese wheel count")
    local total=0
    for _,wheel in ipairs(wheels) do total=total+F.dose(wheel);assert(F.quality(wheel)=="rotten") end
    near(total,3.5,"Cheese complete chain exact poison")
    player:getInventory():Remove(bag)
    print("[HCRMilk160] 16L milk -> vat -> 16curds -> 4trays -> rack -> 4wheels, exact poison and worst freshness PASS")
    for _,name in ipairs({"Make Butter","Make Cream Cheese Culture"}) do
    for _,manual in ipairs({true,false}) do
    for _,state in ipairs({"fresh","stale","rotten"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,"HCRMilk",1234,.875,state)
        local slots={{source}}
        if name=="Make Butter" then slots[2]={inv:AddItem("Hydrocraft.HCChurn")}
        else
            slots[2]={inv:AddItem("Base.Vinegar2")};slots[3]={inv:AddItem("Base.Salt")}
            slots[4]={inv:AddItem("Base.Lighter")};slots[5]={inv:AddItem("Hydrocraft.HCClaycauldronFluid")}
        end
        local results=craft(player,inv,name,slots,manual)
        assert(#results==1,"Milk food output count")
        near(F.dose(results[1]),.875,"Milk food exact poison")
        assert(F.quality(results[1])==state,"Milk food worst freshness")
        near(results[1]:getCalories(),instanceItem(results[1]:getFullType()):getCalories(),"Authored milk food nutrition")
        near(Q.rawAmount(Q.fluid(source)),0,"Milk food full batch consumption")
        assert(source:getContainer()==inv,"Milk food vessel lost")
        player:getInventory():Remove(bag)
    end end end
    print("[HCRMilk160] butter/cream-cheese culture x manual/auto x fresh/stale/rotten, authored nutrition, exact poison, kept bucket PASS")
    local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
    local cheese=inv:AddItem("Hydrocraft.HCCheddarwheelwaxed")
    local expiry=cheese:getOffAgeMax();cheese:setAge(expiry-.5);F.store(cheese,.875)
    local rack=inv:AddItem("Hydrocraft.HCCheeserack")
    local full=craft(player,inv,"Put Cheese on Rack (Cheese Rack with Waxed Cheddar Cheese)",{{cheese},{rack}},true)[1]
    local quality=P.read(full);assert(quality.clock,"Waxed cheddar lost its ageing clock")
    near(quality.clock.lots[1].age,expiry-.5,"Waxed cheddar original age")
    near(quality.clock.lots[1].food.offAgeMax,expiry,"Waxed cheddar original expiry")
    local aged=inv:AddItem("Hydrocraft.HCCheeserackagedcheddarwaxed")
    for key,value in pairs(full:getModData()) do aged:getModData()[key]=L.copy(value) end
    for _,lot in ipairs(aged:getModData()[P.key].clock.lots) do lot.lastHour=lot.lastHour-48 end
    local result=craft(player,inv,"Remove Cheese from Rack (Aged Cheddar Wheel)",{{aged}},true)[1]
    assert(F.quality(result)=="rotten","Waxed cheddar ageing rejuvenated the wheel")
    near(F.dose(result),.875,"Waxed cheddar ageing exact poison")
    player:getInventory():Remove(bag)
    print("[HCRMilk160] near-expiry waxed cheddar -> rack clock -> aged wheel: elapsed age, spoilage and exact poison PASS")
end

local function runPortionCases(player)
    local Q,L,F=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
    for _,manual in ipairs({true,false}) do
    for _,hunger in ipairs({-.125,-.105}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=inv:AddItem("Hydrocraft.HCMilkjug")
        source:setHungChange(hunger);source:setCalories(400);source:setAge(0);F.store(source,1.25)
        local old=source;source=assert(HCRItemMigrations.newReplacement(old));inv:Remove(old);inv:AddItem(source)
        local before=Q.rawAmount(Q.fluid(source))
        local carton=inv:AddItem("Hydrocraft.HCMilkempty")
        local result=craft(player,inv,"Pour into Carton",{{source},{carton}},manual)[1]
        local ledger=Q.capture(result,Q.fluid(result)).ledger
        local fraction=1/before
        near(L.budget(ledger,"calories"),400*fraction,"Fractional hunger actual milk calories")
        near(L.budget(ledger,"poisonPower"),1.25*fraction,"Fractional hunger actual milk dose")
        near(L.budget(Q.capture(source,Q.fluid(source)).ledger,"poisonPower"),1.25*(1-fraction),"Migrated fractional hunger remaining milk dose")
        near(Q.rawAmount(Q.fluid(source)),before-1,"Migrated fractional tail volume")
        assert(source:getContainer()==inv,"Migrated jug vessel removed")
        player:getInventory():Remove(bag)
    end end
    local reversed=0
    for _,manual in ipairs({true,false}) do
    for trial=1,8 do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local a=inv:AddItem("Hydrocraft.HCMilkjug");local b=inv:AddItem("Hydrocraft.HCMilkjug")
        a:setHungChange(-.025);a:setCalories(1000);a:setAge(0);F.store(a,10)
        b:setHungChange(-.13);b:setCalories(300);b:setAge(0);F.store(b,3)
        local oldA,oldB=a,b
        a=assert(HCRItemMigrations.newReplacement(oldA));b=assert(HCRItemMigrations.newReplacement(oldB))
        inv:Remove(oldA);inv:Remove(oldB);inv:AddItem(a);inv:AddItem(b)
        local aVolume,bVolume=Q.rawAmount(Q.fluid(a)),Q.rawAmount(Q.fluid(b))
        local carton=inv:AddItem("Hydrocraft.HCMilkempty")
        local result=craft(player,inv,"Pour into Carton",{{a,b},{carton}},manual)[1]
        local ledger=Q.capture(result,Q.fluid(result)).ledger
        local aFraction=1-Q.rawAmount(Q.fluid(a))/aVolume
        local bFraction=1-Q.rawAmount(Q.fluid(b))/bVolume
        if aFraction<.001 then reversed=reversed+1 end
        near(L.budget(ledger,"calories"),1000*aFraction+300*bFraction,"Native order actual milk calories")
        near(L.budget(ledger,"poisonPower"),10*aFraction+3*bFraction,"Native order actual milk dose")
        near(L.budget(ledger,"poisonPower")+L.budget(Q.capture(a,Q.fluid(a)).ledger,"poisonPower")+L.budget(Q.capture(b,Q.fluid(b)).ledger,"poisonPower"),13,"Native order complete poison budget")
        for _,lot in ipairs(ledger.lots) do
            local volume=lot.food.calories==1000 and aVolume*aFraction or bVolume*bFraction
            near(lot.litres,volume,"Migrated actual hunger volume")
        end
        player:getInventory():Remove(bag)
    end end
    print("[HCRMilk160] migrated fractional hunger/tail and 16 manual-auto multi-input native-order cases PASS; second source first="..reversed)
end

local function runBowlCases(player)
    local Q,L,F=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
    local evolved
    local recipes=getScriptManager():getAllEvolvedRecipes()
    for i=0,recipes:size()-1 do
        if recipes:get(i):getFullResultItem()=="Base.Sandwich" then evolved=recipes:get(i);break end
    end
    assert(evolved,"Missing native Sandwich")
    for _,manual in ipairs({true,false}) do
    for _,kind in ipairs({"CowMilk","SheepMilk","AnimalMilk","HCRMilk"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,kind,1234,3.25,"fresh")
        if kind=="HCRMilk" then
            local saved=Q.capture(source,Q.fluid(source)).ledger
            saved.lots[1].age=3.75
            Q.store(source,Q.fluid(source),saved)
        end
        local empty=inv:AddItem("Base.Bowl")
        local result=craft(player,inv,"Pour Milk into Bowl",{{source},{empty}},manual)
        assert(#result==1 and result[1]:getFullType()=="Hydrocraft.HCRMilkBowl")
        local food=result[1]
        assert(not empty:getContainer() and inv:contains(source),"Bowl/kept donor identity")
        near(Q.rawAmount(Q.fluid(source)),3.7,"Bowl withdrawal")
        near(food:getCalories(),kind=="HCRMilk" and 1234*.075 or (kind=="SheepMilk" and 246.9 or 184.5),"Bowl nutrition")
        near(F.dose(food),kind=="HCRMilk" and 3.25*.075 or 0,"Bowl poison")
        near(food:getOffAge()-food:getAge(),kind=="HCRMilk" and .25 or 4,"Bowl fresh deadline")
        near(food:getOffAgeMax()-food:getAge(),kind=="HCRMilk" and 3.25 or 7,"Bowl rotten deadline")
        assert(not Q.fluid(food),"Bowl duplicated Food/FC nutrition")
        assert(evolved:getItemRecipe(food),"Bowl invisible to native evolved recipe")
        local bread=inv:AddItem("Base.BreadSlices");bread:setAge(0)
        collect(player,bread,player:getInventory()) -- Так делает native UI перед evolved action.
        F.store(bread,.375) -- Включает точный перенос и для чистого native milk.
        local dose=F.dose(food);local calories=food:getCalories()
        local action={recipe=evolved,baseItem=bread,usedItem=food,character=player}
        assert(ISAddItemInRecipe.complete(action))
        local sandwich=action.baseItem
        assert(sandwich,"Native milk sandwich missing")
        collect(player,sandwich,inv)
        local fraction=food:getContainer() and (1-food:getCalories()/calories) or 1
        near(F.dose(sandwich),.375+dose*fraction,"Bowl evolved exact dose")
        near(F.dose(food),dose*(1-fraction),"Bowl evolved remainder")
        if food:getContainer() then
            ISEatFoodAction.complete({item=food,character=player,percentage=1,useUtensil=false})
        end
        local returned=inv:getFirstTypeRecurse("Bowl")
        assert(returned and returned:getModData()[F.key]==nil and returned:getModData()[F.qualityKey]==nil,"Bowl return metadata")
        player:getInventory():Remove(bag)
    end end
    for _,state in ipairs({"stale","rotten"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,"HCRMilk",1234,.375,state)
        local empty=inv:AddItem("Base.Bowl")
        local food=craft(player,inv,"Pour Milk into Bowl",{{source},{empty}},true)[1]
        assert(F.quality(food)==state,"Bowl cleared source quality")
        player:getInventory():Remove(bag)
    end
    for _,field in ipairs({"tainted","frozen","freezingTime","alcoholPower"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=bucket(inv,"HCRMilk",1234,.375,"fresh")
        local fluid=Q.fluid(source);local ledger=Q.capture(source,fluid).ledger
        ledger.lots[1].food[field]=(field=="freezingTime" or field=="alcoholPower") and 1 or true
        Q.store(source,fluid,ledger)
        local empty=inv:AddItem("Base.Bowl")
        craft(player,inv,"Pour Milk into Bowl",{{source},{empty}},true,true)
        near(Q.rawAmount(fluid),4,"Refused bowl retains milk")
        near(L.budget(Q.capture(source,fluid).ledger,"poisonPower"),.375,"Refused bowl retains dose")
        assert(inv:contains(empty),"Refused bowl consumed dish")
        player:getInventory():Remove(bag)
    end
    print("[HCRMilk160] bowl: 8 manual-auto native/tracked portions, deadlines, evolved nutrition/poison and returned dish; stale/rotten PASS")
    print("[HCRMilk160] bowl: taint/frozen/partial-thaw/unsupported effect refused before debit PASS")
end

local function bowlSaveCases(player)
    local F=HCRFoodQuality
    local items=player:getInventory():getItems()
    for i=0,items:size()-1 do
        local bag=items:get(i)
        if bag:getModData().HCRBowlSave then
            local saved=bag:getItemContainer():getItems()
            assert(saved:size()==3,"Milk bowl cold save count")
            for n=0,saved:size()-1 do
                local food=saved:get(n);local expected=food:getModData().HCRBowlExpected
                assert(expected and food:getOffAge()==expected.fresh and food:getOffAgeMax()==expected.rotten,"Milk bowl saved deadlines")
                near(food:getCalories(),expected.calories,"Milk bowl saved calories")
                near(F.dose(food),expected.dose,"Milk bowl saved dose")
                assert(food:getAge()>=expected.age-.001,"Milk bowl age reset on load")
                assert(not HCRFluidQuality.fluid(food),"Milk bowl acquired duplicate fluid")
            end
            print("[HCRMilk160] three saved milk bowls: native deadlines, age, calories, exact dose PASS")
            return
        end
    end
    local bag=player:getInventory():AddItem("Base.Bag_Schoolbag")
    bag:setName("HCRLab: milk bowl save proof");bag:getModData().HCRBowlSave=true
    for i,age in ipairs({.75,1.9,1.001}) do
        local food=bag:getItemContainer():AddItem("Hydrocraft.HCRMilkBowl")
        food:setAge(age);food:setOffAge(i==1 and 1 or 0);food:setOffAgeMax(i==1 and 4 or (i==2 and 2 or 1))
        food:setCalories(80+i);F.store(food,.125*i)
        food:getModData().HCRBowlExpected={fresh=food:getOffAge(),rotten=food:getOffAgeMax(),age=age,calories=80+i,dose=.125*i}
    end
    print("[HCRMilk160] three milk bowls seeded for cold save/load")
end

local function runMilkCanCases(player)
    local Q,L,E,F=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
    for _,manual in ipairs({true,false}) do
    for _,kind in ipairs({"HCUHTmilk","HCPlasticcanmilk","HCDetergentmilk"}) do
    for _,state in ipairs({"fresh","stale","rotten"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local sources={};local litres,calories,dose=0,0,0
        for i=1,(kind=="HCUHTmilk" and 2 or 1) do
            local old=instanceItem("Hydrocraft."..kind)
            old:setAge(state=="rotten" and 501 or (state=="stale" and 251 or 10))
            old:setCalories(100*i);F.store(old,.375*i)
            local item=assert(HCRItemMigrations.newReplacement(old))
            inv:AddItem(item);sources[#sources+1]=item
            local ledger=Q.capture(item,Q.fluid(item)).ledger
            litres=litres+Q.rawAmount(Q.fluid(item));calories=calories+L.budget(ledger,"calories");dose=dose+L.budget(ledger,"poisonPower")
        end
        local target=inv:AddItem("Hydrocraft.HCDetergentemptyFluid");target:setFavorite(true)
        local id=target:getID();local funnel=inv:AddItem("Hydrocraft.HCFunnel")
        local outputs=craft(player,inv,"Fill Empty Soap Can With UHT Milk",{sources,{target},{funnel}},manual)
        assert(#outputs==0 and target:getID()==id and target:isFavorite(),"Milk can duplicated/replaced")
        near(Q.rawAmount(Q.fluid(target)),1.4,"Filled milk can volume")
        local ledger=Q.capture(target,Q.fluid(target)).ledger
        local remaining,restCalories,restDose=0,0,0
        for _,source in ipairs(sources) do
            assert(inv:contains(source),"Milk donor vessel lost")
            local left=Q.capture(source,Q.fluid(source)).ledger
            remaining=remaining+Q.rawAmount(Q.fluid(source));restCalories=restCalories+L.budget(left,"calories");restDose=restDose+L.budget(left,"poisonPower")
        end
        near(remaining+1.4,litres,"Milk can total volume")
        near(restCalories+L.budget(ledger,"calories"),calories,"Milk can total nutrition")
        near(restDose+L.budget(ledger,"poisonPower"),dose,"Milk can exact poison")
        assert(L.quality(ledger)==state,"Milk can quality reset")
        local expectedFreeze=kind~="HCUHTmilk"
        for _,lot in ipairs(ledger.lots) do assert(lot.food.canBeFrozen==expectedFreeze,"Milk can changed freeze policy") end
        player:getInventory():Remove(bag)
    end end end
    print("[HCRMilk160] 18 UHT/plastic/detergent manual-auto fresh/stale/rotten fills: identity, volume, nutrition, poison, freeze flags PASS")
end

local function runJugCases(player)
    local Q,L,F=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
    local function jug(inv,chocolate,state)
        local old=instanceItem(chocolate and "Hydrocraft.HCMilkjugchocolate" or "Hydrocraft.HCMilkjug")
        old:setAge(0);old:setCalories(800);F.store(old,3.25);F.setQuality(old,state)
        local item=assert(HCRItemMigrations.newReplacement(old));inv:AddItem(item)
        near(Q.rawAmount(Q.fluid(item)),2,"Whole milk jug migration")
        return item
    end
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=jug(inv,false,"stale");local calories,dose=0,0
        for i=1,2 do
            local empty=inv:AddItem("Hydrocraft.HCMilkempty")
            local carton=craft(player,inv,"Pour into Carton",{{source},{empty}},manual)[1]
            local ledger=Q.capture(carton,Q.fluid(carton)).ledger
            near(Q.rawAmount(Q.fluid(carton)),1,"Carton from jug volume")
            calories=calories+L.budget(ledger,"calories");dose=dose+L.budget(ledger,"poisonPower")
            assert(L.quality(ledger)=="stale")
            inv:Remove(carton) -- Второй auto розлив должен брать остаток кувшина.
        end
        near(calories,800,"Two cartons complete nutrition");near(dose,3.25,"Two cartons complete dose")
        near(Q.rawAmount(Q.fluid(source)),0,"Two cartons empty one jug")
        assert(source:getContainer()==inv,"Empty jug not retained")
        player:getInventory():Remove(bag)
    end
    for _,manual in ipairs({true,false}) do
    for _,state in ipairs({"fresh","stale","rotten"}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local source=jug(inv,true,state);local empty=inv:AddItem("Base.Bowl")
        local bowl=craft(player,inv,"Pour Milk into Bowl",{{source},{empty}},manual)[1]
        near(bowl:getCalories(),120,"Chocolate bowl current nutrition")
        near(F.dose(bowl),3.25*.15,"Chocolate bowl exact poison");assert(F.quality(bowl)==state)
        local butter=inv:AddItem("Base.Butter");butter:setAge(0)
        local sugar=inv:AddItem("Base.Sugar");local dish=inv:AddItem("Base.Bowl")
        local spatula=inv:AddItem("Base.Spatula")
        local frosting=craft(player,inv,"Make Frosting",{{butter},{source},{sugar},{dish},{spatula}},manual)[1]
        near(F.dose(frosting),3.25*.05,"Chocolate frosting exact poison");assert(F.quality(frosting)==state)
        near(Q.rawAmount(Q.fluid(source)),1.6,"Chocolate two recipes exact withdrawal")
        near(L.budget(Q.capture(source,Q.fluid(source)).ledger,"poisonPower"),3.25*.8,"Chocolate remaining dose")
        assert(not HCRFluidRecipeQuality.compatible(HCRLabCraft.findRecipe("Heat Milk"),source),"Chocolate allowed in heated milk")
        assert(not HCRFluidRecipeQuality.compatible(HCRLabCraft.findRecipe("Pour into Carton"),source),"Chocolate became plain milk")
        player:getInventory():Remove(bag)
    end end
    print("[HCRMilk160] two cartons per plain jug; chocolate 2L migration, bowl/frosting manual-auto quality/dose and plain-milk exclusions PASS")
end

function HCRLabMilkChains.run(player,profile)
    assert(profile=="HCRLab" and not isClient() and not isServer())
    reloadLuaFile("media/lua/shared/HCR_MilkBowl.lua")
    reloadLuaFile("media/lua/shared/HCR_MilkChains.lua")
    local carry=player:isUnlimitedCarry()
    player:setUnlimitedCarry(true)
    -- Старые результаты предыдущих прогонов не должны подменять специально
    -- выбранное сырьё в auto-тестах. Сохраняем их в отдельной сумке HCRLab.
    local quarantine=player:getInventory():AddItem("Base.Bag_Schoolbag")
    quarantine:setName("HCRLab: previous ground samples")
    local inv=quarantine:getItemContainer()
    local square=player:getSquare()
    for dx=-2,2 do for dy=-2,2 do
        local sq=getCell():getGridSquare(square:getX()+dx,square:getY()+dy,square:getZ())
        if sq then
            local worlds=sq:getWorldObjects()
            for i=worlds:size()-1,0,-1 do
                local world=worlds:get(i)
                if world:getFluidContainer() then collect(player,world:getItem(),inv) end
            end
        end
    end end
    local ok,reason=pcall(function()
        runCases(player,profile)
        runCheeseCases(player,profile)
        runPortionCases(player)
        runBowlCases(player)
        bowlSaveCases(player)
        runMilkCanCases(player)
        runJugCases(player)
    end)
    player:setUnlimitedCarry(carry)
    if not ok then error(reason) end
end
