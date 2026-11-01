-- Частный native стенд: лимонад не создаёт дополнительные литры/посуду.
require "HCR_DrinkProducts"
HCRLabDrinkProducts={}
local function near(a,b,label) assert(math.abs(a-b)<.0001,label..": "..tostring(a).." != "..tostring(b)) end
function HCRLabDrinkProducts.run(player,profile)
    assert(profile=="HCRLab" and player and not isClient() and not isServer())
    getGameTime():setTimeOfDay(12.25)
    local Q,L,E,F=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
    for kind,spec in pairs(HCRDrinkProductFamilies) do
        for _,fraction in ipairs({.25,.5,1}) do
            local old=instanceItem(kind)
            old:setHungChange(old:getBaseHunger()*fraction);old:setCalories(73.5);F.store(old,.375)
            local new=assert(HCRItemMigrations.newReplacement(old))
            near(Q.rawAmount(Q.fluid(new)),spec.litres*fraction,"legacy lemonade litres")
            local ledger=Q.capture(new,Q.fluid(new)).ledger
            near(L.budget(ledger,"calories"),73.5,"legacy lemonade nutrition")
            near(L.budget(ledger,"poisonPower"),.375,"legacy lemonade exact poison")
        end
    end
    for _,rule in pairs(HCRDrinkProductRules) do
    for _,state in ipairs({"fresh","stale","rotten"}) do
    for _,manual in ipairs({true,false}) do
        local bag=player:getInventory():AddItem("Base.Bag_Schoolbag")
        local inv=bag:getItemContainer()
        local juice=inv:AddItem("Base.PopBottle");local jf=Q.fluid(juice);jf:Empty();jf:addFluid("HCRJuiceLemon",.2)
        local sample=instanceItem("Hydrocraft.HCLemonjuicebowl")
        sample:setAge(state=="fresh" and 0 or state=="stale" and 6 or 9)
        F.store(sample,3.25)
        Q.store(juice,jf,L.batch("HCRJuiceLemon",.2,E.snapshot(sample),getGameTime():getWorldAgeHours()))
        local sugar=inv:AddItem("Base.Sugar")
        local water=inv:AddItem("Base.WaterBottle");local wf=Q.fluid(water);wf:Empty();wf:addFluid(Fluid.Water,.6)
        local bottle=inv:AddItem(rule.target);Q.fluid(bottle):Empty()
        local id=bottle:getID();bottle:setFavorite(true)
        local recipe=HCRLabCraft.findRecipe(rule.name)
        local logic=HandcraftLogic.new(player,nil,nil)
        local containers=ArrayList.new();containers:add(inv)
        logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
        if manual then
            logic:clearManualInputs()
            for slot,item in ipairs({juice,sugar,water,bottle}) do
                local selected=ArrayList.new();selected:add(item)
                assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected))
            end
        end
        local action={logic=logic,character=player}
        ISHandcraftAction.performRecipe(action)
        assert(not action.hcrFluidRefused,"Lemonade production refused")
        near(Q.rawAmount(jf),.1,"lemonade juice consumption")
        near(Q.rawAmount(wf),.4,"lemonade water consumption")
        near(Q.rawAmount(Q.fluid(bottle)),.3,"lemonade conserved output volume")
        assert(bottle:getID()==id and bottle:getContainer()==inv and bottle:isFavorite(),"Lemonade vessel replaced")
        local result=Q.capture(bottle,Q.fluid(bottle)).ledger
        near(L.budget(result,"poisonPower"),1.625,"lemonade inherited poison")
        near(L.budget(result,"calories"),instanceItem(rule.sourceFood):getCalories(),"lemonade authored nutrition")
        assert(L.quality(result)==state,"Lemonade freshness reset")
        assert(logic:getRecipeData():getAllCreatedItems():isEmpty(),"Extra lemonade vessel created")
        player:getInventory():Remove(bag)
    end
    end
    end
    print("[HCRDrinkProducts160] 6 legacy migrations; 2 vessels x 3 freshness x manual/auto: .3 L, same vessel, exact poison and authored nutrition PASS")
end
