-- Только private HCRLab: настоящие рецепты и действия native Whiskey B42.
require "HCR_NativeWhiskey"
require "HCR_WineQuality"
require "TimedActions/ISDisinfect"
require "TimedActions/ISGrabItemAction"
HCRLabNativeWhiskey={}
HCRLabNativeWhiskeyBoot=HCRLabNativeWhiskeyBoot or tostring(getTimestampMs())
local Q,L,F,P,N=HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRProcessQuality,HCRNativeWhiskey
local function near(a,b,name) assert(math.abs(a-b)<.001,name..' '..tostring(a)..' / '..tostring(b)) end
local function bag(player)
    local holder=player:getInventory():AddItem('Base.Bag_Schoolbag')
    holder:setName('HCRLab native whiskey');return holder,holder:getItemContainer()
end
local function craft(player,inv,name,slots,manual)
    local recipe=assert(HCRLabCraft.findRecipe(name));player:learnRecipe(name)
    local logic=HandcraftLogic.new(player,nil,nil);local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual)
    if manual then
        logic:clearManualInputs()
        for slot,items in ipairs(slots) do
            local selected=ArrayList.new();for _,item in ipairs(items) do selected:add(item) end
            assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),selected),'Manual selection '..name..' slot '..slot)
        end
    end
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    assert(not action.hcrFluidRefused,'Native whiskey recipe refused '..name)
    local created=logic:getRecipeData():getAllCreatedItems();assert(created:size()>0,'No outputs '..name)
    local result={}
    for i=0,created:size()-1 do
        local item=created:get(i)
        if item:getWorldItem() then
            local world=item:getWorldItem()
            ISGrabItemAction.transferItem({item=world,character=player,destContainer=inv,transactionId=0},world)
        elseif item:getContainer()~=inv then
            if item:getContainer() then item:getContainer():Remove(item) end
            inv:AddItem(item)
        end
        result[#result+1]=item
    end
    return result
end
local function bottle(inv,state,dose)
    local item=inv:AddItem('Base.Whiskey');local fluid=Q.fluid(item);fluid:setCanPlayerEmpty(true)
    Q.store(item,fluid,N.ledger(fluid,{dose=dose,quality=state,detection=4},1))
    return item
end
local function dose(item) return L.budget(Q.capture(item,Q.fluid(item)).ledger,'poisonPower') end
local function production(player)
    for _,manual in ipairs({true,false}) do
    for _,quality in ipairs({'fresh','stale','rotten'}) do
        print('[HCRNativeWhiskey160] production '..quality..' manual='..tostring(manual)..' Cooking='..player:getPerkLevel(Perks.Cooking))
        local holder,inv=bag(player);local pots={}
        for i=1,3 do
            pots[i]=inv:AddItem('Hydrocraft.HCPotofflourmashcooked');F.store(pots[i],.25)
            F.setQuality(pots[i],i==2 and quality=='stale' and 'stale' or 'fresh')
        end
        local empty=inv:AddItem('Hydrocraft.HCWoodenbarrel')
        local barrel=craft(player,inv,'Fill Barrel with Flour Mash',{{empty},pots},manual)[1]
        near(P.read(barrel).dose,.75,'Barrel dose')
        assert(P.read(barrel).quality==(quality=='stale' and 'stale' or 'fresh'))
        -- Оригинальный Food input не разрешает rotten pots. Испорченный
        -- сохранённый Normal-полуфабрикат проверяется отдельной fixture.
        if quality=='rotten' then P.write(barrel,{dose=.75,quality='rotten',detection=4},1,nil) end
        local charcoal=inv:AddItem('Base.Charcoal');local fire=inv:AddItem('Base.Lighter')
        local vessels={};for i=1,20 do vessels[i]=inv:AddItem('Base.Whiskey');Q.fluid(vessels[i]):Empty() end
        local water=inv:AddItem('Base.Bucket');Q.fluid(water):Empty();Q.fluid(water):addFluid('Water',6)
        local still=inv:AddItem('Hydrocraft.HCDistillery2')
        local outputs=craft(player,inv,'Distill Bottle of Whiskey',{{barrel},{charcoal},{fire},vessels,{water},{still}},manual)
        assert(#outputs==20);local total=0
        for _,item in ipairs(outputs) do
            local fluid=Q.fluid(item);near(fluid:getSpecificFluidAmount(Fluid.Whiskey),1,'Native whiskey identity')
            near(L.volume(item:getModData()[Q.key]),0,'Quality-only volume')
            assert(L.quality(item:getModData()[Q.key])==quality)
            total=total+dose(item)
        end
        near(total,.75,'Twenty bottles conserved dose');near(Q.rawAmount(Q.fluid(water)),0,'Six litres consumed')
        assert(still:getContainer()==inv,'Kept distillery lost')
        player:getInventory():Remove(holder)
    end end
    print('[HCRNativeWhiskey160] six manual/auto flour production chains PASS')
end
local function drinking(player)
    local inv=player:getInventory();local plain=inv:AddItem('Base.Whiskey');Q.fluid(plain):setCanPlayerEmpty(true)
    local tracked=bottle(inv,'fresh',0)
    local stats,body,nutrition=player:getStats(),player:getBodyDamage(),player:getNutrition()
    local function drink(item)
        for _,name in ipairs({'HUNGER','THIRST','POISON','PAIN','INTOXICATION','BOREDOM','UNHAPPINESS','FATIGUE','STRESS','ENDURANCE'}) do
            stats:set(CharacterStat[name],name=='HUNGER' and .5 or 0)
        end
        nutrition:setCalories(0);body:setHealthFromFoodTimer(0)
        ISDrinkFluidAction:new(player,item,.25):updateEat(1)
        local result={calories=nutrition:getCalories(),timer=body:getHealthFromFoodTimer()}
        for _,name in ipairs({'HUNGER','THIRST','POISON','PAIN','INTOXICATION','BOREDOM','UNHAPPINESS','FATIGUE','STRESS','ENDURANCE'}) do
            result[name]=stats:get(CharacterStat[name])
        end
        near(Q.rawAmount(Q.fluid(item)),.75,'Quarter sip');return result
    end
    local expected,actual=drink(plain),drink(tracked)
    for name,value in pairs(expected) do near(actual[name],value,'Native drink parity '..name) end
    local poison=bottle(inv,'fresh',.875);drink(poison)
    near(dose(poison),.65625,'Exact remaining dose')
    near(stats:get(CharacterStat.POISON),.21875,'Exact ingested dose')
    local spoiled=bottle(inv,'rotten',0);drink(spoiled)
    assert(stats:get(CharacterStat.POISON)>0,'Rotten native Whiskey became harmless')
    for _,item in ipairs({plain,tracked,poison,spoiled}) do inv:Remove(item) end
    stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.INTOXICATION,0)
    print('[HCRNativeWhiskey160] native drink parity, exact poison and spoilage PASS')
end
local function sinks(player)
    for _,manual in ipairs({true,false}) do
    for _,case in ipairs({{'DisinfectRag','Base.RippedSheets',.1},{'DouseCottonInAlcohol','Base.CottonBalls',.1},
        {'Disinfect Diaper','Hydrocraft.HCDiaper',.5},{'Disinfect Menstrual Pad','Hydrocraft.HCMenstrualpad',.5},
        {'MakeMolotovCocktail','Base.RippedSheets',1}}) do
        local holder,inv=bag(player);local liquid=bottle(inv,'rotten',.875);local other=inv:AddItem(case[2])
        local slots=case[1]=='MakeMolotovCocktail' and {{liquid},{other}} or {{other},{liquid}}
        craft(player,inv,case[1],slots,manual)
        near(dose(liquid),.875*(1-case[3]),'Native sink remainder '..case[1])
        if case[3]==1 then assert(liquid:getContainer()==nil,'Molotov bottle not consumed')
        else near(Q.rawAmount(Q.fluid(liquid)),1-case[3],'Native sink volume '..case[1]) end
        player:getInventory():Remove(holder)
    end end
    local inv=player:getInventory();local liquid=bottle(inv,'rotten',.875)
    local part=player:getBodyDamage():getBodyParts():get(0)
    local previous=part:getAlcoholLevel();local poison=player:getStats():get(CharacterStat.POISON)
    local action=ISDisinfect:new(player,player,liquid,part);assert(action:complete())
    near(Q.rawAmount(Q.fluid(liquid)),.85,'Direct disinfect volume');near(dose(liquid),.74375,'Direct disinfect dose')
    assert(part:getAlcoholLevel()>previous,'Native treatment did not happen')
    near(player:getStats():get(CharacterStat.POISON),poison,'Disinfection must not ingest poison')
    inv:Remove(liquid)
    print('[HCRNativeWhiskey160] ten manual/auto non-food sinks and direct disinfect PASS')
end
local function mixing(player)
    local holder,inv=bag(player)
    local a=bottle(inv,'rotten',.875)
    local b=inv:AddItem('Base.Whiskey');Q.fluid(b):setCanPlayerEmpty(true);Q.fluid(b):adjustAmount(.5)
    local c=inv:AddItem('Base.Pot');Q.fluid(c):Empty();Q.fluid(c):addFluid('Water',.5)
    assert(not Q.active(b,Q.fluid(b)),'Ordinary bottle already tracked')
    local function move(source,target,litres)
        local sf,tf=Q.fluid(source),Q.fluid(target)
        local amount=Q.rawAmount(sf);local before,after=dose(source),dose(target)
        local action=ISFluidTransferAction:new(player,ISFluidContainer:new(sf),sf,ISFluidContainer:new(tf),tf,litres)
        action:complete();assert(not action.hcrFluidRefused,'Native quality transfer refused')
        near(dose(source),before*(1-litres/amount),'Mixed source dose')
        near(dose(target),after+before*litres/amount,'Mixed target dose')
    end
    move(a,b,.25);move(b,a,.2);move(a,c,.4);move(b,c,.1)
    near(dose(a)+dose(b)+dose(c),.875,'All mixed dose')
    local saved={boot=HCRLabNativeWhiskeyBoot,rows={}}
    for _,item in ipairs({a,b,c}) do
        local fluid=Q.fluid(item)
        assert(L.volume(Q.capture(item,fluid).ledger)==0,'Quality acquired phantom volume')
        saved.rows[#saved.rows+1]={id=item:getID(),dose=dose(item),volume=Q.rawAmount(fluid),
            whiskey=fluid:getSpecificFluidAmount(Fluid.Whiskey),water=fluid:getSpecificFluidAmount(Fluid.Water),
            hunger=item:getModData()[Q.key].lots[1].food.spoilHunger}
    end
    holder:getModData().HCRNativeWhiskeySaved=saved
    print('[HCRNativeWhiskey160] four native bidirectional/mixed transfers PASS; three cold samples saved')
end
function HCRLabNativeWhiskey.verify(player)
    local all=player:getInventory():getItems();local checked=0
    for i=0,all:size()-1 do
        local holder=all:get(i);local saved=holder:getModData().HCRNativeWhiskeySaved
        if saved then
            assert(saved.boot~=HCRLabNativeWhiskeyBoot,'Native Whiskey process was not restarted')
            local contents=holder:getItemContainer():getItems()
            for _,row in ipairs(saved.rows) do
                local found,count=nil,0
                for index=0,contents:size()-1 do
                    local item=contents:get(index)
                    if item:getID()==row.id then found=item;count=count+1 end
                end
                assert(count==1,'Saved native Whiskey absent/duplicated')
                local fluid=Q.fluid(found);local raw=found:getModData()[Q.key]
                assert(L.matches(raw,Q.amounts(fluid)) and L.quality(raw)=='rotten')
                near(L.budget(raw,'poisonPower'),row.dose,'Saved exact dose')
                near(Q.rawAmount(fluid),row.volume,'Saved volume')
                near(fluid:getSpecificFluidAmount(Fluid.Whiskey),row.whiskey,'Saved Whiskey')
                near(fluid:getSpecificFluidAmount(Fluid.Water),row.water,'Saved water')
                near(raw.lots[1].food.spoilHunger,row.hunger,'Saved spoil potency')
                checked=checked+1
            end
        end
    end
    assert(checked>=3,'No native Whiskey cold fixture')
    print('[HCRNativeWhiskey160] cold verification PASS '..checked..' independently saved samples')
end
function HCRLabNativeWhiskey.run(player)
    assert(player and not isClient() and not isServer(),'Private SP lab only')
    player:setUnlimitedCarry(true);HCRLabCraft.trainCooking(player,'HCRLab')
    for i=1,20 do if player:getPerkLevel(Perks.Cooking)>=10 then break end;player:getXp():AddXP(Perks.Cooking,10000) end
    production(player);drinking(player);sinks(player);mixing(player)
    print('[HCRNativeWhiskey160] PASS native production, consumption and non-food compatibility')
end
