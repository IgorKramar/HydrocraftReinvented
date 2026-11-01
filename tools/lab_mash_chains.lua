-- Только приватный HCRLab. Настоящие миграции, native handcraft и сохранение.
require 'HCRLabCraft'
require 'HCRLabSpirits'
require 'HCR_MashCatalog'
HCRLabMashBoot=HCRLabMashBoot or tostring(getTimestampMs())
HCRLabMash={}
local M,S,Q,L,F,B,C=HCRLabMash,HCRLabSpirits,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRFermentation,HCRMashCatalog
local function near(a,b,label) assert(math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) return assert(item:getModData()[Q.key],'Missing mash ledger') end
local function tainted(ledger) for _,lot in ipairs(ledger.lots) do if lot.food.tainted then return true end end;return false end
local function check(item,litres,calories,dose,quality)
    local ledger=raw(item);L.validate(ledger)
    near(Q.rawAmount(Q.fluid(item)),litres,'Physical litres');near(L.budget(ledger,'calories'),calories,'Calories')
    near(L.budget(ledger,'poisonPower'),dose,'Poison');assert(L.quality(ledger)==quality,'Freshness')
    assert(tainted(ledger),'Taint lost')
end
local function cooked(kind,fraction)
    local old=assert(instanceItem(kind));old:setHungChange(old:getBaseHunger()*fraction)
    old:setCalories(137);F.store(old,.125);F.setQuality(old,'rotten');F.setTainted(old)
    old:setName('Mash keepsake');old:setCustomName(true);old:setFavorite(true)
    old:getModData().HCRMashProbe='preserved'
    local item=assert(HCRItemMigrations.newReplacement(old),'Cooked migration '..kind)
    assert(item:getFullType()=='Base.Pot' and item:isFavorite(),'Cooked vessel/state')
    assert(item:getModData().HCRLegacyCustomName=='Mash keepsake' and item:getModData().HCRMashProbe=='preserved','Cooked custom metadata')
    assert(not HCRItemMigrations.newReplacement(item),'Repeated migration')
    check(item,.5*fraction,137,.125,'rotten');near(F.dose(old),.125,'Original poison unchanged')
    item:setFavorite(false);return item
end
local function water(inv,litres)
    local item=inv:AddItem('Hydrocraft.HCWoodenbarrelFluid');Q.fluid(item):addFluid('Water',litres);return item
end
local function remember(saved,item)
    local inv=saved:getItemContainer();if item:getContainer() then item:getContainer():Remove(item) end;inv:AddItem(item)
    local records=saved:getModData().HCRMashSaved.rows
    records[#records+1]={id=item:getID(),litres=Q.rawAmount(Q.fluid(item)),ledger=L.copy(raw(item))}
end
local function distill(player,inv,cask,name,manual,calories,dose)
    local charcoal=inv:AddItem('Base.Charcoal');local fire=inv:AddItem('Base.Lighter');local bottles={}
    for i=1,20 do local item=inv:AddItem('Base.Whiskey');Q.fluid(item):setCanPlayerEmpty(true);Q.fluid(item):Empty();bottles[i]=item end
    local cooling=water(inv,6);local still=inv:AddItem('Hydrocraft.HCDistillery2')
    local function waterAmount()
        local amount=0;local items=inv:getItems()
        for i=0,items:size()-1 do local f=Q.fluid(items:get(i));if f then amount=amount+f:getSpecificFluidAmount(Fluid.Water) end end
        return amount
    end
    local beforeWater=waterAmount()
    local groups={{cask},{charcoal},{fire},bottles}
    if name=='Distill Bottle of Mezcal' then
        local worms={};for i=1,20 do worms[i]=inv:AddItem('Base.Worm');worms[i]:setAge(0) end;groups[#groups+1]=worms
    end
    groups[#groups+1]={cooling};groups[#groups+1]={still}
    local id=cask:getID();local out=S.craft(player,inv,name,groups,manual)
    assert(#out==20 and cask:getContainer()==inv and cask:getID()==id and Q.fluid(cask):isEmpty(),'Distillation cask retained')
    assert(still:getContainer()==inv,'Still disappeared');near(beforeWater-waterAmount(),6,'Cooling water from all available sources')
    local rule=HCRWineQuality.outputs[name]
    local expected=rule.nativeQuality and 0 or instanceItem(rule.sourceFood):getCalories()
    for _,item in ipairs(out) do check(item,1,expected,dose/20,'rotten') end
    for _,item in ipairs(bottles) do assert(not item:getContainer(),'Empty input bottle survived') end
    return out
end
function M.run(player)
    assert(not isClient() and not isServer(),'Private SP only')
    HCRLabCraft.trainCooking(player,'HCRLab');player:setUnlimitedCarry(true)
    local saved=player:getInventory():AddItem('Base.Bag_Schoolbag')
    saved:setName('HCRLab mash cold samples');saved:getModData().HCRMashSaved={boot=HCRLabMashBoot,rows={}}
    local count=0
    for kind in pairs(C.families) do
        for _,fraction in ipairs({1,.5,.01}) do cooked(kind,fraction);count=count+1 end
        local rawFood=instanceItem(kind:gsub('cooked$',''))
        assert(rawFood and not HCRItemMigrations.newReplacement(rawFood),'Raw mash migrated before cooking')
    end
    print('[HCRMash160] '..count..' cooked full/partial migrations; ten raw foods preserved PASS')
    for kind,stage in pairs(C.stages) do if stage.preserveNutrition then
        local old=assert(instanceItem(kind));old:setFavorite(true)
        HCRProcessQuality.write(old,{quality='rotten',dose=.875,detection=4,tainted=true},1,nil)
        old:getModData().StartTime=getGameTime():getWorldAgeHours()
        local item=assert(HCRItemMigrations.newReplacement(old),'Legacy ready barrel '..kind)
        assert(item:isFavorite() and raw(item).lots[1].fermentation.kind==kind,'Legacy barrel delayed')
        check(item,20,0,.875,'rotten');remember(saved,item)
    end end
    print('[HCRMash160] eight legacy barrels ready immediately PASS')
    local filled,distilled=0,0
    for _,manual in ipairs({true,false}) do for name,rule in pairs(C.products) do
        local bag,inv=S.bag(player);local pots={};local n=manual and 3 or 6
        local sourceKind
        for kind,spec in pairs(C.families) do if spec.fluid==rule.marker then sourceKind=kind end end
        for i=1,n do pots[i]=cooked(assert(sourceKind),3/n);inv:AddItem(pots[i]) end
        local cask=inv:AddItem('Hydrocraft.HCWoodenbarrelFluid');local id=cask:getID();local supply=water(inv,20)
        local out=S.craft(player,inv,name,{{cask},pots,{supply}},manual,false,true)
        assert(#out==0 and cask:getContainer()==inv and cask:getID()==id,'Fill duplicated/replaced cask')
        check(cask,20,137*n,.125*n,'rotten');near(Q.rawAmount(Q.fluid(supply)),1.5,'Water remainder')
        for _,item in ipairs(pots) do assert(item:getContainer()==inv and Q.fluid(item):isEmpty(),'Pot lost or not emptied') end
        for _,lot in ipairs(raw(cask).lots) do assert(lot.fermentation.kind==rule.stage,'Wrong active mash stage') end
        if manual then
            local active=instanceItem('Hydrocraft.HCWoodenbarrelFluid');Q.fluid(active):addFluid(B.stages[rule.stage].marker,20)
            Q.store(active,Q.fluid(active),L.copy(raw(cask)));remember(saved,active)
        end
        local now=getGameTime():getWorldAgeHours()
        for _,lot in ipairs(raw(cask).lots) do lot.fermentation.startedAt=now-335.999;lot.fermentation.lastHour=now end
        Q.capture(cask,Q.fluid(cask));assert(raw(cask).lots[1].fermentation.kind==rule.stage,'Mash matured early')
        for _,lot in ipairs(raw(cask).lots) do lot.fermentation.startedAt=now-336;lot.fermentation.lastHour=now end
        Q.capture(cask,Q.fluid(cask))
        local ready=HCRFermentationClock.transition(rule.stage).target
        assert(raw(cask).lots[1].fermentation.kind==ready,'Mash did not mature at 336h')
        local marker=B.stages[ready].marker
        near(Q.fluid(cask):getSpecificFluidAmount(Fluid.Get(marker)),20,'Ready native marker')
        if B.stages[ready].preserveNutrition then
            check(cask,20,137*n,.125*n,'rotten')
            local matches={};for dist,definition in pairs(C.consumers) do
                if definition.inputs[0].fluids[1]==marker then matches[#matches+1]=dist end
            end
            local readyLedger=L.copy(raw(cask))
            for index,dist in ipairs(matches) do
                local input=cask
                if index>1 then
                    -- Автовыбор видит ровно одну готовую партию; предыдущая
                    -- перегонка уже опустошила исходную бочку.
                    input=inv:AddItem('Hydrocraft.HCWoodenbarrelFluid');Q.fluid(input):addFluid(marker,20);Q.store(input,Q.fluid(input),L.copy(readyLedger))
                end
                local made=distill(player,inv,input,dist,manual,137*n,.125*n)
                remember(saved,made[1]);distilled=distilled+1
            end
        else
            local bottleName=ready=='Hydrocraft.HCBarrelmead' and 'Make Bottle of Mead' or 'Make Bottle of Sake'
            local bottles={};for i=1,20 do bottles[i]=inv:AddItem('Base.Whiskey');Q.fluid(bottles[i]):Empty() end
            out=S.craft(player,inv,bottleName,{{cask},bottles},manual)
            assert(#out==20 and cask:getContainer()==inv and Q.fluid(cask):isEmpty(),'Mead/sake bottling vessel')
            for _,item in ipairs(out) do check(item,1,ready=='Hydrocraft.HCBarrelmead' and 356 or 39,.125*n/20,'rotten') end
            remember(saved,out[1])
        end
        player:getInventory():Remove(bag);filled=filled+1
    end end
    assert(filled==20 and distilled==18)
    print('[HCRMash160] 20 native fills (manual/auto), 18 distillations, 4 mead/sake bottlings PASS')
    saved:getModData().HCRMashSaved.complete=true
    print('[HCRMash160] ALL PASS; cold samples '..#saved:getModData().HCRMashSaved.rows)
end
function M.verify(player)
    local all=player:getInventory():getItems();local count,heated,complete=0,0,false;local samples={}
    for i=0,all:size()-1 do local bag=all:get(i);local saved=bag:getModData().HCRMashSaved
        if saved then
            assert(saved.boot~=HCRLabMashBoot,'Process was not restarted')
            complete=complete or saved.complete
            for _,row in ipairs(saved.rows) do
                local items=bag:getItemContainer():getItems();local found
                for j=0,items:size()-1 do if items:get(j):getID()==row.id then assert(not found);found=items:get(j) end end
                assert(found,'Cold mash sample missing')
                check(found,row.litres,L.budget(row.ledger,'calories'),L.budget(row.ledger,'poisonPower'),'rotten')
                assert(#raw(found).lots==#row.ledger.lots,'Cold lot count')
                for j,lot in ipairs(row.ledger.lots) do if lot.fermentation then
                    local actual=raw(found).lots[j].fermentation
                    local expected=lot.fermentation
                    -- Часы уксусной выдержки в бутылках приостановлены:
                    -- startedAt движется вместе с lastHour, срок остаётся прежним.
                    local delta=expected.barrel and actual.startedAt-expected.startedAt or
                        (actual.lastHour-actual.startedAt)-(expected.lastHour-expected.startedAt)
                    assert(actual.kind==expected.kind and math.abs(delta)<.00001,
                        'Cold fermentation clock '..tostring(actual.kind)..'/'..tostring(lot.fermentation.kind)..' '..tostring(actual.startedAt)..'/'..tostring(lot.fermentation.startedAt))
                end end
                if #samples<3 then samples[#samples+1]=found end;count=count+1
            end
            local contents=bag:getItemContainer():getItems()
            for j=0,contents:size()-1 do local item=contents:get(j);local row=item:getModData().HCRMashHeatSaved
                if row then
                    assert(row.boot~=HCRLabMashBoot,'Heating process was not restarted')
                    local ledger=raw(item);L.validate(ledger)
                    near(Q.rawAmount(Q.fluid(item)),.25,'Cold heated volume')
                    near(L.budget(ledger,'calories'),row.calories,'Cold heated nutrition')
                    near(L.budget(ledger,'poisonPower'),row.dose,'Cold heated poison')
                    assert(L.quality(ledger)==row.quality and not tainted(ledger),'Cold heated quality')
                    heated=heated+1
                end
            end
        end
    end
    assert(complete and count>=40 and heated>=20,'Incomplete saved fixture');print('[HCRMash160] COLD PASS '..count..' mash and '..heated..' heated samples')
    M.tooltips={};for i,item in ipairs(samples) do
        local tip=ISToolTipInv:new(item);tip:initialise();tip:setCharacter(player)
        tip.followMouse=false;tip:setX(20+(i-1)*420);tip:setY(70);tip.backgroundColor.a=.96
        tip:addToUIManager();M.tooltips[#M.tooltips+1]=tip
    end
end
function M.heat(player)
    assert(not isClient() and not isServer(),'Private native heating only')
    local square=player:getSquare();local crate=IsoObject.new(getCell(),square,'carpentry_01_16')
    local inv=ItemContainer.new('crate',square,crate);inv:setCapacity(100);inv:setCustomTemperature(2)
    crate:setContainer(inv);square:AddTileObject(crate)
    local saved=player:getInventory():AddItem('Base.Bag_Schoolbag')
    saved:getModData().HCRMashSaved={boot=HCRLabMashBoot,rows={}}
    local cases={};local count=0
    for kind,spec in pairs(C.raw) do for _,quality in ipairs({'fresh','rotten'}) do
        local item=inv:AddItem(kind);local replacements=item:getReplaceOnCooked()
        assert(not replacements or replacements:size()==0,'Pristine cooked replacement still active')
        assert(item:getMinutesToCook()==120,'Original cooking duration changed')
        assert(item:getMinutesToBurn()==(kind=='Hydrocraft.HCPotofpotatomash' and 140 or 180),'Original burn duration changed')
        item:setAge(0);item:setHungChange(item:getBaseHunger()*.5);item:setCalories(137)
        F.store(item,.625);F.setQuality(item,quality);F.setTainted(item)
        -- Ускоряется только эта тестовая партия. Food.update и OnCooked
        -- остаются настоящими; cookingTime тест не подменяет.
        item:setMinutesToCook(6);item:setMinutesToBurn(100);item:setHeat(2)
        count=count+1;item:getModData().HCRMashHeatLabel=count
        cases[count]={label=count,spec=spec,quality=quality}
    end end
    local control=player:getInventory():AddItem('Hydrocraft.HCPotofpotatomash')
    control:setHungChange(control:getBaseHunger()*.5);F.setTainted(control)
    M.heating={inv=inv,cases=cases,control=control,saved=saved,started=getTimestampMs(),speed=getGameSpeed(),player=player}
    setGameSpeed(3);print('[HCRMash160] HEAT START twenty half-raw foods with native heating and cold control')
end
function M.heatTick()
    local state=M.heating;if not state then return end
    assert(getTimestampMs()-state.started<180000,'Native mash heating timeout')
    local items=state.inv:getItems();local found={}
    for i=0,items:size()-1 do local item=items:get(i);local label=item:getModData().HCRMashHeatLabel
        if label then found[label]=item end
    end
    local done=0
    for _,row in ipairs(state.cases) do
        local item=found[row.label]
        if row.done then done=done+1
        elseif item and Q.fluid(item) then
            local ledger=raw(item);near(Q.rawAmount(Q.fluid(item)),.25,'Half raw heated litres')
            near(L.budget(ledger,'calories'),137,'Heated actual nutrition');near(L.budget(ledger,'poisonPower'),.625,'Heated poison')
            assert(L.quality(ledger)==row.quality,'Heated freshness')
            assert(not tainted(ledger),'Native heat did not clear water contamination')
            local food=ledger.lots[1].food;local prototype=instanceItem(row.spec.readyFood)
            assert(not food.cooked and not food.dangerousUncooked,'Extra cooked hunger bonus/raw penalty')
            assert(food.offAge==prototype:getOffAge() and food.offAgeMax==prototype:getOffAgeMax(),'Wrong cooked expiry')
            row.done=true;done=done+1
            -- Отдельная heat запись имеет очищенную воду, проверяется отдельно.
            item:getModData().HCRMashHeatSaved={boot=HCRLabMashBoot,calories=137,dose=.625,quality=row.quality}
            state.inv:Remove(item);state.saved:getItemContainer():AddItem(item)
        end
    end
    assert(not state.control:isCooked() and F.tainted(state.control),'Cold raw control changed')
    if done==20 then
        state.inv:setCustomTemperature(1);setGameSpeed(state.speed)
        M.heating=nil;print('[HCRMash160] HEAT PASS twenty native half-raw cooks, exact remaining nutrition/poison, correct expiry and clean water')
    end
end
if not HCRLabMashWatch then
    HCRLabMashWatch=true;local ticks,last=0,nil
    Events.OnTick.Add(function()
        if isClient() or isServer() then return end
        ticks=ticks+1;if ticks%60~=0 then return end
        if M.heating then local ok,why=pcall(M.heatTick);if not ok then
            setGameSpeed(M.heating.speed);M.heating=nil;print('[HCRMash160] HEAT FAIL '..tostring(why))
        end end
        local r=getFileReader('HCRLabMashCommand.txt',false);local line=r and r:readLine();if r then r:close() end
        if line and line~=last then
            last=line;local seq,command=line:match('^(%d+):(%w+)$')
            if command then local ok,why=pcall(function()
                if command=='run' then M.run(getSpecificPlayer(0)) elseif command=='verify' then M.verify(getSpecificPlayer(0))
                elseif command=='heat' then M.heat(getSpecificPlayer(0)) else error('Unknown command') end
            end);print('[HCRMash160] '..line..' '..(ok and 'PASS' or 'FAIL '..tostring(why))) end
        end
    end)
end
