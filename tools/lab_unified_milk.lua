-- Только отдельный HCRLab: native ручной/автоматический крафт девяти рецептов.
require 'HCRLabCraft'
require 'HCRLabSpirits'
HCRLabUnifiedMilkBoot=HCRLabUnifiedMilkBoot or tostring(getTimestampMs())
HCRLabUnifiedMilk={boot=HCRLabUnifiedMilkBoot}
local M,S,Q,L,F=HCRLabUnifiedMilk,HCRLabSpirits,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local function near(a,b,why) assert(math.abs(a-b)<.001,why..' '..tostring(a)..' / '..tostring(b)) end
local cases={
    {'Make Eggnog Pot',.1,{'milk','Base.Egg','Base.Whiskey','Base.Pot'}},
    {'Make Monkey Tail Pot',.1,{'milk','Base.Sugar','agua','Base.Coffee2','Base.Pot'}},
    {'Prepare Cornbread',.1,{'Hydrocraft.HCBreadpan','Base.Cornflour2','Base.Butter','milk','Base.Sugar','Base.Salt','Base.Egg'}},
    {'Make Nacho Cheese',.1,{'Base.Flour2','milk','Base.Butter','Hydrocraft.HCGratedcheese','Base.Bowl','Base.KitchenKnife'}},
    {'Make Frosting',.1,{'Base.Butter','milk','Base.Sugar','Base.Bowl','Base.Spatula'}},
    {'Make Fruit Cake Batter',.1,{'Base.Spoon','Base.Flour2','Base.Butter','Base.Sugar',{'Hydrocraft.HCDriedfruit','Hydrocraft.HCDriedfruit'},'Base.Egg','Base.Yeast','milk','Base.Bowl'}},
    {'Make Pot of Rice Pudding',.1,{'Base.Pot','Base.Rice','Base.Sugar','milk'}},
    {'Make Cup of Hot Chocolate',.2,{'Base.Mugl','milk','Hydrocraft.HCCoco'}},
    {'Make Cup of Hot Chocolate (Cup of Hot Chocolate)',.2,{'Hydrocraft.HCClaymugFluid','milk','Hydrocraft.HCCoco'}},
}
local function fixture(inv,kind)
    local item=inv:AddItem('Base.Milk');local fluid=Q.fluid(item);fluid:Empty();fluid:addFluid(kind,1)
    if kind~='CowMilk' then
        local food=instanceItem('Hydrocraft.HCSoymilk');food:setCooked(true);food:setAge(0);food:setCalories(137)
        F.setQuality(food,kind=='HCRMilkSoy' and 'rotten' or 'stale');F.store(food,.875);F.setTainted(food)
        Q.store(item,fluid,L.batch(kind,1,HCRFluidEffects.snapshot(food),getGameTime():getWorldAgeHours()))
    end
    return item
end
local function dose(item)
    if Q.fluid(item) then return L.budget(Q.capture(item,Q.fluid(item)).ledger,'poisonPower') end
    return item:IsFood() and F.dose(item) or 0
end
local function quality(item)
    if Q.fluid(item) then return L.quality(Q.capture(item,Q.fluid(item)).ledger) end
    return F.quality(item)
end
local function tainted(item)
    if Q.fluid(item) then
        for _,lot in ipairs(Q.capture(item,Q.fluid(item)).ledger.lots) do if lot.food.tainted then return true end end
        return false
    end
    return F.tainted(item)
end
function M.run(player)
    assert(not isClient() and not isServer())
    HCRLabCraft.trainCooking(player,'HCRLab');player:setUnlimitedCarry(true)
    local count=0
    for _,kind in ipairs({'CowMilk','HCRMilk','HCRMilkSoy'}) do for _,manual in ipairs({true,false}) do
    for _,case in ipairs(cases) do
        local bag,inv=S.bag(player);local milk=fixture(inv,kind);local id=milk:getID();local groups={}
        for _,entry in ipairs(case[3]) do
            local group={};local types=type(entry)=='table' and entry or {entry}
            for _,name in ipairs(types) do
                local item
                if name=='milk' then item=milk
                elseif name=='agua' then item=S.migrated(inv,'Hydrocraft.HCAguaardiente',1,false)
                else item=inv:AddItem(name)
                    if item:IsFood() then item:setAge(0) end
                    if Q.fluid(item) and name~='Base.Whiskey' then Q.fluid(item):Empty() end
                end
                group[#group+1]=item
            end
            groups[#groups+1]=group
        end
        local output=S.craft(player,inv,case[1],groups,manual)[1]
        assert(milk:getContainer()==inv and milk:getID()==id,'Milk vessel lost')
        near(Q.rawAmount(Q.fluid(milk)),1-case[2],'Real milk withdrawal '..case[1])
        if kind~='CowMilk' then
            near(dose(milk),.875*(1-case[2]),'Milk remaining dose')
            near(dose(output),.875*case[2],'Output milk dose')
            assert(quality(output)==(kind=='HCRMilkSoy' and 'rotten' or 'stale'),'Output freshness')
            assert(tainted(output),'Output taint')
            near(L.budget(Q.capture(milk,Q.fluid(milk)).ledger,'calories'),137*(1-case[2]),'Milk remaining calories')
        end
        player:getInventory():Remove(bag);count=count+1
    end end end
    assert(count==54);print('[HCRUnifiedMilk] 54 canonical recipes: native/tracked/soy x manual/auto, volumes, quality, dose and vessels PASS')
    local saved=player:getInventory():AddItem('Base.Bag_Schoolbag')
    saved:setName('HCRLab diluted milk cold samples')
    local records={}
    for _,manual in ipairs({true,false}) do for _,fraction in ipairs({1,.5,.25,.01}) do
        local bag,inv=S.bag(player)
        local concentrate=inv:AddItem('Hydrocraft.HCEvaporatedmilkopen')
        concentrate:setHungChange(concentrate:getBaseHunger()*fraction);concentrate:setCalories(173)
        F.store(concentrate,.625);F.setQuality(concentrate,'rotten');F.setTainted(concentrate)
        local water=inv:AddItem('Base.WaterBottle');Q.fluid(water):Empty();Q.fluid(water):addFluid('Water',1)
        local carton=inv:AddItem('Hydrocraft.HCMilkempty')
        local results=S.craft(player,inv,'Dilute Evaporated Milk',{{concentrate},{water},{carton}},manual)
        local output,empties=nil,0
        for _,item in ipairs(results) do
            if item:getFullType()=='Base.Milk' then assert(not output);output=item
            elseif item:getFullType()=='Hydrocraft.HCEvaporatedmilkopenempty' then empties=empties+1 end
        end
        assert(output and empties==1 and #results==2,'Dilution must return exactly one empty tin')
        local ledger=Q.capture(output,Q.fluid(output)).ledger
        near(Q.rawAmount(Q.fluid(output)),.7+.3*fraction,'Diluted remainder volume')
        near(L.budget(ledger,'calories'),173,'Concentrate current calories')
        near(L.budget(ledger,'poisonPower'),.625,'Concentrate current poison')
        assert(quality(output)=='rotten' and tainted(output),'Concentrate quality')
        assert(not concentrate:getContainer() and not carton:getContainer(),'Concentrate/carton not consumed')
        assert(water:getContainer()==inv);near(Q.rawAmount(Q.fluid(water)),.3,'Water remainder')
        inv:Remove(output);saved:getItemContainer():AddItem(output)
        records[#records+1]={id=output:getID(),litres=.7+.3*fraction}
        player:getInventory():Remove(bag)
    end end
    saved:getModData().HCRUnifiedMilkSaved={boot=M.boot,rows=records}
    print('[HCRUnifiedMilk] 8 full/partial concentrate native crafts PASS')
    for _,manual in ipairs({true,false}) do
        local bag,inv=S.bag(player);local milk=fixture(inv,'HCRMilkSoy')
        local mug=inv:AddItem('Base.Mugl');Q.fluid(mug):addFluid('Water',.1)
        local cocoa=inv:AddItem('Hydrocraft.HCCoco')
        S.craft(player,inv,'Make Cup of Hot Chocolate',{{mug},{milk},{cocoa}},manual,true)
        near(Q.rawAmount(Q.fluid(milk)),1,'Rejected cocoa milk');near(Q.rawAmount(Q.fluid(mug)),.1,'Occupied mug contents')
        assert(cocoa:getContainer()==inv and mug:getContainer()==inv,'Rejected cocoa changed inputs')
        Q.fluid(mug):Empty()
        local raw=inv:AddItem('Hydrocraft.HCSoymilk');raw:setAge(0)
        inv:Remove(milk)
        S.craft(player,inv,'Make Cup of Hot Chocolate',{{mug},{raw},{cocoa}},manual,true)
        assert(raw:getContainer()==inv and cocoa:getContainer()==inv,'Raw soy refusal changed inputs')
        player:getInventory():Remove(bag)
    end
    print('[HCRUnifiedMilk] filled mug / raw soy manual-auto refusals PASS; ALL PASS')
end
function M.verify(player)
    local count=0;local all=player:getInventory():getItems();local samples={}
    for i=0,all:size()-1 do
        local bag=all:get(i);local saved=bag:getModData().HCRUnifiedMilkSaved
        if saved then
            assert(saved.boot~=M.boot,'Process not restarted')
            for _,row in ipairs(saved.rows) do
                local items=bag:getItemContainer():getItems();local found
                for j=0,items:size()-1 do if items:get(j):getID()==row.id then assert(not found);found=items:get(j) end end
                assert(found,'Saved diluted milk missing');local ledger=assert(found:getModData()[Q.key]);L.validate(ledger)
                near(Q.rawAmount(Q.fluid(found)),row.litres,'Cold milk litres')
                near(L.budget(ledger,'calories'),173,'Cold milk calories');near(L.budget(ledger,'poisonPower'),.625,'Cold milk poison')
                assert(L.quality(ledger)=='rotten' and tainted(found),'Cold milk quality');count=count+1
                if #samples<3 then samples[#samples+1]=found end
            end
        end
    end
    assert(count>=8);print('[HCRUnifiedMilk] COLD PASS '..count..' saved cartons')
    M.tooltips={}
    for i,item in ipairs(samples) do
        local tip=ISToolTipInv:new(item);tip:initialise();tip:setCharacter(player)
        tip.followMouse=false;tip:setX(20+(i-1)*420);tip:setY(70);tip.backgroundColor.a=.96
        tip:addToUIManager();M.tooltips[#M.tooltips+1]=tip
    end
end
if not HCRLabUnifiedMilkWatch then
    HCRLabUnifiedMilkWatch=true
    local ticks,last=0,nil
    Events.OnTick.Add(function()
        if isClient() or isServer() then return end
        ticks=ticks+1;if ticks%60~=0 then return end
        local reader=getFileReader('HCRLabUnifiedMilkCommand.txt',false)
        local line=reader and reader:readLine();if reader then reader:close() end
        if line and line~=last then
            last=line;local seq,command=line:match('^(%d+):(%w+)$')
            if command then local ok,why=pcall(function()
                assert(command=='run' or command=='verify')
                if command=='run' then M.run(getSpecificPlayer(0)) else M.verify(getSpecificPlayer(0)) end
            end);print('[HCRUnifiedMilk] '..line..' '..(ok and 'PASS' or 'FAIL '..tostring(why))) end
        end
    end)
end
