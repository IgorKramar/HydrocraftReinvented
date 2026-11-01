-- Только private HCRLab: реальный milk batch и пакетный разлив.
require 'HCR_MilkCocktailCatalog'
HCRLabMilkCocktails={}
HCRLabMilkCocktailBoot=HCRLabMilkCocktailBoot or tostring(getTimestampMs())
local C,Q,L,F=HCRLabMilkCocktails,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local function near(a,b,label) assert(math.abs(a-b)<.002,label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) return Q.capture(item,Q.fluid(item)).ledger end
local function budget(item)
    if Q.fluid(item) then
        local value=raw(item);local props=Q.fluid(item):getProperties()
        return L.budget(value,'calories')+props:getCalories(),L.budget(value,'poisonPower'),L.budget(value,'nativeAlcohol')+props:getAlcohol()
    elseif item:IsFood() then return item:getCalories(),F.dose(item),0 end
    return 0,0,0
end
local function snapshot(groups)
    local before={}
    for _,group in ipairs(groups) do for _,item in ipairs(group) do before[item]={budget(item)} end end
    return before
end
local function verify(outputs,before,rule,quality)
    local used={0,0,0};local totals={0,0,0}
    for item,value in pairs(before) do
        local after=item:getContainer() and {budget(item)} or {0,0,0}
        for i=1,3 do used[i]=used[i]+value[i]-after[i] end
    end
    assert(#outputs==rule.count)
    for _,item in ipairs(outputs) do
        local ledger=raw(item);local values={budget(item)}
        assert(item:getFullType()==rule.target)
        near(Q.rawAmount(Q.fluid(item)),rule.litres/rule.count,'Milk cocktail amount')
        assert(L.quality(ledger)==quality,'Milk cocktail quality')
        for i=1,3 do near(values[i],used[i]/rule.count,'Equal output portion');totals[i]=totals[i]+values[i] end
        if rule.safeEggSlot then for _,lot in ipairs(ledger.lots) do
            if lot.food.sourceType=='Base.Egg' then assert(not lot.food.dangerousUncooked,'New raw egg penalty') end
        end end
    end
    for i=1,3 do near(totals[i],used[i],'Conserved output budgets') end
end
local function save(holder,outputs)
    local rows={}
    for _,item in ipairs(outputs) do rows[#rows+1]={id=item:getID(),ledger=L.copy(item:getModData()[Q.key]),amount=Q.rawAmount(Q.fluid(item))} end
    holder:getModData().HCRMilkCocktailCold={boot=HCRLabMilkCocktailBoot,rows=rows}
    holder:setName('HCRLab milk cocktail cold samples')
end
local function food(inv,kind)
    local item=inv:AddItem(kind);item:setAge(0);F.store(item,.125);return item
end
function C.run(player)
    local S=HCRLabSpirits;local count=0
    -- Завершённый cold cocktail checkpoint уже сохранён в отчёте. Копии
    -- ledger в сотнях лабораторных сумок переполняют PlayerDB buffer.
    -- Удаляются только явно помеченные fixtures предыдущего среза.
    local previous=player:getInventory():getItems();local retired=0
    for i=previous:size()-1,0,-1 do
        local item=previous:get(i)
        if item:getModData().HCRCocktailCold then player:getInventory():Remove(item);retired=retired+1 end
    end
    print('[HCRMilkCocktail160] retired completed cocktail cold fixtures '..retired)
    for kind,spec in pairs(HCRMilkCocktailCatalog.families) do
        local holder,inv=S.bag(player)
        S.inspect(S.migrated(inv,kind,1,false),spec.litres,instanceItem(kind):getCalories(),0,'fresh')
        for _,fraction in ipairs({1,.5,.25}) do S.inspect(S.migrated(inv,kind,fraction,true),spec.litres*fraction,123.5,.875,'rotten') end
        player:getInventory():Remove(holder)
    end
    print('[HCRMilkCocktail160] 6 pristine + 18 modified/partial migrations PASS')
    for _,manual in ipairs({true,false}) do for _,eggnog in ipairs({true,false}) do
    for _,native in ipairs({true,false}) do for _,quality in ipairs({'fresh','stale','rotten'}) do
        local holder,inv=S.bag(player);local milk
        if native then milk=inv:AddItem('Base.Milk');Q.fluid(milk):Empty();Q.fluid(milk):addFluid('CowMilk',1)
        else milk=S.migrated(inv,'Hydrocraft.HCMilkjug',.5,true,quality) end
        local alcohol
        if eggnog then
            alcohol=inv:AddItem('Base.Whiskey')
            Q.store(alcohol,Q.fluid(alcohol),HCRNativeWhiskey.ledger(Q.fluid(alcohol),{quality=quality,dose=.875,detection=4},1))
        else alcohol=S.migrated(inv,'Hydrocraft.HCAguaardiente',1,true,quality) end
        local pot=inv:AddItem('Base.Pot');Q.fluid(pot):Empty()
        local groups={{milk},{food(inv,eggnog and 'Base.Egg' or 'Base.Sugar')},{alcohol}}
        if not eggnog then groups[#groups+1]={food(inv,'Base.Coffee2')} end
        groups[#groups+1]={pot};local before=snapshot(groups)
        local name='Make '..(eggnog and 'Eggnog' or 'Monkey Tail')..' Pot'
        local outputs=S.craft(player,inv,name,groups,manual)
        verify(outputs,before,HCRMilkCocktailCatalog.products[name],quality)
        assert(not pot:getContainer() and milk:getContainer()==inv and alcohol:getContainer()==inv,'Pot/ingredient vessels')
        if manual and not native then save(holder,outputs) else player:getInventory():Remove(holder) end
        count=count+1
    end end end end
    assert(count==24);print('[HCRMilkCocktail160] 24 milk/HC manual/auto fresh/stale/rotten production PASS')
    count=0
    for _,manual in ipairs({true,false}) do for _,eggnog in ipairs({true,false}) do
    for _,bottles in ipairs({true,false}) do for _,quality in ipairs({'fresh','stale','rotten'}) do
        local holder,inv=S.bag(player);local kind=eggnog and 'Hydrocraft.HCEggnogpot' or 'Hydrocraft.HCColademonopot'
        local a=S.migrated(inv,kind,1,true,quality);local b=bottles and S.migrated(inv,kind,.5,true,quality) or nil
        local donors=b and {a,b} or {a};local groups={donors};local empties={}
        if eggnog and not bottles then groups[#groups+1]={food(inv,'Base.Chocolate')} end
        local name='Make '..(eggnog and 'Eggnog' or 'Monkey Tail')..(bottles and ' Bottle' or eggnog and ' Cuppa' or ' Mug')
        local rule=HCRMilkCocktailCatalog.products[name]
        for i=1,rule.count do
            empties[i]=inv:AddItem(i%2==0 and rule.target or bottles and 'Base.Whiskey' or 'Base.Mugl');Q.fluid(empties[i]):Empty()
        end
        groups[#groups+1]=empties;local before=snapshot(groups)
        local outputs=S.craft(player,inv,name,groups,manual)
        verify(outputs,before,rule,quality)
        assert(a:getContainer()==inv and (not b or b:getContainer()==inv),'Pour lost source pot')
        near(Q.rawAmount(Q.fluid(a))+(b and Q.rawAmount(Q.fluid(b)) or 0),bottles and .25 or .7,'Pour remainder')
        for _,empty in ipairs(empties) do assert(not empty:getContainer(),'Duplicated output vessel') end
        if manual and quality=='stale' then save(holder,outputs) else player:getInventory():Remove(holder) end
        count=count+1
    end end end end
    assert(count==24);print('[HCRMilkCocktail160] 24 manual/auto 4-mug/2-bottle batch crafts incl pooled pots PASS')
    for _,manual in ipairs({true,false}) do
        local holder,inv=S.bag(player)
        local source=S.migrated(inv,'Hydrocraft.HCEggnogpot',1,true)
        local bottles={inv:AddItem('Hydrocraft.HCEggnogbottleFluid'),inv:AddItem('Hydrocraft.HCEggnogbottleFluid')}
        S.craft(player,inv,'Make Eggnog Bottle',{{source},bottles},manual,true)
        near(Q.rawAmount(Q.fluid(source)),1.5,'Insufficient batch not spent')
        for _,item in ipairs(bottles) do assert(item:getContainer()==inv and Q.fluid(item):isEmpty()) end
        local milk=S.migrated(inv,'Hydrocraft.HCMilkjug',.5,true,'fresh')
        local spirit=inv:AddItem('Base.Whiskey');local pot=inv:AddItem('Base.Pot');Q.fluid(pot):Empty();Q.fluid(pot):addFluid('Water',.01)
        local egg=food(inv,'Base.Egg')
        -- Уберите другие пустые кастрюли из auto candidates этого fixture.
        inv:Remove(source)
        S.craft(player,inv,'Make Eggnog Pot',{{milk},{egg},{spirit},{pot}},manual,true)
        assert(egg:getContainer()==inv and pot:getContainer()==inv)
        near(Q.rawAmount(Q.fluid(milk)),1,'Rejected milk unchanged');near(Q.rawAmount(Q.fluid(spirit)),1,'Rejected whiskey unchanged')
        near(Q.rawAmount(Q.fluid(pot)),.01,'Filled target not destroyed')
        player:getInventory():Remove(holder)
    end
    print('[HCRMilkCocktail160] manual/auto insufficient pooled source and filled destination refusals PASS')
    C.show(player)
end
function C.verify(player)
    local all=player:getInventory():getItems();local count=0
    for i=0,all:size()-1 do
        local holder=all:get(i);local saved=holder:getModData().HCRMilkCocktailCold
        if saved then
            assert(saved.boot~=HCRLabMilkCocktailBoot,'Not a cold process')
            for _,entry in ipairs(saved.rows) do
                local item=assert(holder:getItemContainer():getItemById(entry.id));local ledger=assert(item:getModData()[Q.key])
                L.validate(ledger);assert(L.matches(ledger,Q.amounts(Q.fluid(item))))
                near(Q.rawAmount(Q.fluid(item)),entry.amount,'Cold volume');assert(L.quality(ledger)==L.quality(entry.ledger))
                for _,key in ipairs({'calories','poisonPower','nativeAlcohol','fatigueChange','hungChange'}) do
                    near(L.budget(ledger,key),L.budget(entry.ledger,key),'Cold milk cocktail '..key)
                end
                count=count+1
            end
        end
    end
    assert(count>=18,'Missing cold milk cocktail samples');print('[HCRMilkCocktail160] COLD PASS '..count)
    C.show(player)
end
function C.show(player)
    if HCRLabMilkCocktailTooltip then HCRLabMilkCocktailTooltip:removeFromUIManager() end
    local all=player:getInventory():getItems();local item
    for i=0,all:size()-1 do
        local holder=all:get(i);local saved=holder:getModData().HCRMilkCocktailCold
        if saved then for _,entry in ipairs(saved.rows) do
            if math.abs(entry.amount-.35)<.001 then item=holder:getItemContainer():getItemById(entry.id) end
        end end
    end
    assert(item,'Missing milk cocktail sample')
    local ui=ISToolTipInv:new(item);ui:initialise();ui:setCharacter(player)
    ui.followMouse=false;ui:setX(40);ui:setY(90);ui:addToUIManager();ui:setVisible(true);HCRLabMilkCocktailTooltip=ui
end
