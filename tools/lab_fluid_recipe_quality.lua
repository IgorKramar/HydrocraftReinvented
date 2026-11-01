-- Частная native проверка fluid→Food; не включать в опубликованный мод.
require "HCR_FluidRecipeQuality"
require "HCR_FoodTransfers"
HCRLabFluidRecipeQuality={}
local function near(a,b,label) assert(math.abs(a-b)<.0001,label..": "..tostring(a).." != "..tostring(b)) end
function HCRLabFluidRecipeQuality.run(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    getGameTime():setTimeOfDay(12.25)
    local Q,L,E,F=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
    for _,state in ipairs({"fresh","stale","rotten"}) do
    for _,manual in ipairs({true,false}) do
        local root=player:getInventory()
        local bag=root:AddItem("Base.Bag_Schoolbag")
        local inv=bag:getItemContainer()
        local empty=inv:AddItem("Base.Whiskey");Q.fluid(empty):Empty()
        local juice=inv:AddItem("Base.Mugl")
        local fluid=Q.fluid(juice);fluid:Empty()
        local volume=manual and .2 or .15
        fluid:addFluid("HCRJuiceLemon",volume)
        if not manual then fluid:addFluid(Fluid.Water,.05) end
        local sample=instanceItem("Hydrocraft.HCLemonjuicebowl")
        sample:setAge(state=="fresh" and 0 or state=="stale" and 6 or 9);sample:setPoisonPower(3)
        local snapshot=E.snapshot(sample);snapshot.poisonPower=3.25
        Q.store(juice,fluid,L.batch("HCRJuiceLemon",volume,snapshot,getGameTime():getWorldAgeHours()))
        local id=juice:getID()
        local recipe=HCRLabCraft.findRecipe("Make Lemon Mixer")
        local logic=HandcraftLogic.new(player,nil,nil)
        local containers=ArrayList.new();containers:add(inv)
        logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
        if manual then
            logic:clearManualInputs()
            for slot,item in ipairs({empty,juice}) do
                local selected=ArrayList.new();selected:add(item)
                assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected))
            end
        end
        local action={logic=logic,character=player}
        ISHandcraftAction.performRecipe(action)
        local outputs=logic:getRecipeData():getAllCreatedItems()
        assert(outputs:size()==1,"Native juice consumer produced no output")
        local result=outputs:get(0)
        assert(result:getFullType()=="Hydrocraft.HCLemonmixer")
        near(Q.rawAmount(fluid),.1,"actual juice remainder")
        near(F.dose(result),1.625,"fluid poison in Food output")
        near(L.budget(Q.capture(juice,fluid).ledger,"poisonPower"),1.625,"remaining fluid poison")
        near(result:getCalories(),550,"fixed authored output nutrition")
        assert(F.quality(result)==state,"Worst freshness not carried into nonperishable mixer")
        if state=="rotten" then
            assert(result:isRotten() and result:getAge()<2,"Nonperishable rotten scale invalid")
        elseif state=="stale" then
            assert(not result:isFresh() and not result:isRotten(),"Nonperishable stale interval invalid")
        end
        assert(juice:getID()==id and juice:getContainer()==inv,"Juice vessel identity changed")
        assert(not empty:getContainer(),"Result vessel was not consumed")
        root:Remove(result);root:Remove(bag)
    end
    end
    print("[HCRFluidRecipe160] native manual/auto x fresh/stale/rotten juice -> nonperishable Food, precise poison and same vessel PASS")
    local bag=player:getInventory():AddItem("Base.Bag_Schoolbag")
    local ice=bag:getItemContainer():AddItem("Hydrocraft.HCIcecreamsoft")
    F.store(ice,.625);F.setQuality(ice,"rotten")
    ice:update()
    local melted=bag:getItemContainer():getFirstTypeRecurse("HCIcecreamsoftmelted")
    assert(melted and melted~=ice,"Native rotten replacement not reached")
    F.reconcile(melted)
    assert(melted:isRotten() and melted:getAge()<2,"Replacement rotten floor has invalid age")
    near(F.dose(melted),.625,"melted poison dose")
    player:getInventory():Remove(bag)
    print("[HCRFluidRecipe160] native rotten replacement into nonperishable Food retains safe age scale PASS")
    for _,extra in ipairs({"Brandy","TaintedWater","HCRWhiskey"}) do
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag")
        local inv=bag:getItemContainer()
        local empty=inv:AddItem("Base.Whiskey");Q.fluid(empty):Empty()
        local juice=inv:AddItem("Base.Mugl");local fluid=Q.fluid(juice)
        fluid:Empty();fluid:addFluid("HCRJuiceLemon",.15);fluid:addFluid(extra,.05)
        local sample=E.snapshot(instanceItem("Hydrocraft.HCLemonjuicebowl"));sample.poisonPower=.875
        local ledger=L.batch("HCRJuiceLemon",.15,sample,getGameTime():getWorldAgeHours())
        if Q.transport[extra] then
            ledger=L.mix(ledger,L.batch(extra,.05,E.snapshot(instanceItem("Hydrocraft.HCRFluidSample")),getGameTime():getWorldAgeHours()))
        end
        Q.store(juice,fluid,ledger)
        local recipe=HCRLabCraft.findRecipe("Make Lemon Mixer")
        local logic=HandcraftLogic.new(player,nil,nil)
        local containers=ArrayList.new();containers:add(inv)
        logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
        if manual then
            logic:clearManualInputs()
            for slot,item in ipairs({empty,juice}) do
                local selected=ArrayList.new();selected:add(item)
                assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected))
            end
        end
        assert(not HCRFluidCrafting.check(logic),"Unexpected recipe mixture accepted")
        ISHandcraftAction.performRecipe({logic=logic,character=player})
        near(Q.rawAmount(fluid),.2,"unsupported mixture volume changed")
        near(L.budget(Q.capture(juice,fluid).ledger,"poisonPower"),.875,"unsupported mixture poison changed")
        assert(empty:getContainer()==inv and logic:getRecipeData():getAllCreatedItems():isEmpty(),"Unsupported mixture created output")
        player:getInventory():Remove(bag)
    end
    end
    print("[HCRFluidRecipe160] manual/auto Brandy, TaintedWater and HCRWhiskey recipe mixtures refused without consumption PASS")
end

function HCRLabFluidRecipeQuality.seed(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local bag=player:getInventory():AddItem("Base.Bag_Schoolbag")
    bag:getModData().HCRFreshnessSaveProbe=true
    for _,state in ipairs({"stale","rotten"}) do
        local food=bag:getItemContainer():AddItem("Hydrocraft.HCLemonmixer")
        food:getModData().HCRExpectedFreshness=state
        HCRFoodQuality.setQuality(food,state);HCRFoodQuality.store(food,.875)
    end
    print("[HCRFluidRecipe160] cold-save freshness/poison fixtures seeded; verify after process restart")
end

function HCRLabFluidRecipeQuality.verify(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    local items=player:getInventory():getItems()
    local found=0
    for i=0,items:size()-1 do
        local bag=items:get(i)
        if bag:getModData().HCRFreshnessSaveProbe then
            local foods=bag:getItemContainer():getItems()
            assert(foods:size()==2,"Cold-save fixtures missing")
            for j=0,foods:size()-1 do
                local food=foods:get(j)
                HCRFoodQuality.reconcile(food)
                local expected=food:getModData().HCRExpectedFreshness
                assert(HCRFoodQuality.quality(food)==expected,"Cold-save freshness lost")
                assert(food:getAge()<3,"Cold-save freshness age invalid")
                assert(not food:isFresh() and food:isRotten()==(expected=="rotten"))
                near(HCRFoodQuality.dose(food),.875,"Cold-save exact poison")
                if expected=="stale" then
                    if HCRLabFoodTooltip then HCRLabFoodTooltip:removeFromUIManager() end
                    local ui=ISToolTipInv:new(food);ui:initialise();ui:setCharacter(player)
                    ui.followMouse=false;ui:setX(40);ui:setY(90)
                    ui:addToUIManager();ui:setVisible(true);HCRLabFoodTooltip=ui
                end
                found=found+1
            end
        end
    end
    assert(found==2,"Ambiguous cold-save fixtures")
    print("[HCRFluidRecipe160] cold process restart: nonperishable stale/rotten Food and exact poison PASS; stale tooltip open")
end
