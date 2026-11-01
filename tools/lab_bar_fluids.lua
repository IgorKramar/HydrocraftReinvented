-- Только private HCRLab: новые смеси и сохранение старого состояния.
require 'HCR_BarDrinks'
HCRLabBar={}
HCRLabBarBoot=HCRLabBarBoot or tostring(getTimestampMs())
local B,Q,L,F=HCRLabBar,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) return Q.capture(item,Q.fluid(item)).ledger end
function B.run(player)
    local S=HCRLabSpirits;local holder,inv=S.bag(player);local migrationCount=0
    for kind,spec in pairs(HCRBarCatalog.families) do
        if spec.unitLitres then
            for _,uses in ipairs({40,17,1,0}) do
                local old=instanceItem(kind);old:setCurrentUsesFloat(uses/40);assert(old:getCurrentUses()==uses)
                local item=assert(HCRItemMigrations.newReplacement(old));inv:AddItem(item)
                S.inspect(item,uses*.025,0,0,'fresh');migrationCount=migrationCount+1
            end
        else
            for _,fraction in ipairs({1,.5,.25}) do
                S.inspect(S.migrated(inv,kind,fraction,true),fraction,123.5,.875,'rotten');migrationCount=migrationCount+1
            end
        end
    end
    assert(migrationCount==21);player:getInventory():Remove(holder)
    local cases={{'Make Lemon Mixer','lemon'},{'Make Lime Mixer','lime'},{'Make Bloody Mary Mixer','tomato'}}
    local count=0
    for _,manual in ipairs({true,false}) do for _,case in ipairs(cases) do
    for _,quality in ipairs({'fresh','stale','rotten'}) do for _,diluted in ipairs({false,true}) do
        holder,inv=S.bag(player)
        local source=S.migrated(inv,'Hydrocraft.HCWhiskey'..case[2]..'juice',.5,true,quality)
        local fluid=Q.fluid(source)
        if diluted then fluid:addFluid('Water',.125) end
        local amount=Q.rawAmount(fluid);local before=raw(source)
        local expectedCalories=L.budget(before,'calories')*.1/amount
        local expectedDose=L.budget(before,'poisonPower')*.1/amount
        local bottle=inv:AddItem(manual and HCRBarCatalog.products[case[1]].target or 'Base.Whiskey');Q.fluid(bottle):Empty()
        local groups={{bottle}};local solids={}
        if case[2]=='tomato' then
            for _,kind in ipairs({'Base.Salt','Base.Pepper','Hydrocraft.HCHotsauce'}) do
                local item=inv:AddItem(kind)
                if item:IsFood() then
                    item:setAge(0);F.store(item,.5)
                    solids[#solids+1]={item=item,calories=item:getCalories(),dose=F.dose(item)}
                end
                groups[#groups+1]={item}
            end
        end
        groups[#groups+1]={source}
        local output=S.craft(player,inv,case[1],groups,manual)[1]
        for _,entry in ipairs(solids) do
            local remains=entry.item:getContainer() and entry.item:getCurrentUses()>0
            expectedCalories=expectedCalories+entry.calories-(remains and entry.item:getCalories() or 0)
            expectedDose=expectedDose+entry.dose-F.dose(entry.item)
        end
        S.inspect(output,.1,expectedCalories,expectedDose,quality)
        S.inspect(source,amount-.1,L.budget(before,'calories')*(1-.1/amount),L.budget(before,'poisonPower')*(1-.1/amount),quality)
        assert(not bottle:getContainer(),'Duplicate mixer bottle')
        assert(inv:getItems():size()==#groups,'Unexpected mixer physical items')
        if manual and quality=='fresh' and not diluted then
            local record={boot=HCRLabBarBoot,id=output:getID(),amount=.1,ledger=L.copy(output:getModData()[Q.key])}
            holder:getModData().HCRBarCold=record;holder:setName('HCRLab mixer cold sample')
        else player:getInventory():Remove(holder) end
        count=count+1
    end end end end
    assert(count==36)
    for _,diluted in ipairs({false,true}) do
        holder,inv=S.bag(player)
        local source=S.migrated(inv,'Hydrocraft.HCWhiskeylemonjuice',diluted and .08 or .10005,true)
        if diluted then Q.fluid(source):addFluid('Water',.02005) end
        local bottle=inv:AddItem('Hydrocraft.HCLemonmixerFluid')
        local output=S.craft(player,inv,'Make Lemon Mixer',{{bottle},{source}},true)[1]
        S.inspect(output,.1,123.5,.875,'rotten')
        assert(Q.fluid(source):isEmpty(),'Native pruning fixture did not empty donor')
        near(L.budget(raw(source),'poisonPower'),0,'Pruned donor dose')
        player:getInventory():Remove(holder)
    end
    print('[HCRBar160] 21 legacy migrations + 36 manual/auto mixer crafts, diluted/fresh/stale/rotten PASS')
    print('[HCRBar160] pure/diluted .10005 L native pruning conserves all nutrition and poison PASS')
    for _,case in ipairs({{lots=127,water=2},{lots=1,water=129}}) do
        holder,inv=S.bag(player)
        local source=S.migrated(inv,'Hydrocraft.HCWhiskeylemonjuice',.5,true)
        local value=raw(source);local many=L.empty()
        for i=1,case.lots do
            local food=L.copy(value.lots[1].food);food.calories=i
            many=L.mix(many,L.batch('HCRJuiceLemon',.5/case.lots,food,getGameTime():getWorldAgeHours()))
        end
        Q.store(source,Q.fluid(source),many)
        local waters={}
        for i=1,case.water do
            local water=inv:AddItem('Base.PopBottle');local fluid=Q.fluid(water)
            fluid:Empty();fluid:addFluid('Water',.2+i/200);waters[#waters+1]=water
        end
        local bottle=inv:AddItem('Hydrocraft.HCLemonmixerFluid')
        local output=S.craft(player,inv,'Make Lemon Mixer',{{bottle},{source}},false)[1]
        near(Q.rawAmount(Q.fluid(output)),.1,'Busy inventory mixer output')
        near(L.budget(raw(output),'calories'),L.budget(many,'calories')*.2,'Busy inventory nutrition')
        for i,water in ipairs(waters) do near(Q.rawAmount(Q.fluid(water)),.2+i/200,'Unrelated water untouched') end
        player:getInventory():Remove(holder)
    end
    print('[HCRBar160] auto preflight ignores unrelated water: 127 juice lots +2 waters and 1 lot +129 waters PASS')
end
function B.verify(player)
    local items=player:getInventory():getItems();local count=0
    for i=0,items:size()-1 do
        local bag=items:get(i);local saved=bag:getModData().HCRBarCold
        if saved then
            assert(saved.boot~=HCRLabBarBoot,'Not a cold game process')
            local item=bag:getItemContainer():getItemById(saved.id);assert(item,'Missing saved mixer')
            local ledger=assert(item:getModData()[Q.key]);L.validate(ledger)
            near(Q.rawAmount(Q.fluid(item)),saved.amount,'Cold mixer volume')
            assert(L.matches(ledger,Q.amounts(Q.fluid(item))) and L.quality(ledger)==L.quality(saved.ledger))
            for _,key in ipairs({'calories','poisonPower','thirstChange','hungChange'}) do
                near(L.budget(ledger,key),L.budget(saved.ledger,key),'Cold mixer '..key)
            end
            count=count+1
        end
    end
    assert(count>=3,'Missing cold samples');print('[HCRBar160] COLD PASS '..count)
end
function B.chain(player)
    local S=HCRLabSpirits;local holder,inv=S.bag(player)
    local source=S.migrated(inv,'Hydrocraft.HCWhiskeylemonjuice',.5,true)
    local bottle=inv:AddItem('Hydrocraft.HCLemonmixerFluid')
    local mixer=S.craft(player,inv,'Make Lemon Mixer',{{bottle},{source}},true)[1]
    local mixerDose=L.budget(raw(mixer),'poisonPower')
    local spirit=S.migrated(inv,'Hydrocraft.HCDrinkglassshortwhiskey',1,true)
    local result=S.craft(player,inv,'Mix Whiskey Sour',{{inv:AddItem('Base.Spoon')},{spirit},{mixer},{inv:AddItem('Base.Sugar')}},true)[1]
    near(L.budget(raw(result),'poisonPower'),.875+mixerDose,'Actual mixer to cocktail poison')
    assert(L.quality(raw(result))=='rotten' and mixer:getContainer()==inv and Q.fluid(mixer):isEmpty())
    assert(not spirit:getContainer(),'Actual cocktail duplicated glass')
    player:getInventory():Remove(holder)
    print('[HCRBar160] actual juice -> mixer -> Whiskey Sour; retained empty mixer bottle PASS')
end
function B.show(player)
    if HCRLabBarTooltip then HCRLabBarTooltip:removeFromUIManager() end
    local all=player:getInventory():getItems();local item
    for i=0,all:size()-1 do
        local holder=all:get(i);local record=holder:getModData().HCRBarCold
        if record then item=holder:getItemContainer():getItemById(record.id) end
    end
    assert(item,'No saved mixer to display')
    getGameTime():setTimeOfDay(12)
    local ui=ISToolTipInv:new(item);ui:initialise();ui:setCharacter(player)
    ui.followMouse=false;ui:setX(40);ui:setY(90);ui:addToUIManager();ui:setVisible(true)
    HCRLabBarTooltip=ui
end
