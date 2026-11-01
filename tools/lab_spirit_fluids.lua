-- Только private HCRLab: native craft и сохранение бутылок/бокалов.
require 'HCR_SpiritCatalog'
require 'TimedActions/ISGrabItemAction'
HCRLabSpirits={}
HCRLabSpiritsBoot=HCRLabSpiritsBoot or tostring(getTimestampMs())
local Q,L,E,F,S=HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality,HCRSpiritCatalog
local function near(a,b,label) assert(math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function bag(player)
    local holder=player:getInventory():AddItem('Base.Bag_Schoolbag')
    return holder,holder:getItemContainer()
end
local function migrated(inv,kind,fraction,changed,state)
    local old=assert(instanceItem(kind));old:setAge(0)
    if kind=='Hydrocraft.HCSoymilk' then old:setCooked(true) end
    if old:getBaseHunger()==0 then old:setThirstChange(old:getThirstChangeUnmodified()*fraction)
    else old:setHungChange(old:getBaseHunger()*fraction) end
    if changed then old:setCalories(123.5);F.store(old,.875);F.setQuality(old,state or 'rotten') end
    old:setFavorite(true)
    local item=assert(HCRItemMigrations.newReplacement(old),'Spirit migration '..kind)
    assert(item:isFavorite() and not HCRItemMigrations.newReplacement(item),'Migration repeated/lost favourite')
    item:setFavorite(false);inv:AddItem(item);return item
end
local function inspect(item,litres,calories,dose,state)
    local ledger=Q.capture(item,Q.fluid(item)).ledger
    near(Q.rawAmount(Q.fluid(item)),litres,'Volume');near(L.budget(ledger,'calories'),calories,'Calories')
    near(L.budget(ledger,'poisonPower'),dose,'Poison');assert(L.quality(ledger)==state,'Freshness '..item:getFullType())
end
local function pristine(inv,kind)
    local item=instanceItem(kind);if item:IsFood() then item:setAge(0) end
    if HCRBarCatalog and HCRBarCatalog.families[kind]
        or HCRSoftDrinkCatalog and HCRSoftDrinkCatalog.families[kind] then
        item=assert(HCRItemMigrations.newReplacement(item))
    end
    inv:AddItem(item);return item
end
local function craft(player,inv,name,groups,manual,refused,allowEmpty)
    print('[HCRSpirits160] craft '..name..' manual='..tostring(manual))
    local recipe=assert(HCRLabCraft.findRecipe(name));player:learnRecipe(name)
    local logic=HandcraftLogic.new(player,nil,nil);local containers=ArrayList.new();containers:add(inv)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(manual);logic:updateFloorContainer(containers)
    if manual then
        logic:clearManualInputs()
        for slot,group in ipairs(groups) do
            local items=ArrayList.new();for _,item in ipairs(group) do items:add(item) end
            local accepted=logic:setManualInputsFor(recipe:getInputs():get(slot-1),items)
            if not accepted and refused then return nil end
            assert(accepted,'Manual slot '..slot..' '..name)
        end
    end
    local ready=logic:getRecipeData():canConsumeInputs(logic:getSourceResources())
    if not ready and refused then return nil end
    assert(ready,'Native ingredients '..name)
    local action={logic=logic,character=player};ISHandcraftAction.performRecipe(action)
    if refused then assert(action.hcrFluidRefused,'Unsafe craft accepted '..name);return nil end
    assert(not action.hcrFluidRefused,'Craft refused '..name)
    local result={};local outputs=logic:getRecipeData():getAllCreatedItems()
    assert(allowEmpty or outputs:size()>0,'No outputs '..name)
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
local function migrations(player)
    local count=0
    for kind,spec in pairs(S.families) do
        local holder,inv=bag(player)
        local pristine=migrated(inv,kind,1,false)
        inspect(pristine,spec.litres,instanceItem(kind):getCalories(),0,'fresh')
        for _,fraction in ipairs({1,.5,.25}) do
            inspect(migrated(inv,kind,fraction,true),spec.litres*fraction,123.5,.875,'rotten');count=count+1
        end
        player:getInventory():Remove(holder)
    end
    assert(count==108);print('[HCRSpirits160] 36 pristine + 108 modified/partial migrations PASS')
end
local distills={
    {'Vodka','potato','Potato'}, {'Tequila','blueagave','Blue Agave'}, {'Mezcal','blueagave','Blue Agave'},
    {'Applejack','apple','Apple'}, {'Peach Schnapps','peach','Peach'}, {'Flip','pumpkin','Pumpkin'},
    {'Gin','juniper','Juniper Berry'}, {'Corn Whiskey','corn','Corn'},
}
local function production(player)
    -- Полная цепочка теперь включает реальные жидкости и часы брожения.
    require 'HCRLabMash'
    HCRLabMash.run(player)
end
local empties={Short='HCGlassshortempty',Tall='HCGlasstallempty',Cocktail='HCCocktailglassempty'}
local function pours(player)
    for _,manual in ipairs({true,false}) do
    for name,rule in pairs(S.pours) do
        local holder,inv=bag(player);local shape=name:match('Pour (%w+)')
        local empty=inv:AddItem(manual and 'Hydrocraft.'..empties[shape] or rule.target)
        local source,calories
        if name:find('Bottled Whiskey') then
            source=inv:AddItem('Base.Whiskey');Q.fluid(source):setCanPlayerEmpty(true)
            calories=Q.fluid(source):getProperties():getCalories()
            Q.store(source,Q.fluid(source),HCRNativeWhiskey.ledger(Q.fluid(source),{dose=.875,quality='rotten',detection=4},1))
        else
            local kind=name:find('Gin') and 'HCGin1' or name:find('Vodka') and 'HCVodka' or name:find('Rum') and 'HCRum1' or 'HCWhiskeycorn'
            source=migrated(inv,'Hydrocraft.'..kind,1,true);calories=123.5
        end
        local output=craft(player,inv,name,{{empty},{source}},manual)[1]
        inspect(output,.1,calories*.1,.0875,'rotten')
        near(Q.rawAmount(Q.fluid(source)),.9,'Pour remainder')
        near(L.budget(Q.capture(source,Q.fluid(source)).ledger,'poisonPower'),.7875,'Pour remaining poison')
        assert(not empty:getContainer(),'Input glass duplicated')
        player:getInventory():Remove(holder)
    end end
    print('[HCRSpirits160] 30 manual/auto pours conserve native/HC calories and exact dose PASS')
end
local cocktails={
    {'Mix Old Fashioned','glassshortwhiskey','HCBitters','Base.Sugar','HCSlicedorange'},
    {'Mix Martini','cocktailglassgin','HCBitters','HCVermouth'},
    {'Mix Manhattan','cocktailglasswhiskey','HCBitters','HCVermouth'},
    {'Mix Bloody Mary','glasstallvodka','HCBloodymarymixer'},
    {'Mix Whiskey Sour','glassshortwhiskey','HCLemonmixer','Base.Sugar'},
    {'Mix Cosmopolitan','cocktailglassvodka','HCTriplesec','HCLimemixer','HCSlicedlime'},
    {'Mix Tom Collins','glasstallgin','HCLemonmixer','Base.Sugar'},
    {'Mix Long Island Iced Tea','glasstallvodka','HCRum1','HCLemonmixer','HCLimemixer','HCTriplesec','Base.Sugar'},
    {'Mix Gimlet','cocktailglassgin','HCLimemixer','Base.Sugar'},
    {'Whiskey and Coke','glasstallwhiskey','HCSodacola'},
    {'Whiskey and Coke (Canned Cola)','glasstallwhiskey','Base.Pop'},
    {'Mix Daquiri','cocktailglassrum','HCLimemixer','Base.Sugar','HCSlicedlime'},
    {'Mix Mai Tai','glassshortrum','HCLimemixer','Base.Sugar','HCTriplesec'},
    {"Mix Planter's Punch",'glassshortrum','HCBitters','HCLemonmixer','Base.Sugar'},
}
local function consumers(player)
    for _,manual in ipairs({true,false}) do
    for _,case in ipairs(cocktails) do
        local holder,inv=bag(player);local liquid=migrated(inv,'Hydrocraft.HCDrink'..case[2],1,true)
        local groups={};local rum
        if case[1]:find('Mix ') then groups[1]={inv:AddItem('Base.Spoon')} end
        groups[#groups+1]={liquid}
        for i=3,#case do
            local kind=case[i]:find('%.') and case[i] or 'Hydrocraft.'..case[i]
            local item
            if kind=='Hydrocraft.HCRum1' then item=migrated(inv,kind,1,true);rum=item
            else item=pristine(inv,kind) end
            groups[#groups+1]={item}
        end
        local output=craft(player,inv,case[1],groups,manual)[1]
        near(L.budget(Q.capture(output,Q.fluid(output)).ledger,'poisonPower'),rum and .9625 or .875,'Cocktail dose');assert(L.quality(Q.capture(output,Q.fluid(output)).ledger)=='rotten')
        if rum then inspect(rum,.9,111.15,.7875,'rotten') end
        assert(not liquid:getContainer(),'Cocktail duplicated glass')
        player:getInventory():Remove(holder)
    end
    for _,suffix in ipairs({'',' (Cup of Irish Coffee)',' (Cup of Irish Coffee 2)',' (Cup of Irish Coffee 3)'}) do
        local holder,inv=bag(player)
        local clay=suffix==' (Cup of Irish Coffee)' or suffix==' (Cup of Irish Coffee 3)'
        local mug=inv:AddItem(clay and 'Hydrocraft.HCClaymugFluid' or 'Base.Mugl');Q.fluid(mug):Empty()
        local water=inv:AddItem('Base.Whiskey');Q.fluid(water):Empty();Q.fluid(water):addFluid('Water',1)
        local powder=inv:AddItem(suffix:find('[23]') and 'Hydrocraft.HCCoffeelarge' or 'Base.Coffee2');powder:setAge(0)
        local liquid=migrated(inv,'Hydrocraft.HCDrinkglassshortwhiskey',1,true)
        local output=craft(player,inv,'Brew Irish Coffee'..suffix,{{mug},{water},{powder},{liquid}},manual)[1]
        near(L.budget(Q.capture(output,Q.fluid(output)).ledger,'poisonPower'),.875,'Irish coffee dose');assert(L.quality(Q.capture(output,Q.fluid(output)).ledger)=='rotten')
        assert(liquid:getContainer()==inv and Q.fluid(liquid):isEmpty(),'Irish coffee lost whiskey glass')
        assert(not mug:getContainer(),'Irish coffee duplicated mug')
        player:getInventory():Remove(holder)
    end
    local holder,inv=bag(player);local tequila=migrated(inv,'Hydrocraft.HCTequila',1,true)
    local groups={{inv:AddItem('Base.Spoon')},{inv:AddItem('Hydrocraft.HCMargaritaglassempty')},{tequila}}
    for _,kind in ipairs({'Hydrocraft.HCTriplesec','Hydrocraft.HCLemonmixer','Base.Salt','Hydrocraft.HCSlicedlime'}) do
        groups[#groups+1]={pristine(inv,kind)}
    end
    local output=craft(player,inv,'Mix Margarita',groups,manual)[1]
    near(L.budget(Q.capture(output,Q.fluid(output)).ledger,'poisonPower'),.0875,'Margarita dose');assert(L.quality(Q.capture(output,Q.fluid(output)).ledger)=='rotten')
    inspect(tequila,.9,111.15,.7875,'rotten');player:getInventory():Remove(holder)
    end
    print('[HCRSpirits160] 38 manual/auto cocktail + Irish coffee + Margarita consumers PASS')
end
HCRLabSpirits.craft=craft
HCRLabSpirits.bag=bag
HCRLabSpirits.migrated=migrated
HCRLabSpirits.inspect=inspect
local function cooking(player)
    local eligible=HCRAlcoholPortions.rules['Prepare Spirit for Cooking'].inputs[0].sourceTypes
    for source,spec in pairs(S.families) do
        if spec.litres==1 then
            local holder,inv=bag(player);local item=migrated(inv,source,1,true)
            local vessel=inv:AddItem('Base.GlassTumbler');Q.fluid(vessel):Empty()
            local herbal=source=='Hydrocraft.HCAbsinth' or source=='Hydrocraft.HCHerballiqueur'
            local mead=source=='Hydrocraft.HCMead2'
            if eligible[source] or herbal or mead then
                local amount=herbal and .8 or mead and .4 or .2
                if herbal or mead then
                    inv:Remove(vessel);vessel=inv:AddItem(herbal and 'Hydrocraft.HCHerballiqueurFluid' or 'Hydrocraft.HCAlestienFluid')
                end
                local name=herbal and 'Prepare Herbal Spirit for Cooking' or mead and 'Prepare Mead for Cooking' or 'Prepare Spirit for Cooking'
                local output=craft(player,inv,name,{{item},{vessel}},true)[1]
                near(output:getCalories(),123.5*amount,'Cooking nutrition');near(F.dose(output),.875*amount,'Cooking dose')
                inspect(item,1-amount,123.5*(1-amount),.875*(1-amount),'rotten')
            else
                craft(player,inv,'Prepare Spirit for Cooking',{{item},{vessel}},true,true)
                inspect(item,1,123.5,.875,'rotten');assert(vessel:getContainer()==inv)
            end
            player:getInventory():Remove(holder)
        end
    end
    print('[HCRSpirits160] 22 eligible bottle cooking portions; homemade vodka and zero-hunger Agua refused PASS')
end
local function herbalEvolved(player)
    local inv=player:getInventory();local recipes=getScriptManager():getAllEvolvedRecipes();local evolved
    for i=0,recipes:size()-1 do if recipes:get(i):getFullResultItem()=='Base.PotOfSoupRecipe' then evolved=recipes:get(i);break end end
    assert(evolved,'Native soup recipe')
    local function pot() local p=inv:AddItem('Base.Pot');Q.fluid(p):Empty();Q.fluid(p):addFluid('Water',1.5);return p end
    for _,kind in ipairs({'Hydrocraft.HCAbsinth','Hydrocraft.HCHerballiqueur'}) do
        local previous={};local all=inv:getItems()
        for i=0,all:size()-1 do previous[all:get(i):getID()]=true end
        local function newVessels()
            local result={};local all=inv:getItems()
            for i=0,all:size()-1 do
                local item=all:get(i)
                if item:getFullType()=='Hydrocraft.HCHerballiqueurFluid' and not previous[item:getID()] then result[#result+1]=item end
            end
            return result
        end
        local holder,inputs=bag(player);local source=migrated(inputs,kind,1,true)
        local empty=inputs:AddItem('Hydrocraft.HCHerballiqueurFluid')
        local portion=craft(player,inputs,'Prepare Herbal Spirit for Cooking',{{source},{empty}},true)[1]
        inputs:Remove(portion);inv:AddItem(portion)
        local action={recipe=evolved,baseItem=pot(),usedItem=portion,character=player}
        assert(ISAddItemInRecipe.complete(action),'Herbal native evolved completion')
        local legacy=inv:AddItem(kind);legacy:setAge(0);legacy:setReplaceOnUse(nil);legacy:setCalories(123.5)
        F.store(legacy,.875);F.setQuality(legacy,'rotten')
        local reference={recipe=evolved,baseItem=pot(),usedItem=legacy,character=player}
        assert(ISAddItemInRecipe.complete(reference),'Legacy herbal evolved completion')
        for _,getter in ipairs({'getCalories','getCarbohydrates','getProteins','getLipids','getHungChange'}) do
            near(action.baseItem[getter](action.baseItem),reference.baseItem[getter](reference.baseItem),'Herbal evolved parity '..getter)
        end
        near(F.dose(action.baseItem),F.dose(reference.baseItem),'Herbal evolved dose')
        local transferred=F.dose(action.baseItem);local iterations=1
        near(transferred+F.dose(portion),.7,'Herbal exact poison')
        assert(#newVessels()==(portion:getContainer() and 0 or 1),'Early herbal bottle return')
        while portion:getContainer() do
            iterations=iterations+1;assert(iterations<40,'Herbal portion never depleted')
            local nextAction={recipe=evolved,baseItem=pot(),usedItem=portion,character=player}
            assert(ISAddItemInRecipe.complete(nextAction),'Repeated herbal addition')
            transferred=transferred+F.dose(nextAction.baseItem)
            near(transferred+F.dose(portion),.7,'Repeated herbal exact dose')
            assert(#newVessels()==(portion:getContainer() and 0 or 1),'Repeated herbal bottle return')
            inv:Remove(nextAction.baseItem)
        end
        assert(iterations>1,'Herbal partial use not exercised')
        local vessels=newVessels()
        assert(#vessels==1 and Q.fluid(vessels[1]):isEmpty(),'Herbal returned bottle missing/duplicated/filled')
        for _,item in ipairs({vessels[1],legacy,action.baseItem,reference.baseItem,holder}) do inv:Remove(item) end
    end
    print('[HCRSpirits160] herbal native evolved parity and exactly one empty bottle PASS')
end
local function aguardiente(player)
    local inv=player:getInventory();local stats,body,nutrition=player:getStats(),player:getBodyDamage(),player:getNutrition()
    local names={'HUNGER','THIRST','POISON','PAIN','INTOXICATION','BOREDOM','UNHAPPINESS','FATIGUE','STRESS','ENDURANCE'}
    local function reset()
        for _,name in ipairs(names) do stats:set(CharacterStat[name],name=='HUNGER' and .5 or 0) end
        nutrition:setCalories(0);body:setHealthFromFoodTimer(0)
    end
    local function values()
        local result={calories=nutrition:getCalories(),timer=body:getHealthFromFoodTimer()}
        for _,name in ipairs(names) do result[name]=stats:get(CharacterStat[name]) end
        return result
    end
    local old=inv:AddItem('Hydrocraft.HCAguaardiente');old:setAge(0)
    reset();assert(player:Eat(old,.25,false));local expected=values()
    near(old:getThirstChangeUnmodified(),-.075,'Native zero-hunger remainder')
    local recovered=assert(HCRItemMigrations.newReplacement(old));inv:AddItem(recovered)
    inspect(recovered,.75,1612.5,0,'fresh')
    local native=migrated(inv,'Hydrocraft.HCAguaardiente',1,false)
    reset();ISDrinkFluidAction:new(player,native,.25):updateEat(1);local actual=values()
    for key,value in pairs(expected) do near(actual[key],value,'Zero-hunger drink parity '..key) end
    inspect(native,.75,1612.5,0,'fresh')
    -- После переноса остатка сохраняется именно исходная формула этого Food.
    reset();assert(player:Eat(old,.5,false));expected=values()
    reset();ISDrinkFluidAction:new(player,recovered,.5):updateEat(1);actual=values()
    for key,value in pairs(expected) do near(actual[key],value,'Partial zero-hunger parity '..key) end
    for _,item in ipairs({old,recovered,native}) do inv:Remove(item) end
    stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.INTOXICATION,0)
    for _,manual in ipairs({true,false}) do
    for _,soy in ipairs({true,false}) do
        local holder,inputs=bag(player);local alcohol=migrated(inputs,'Hydrocraft.HCAguaardiente',1,true)
        local milk=soy and migrated(inputs,'Hydrocraft.HCSoymilk',1,false) or inputs:AddItem('Base.Milk')
        local sugar=inputs:AddItem('Base.Sugar');local coffee=inputs:AddItem('Base.Coffee2')
        local pot=inputs:AddItem('Base.Pot');Q.fluid(pot):Empty()
        local output=craft(player,inputs,'Make Monkey Tail Pot',{{milk},{sugar},{alcohol},{coffee},{pot}},manual)[1]
        if Q.fluid(output) then
            local ledger=Q.capture(output,Q.fluid(output)).ledger
            near(L.budget(ledger,'poisonPower'),.875,'Monkey Tail exact dose');assert(L.quality(ledger)=='rotten')
        else near(F.dose(output),.875,'Monkey Tail exact dose');assert(F.quality(output)=='rotten') end
        assert(alcohol:getContainer()==inputs and Q.fluid(alcohol):isEmpty(),'Monkey Tail lost bottle')
        player:getInventory():Remove(holder)
    end end
    print('[HCRSpirits160] zero-hunger native drinking, partial recovery and four Monkey Tail crafts PASS')
end
local function mixed(player)
    local holder,inv=bag(player)
    local source=migrated(inv,'Hydrocraft.HCWhiskey1',.8,true)
    local donor=inv:AddItem('Base.Whiskey');local df=Q.fluid(donor);df:setCanPlayerEmpty(true)
    local nativeCalories=df:getProperties():getCalories()
    Q.store(donor,df,HCRNativeWhiskey.ledger(df,{dose=.875,quality='rotten',detection=4},1))
    local function move(a,b,amount)
        local af,bf=Q.fluid(a),Q.fluid(b)
        local action=ISFluidTransferAction:new(player,ISFluidContainer:new(af),af,ISFluidContainer:new(bf),bf,amount)
        action:complete();assert(not action.hcrFluidRefused,'Spirit transfer refused')
    end
    move(donor,source,.2)
    local empty=inv:AddItem('Hydrocraft.HCGlassshortFluid')
    local glass=craft(player,inv,'Pour Short Glass of Whiskey',{{empty},{source}},true)[1]
    inspect(glass,.1,(123.5+.2*nativeCalories)*.1,.105,'rotten')
    local raw=inv:AddItem('Hydrocraft.HCGlassshortFluid');move(donor,raw,.1)
    local output=craft(player,inv,'Mix Old Fashioned',{{inv:AddItem('Base.Spoon')},{raw},
        {pristine(inv,'Hydrocraft.HCBitters')},{inv:AddItem('Base.Sugar')},{inv:AddItem('Hydrocraft.HCSlicedorange')}},true)[1]
    near(L.budget(Q.capture(output,Q.fluid(output)).ledger,'poisonPower'),.0875,'Native Whiskey glass cocktail');assert(not raw:getContainer())
    player:getInventory():Remove(holder)
    print('[HCRSpirits160] mixed native/HC pour and directly transferred native Whiskey cocktail PASS')
end
function HCRLabSpirits.guard(player)
    local inv=player:getInventory();local recipes=getScriptManager():getAllEvolvedRecipes();local evolved
    for i=0,recipes:size()-1 do if recipes:get(i):getFullResultItem()=='Base.PotOfSoupRecipe' then evolved=recipes:get(i);break end end
    assert(evolved,'Native soup recipe')
    for _,case in ipairs({'fresh','modified','spice'}) do
        local old=inv:AddItem('Hydrocraft.HCAguaardiente');old:setAge(0)
        if case~='fresh' then
            old:setThirstChange(.1);old:setCalories(123.5);F.store(old,.875);F.setQuality(old,'rotten')
            assert(not HCRItemMigrations.newReplacement(old),'Invalid thirst must defer migration')
            if case=='spice' then old:setSpice(true) end
        end
        local pot=inv:AddItem('Base.Pot');Q.fluid(pot):Empty();Q.fluid(pot):addFluid('Water',1.5)
        local calories,dose,quality=old:getCalories(),F.dose(old),F.quality(old)
        local action=ISAddItemInRecipe:new(player,evolved,pot,old)
        for _,name in ipairs({'isValidStart','isValid','complete'}) do
            assert(not action[name](action),'Unsafe native action '..name)
        end
        assert(HCRFoodTransfers.addIngredient(evolved,pot,old,player)==pot)
        assert(action.baseItem==pot and old:getContainer()==inv and pot:getContainer()==inv)
        near(old:getCalories(),calories,'Refusal calories');near(F.dose(old),dose,'Refusal poison')
        near(Q.rawAmount(Q.fluid(pot)),1.5,'Refusal pot volume');assert(F.quality(old)==quality)
        old:setHungChange(-.1);assert(action:isValid(),'Modified nonzero hunger blocked')
        inv:Remove(old);inv:Remove(pot)
    end
    print('[HCRSpirits160] legacy Agua fresh/modified deferred native action safe refusal PASS')
end
function HCRLabSpirits.run(player)
    assert(not isClient() and not isServer())
    local carry=player:isUnlimitedCarry();player:setUnlimitedCarry(true)
    local ok,reason=pcall(function()
        migrations(player);production(player);pours(player);consumers(player);cooking(player);herbalEvolved(player);aguardiente(player);mixed(player)
        local holder,inv=bag(player);holder:setName('HCRLab spirit cold samples')
        local record={boot=HCRLabSpiritsBoot,rows={}}
        for _,kind in ipairs({'HCVodka','HCMezcal','HCDrinkglasstallwhiskey','HCBourbon1','HCRum1','HCDrinkcocktailglassrum','HCAbsinth','HCHerballiqueur','HCMead2','HCAguaardiente'}) do
            local item=migrated(inv,'Hydrocraft.'..kind,.5,true)
            record.rows[#record.rows+1]={id=item:getID(),kind=item:getFullType(),ledger=L.copy(item:getModData()[Q.key]),amount=Q.rawAmount(Q.fluid(item))}
        end
        holder:getModData().HCRSpiritCold=record
    end)
    player:setUnlimitedCarry(carry);assert(ok,reason)
    print('[HCRSpirits160] ALL PASS')
end
function HCRLabSpirits.verify(player)
    local count=0;local items=player:getInventory():getItems()
    for i=0,items:size()-1 do
        local holder=items:get(i);local saved=holder:getModData().HCRSpiritCold
        if saved then
            assert(saved.boot~=HCRLabSpiritsBoot,'Game process was not restarted')
            local contents=holder:getItemContainer():getItems()
            assert(contents:size()==#saved.rows,'Saved vessel count')
            for _,row in ipairs(saved.rows) do
                local item
                for n=0,contents:size()-1 do if contents:get(n):getID()==row.id then assert(not item);item=contents:get(n) end end
                assert(item and item:getFullType()==row.kind,'Saved vessel identity')
                near(Q.rawAmount(Q.fluid(item)),row.amount,'Cold amount')
                local raw=assert(item:getModData()[Q.key]);L.validate(raw)
                assert(L.quality(raw)==L.quality(row.ledger))
                for _,key in ipairs({'calories','poisonPower','hungChange','thirstChange','nativeAlcohol'}) do
                    near(L.budget(raw,key),L.budget(row.ledger,key),'Cold '..key)
                end
                assert(L.matches(raw,Q.amounts(Q.fluid(item))),'Cold composition');count=count+1
            end
        end
    end
    assert(count>=3,'No saved spirits');print('[HCRSpirits160] COLD PASS saved='..count)
end
