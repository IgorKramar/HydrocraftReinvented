-- Частная проверка настоящего Food.Eat: округление, BaseHunger и native OnEat.
require "HCR_FoodQuality"
HCRLabFoodQuality={}
local function near(a,b,label)
    assert(math.abs(a-b)<.0001,label..": "..tostring(a).." != "..tostring(b))
end
local function genericPortions(player)
    local F=HCRFoodQuality
    for _,manual in ipairs({true,false}) do
    for _,hunger in ipairs({-.125,-.015}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=bag:getItemContainer()
        local a=inv:AddItem("Base.Potato");local b=inv:AddItem("Base.Potato")
        a:setAge(0);b:setAge(0);a:setCalories(100);b:setCalories(300)
        F.store(a,1);F.store(b,2)
        local butter=inv:AddItem("Base.Butter");butter:setAge(0);butter:setHungChange(hunger)
        butter:setCalories(400);F.store(butter,1.25)
        local groups={{a,b},{inv:AddItem("Hydrocraft.HCPotatopeeler")},{inv:AddItem("Base.Pot")},
            {butter},{inv:AddItem("Hydrocraft.HCPotatomasher")}}
        groups[3][1]:getFluidContainer():Empty()
        local recipe=HCRLabCraft.findRecipe("Make Creamy Mashed Potatoes")
        player:learnRecipe(recipe:getName())
        local logic=HandcraftLogic.new(player,nil,nil);local containers=ArrayList.new();containers:add(inv)
        logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
        if manual then
            logic:clearManualInputs()
            for i,group in ipairs(groups) do
                local selected=ArrayList.new();for _,item in ipairs(group) do selected:add(item) end
                assert(logic:setManualInputsFor(recipe:getInputs():get(i-1),selected))
            end
        end
        ISHandcraftAction.performRecipe({logic=logic,character=player})
        local created=logic:getRecipeData():getAllCreatedItems()
        assert(created:size()==1,"Native generic output missing")
        local output=created:get(0)
        local fraction=hunger==-.125 and .08 or 1
        near(output:getCalories(),400+400*fraction,"Generic actual fractional nutrition")
        near(F.dose(output),3+1.25*fraction,"Generic actual fractional poison")
        near(F.dose(butter),1.25*(1-fraction),"Generic exact remaining poison")
        assert(not a:getContainer() and not b:getContainer(),"Whole potatoes survived recipe")
        if output:getContainer() then output:getContainer():Remove(output) end
        player:getInventory():Remove(bag)
    end end
    print("[HCRFoodQuality160] native generic nutrition manual/auto x fractional retained/removed tail PASS")
end
function HCRLabFoodQuality.previous(_,_,fraction)
    HCRLabFoodQuality.calls=(HCRLabFoodQuality.calls or 0)+1
    HCRLabFoodQuality.lastFraction=fraction
end
function HCRLabFoodQuality.run(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    getGameTime():setTimeOfDay(12.25) -- Factory lastCookMinute=0: нужна ненулевая минута.
    reloadLuaFile("media/lua/server/HCR_FoodBridge.lua") -- Только чистые функции, без повторной установки hooks.
    local F,E=HCRFoodQuality,HCRFluidEffects
    genericPortions(player)
    local stats=player:getStats()
    local calibration=instanceItem("Base.Apple")
    calibration:setAge(0);calibration:setPoisonPower(1)
    stats:set(CharacterStat.POISON,0)
    player:getBodyDamage():JustAteFood(calibration,1,false)
    local factor=stats:get(CharacterStat.POISON)
    local function food(hunger,base,dose)
        local item=player:getInventory():AddItem("Base.Apple")
        item:setAge(0);item:setHungChange(hunger);item:setBaseHunger(base)
        item:setFoodSicknessChange(0);item:setTainted(false)
        F.store(item,dose)
        return item
    end
    local item=food(-.2,-.4,1.3)
    item:setOnEat("HCRLabFoodQuality.previous")
    stats:set(CharacterStat.POISON,0)
    ISEatFoodAction.complete({item=item,character=player,percentage=.25,useUtensil=false})
    near(stats:get(CharacterStat.POISON),.65*factor,"native rebased poison")
    near(F.dose(item),.65,"native remaining exact dose")
    near(item:getHungChange(),-.1,"native remaining hunger")
    assert(HCRLabFoodQuality.calls==1)
    near(HCRLabFoodQuality.lastFraction,.5,"native actual percentage")
    assert(item:getOnEat()=="HCRLabFoodQuality.previous","Previous OnEat not restored")
    ISEatFoodAction.complete({item=item,character=player,percentage=1,useUtensil=false})
    near(stats:get(CharacterStat.POISON),1.3*factor,"native complete total")
    assert(not item:getContainer(),"Finished food remains")
    print("[HCRFoodQuality160] partial/rebased/full eating, fractional poison and previous OnEat PASS")

    item=food(-.02,-.02,2.5)
    stats:set(CharacterStat.POISON,0)
    ISEatFoodAction.complete({item=item,character=player,percentage=.6,useUtensil=false})
    near(stats:get(CharacterStat.POISON),2.5*factor,"native last-bite snap")
    assert(not item:getContainer())
    print("[HCRFoodQuality160] native end-of-bite snap consumes exact remaining dose PASS")

    item=food(-.4,-.4,.125)
    stats:set(CharacterStat.POISON,0)
    ISEatFoodAction.eat({item=item,character=player,percentage=.5,useUtensil=false},item,.5)
    near(stats:get(CharacterStat.POISON),.03125*factor,"cancelled bite")
    near(F.dose(item),.09375,"cancelled remainder")
    local snapshot=E.snapshot(item)
    near(snapshot.poisonPower,.09375,"Food to liquid snapshot")
    local ledger=HCRFluidLedger.batch("HCRJuiceApple",1,snapshot,getGameTime():getWorldAgeHours())
    player:getInventory():Remove(item)
    stats:set(CharacterStat.POISON,0)
    E.consume(player,E.prepare(ledger),false)
    near(stats:get(CharacterStat.POISON),.09375*factor,"Food to liquid exact poison")
    print("[HCRFoodQuality160] cancelled bite and Food->drink fractional dose PASS")

    local original=food(-.2,-.2,.875)
    local replacement=instanceItem("Base.Apple")
    replacement:copyConditionStatesFrom(original)
    near(F.dose(replacement),.875,"native condition metadata copy")
    F.store(replacement,.125)
    near(F.dose(original),.875,"independent replacement dose")
    player:getInventory():Remove(original)
    print("[HCRFoodQuality160] native cooking/rotting metadata-copy API preserves exact dose PASS")

    local bag=player:getInventory():AddItem("Base.Bag_Schoolbag")
    local inventory=bag:getItemContainer()
    local raw=inventory:AddItem("Hydrocraft.HCPotBeets")
    assert(raw,"Missing private cooking fixture")
    F.store(raw,.375)
    raw:setHeat(2);raw:setAge(0);raw:setCookingTime(raw:getMinutesToCook()+1)
    raw:update()
    local cooked=inventory:getFirstTypeRecurse("HCPotBeetsCooked")
    assert(cooked and cooked~=raw,"Native cooked replacement not reached")
    near(F.dose(cooked),.375,"actual cooked replacement dose")
    F.reconcile(cooked);assert(cooked:getPoisonPower()==1,"Cooked poison marker missing")
    local ice=inventory:AddItem("Hydrocraft.HCIcecreamsoft")
    assert(ice,"Missing private rotting fixture")
    F.store(ice,.625);ice:setAge(ice:getOffAgeMax()+1)
    ice:update()
    local melted=inventory:getFirstTypeRecurse("HCIcecreamsoftmelted")
    assert(melted and melted~=ice,"Native rotten replacement not reached")
    near(F.dose(melted),.625,"actual rotten replacement dose")
    F.reconcile(melted);assert(melted:getPoisonPower()==1,"Rotten poison marker missing")
    local dish=inventory:AddItem("Hydrocraft.HCMashedpotatosplainbowl")
    F.store(dish,.75)
    ISEatFoodAction.complete({item=dish,character=player,percentage=1,useUtensil=false})
    local empty=inventory:getFirstTypeRecurse("Bowl")
    assert(empty and empty:getModData()[F.key]==nil,"Poison resurrected in empty dish")
    player:getInventory():Remove(bag)
    print("[HCRFoodQuality160] actual native cooked and rotten replacements preserve exact dose PASS")
    print("[HCRFoodQuality160] native empty dish does not inherit consumed poison PASS")

    getGameTime():setTimeOfDay(12)
    local inv=player:getInventory()
    local function split(name,sourceType,groups,count)
        local source=inv:AddItem(sourceType)
        source:setAge(0);source:setCalories(480);F.store(source,1.3)
        local inputs={{source}}
        local spawned={source}
        for _,group in ipairs(groups) do
            local items={}
            for _,kind in ipairs(group) do
                local added=inv:AddItem(kind);items[#items+1]=added;spawned[#spawned+1]=added
            end
            inputs[#inputs+1]=items
        end
        local recipe=HCRLabCraft.findRecipe(name)
        local learned=player:getKnownRecipes():contains(name)
        if not learned then player:getKnownRecipes():add(name) end
        local logic=HandcraftLogic.new(player,nil,nil)
        local containers=ArrayList.new();containers:add(inv)
        logic:setContainers(containers);logic:setRecipe(recipe)
        logic:setManualSelectInputs(true);logic:clearManualInputs()
        for i=0,recipe:getInputs():size()-1 do
            local selected=ArrayList.new()
            for _,item in ipairs(inputs[i+1]) do selected:add(item) end
            assert(logic:setManualInputsFor(recipe:getInputs():get(i),selected),"Split selection")
        end
        local action={character=player,logic=logic}
        ISHandcraftAction.performRecipe(action)
        local outputs=logic:getRecipeData():getAllCreatedItems()
        assert(outputs:size()==count,"Missing native split outputs")
        local poison,calories=0,0
        for i=0,outputs:size()-1 do
            local result=outputs:get(i)
            poison=poison+F.dose(result);calories=calories+result:getCalories()
            near(F.dose(result),1.3/count,"split portion poison")
            inv:Remove(result)
        end
        near(poison,1.3,"split total poison");near(calories,480,"split total nutrition")
        assert(not source:getContainer(),"Split source not consumed")
        for _,item in ipairs(spawned) do inv:Remove(item) end
        if not learned then player:getKnownRecipes():remove(name) end
    end
    split("Cut Cheese Wheel","Hydrocraft.HCCheesewheel",{{"Base.KitchenKnife"}},8)
    split("Make Bowl of Plain Mashed Potatos","Hydrocraft.HCMashedpotatosplain",{{"Base.Bowl","Base.Bowl"}},2)
    print("[HCRFoodQuality160] native cheese8/mashed2 split preserves total nutrition and fractional poison PASS")

    local cheese=inv:AddItem("Base.Cheese")
    cheese:setAge(0);F.store(cheese,.625)
    local grater=inv:AddItem("Hydrocraft.HCCheesegrater")
    local logic=HandcraftLogic.new(player,nil,nil)
    local containers=ArrayList.new();containers:add(inv)
    local recipe=HCRLabCraft.findRecipe("Grate Cheese")
    logic:setContainers(containers);logic:setRecipe(recipe)
    logic:setManualSelectInputs(true);logic:clearManualInputs()
    for i,item in ipairs({grater,cheese}) do
        local selected=ArrayList.new();selected:add(item)
        assert(logic:setManualInputsFor(recipe:getInputs():get(i-1),selected))
    end
    ISHandcraftAction.performRecipe({logic=logic,character=player})
    local grated=logic:getRecipeData():getAllCreatedItems():get(0)
    assert(grated and grated:getFullType()=="Hydrocraft.HCGratedcheese")
    near(F.dose(grated),.625,"native no-callback craft")
    assert(not cheese:getContainer())
    inv:Remove(grated);inv:Remove(grater)
    print("[HCRFoodQuality160] native Grate Cheese without OnCreate preserves exact dose PASS")

    local evolved
    local definitions=getScriptManager():getAllEvolvedRecipes()
    for i=0,definitions:size()-1 do
        if definitions:get(i):getFullResultItem()=="Base.Sandwich" then evolved=definitions:get(i);break end
    end
    assert(evolved,"Native Sandwich recipe missing")
    local bread=inv:AddItem("Base.BreadSlices")
    bread:setAge(0);F.store(bread,.375)
    cheese=inv:AddItem("Base.Cheese")
    cheese:setAge(0);cheese:setCalories(400);cheese:setHungChange(-.4);cheese:setBaseHunger(-.4)
    F.store(cheese,1.25)
    local action={recipe=evolved,baseItem=bread,usedItem=cheese,character=player}
    assert(ISAddItemInRecipe.complete(action))
    local used=1-cheese:getCalories()/400
    assert(used>0 and used<1,"Native evolved test must use a partial ingredient")
    near(F.dose(action.baseItem),.375+1.25*used,"native evolved replacement dose")
    near(F.dose(cheese),1.25*(1-used),"native evolved ingredient remainder")
    assert(action.baseItem~=bread and not bread:getContainer(),"Native base replacement missing")
    local previousDose=F.dose(action.baseItem)
    local last=inv:AddItem("Base.Cheese")
    last:setAge(0);last:setHungChange(-.01);last:setBaseHunger(-.01);F.store(last,.625)
    action.usedItem=last
    assert(ISAddItemInRecipe.complete(action))
    assert(not last:getContainer(),"Native evolved end fragment remains")
    near(F.dose(action.baseItem),previousDose+.625,"native evolved final fragment")
    inv:Remove(action.baseItem);inv:Remove(cheese)
    print("[HCRFoodQuality160] native evolved base replacement, partial ingredient and final fragment PASS")

    local budgetBag=inv:AddItem("Base.Bag_Schoolbag")
    local budgetInv=budgetBag:getItemContainer()
    local a=budgetInv:AddItem("Base.Potato")
    local b=budgetInv:AddItem("Base.Potato")
    a:setAge(0);b:setAge(0);F.store(a,600000);F.store(b,600000)
    local peeler=budgetInv:AddItem("Hydrocraft.HCPotatopeeler")
    local pot=budgetInv:AddItem("Base.Pot");pot:getFluidContainer():Empty()
    local water=budgetInv:AddItem("Base.WaterBottle")
    water:getFluidContainer():Empty();water:getFluidContainer():addFluid(Fluid.Water,1)
    local masher=budgetInv:AddItem("Hydrocraft.HCPotatomasher")
    local budgetGroups={{a,b},{peeler},{pot},{water},{masher}}
    local budgetRecipe=HCRLabCraft.findRecipe("Make Plain Mashed Potatoes")
    for _,manual in ipairs({true,false}) do
        local testLogic=HandcraftLogic.new(player,nil,nil)
        local testContainers=ArrayList.new();testContainers:add(budgetInv)
        testLogic:setContainers(testContainers);testLogic:setRecipe(budgetRecipe)
        testLogic:setManualSelectInputs(manual)
        if manual then
            testLogic:clearManualInputs()
            for i,group in ipairs(budgetGroups) do
                local selected=ArrayList.new()
                for _,ingredient in ipairs(group) do selected:add(ingredient) end
                assert(testLogic:setManualInputsFor(budgetRecipe:getInputs():get(i-1),selected))
            end
        end
        ISHandcraftAction.performRecipe({logic=testLogic,character=player})
        assert(testLogic:getRecipeData():getAllCreatedItems():isEmpty(),"Over-budget recipe created free food")
        assert(a:getContainer()==budgetInv and b:getContainer()==budgetInv and pot:getContainer()==budgetInv)
        near(water:getFluidContainer():getAmount(),1,"Over-budget recipe consumed water")
        near(F.dose(a)+F.dose(b),1200000,"Over-budget input doses changed")
    end
    inv:Remove(budgetBag)
    print("[HCRFoodQuality160] native manual/auto over-budget refusal before output/water/food mutation PASS")

    stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.PAIN,0)
    local calories=player:getNutrition():getCalories()
    local timer=player:getBodyDamage():getHealthFromFoodTimer()
    E.poison(player,254)
    near(stats:get(CharacterStat.POISON),math.min(100,254*factor),"large O(1) native dose with stat cap")
    near(stats:get(CharacterStat.PAIN),254/6,"large native poison pain")
    near(player:getNutrition():getCalories(),calories,"poison carrier nutrition")
    near(player:getBodyDamage():getHealthFromFoodTimer(),timer,"poison carrier food timer")
    stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.PAIN,0)
    print("[HCRFoodQuality160] O(1) dose254, native traits, unchanged nutrition/timer PASS")
end
