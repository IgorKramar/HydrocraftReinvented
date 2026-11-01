-- Только HCRLab: отмеривание, evolved, питьё и сохранение Food-порций.
require "HCR_AlcoholPortions"
require "TimedActions/ISGrabItemAction"
HCRLabAlcohol={}
local Q,L,E,F=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..": "..tostring(a).." != "..tostring(b)) end
local function source(inv,kind,marker,state,concentration)
    local prototype=instanceItem("Hydrocraft."..kind)
    prototype:setAge(0);prototype:setHungChange(prototype:getBaseHunger()*concentration)
    prototype:setCalories(prototype:getCalories()*concentration)
    F.store(prototype,.875*concentration);F.setQuality(prototype,state)
    local item=inv:AddItem("Base.Whiskey");local fluid=Q.fluid(item)
    fluid:Empty();fluid:addFluid(marker,concentration)
    if concentration<1 then fluid:addFluid("Water",1-concentration) end
    local ledger=L.batch(marker,concentration,E.snapshot(prototype),getGameTime():getWorldAgeHours())
    Q.store(item,fluid,ledger)
    return item,prototype:getCalories()
end
local function craft(player,inv,name,source,manual)
    local mead=name=="Prepare Mead for Cooking"
    local empty=inv:AddItem(mead and "Hydrocraft.HCAlestienFluid" or "Base.GlassTumbler")
    Q.fluid(empty):Empty()
    local logic=HandcraftLogic.new(player,nil,nil)
    local recipe=HCRLabCraft.findRecipe(name);local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
    logic:updateFloorContainer(containers)
    if manual then
        logic:clearManualInputs()
        for slot,item in ipairs({source,empty}) do
            local selected=ArrayList.new();selected:add(item)
            assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected),"Cooking alcohol manual selection")
        end
    end
    assert(logic:getRecipeData():canConsumeInputs(logic:getSourceResources()),"Cooking alcohol native input availability")
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    assert(not action.hcrFluidRefused,"Cooking alcohol refused")
    local outputs=logic:getRecipeData():getAllCreatedItems()
    assert(outputs:size()==1,"Cooking alcohol output count")
    local item=outputs:get(0)
    assert(item:IsFood() and not Q.fluid(item),"Cooking portion must be Food only")
    if item:getWorldItem() then
        local world=item:getWorldItem()
        ISGrabItemAction.transferItem({item=world,character=player,destContainer=inv,transactionId=0},world)
    elseif item:getContainer()~=inv then
        if item:getContainer() then item:getContainer():Remove(item) end
        inv:AddItem(item)
    end
    assert(not empty:getContainer(),"Cooking portion duplicated empty vessel")
    return item
end
local families={{"HCGin3","HCRGin"},{"HCWhiskeycorn","HCRWhiskeyCorn"},{"HCTequila","HCRTequila"},
    {"HCMezcal","HCRMezcal"},{"HCApplejack","HCRApplejack"},{"HCPeachschnapps","HCRPeachSchnapps"},
    {"HCFlip","HCRFlip"},{"HCSake","HCRSake"},{"HCMead","HCRMead"}}
local function evolvedPortion(player,portion,resultType)
    local inv=player:getInventory();local recipes=getScriptManager():getAllEvolvedRecipes();local evolved
    for i=0,recipes:size()-1 do
        if recipes:get(i):getFullResultItem()==resultType then evolved=recipes:get(i);break end
    end
    assert(evolved and evolved:getItemRecipe(portion),"Missing evolved ingredient registration")
    local pot=inv:AddItem("Base.Pot");Q.fluid(pot):Empty();Q.fluid(pot):addFluid("Water",1.5)
    assert(evolved:getItemsCanBeUse(player,pot,nil):contains(portion),"Cooking alcohol absent from native ingredient list")
    local dose,calories,baseline=F.dose(portion),portion:getCalories(),portion:getBaseHunger()
    local action={recipe=evolved,baseItem=pot,usedItem=portion,character=player}
    assert(ISAddItemInRecipe.complete(action));local result=action.baseItem
    local fraction=portion:getContainer() and (1-portion:getCalories()/calories) or 1
    near(F.dose(result),dose*fraction,"Evolved cooking alcohol dose")
    near(F.dose(portion),dose*(1-fraction),"Evolved cooking alcohol remaining dose")
    near(portion:getBaseHunger(),baseline,"Evolved cooking alcohol original baseline")
    assert(F.quality(result)==F.quality(portion),"Evolved cooking alcohol freshness")
    inv:Remove(result)
    return fraction
end
local function drink(player,item,fluid,amount)
    local stats=player:getStats()
    for _,name in ipairs({"INTOXICATION","HUNGER","THIRST","BOREDOM","UNHAPPINESS","POISON"}) do
        stats:set(CharacterStat[name],name=="HUNGER" and .5 or 0)
    end
    player:getNutrition():setCalories(0)
    if fluid then ISDrinkFluidAction:new(player,item,amount):updateEat(1)
    else ISEatFoodAction.complete({item=item,character=player,percentage=1,useUtensil=false}) end
    return {alcohol=stats:get(CharacterStat.INTOXICATION),calories=player:getNutrition():getCalories(),
        hunger=stats:get(CharacterStat.HUNGER),poison=stats:get(CharacterStat.POISON)}
end
function HCRLabAlcohol.run(player)
    assert(not isClient() and not isServer())
    HCRLabCraft.trainCooking(player,"HCRLab")
    local carry=player:isUnlimitedCarry();player:setUnlimitedCarry(true)
    local ok,reason=pcall(function()
        for _,manual in ipairs({true,false}) do
        for _,family in ipairs(families) do
        for _,state in ipairs({"fresh","stale","rotten"}) do
            local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
            local mead=family[1]=="HCMead";local amount=mead and .4 or .2
            local donor,calories=source(inv,family[1],family[2],state,1)
            local portion=craft(player,inv,mead and "Prepare Mead for Cooking" or "Prepare Spirit for Cooking",donor,manual)
            near(Q.rawAmount(Q.fluid(donor)),1-amount,"Cooking alcohol kept donor")
            near(portion:getCalories(),calories*amount,"Cooking alcohol nutrition")
            near(F.dose(portion),.875*amount,"Cooking alcohol exact dose")
            near(2*portion:getHungChange()/portion:getBaseHunger(),2*amount,"Cooking alcohol strength")
            assert(F.quality(portion)==state and portion:isAlcoholic() and not portion:canBeFrozen())
            player:getInventory():Remove(holder)
        end end end
        print("[HCRAlcohol160] 54 nine-family manual-auto fresh/stale/rotten cooking portions: volume, nutrition, dose, strength PASS")
        for _,family in ipairs({families[1],families[9]}) do
            local inv=player:getInventory();local mead=family[1]=="HCMead";local amount=mead and .4 or .2
            local donor,calories=source(inv,family[1],family[2],"stale",.6)
            local portion=craft(player,inv,mead and "Prepare Mead for Cooking" or "Prepare Spirit for Cooking",donor,true)
            near(portion:getCalories(),calories*amount,"Diluted cooking alcohol nutrition")
            near(2*portion:getHungChange()/portion:getBaseHunger(),2*.6*amount,"Diluted cooking alcohol strength")
            evolvedPortion(player,portion,"Base.PotOfSoupRecipe")
            inv:Remove(donor);if portion:getContainer() then inv:Remove(portion) end
        end
        print("[HCRAlcohol160] water-diluted spirits/mead remain native evolved soup ingredients, exact dose and strength PASS")
        for _,family in ipairs({families[1],families[9]}) do
        for _,concentration in ipairs({1,.6}) do
            local inv=player:getInventory();local mead=family[1]=="HCMead";local amount=mead and .4 or .2
            local donor=source(inv,family[1],family[2],"fresh",concentration)
            local reference=source(inv,family[1],family[2],"fresh",concentration)
            local portion=craft(player,inv,mead and "Prepare Mead for Cooking" or "Prepare Spirit for Cooking",donor,true)
            local expected=drink(player,reference,true,amount);local actual=drink(player,portion,false)
            for key,value in pairs(expected) do near(actual[key],value,"Food versus fluid consumption "..key) end
            assert(not portion:getContainer(),"Consumed portion remains in inventory")
            inv:Remove(donor);inv:Remove(reference)
        end end
        print("[HCRAlcohol160] actual native Food Eat versus ledger DrinkFluid, pure/diluted spirit/mead PASS")
        for i=1,20 do
            if player:getPerkLevel(Perks.Cooking)>=10 then break end
            player:getXp():AddXP(Perks.Cooking,10000)
        end
        assert(player:getPerkLevel(Perks.Cooking)==10,"Retained portion fixture requires Cooking10")
        for _,resultType in ipairs({"Base.PotOfSoupRecipe","Base.PotOfStew"}) do
            local inv=player:getInventory();local donor=source(inv,"HCMead","HCRMead","fresh",1)
            local portion=craft(player,inv,"Prepare Mead for Cooking",donor,true)
            F.store(portion,0) -- Чистая порция тоже должна пройти восстановление baseline.
            evolvedPortion(player,portion,resultType)
            assert(portion:getContainer(),"Expected retained mead at trained Cooking level")
            local remaining=portion:getHungChange();local stats=player:getStats()
            local expectedSource=instanceItem("Hydrocraft.HCMead")
            stats:set(CharacterStat.INTOXICATION,0);stats:set(CharacterStat.HUNGER,.5+remaining)
            player:getBodyDamage():JustDrankBooze(expectedSource,remaining/expectedSource:getHungChange())
            local expected=stats:get(CharacterStat.INTOXICATION)
            near(drink(player,portion,false).alcohol,expected,"Retained mead native drinking strength")
            inv:Remove(donor)
        end
        print("[HCRAlcohol160] fresh poison-free retained mead after Soup/Stew: proportional native intoxication PASS")
    end)
    player:setUnlimitedCarry(carry)
    if not ok then error(reason) end
end

function HCRLabAlcohol.seed(player)
    local carry=player:isUnlimitedCarry();player:setUnlimitedCarry(true)
    local ok,reason=pcall(function()
    local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
    holder:setName("HCRLab: alcohol portion save proof");holder:getModData().HCRAlcoholSaveProof=true
    for _,family in ipairs({families[1],families[9]}) do
        local donor=source(inv,family[1],family[2],"rotten",.6)
        local portion=craft(player,inv,family[1]=="HCMead" and "Prepare Mead for Cooking" or "Prepare Spirit for Cooking",donor,true)
        portion:getModData().expectedAlcohol=2*portion:getHungChange()/portion:getBaseHunger()
        portion:getModData().expectedDose=F.dose(portion)
        inv:Remove(donor)
    end
    local donor=source(player:getInventory(),"HCMead","HCRMead","rotten",1)
    local retained=craft(player,player:getInventory(),"Prepare Mead for Cooking",donor,true)
    evolvedPortion(player,retained,"Base.PotOfSoupRecipe")
    assert(retained:getContainer(),"Expected retained mead save sample")
    retained:getModData().expectedAlcohol=2*retained:getHungChange()/retained:getBaseHunger()
    retained:getModData().expectedDose=F.dose(retained)
    player:getInventory():Remove(retained);inv:AddItem(retained);player:getInventory():Remove(donor)
    print("[HCRAlcohol160] three cooking portions including evolved remainder SEEDED; cold verification pending")
    end)
    player:setUnlimitedCarry(carry)
    if not ok then error(reason) end
end
function HCRLabAlcohol.verify(player)
    local items=player:getInventory():getItems();local count=0
    for i=0,items:size()-1 do
        local holder=items:get(i)
        if holder:getModData().HCRAlcoholSaveProof then
            local portions=holder:getItemContainer():getItems()
            print("[HCRAlcohol160] saved fixture bag items="..portions:size())
            for j=0,portions:size()-1 do
                local portion=portions:get(j)
                if portion:IsFood() then
                    count=count+1
                    near(2*portion:getHungChange()/portion:getBaseHunger(),portion:getModData().expectedAlcohol,"Saved cooking alcohol strength")
                    near(F.dose(portion),portion:getModData().expectedDose,"Saved cooking alcohol dose")
                    assert(portion:isAlcoholic() and not portion:canBeFrozen() and F.quality(portion)=="rotten")
                end
            end
        end
    end
    assert(count>=3,"Cooking alcohol save fixtures missing, actual="..count)
    print("[HCRAlcohol160] cold-load Food alcohol baseline, flags, poison and freshness PASS")
end
