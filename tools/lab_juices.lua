-- Только частный HCRLab. Native Food/FluidContainer/HandcraftAction.
require "HCR_DrinkMigrations"
require "HCR_DrinkRecipes"
require "HCR_FluidCrafting"
HCRLabJuices = {}
local function near(a,b,label)
    assert(math.abs(a-b)<.0001, label..": "..tostring(a).." != "..tostring(b))
end

function HCRLabJuices.show(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local Q,L,E=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects
    if HCRLabJuiceTooltip then HCRLabJuiceTooltip:removeFromUIManager() end
    local item=player:getInventory():AddItem("Base.PopBottle")
    local fluid=Q.fluid(item);fluid:Empty();fluid:addFluid("HCRJuiceApple",1)
    local food=instanceItem("Hydrocraft.HCPopbottleapplejuice")
    food:setAge(5);food:setOffAge(3);food:setOffAgeMax(7)
    Q.store(item,fluid,L.batch("HCRJuiceApple",1,E.snapshot(food),getGameTime():getWorldAgeHours()))
    local ui=ISToolTipInv:new(item);ui:initialise();ui:setCharacter(player)
    ui.followMouse=false;ui:setX(40);ui:setY(90)
    ui:addToUIManager();ui:setVisible(true)
    HCRLabJuiceTooltip=ui
    print("[HCRJuices160] stale juice tooltip opened for visual inspection")
end

function HCRLabJuices.run(player, profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local Q,L,E=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects
    local count=0
    for kind,spec in pairs(HCRDrinkFamilies) do
        if spec.enabled and not spec.unitLitres and not spec.retail and not spec.product and not spec.milk then
            for _,fraction in ipairs({.25,.5,1}) do
                local old=instanceItem(kind)
                old:setHungChange(old:getBaseHunger()*fraction)
                old:setCalories(137);old:setPoisonPower(7);old:setAge(9)
                old:setFavorite(true);old:getModData().juiceProbe="preserve"
                local new=HCRItemMigrations.newReplacement(old)
                assert(new and new:getFullType()==spec.target,"Missing juice migration "..kind)
                near(Q.rawAmount(Q.fluid(new)),spec.litres*fraction,"legacy remaining litres")
                local ledger=Q.capture(new,Q.fluid(new)).ledger
                near(L.budget(ledger,"calories"),137,"legacy current nutrition")
                near(L.budget(ledger,"poisonPower"),7,"legacy current poison")
                near(ledger.lots[1].age,9,"legacy current age")
                assert(new:isFavorite() and new:getModData().juiceProbe=="preserve")
                assert(not HCRItemMigrations.newReplacement(new),"Repeat migration")
                count=count+1
            end
        end
    end
    assert(count==258)
    print("[HCRJuices160] 86 Food IDs x 3 remaining portions, quality/state/idempotence PASS")
    for _,flavour in ipairs({"Lemon","Lime"}) do
        for uses=0,4 do
            local source=instanceItem("Hydrocraft.HC"..flavour.."juicebottle")
            source:setCurrentUses(uses)
            local target=assert(HCRItemMigrations.newReplacement(source),"Citrus concentrate migration missing")
            near(Q.rawAmount(Q.fluid(target)),uses*.1,"concentrate integer uses")
            if uses>0 then
                local ledger=Q.capture(target,Q.fluid(target)).ledger
                near(L.budget(ledger,"calories"),0,"no invented concentrate nutrition")
                near(L.budget(ledger,"poisonPower"),0,"no invented concentrate poison")
            end
        end
    end
    print("[HCRJuices160] two legacy Drainable concentrates x 0..4 uses PASS")
    local old=instanceItem("Hydrocraft.HCPopbottleapplejuice")
    local reference=instanceItem("Hydrocraft.HCPopbottleapplejuice")
    local now=getGameTime():getWorldAgeHours()
    for _,item in ipairs({old,reference}) do
        item:setAge(0);item:setOffAge(3);item:setOffAgeMax(7)
        item:setLastAged(math.max(0,now-240))
    end
    reference:updateAge(false)
    local migrated=assert(HCRItemMigrations.newReplacement(old))
    near(migrated:getModData()[Q.key].lots[1].age,reference:getAge(),"unloaded Food age catch-up")
    assert(reference:getAge()>0,"Unloaded-age fixture has no elapsed time")
    print("[HCRJuices160] native unloaded Food age catches up before migration PASS")

    local inv=player:getInventory()
    local spawned={}
    local function add(kind)
        local item=assert(inv:AddItem(kind),kind);spawned[#spawned+1]=item;return item
    end
    local function craft(name,groups)
        local recipe=HCRLabCraft.findRecipe(name)
        local learned=player:getKnownRecipes():contains(name)
        if not learned then player:getKnownRecipes():add(name) end
        local logic=HandcraftLogic.new(player,nil,nil)
        local containers=ArrayList.new();containers:add(inv)
        logic:setContainers(containers);logic:setRecipe(recipe)
        logic:setManualSelectInputs(true);logic:clearManualInputs()
        assert(recipe:getInputs():size()==#groups,"Wrong juice input groups")
        for index=0,recipe:getInputs():size()-1 do
            local items=ArrayList.new()
            for _,item in ipairs(groups[index+1]) do items:add(item) end
            assert(logic:setManualInputsFor(recipe:getInputs():get(index),items),"Rejected juice slot")
        end
        assert(logic:getRecipeData():canConsumeInputs(logic:getSourceResources()),"Native juice inputs unavailable")
        local action={character=player,logic=logic}
        ISHandcraftAction.performRecipe(action)
        assert(not action.hcrFluidRefused,"Juice crafting refused")
        if not learned then player:getKnownRecipes():remove(name) end
    end
    assert(not player:tooDarkToRead(),"Run private day command before juicing")
    local bottle=add("Base.PopBottle");Q.fluid(bottle):Empty()
    bottle:setFavorite(true);bottle:getModData().juiceIdentity="same"
    local originalID=bottle:getID()
    local fruit={}
    for index=1,4 do
        local apple=add("Base.Apple")
        apple:setCalories(index*11);apple:setPoisonPower(index==1 and 3 or 0)
        apple:setAge(index==1 and apple:getOffAge()+1 or 0)
        fruit[#fruit+1]=apple
    end
    local juicer=add("Hydrocraft.HCJuicer")
    craft("Make Bottle of Juice (Apple Juice)",{{bottle},fruit,{juicer}})
    assert(bottle:getContainer()==inv and bottle:getID()==originalID and bottle:isFavorite()
        and bottle:getModData().juiceIdentity=="same","Juicing replaced the vessel")
    near(Q.rawAmount(Q.fluid(bottle)),1,"apple juice litres")
    local ledger=Q.capture(bottle,Q.fluid(bottle)).ledger
    near(L.budget(ledger,"calories"),110,"actual apple nutrition")
    near(L.budget(ledger,"poisonPower"),3,"actual apple poison")
    assert(L.quality(ledger)=="stale","Old apple rejuvenated")
    for _,apple in ipairs(fruit) do assert(not apple:getContainer(),"Apple was not consumed") end
    print("[HCRJuices160] real ISHandcraftAction apple juice, same vessel, mixed-age nutrition/poison PASS")

    local mugs={}
    for i=1,5 do mugs[i]=add("Base.Mugl");Q.fluid(mugs[i]):Empty() end
    local wrap=add("Hydrocraft.HCSaranwrap")
    local pineapple=add("Base.Pineapple")
    pineapple:setCalories(111);pineapple:setPoisonPower(3);pineapple:setAge(0)
    craft("Make Mug of Juice (Pineapple Juice)",{mugs,{wrap},{pineapple},{juicer}})
    for _,item in ipairs(mugs) do
        near(Q.rawAmount(Q.fluid(item)),.2,"mug litres")
        local part=Q.capture(item,Q.fluid(item)).ledger
        near(L.budget(part,"calories"),22.2,"split mug nutrition")
        near(L.budget(part,"poisonPower"),.6,"split mug fractional poison")
    end
    assert(not pineapple:getContainer(),"Pineapple was not consumed")
    print("[HCRJuices160] one pineapple -> 1 L in five existing mugs, fractional poison conserved PASS")

    local small={}
    for i=1,3 do small[i]=add("Base.Mugl");Q.fluid(small[i]):Empty() end
    local apples={add("Base.Apple"),add("Base.Apple")}
    for _,apple in ipairs(apples) do apple:setCalories(100);apple:setPoisonPower(1);apple:setAge(0) end
    craft("Make Mug of Juice",{small,{wrap},apples,{juicer}})
    for i,item in ipairs(small) do
        local amount=i==3 and .1 or .2
        near(Q.rawAmount(Q.fluid(item)),amount,"unequal last mug volume")
        local part=Q.capture(item,Q.fluid(item)).ledger
        near(L.budget(part,"calories"),200*amount/.5,"unequal last mug nutrition")
        near(L.budget(part,"poisonPower"),2*amount/.5,"unequal last mug poison")
    end
    print("[HCRJuices160] half-litre apple batch -> .2/.2/.1 L, proportional nutrition/poison PASS")

    local bowls,lemons={},{}
    for i=1,4 do
        bowls[i]=add("Base.Bowl");Q.fluid(bowls[i]):Empty()
        lemons[i]=add("Base.Lemon");lemons[i]:setCalories(40);lemons[i]:setAge(0)
    end
    craft("Make Lemon Juice",{{add("Base.KitchenKnife")},{juicer},lemons,bowls})
    for i,bowl in ipairs(bowls) do
        local amount=i==4 and .1 or .3
        near(Q.rawAmount(Q.fluid(bowl)),amount,"uniform lemon batch in bowls")
        near(L.budget(Q.capture(bowl,Q.fluid(bowl)).ledger,"calories"),160*amount,"lemon bowl nutrition")
    end
    print("[HCRJuices160] four lemons -> 1 L in four same bowls, .3/.3/.3/.1 L PASS")

    local trace,wrong,water=add("Base.WaterBottle"),add("Base.WaterBottle"),add("Base.WaterBottle")
    local tf,wf,pf=Q.fluid(trace),Q.fluid(wrong),Q.fluid(water)
    tf:Empty();wf:Empty();pf:Empty()
    tf:addFluid(Fluid.Water,.1);wf:addFluid("HCRJuiceApple",.2);pf:addFluid(Fluid.Water,.4)
    local probe=E.snapshot(instanceItem("Hydrocraft.HCPopbottleapplejuice"));probe.poisonPower=13
    local lost=L.alignVolumes(L.batch("HCRJuiceApple",.0005,probe,now),{},.00101)
    Q.store(trace,tf,lost)
    Q.store(wrong,wf,L.batch("HCRJuiceApple",wf:getAmount(),probe,now))
    local lemon,sugar,empty=add("Base.Mugl"),add("Base.Sugar"),add("Base.PopBottle")
    local lf=Q.fluid(lemon);lf:Empty();lf:addFluid("HCRJuiceLemon",.2)
    Q.store(lemon,lf,L.batch("HCRJuiceLemon",.2,E.snapshot(instanceItem("Hydrocraft.HCLemonjuicebowl")),now))
    Q.fluid(empty):Empty()
    -- Native updateFloorContainer заново обходит реальные контейнеры. Отдельная
    -- сумка исключает случайную чистую воду от предыдущих стендов в инвентаре.
    local bag=add("Base.Bag_DuffelBagTINT")
    local bagInv=bag:getItemContainer()
    for _,item in ipairs({lemon,sugar,trace,wrong,water,empty}) do
        inv:Remove(item);bagInv:AddItem(item)
    end
    local recipe=HCRLabCraft.findRecipe("Make Bottle of Juice")
    local logic=HandcraftLogic.new(player,nil,nil)
    local containers=ArrayList.new();containers:add(bagInv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(false)
    local all=logic:getAllItems();all:clear()
    for _,item in ipairs({lemon,sugar,trace,wrong,water,empty}) do all:add(item) end
    local known=player:getKnownRecipes():contains(recipe:getName())
    if not known then player:getKnownRecipes():add(recipe:getName()) end
    assert(HCRFluidCrafting.check(logic),"Safe automatic water should remain available")
    local action={character=player,logic=logic}
    ISHandcraftAction.performRecipe(action)
    assert(not action.hcrFluidRefused,"Safe automatic water was refused")
    near(Q.rawAmount(tf),.1,"tracked prefix must remain untouched")
    near(L.budget(trace:getModData()[Q.key],"poisonPower"),13,"tracked prefix poison")
    near(Q.rawAmount(wf),.2,"incompatible carried juice must remain untouched")
    near(Q.rawAmount(pf),.2,"clean automatic provider consumption")
    assert(action.logic==logic,"Temporary crafting facade not restored")
    local outputs=logic:getRecipeData():getAllCreatedItems()
    for index=0,outputs:size()-1 do inv:Remove(outputs:get(index)) end
    if not known then player:getKnownRecipes():remove(recipe:getName()) end
    print("[HCRJuices160] native auto craft skips tracked prefix and wrong-fluid candidate, uses plain water PASS")
    -- Сок в keep-кастрюле не мешает варить яйцо на отдельной чистой воде.
    local pot=add("Base.Pot");local potFluid=Q.fluid(pot);potFluid:Empty()
    potFluid:addFluid("HCRJuiceApple",.5)
    Q.store(pot,potFluid,L.batch("HCRJuiceApple",.5,probe,now))
    local egg=add("Base.Egg")
    inv:Remove(pot);bagInv:AddItem(pot);inv:Remove(egg);bagInv:AddItem(egg)
    local boil=HCRLabCraft.findRecipe("Boil Egg")
    local learned=player:getKnownRecipes():contains(boil:getName())
    if not learned then player:getKnownRecipes():add(boil:getName()) end
    local boilLogic=HandcraftLogic.new(player,nil,nil)
    boilLogic:setContainers(containers);boilLogic:setRecipe(boil);boilLogic:setManualSelectInputs(false)
    local boilAction={character=player,logic=boilLogic}
    ISHandcraftAction.performRecipe(boilAction)
    assert(not boilAction.hcrFluidRefused and not egg:getContainer(),"Safe keep-pot auto craft failed")
    near(Q.rawAmount(potFluid),.5,"keep-pot volume")
    near(L.budget(pot:getModData()[Q.key],"poisonPower"),13,"keep-pot poison")
    if not learned then player:getKnownRecipes():remove(boil:getName()) end
    local boiled=boilLogic:getRecipeData():getAllCreatedItems()
    for i=0,boiled:size()-1 do inv:Remove(boiled:get(i)) end
    print("[HCRJuices160] tracked keep-pot allowed beside ordinary water in native automatic cooking PASS")
    for _,item in ipairs(spawned) do if item:getContainer()==inv then inv:Remove(item) end end
    print("[HCRJuices160] ALL PASS")
end
