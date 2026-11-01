-- Частный HCRLab: настоящий handcraft, частичные Food и два жидких входа.
reloadLuaFile("media/lua/shared/HCR_BrewedDrinkRules.lua")
reloadLuaFile("media/lua/shared/HCR_BrewedDrinks.lua")
require "HCR_BrewedDrinks"
for name,rule in pairs(HCRBrewedDrinkRules) do
    if rule.inputs then HCRFluidRecipeQuality.rules[name]=rule end
end
require "TimedActions/ISGrabItemAction"
HCRLabCoffee={}
local B,Q,L,E,F=HCRBrewedDrinks,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..": "..tostring(a).." != "..tostring(b)) end
local function craft(player,inv,name,selected,manual,refused)
    print("[HCRCoffee160] craft "..name.." manual="..tostring(manual))
    local logic=HandcraftLogic.new(player,nil,nil)
    local recipe=HCRLabCraft.findRecipe(name);local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
    logic:updateFloorContainer(containers)
    if manual then
        logic:clearManualInputs()
        for slot,item in ipairs(selected) do
            local items=ArrayList.new()
            if type(item)=="table" then for _,part in ipairs(item) do items:add(part) end else items:add(item) end
            assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),items),"Coffee manual input "..name.." "..slot)
        end
    end
    assert(logic:getRecipeData():canConsumeInputs(logic:getSourceResources()),"Coffee native inputs "..name)
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    if refused then
        assert(action.hcrFluidRefused,"Unsafe coffee recipe was not refused")
        return nil
    end
    assert(not action.hcrFluidRefused,"Coffee action refused "..name)
    local outputs=logic:getRecipeData():getAllCreatedItems()
    if outputs:size()==0 then return nil end
    assert(outputs:size()==1,"Coffee duplicated output")
    local result=outputs:get(0)
    if result:getWorldItem() then
        local world=result:getWorldItem()
        ISGrabItemAction.transferItem({item=world,character=player,destContainer=inv,transactionId=0},world)
    elseif result:getContainer()~=inv then
        if result:getContainer() then result:getContainer():Remove(result) end
        inv:AddItem(result)
    end
    return result
end
local function batch(inv,kind,marker,litres,calories,dose,state)
    local item=inv:AddItem(kind);local fc=Q.fluid(item);fc:setCanPlayerEmpty(true);fc:Empty();fc:addFluid(marker,litres)
    local food=instanceItem("Hydrocraft.HCCoffeeblack");food:setAge(0);food:setCooked(true)
    food:setCalories(calories);F.store(food,dose);F.setQuality(food,state)
    Q.store(item,fc,L.batch(marker,litres,E.snapshot(food),getGameTime():getWorldAgeHours()))
    return item
end
function HCRLabCoffee.run(player)
    assert(not isClient() and not isServer())
    local carry=player:isUnlimitedCarry();player:setUnlimitedCarry(true)
    local ok,reason=pcall(function()
        local saved=HCRLabCoffee.verify(player)
        local finishCount,mixCount,pourCount,brewCount=0,0,0,0
        for name,rule in pairs(B.rules) do
        if rule.brew then
        for _,manual in ipairs({true,false}) do
            local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
            local kettle=rule.litres==1.5
            local target=inv:AddItem(kettle and "Base.Kettle" or (name=="Brew Black Coffee" and "Hydrocraft.HCClaymugFluid" or "Base.MugWhite"))
            Q.fluid(target):Empty()
            local water=inv:AddItem("Base.PopBottle");Q.fluid(water):setCanPlayerEmpty(true);Q.fluid(water):Empty();Q.fluid(water):addFluid("Water",2)
            local mixed=inv:AddItem("Base.PopBottle");Q.fluid(mixed):setCanPlayerEmpty(true);Q.fluid(mixed):Empty()
            Q.fluid(mixed):addFluid("Water",1.8);Q.fluid(mixed):addFluid("TaintedWater",.2)
            local coffee=inv:AddItem("Base.Coffee2");coffee:setAge(0)
            local selected={target,water,coffee}
            if kettle then selected[4]=inv:AddItem("Hydrocraft.HCCoffeefilterdry") end
            if manual then
                selected[2]=mixed
                craft(player,inv,name,selected,true,true)
                assert(target:getContainer()==inv,"Rejected brewer consumed vessel")
                near(Q.rawAmount(Q.fluid(mixed)),2,"Rejected brewer consumed water")
                selected[2]=water
            end
            local output=craft(player,inv,name,selected,manual)
            assert(output:IsFood() and not output:isCooked() and not target:getContainer(),"Brewing skipped native heating")
            near(Q.rawAmount(Q.fluid(water)),2-rule.litres,"Brewing water remainder")
            near(Q.rawAmount(Q.fluid(mixed)),2,"Auto brewing used contaminated candidate")
            player:getInventory():Remove(holder);brewCount=brewCount+1
        end
        elseif rule.finish then
        for _,manual in ipairs({true,false}) do
        for _,fraction in ipairs({1,.4}) do
            local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
            local item=inv:AddItem(rule.source);item:setAge(0);item:setCooked(rule.cookable)
            item:setHungChange(item:getBaseHunger()*fraction);item:setCalories(123.5*fraction)
            F.store(item,.375*fraction);F.setQuality(item,"rotten");item:setFavorite(true)
            local output=craft(player,inv,name,{item},manual);local fc=Q.fluid(output)
            assert(output:getFullType()==rule.target and output:isFavorite(),"Coffee vessel or favorite lost")
            assert(not item:getContainer() and inv:getItems():size()==1,"Coffee extra vessel or surviving source")
            local ledger=Q.capture(output,fc).ledger
            near(Q.rawAmount(fc),rule.litres*fraction,"Finished coffee volume")
            near(L.budget(ledger,"calories"),123.5*fraction,"Finished coffee calories")
            near(L.budget(ledger,"poisonPower"),.375*fraction,"Finished coffee dose")
            assert(L.quality(ledger)=="rotten","Coffee freshness lost")
            player:getInventory():Remove(holder);finishCount=finishCount+1
        end end
        elseif rule.inputs[1] then
        for _,manual in ipairs({true,false}) do
        for _,state in ipairs({"fresh","stale","rotten"}) do
            local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
            local coffee=batch(inv,"Base.Kettle","HCRCoffee",1.5,1500,.75,"fresh")
            local milk=batch(inv,"Base.Milk","HCRMilk",1,1000,.5,state)
            local target=inv:AddItem(rule.target);Q.fluid(target):Empty()
            assert(not craft(player,inv,name,{coffee,milk,target},manual),"Milk coffee creates extra vessel")
            near(Q.rawAmount(Q.fluid(coffee)),1.5-rule.litres/2,"Coffee remainder")
            near(Q.rawAmount(Q.fluid(milk)),1-rule.litres/2,"Milk remainder")
            local ledger=Q.capture(target,Q.fluid(target)).ledger
            near(Q.rawAmount(Q.fluid(target)),rule.litres,"Milk coffee volume")
            near(L.budget(ledger,"calories"),1000*rule.litres,"Milk coffee calories")
            near(L.budget(ledger,"poisonPower"),.5*rule.litres,"Milk coffee dose")
            assert(L.quality(ledger)==state,"Milk coffee freshness")
            assert(inv:getItems():size()==3,"Milk coffee changed vessel count")
            player:getInventory():Remove(holder);mixCount=mixCount+1
        end end
        else
        for _,manual in ipairs({true,false}) do
            local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
            local volume=rule.inPlace and rule.litres or 1.5
            local coffee=batch(inv,rule.inPlace and rule.target or "Base.Kettle","HCRCoffee",volume,volume*1000,volume*.5,"stale")
            local target=rule.inPlace and coffee or inv:AddItem(rule.target)
            if not rule.inPlace then Q.fluid(target):Empty() end
            local selected={coffee,target};local sugar,calories,dose
            if rule.foodSlot then
                sugar=inv:AddItem(name:find('Cubes') and "Hydrocraft.HCSugarcubes" or "Base.Sugar")
                sugar:setAge(0);F.store(sugar,.125);F.setQuality(sugar,"rotten")
                calories=sugar:getCalories();dose=F.dose(sugar);selected={coffee,sugar}
            end
            assert(not craft(player,inv,name,selected,manual),"Pour creates extra vessel")
            local usedCalories=sugar and (calories-(sugar:getContainer() and sugar:getCalories() or 0)) or 0
            local usedDose=sugar and (dose-(sugar:getContainer() and F.dose(sugar) or 0)) or 0
            local ledger=Q.capture(target,Q.fluid(target)).ledger
            if not rule.inPlace then near(Q.rawAmount(Q.fluid(coffee)),1.5-rule.litres,"Measured coffee remainder") end
            near(Q.rawAmount(Q.fluid(target)),rule.litres,"Measured coffee volume")
            near(L.budget(ledger,"calories"),rule.litres*1000+usedCalories,"Coffee and actual sugar calories")
            near(L.budget(ledger,"poisonPower"),rule.litres*.5+usedDose,"Coffee and actual sugar poison")
            assert(L.quality(ledger)==(sugar and 'rotten' or 'stale'),"Coffee sugar quality")
            player:getInventory():Remove(holder);pourCount=pourCount+1
        end
        end end
        assert(finishCount==52 and mixCount==36 and pourCount==18 and brewCount==6,"Incomplete coffee/soy scenario")
        print("[HCRCoffee160] 52 partial/full coffee/cocoa/soy finishes, 36 milk mixtures, 18 pours/sweeteners, 6 measured water brewers; manual/auto PASS")
        for _,kind in ipairs({"HCCoffeeblack","HCKettlecoffee","HCSoymilk"}) do
            local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
            local item=inv:AddItem("Hydrocraft."..kind)
            assert(not B.TestCooked(item),"Raw coffee unexpectedly ready")
            local soy=kind=="HCSoymilk"
            local recipeName=soy and "Finish Preparing Soy Milk" or (kind=="HCKettlecoffee" and "Finish Brewing Coffee Kettle" or "Finish Brewing Black Coffee")
            assert(not HCRLabCraft.findRecipe(recipeName):OnTestItem(item,player),"Native accepts unfinished brew")
            local cook,burn=item:getMinutesToCook(),item:getMinutesToBurn()
            near(cook,soy and 20 or (kind=="HCKettlecoffee" and 15 or 5),"Original brew time")
            near(burn,soy and 40 or (kind=="HCKettlecoffee" and 120 or 20),"Original burn time")
            if soy then
                near(item:getOffAge(),15,"Soy fresh days");near(item:getOffAgeMax(),30,"Soy rotten days")
                assert(item:isbDangerousUncooked(),"Raw soy safety changed")
            end
            item:setHeat(2);item:setCookingTime(cook+1);item:update()
            assert(item:isCooked() and B.TestCooked(item),"Native coffee cooking boundary")
            inv:Remove(item)
            -- Food.update нагревает один раз за игровую минуту: отдельный
            -- образец проверяет burn, не ожидая смены минуты у первого.
            item=inv:AddItem("Hydrocraft."..kind)
            item:setHeat(2);item:setCookingTime(burn+1);item:update()
            assert(item:isBurnt() and B.TestCooked(item),"Native coffee burn boundary")
            local result=craft(player,inv,recipeName,{item},true)
            assert(Q.capture(result,Q.fluid(result)).ledger.lots[1].food.burnt,"Finish removes burning")
            player:getInventory():Remove(holder)
        end
        print("[HCRCoffee160] original native brew/burn boundaries and raw guard PASS")
        local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
        local coffee=batch(inv,"Hydrocraft.HCThermosFluid","HCRCoffee",1.4,1,0,"fresh")
        local ledger=L.empty()
        for i=1,127 do
            ledger=L.mix(ledger,L.batch("HCRCoffee",1.4/127,{calories=i/127,hungChange=-.01,baseHunger=-.01},getGameTime():getWorldAgeHours()))
        end
        Q.store(coffee,Q.fluid(coffee),L.alignVolumes(ledger,Q.amounts(Q.fluid(coffee))))
        local sugars={}
        for i=1,3 do
            local item=inv:AddItem("Hydrocraft.HCSugarcubes");item:setAge(0);item:setCalories(i*10)
            if i>1 then item:setHungChange(-.01) end
            sugars[i]=item
        end
        craft(player,inv,"Add Sugar Cubes (Thermos of Coffee with Sugar)",{coffee,sugars},true,true)
        near(Q.rawAmount(Q.fluid(coffee)),1.4,"Overflow refusal consumed coffee")
        for i,item in ipairs(sugars) do near(item:getCalories(),i*10,"Overflow refusal consumed sugar") end
        player:getInventory():Remove(holder)
        print("[HCRCoffee160] pure-water candidate filtering and 127-lot multi-sugar refusal before debit PASS")
        local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
        local coffee=inv:AddItem("Base.Kettle");local fc=Q.fluid(coffee);fc:Empty();fc:addFluid("Coffee",1);fc:addFluid("Water",.5)
        local milk=inv:AddItem("Base.Milk");local fm=Q.fluid(milk)
        local expectedCalories=fc:getProperties():getCalories()*.1/1.5+fm:getProperties():getCalories()*.1/Q.rawAmount(fm)
        local target=inv:AddItem("Base.Mugl");Q.fluid(target):Empty()
        craft(player,inv,"Add Milk From Carton",{coffee,milk,target},true)
        local mixed=Q.capture(target,Q.fluid(target)).ledger
        near(L.budget(mixed,"calories"),expectedCalories,"Native diluted coffee and CowMilk calories")
        near(Q.rawAmount(fc),1.4,"Native coffee remainder")
        near(Q.rawAmount(fm),.9,"Native milk remainder")
        player:getInventory():Remove(holder)
        print("[HCRCoffee160] native Coffee+Water and CowMilk inputs: measured nutrition/remainders PASS")
        if saved==0 then HCRLabCoffee.seed(player) end
    end)
    player:setUnlimitedCarry(carry)
    if not ok then error(reason) end
end

function HCRLabCoffee.seed(player)
    local holder=player:getInventory():AddItem("Base.Bag_Schoolbag");local inv=holder:getItemContainer()
    holder:setName("HCRLab: coffee save proof");holder:getModData().HCRCoffeeSaveProof=true
    local source=inv:AddItem("Hydrocraft.HCCoffeeblack");source:setAge(0);source:setCooked(true)
    source:setHungChange(source:getBaseHunger()*.4);source:setCalories(49.4);F.store(source,.15);F.setQuality(source,"rotten")
    local partial=craft(player,inv,"Finish Brewing Black Coffee",{source},true)
    local sweet=batch(inv,"Base.Mugl","HCRCoffee",.2,3,.125,"stale")
    local sugar=inv:AddItem("Hydrocraft.HCSugarcubes");sugar:setAge(0);F.store(sugar,.25)
    craft(player,inv,"Add Sugar Cubes",{sweet,sugar},true);inv:Remove(sugar)
    local coffee=batch(inv,"Base.Kettle","HCRCoffee",1.5,15,.75,"fresh")
    local milk=batch(inv,"Base.Milk","HCRMilk",1,615,.5,"rotten")
    local target=inv:AddItem("Base.Mugl");Q.fluid(target):Empty()
    craft(player,inv,"Add Milk From Carton",{coffee,milk,target},true);inv:Remove(coffee);inv:Remove(milk)
    for _,item in ipairs({partial,sweet,target}) do
        local ledger=Q.capture(item,Q.fluid(item)).ledger
        item:getModData().HCRCoffeeExpected={amount=Q.rawAmount(Q.fluid(item)),calories=L.budget(ledger,"calories"),
            dose=L.budget(ledger,"poisonPower"),quality=L.quality(ledger),lots=#ledger.lots}
    end
    print("[HCRCoffee160] partial coffee, zero-volume sugar and two-source milk mixture SEEDED; cold-load pending")
end

function HCRLabCoffee.verify(player)
    local items=player:getInventory():getItems();local count=0
    for i=0,items:size()-1 do
        local holder=items:get(i)
        if holder:getModData().HCRCoffeeSaveProof then
            local contents=holder:getItemContainer():getItems()
            for j=0,contents:size()-1 do
                local item=contents:get(j);local expected=assert(item:getModData().HCRCoffeeExpected,"Missing saved coffee expectation")
                local ledger=Q.capture(item,Q.fluid(item)).ledger
                near(Q.rawAmount(Q.fluid(item)),expected.amount,"Saved coffee amount")
                near(L.budget(ledger,"calories"),expected.calories,"Saved coffee calories")
                near(L.budget(ledger,"poisonPower"),expected.dose,"Saved coffee dose")
                assert(L.quality(ledger)==expected.quality and #ledger.lots==expected.lots,"Saved coffee quality/lots")
                count=count+1
            end
        end
    end
    if count>0 then
        assert(count==3,"Incomplete coffee save fixtures")
        print("[HCRCoffee160] saved partial coffee, sugar and milk mixture: volume/nutrition/dose/quality/lots PASS")
    end
    return count
end
