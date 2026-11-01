-- Только private HCRLab: банка, бутылка, блендер и сохранение состояния.
require 'HCR_SoftDrinks'
HCRLabSoft={}
HCRLabSoftBoot=HCRLabSoftBoot or tostring(getTimestampMs())
local C,Q,L,F=HCRSoftDrinkCatalog,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..': '..tostring(a)..' / '..tostring(b)) end
local function ledger(item) return Q.capture(item,Q.fluid(item)).ledger end
local function save(holder,item)
    local rows=holder:getModData().HCRSoftCold or {};holder:getModData().HCRSoftCold=rows
    rows[#rows+1]={boot=HCRLabSoftBoot,id=item:getID(),kind=item:getFullType(),amount=Q.rawAmount(Q.fluid(item)),
        ledger=L.copy(ledger(item)),factory=HCRBeerQuality.factory(item)}
end
function HCRLabSoft.run(player)
    assert(not isClient() and not isServer())
    local S=HCRLabSpirits;local holder,inv=S.bag(player);local count=0
    for kind,spec in pairs(C.families) do
        local pristine=S.migrated(inv,kind,1,false)
        S.inspect(pristine,spec.litres,instanceItem(kind):getCalories(),0,'fresh')
        assert(HCRBeerQuality.factory(pristine)==spec.factoryDrink,'Factory mark '..kind)
        local snap=HCRFluidEffects.snapshot(instanceItem(kind))
        for _,key in ipairs({'fatigueChange','enduranceChange','thirstChange'}) do
            near(L.budget(ledger(pristine),key),snap[key] or 0,'Migration effect '..key)
        end
        if spec.factoryDrink or kind=='Hydrocraft.HCEnergydrink' or kind=='Hydrocraft.HCApplecider' then save(holder,pristine) end
        for _,fraction in ipairs({1,.5,.25}) do
            S.inspect(S.migrated(inv,kind,fraction,true),spec.litres*fraction,123.5,.875,'rotten');count=count+1
        end
    end
    assert(count==51);holder:setName('HCRLab soft drink cold samples')
    print('[HCRSoft160] 17 pristine + 51 modified/full/partial migrations PASS')
    for _,manual in ipairs({true,false}) do
        holder,inv=S.bag(player)
        local pack=inv:AddItem('Hydrocraft.HCPoppack6')
        local cans=S.craft(player,inv,'Unpack Pop (Pop)',{{pack}},manual)
        assert(#cans==6 and not pack:getContainer())
        for _,can in ipairs(cans) do S.inspect(can,.3,140,0,'fresh');assert(HCRBeerQuality.factory(can)) end
        local bad=S.migrated(inv,'Hydrocraft.HCPop6',1,true);local empty=inv:AddItem('Hydrocraft.HCPop6Fluid')
        local packed=S.craft(player,inv,'Pack Pop (Pack of Pop 3)',{cans},manual)
        assert(#packed==1 and bad:getContainer()==inv and empty:getContainer()==inv)
        for _,can in ipairs(cans) do assert(not can:getContainer()) end
        cans=S.craft(player,inv,'Unpack Pop (Pop)',{packed},manual)
        for _,can in ipairs(cans) do S.inspect(can,.3,140,0,'fresh');assert(HCRBeerQuality.factory(can)) end
        Q.remove(cans[1],player,function() Q.fluid(cans[1]):adjustAmount(.15) end,false)
        S.craft(player,inv,'Pack Pop (Pack of Pop 3)',{cans},true,true)
        for _,can in ipairs(cans) do assert(can:getContainer()==inv) end
        near(Q.rawAmount(Q.fluid(cans[1])),.15,'Rejected pack keeps contents')
        player:getInventory():Remove(holder)
    end
    print('[HCRSoft160] manual/auto six-pack roundtrip and partial-pack refusal PASS')
    holder,inv=S.bag(player);local blender=inv:AddItem('Hydrocraft.HCBlenderpowered')
    for n=1,8 do
        local quality=n%2==0 and 'stale' or 'fresh'
        local bottle=inv:AddItem('Hydrocraft.HCCanteenFluid');Q.fluid(bottle):Empty();bottle:setFavorite(true)
        local id=bottle:getID();local groups={{bottle}};local foods={}
        for _,kind in ipairs({'Base.Banana','Hydrocraft.HCBunchofberries','Hydrocraft.HCSpirulinafresh'}) do
            local group={}
            for supply=1,5 do
                local item=inv:AddItem(kind);item:setAge(0);F.setQuality(item,quality);F.store(item,.875)
                group[#group+1]=item;foods[#foods+1]=item
            end
            groups[#groups+1]=group
        end
        groups[#groups+1]={blender}
        local result=S.craft(player,inv,'Mix Fitness Drink',groups,n%2==0,false,true)
        assert(#result==0 and bottle:getID()==id and bottle:isFavorite() and bottle:getContainer()==inv)
        local spent=0
        for _,item in ipairs(foods) do
            spent=spent+.875-(item:getContainer() and F.dose(item) or 0)
            if item:getContainer() then inv:Remove(item) end
        end
        S.inspect(bottle,1.4,300,spent,quality)
        if n<8 then assert(blender:getContainer()==inv and blender:getCurrentUses()==8-n,'Blender charge '..n)
        else assert(not blender:getContainer() and inv:getCountTypeRecurse('HCBlenderdead')==1,'Blender exhaustion') end
        if n==8 then save(holder,bottle) else inv:Remove(bottle) end
    end
    print('[HCRSoft160] eight fresh/stale fitness batches same vessel/300 calories/exact poison; eight blender charges PASS')
    holder:setName('HCRLab fitness cold sample')
    do
        local rejectedHolder,rejectedInv=S.bag(player)
        local vessel=rejectedInv:AddItem('Hydrocraft.HCCanteenFluid');Q.fluid(vessel):Empty()
        local device=rejectedInv:AddItem('Hydrocraft.HCBlenderpowered');local groups={{vessel}};local foods={}
        for _,kind in ipairs({'Base.Banana','Hydrocraft.HCBunchofberries','Hydrocraft.HCSpirulinafresh'}) do
            local group={}
            for n=1,5 do local item=rejectedInv:AddItem(kind);F.setQuality(item,'rotten');group[#group+1]=item;foods[#foods+1]=item end
            groups[#groups+1]=group
        end
        groups[#groups+1]={device}
        S.craft(player,rejectedInv,'Mix Fitness Drink',groups,false,true,true)
        assert(device:getCurrentUses()==8 and Q.fluid(vessel):isEmpty())
        for _,item in ipairs(foods) do assert(item:getContainer()==rejectedInv) end
        player:getInventory():Remove(rejectedHolder)
        print('[HCRSoft160] native rotten solids refusal preserves ingredients, vessel and battery PASS')
    end
    for _,manual in ipairs({true,false}) do
        for _,kind in ipairs(C.emptyAliases['Base.PopBottle']) do
            holder,inv=S.bag(player);local bottle=inv:AddItem(kind);local id=bottle:getID();local apples={}
            for n=1,4 do local apple=inv:AddItem('Base.Apple');apple:setAge(0);apples[#apples+1]=apple end
            local juicer=inv:AddItem('Hydrocraft.HCJuicer')
            S.craft(player,inv,'Make Bottle of Juice (Apple Juice)',{{bottle},apples,{juicer}},manual,false,true)
            assert(bottle:getContainer()==inv and bottle:getID()==id);near(Q.rawAmount(Q.fluid(bottle)),1,'Soda vessel juice')
            assert(Q.fluid(bottle):getPrimaryFluid()==Fluid.Get('HCRJuiceApple'))
            player:getInventory():Remove(holder)
        end
        holder,inv=S.bag(player)
        local lemon=S.migrated(inv,'Hydrocraft.HCPopbottlelemonjuice',.1,true)
        local sugar=inv:AddItem('Base.Sugar');local water=inv:AddItem('Base.WaterBottle')
        Q.fluid(water):Empty();Q.fluid(water):addFluid('Water',.6)
        local bottle=inv:AddItem('Hydrocraft.HCSodacolaFluid')
        S.craft(player,inv,'Make Bottle of Juice',{{lemon},{sugar},{water},{bottle}},manual,false,true)
        near(Q.rawAmount(Q.fluid(bottle)),.3,'Soda vessel lemonade');assert(bottle:getContainer()==inv)
        player:getInventory():Remove(holder)
        holder,inv=S.bag(player)
        local cola=S.migrated(inv,'Hydrocraft.HCSodacola',1,true)
        local whiskey=S.migrated(inv,'Hydrocraft.HCDrinkglasstallwhiskey',1,false)
        local output=S.craft(player,inv,'Whiskey and Coke',{{whiskey},{cola}},manual)[1]
        near(Q.rawAmount(Q.fluid(cola)),2-2/15,'Coke retained bottle')
        near(L.budget(ledger(output),'poisonPower'),.875/15,'Coke actual dose');assert(not whiskey:getContainer() and cola:getContainer()==inv)
        player:getInventory():Remove(holder)
    end
    print('[HCRSoft160] 20 same-bottle juice crafts, 2 lemonade aliases, 2 actual cola portions PASS')
    HCRLabSoft.gym(player)
    HCRLabSoft.show(player)
end
function HCRLabSoft.gym(player)
    local S=HCRLabSpirits
    for _,perk in ipairs({Perks.Nimble,Perks.Sprinting,Perks.Strength}) do
        for i=1,20 do if player:getPerkLevel(perk)>=5 then break end;player:getXp():AddXP(perk,10000) end
    end
    local cases={
        {'Exercise hard on Treadmill',{'Hydrocraft.HCTredmillgenerator','liquid','Hydrocraft.HCGymtowel'}},
        {'Exercise hard with Weights',{'Hydrocraft.HCWeights','liquid','Hydrocraft.HCGymtowel'}},
        {'Exercise hard with Punching Bag',{'Hydrocraft.HCPunchingbag','Hydrocraft.HCBoxinggloves','liquid','Hydrocraft.HCGymtowel'}},
        {'Research Fitness Training',{'Base.SheetPaper2','Base.Pencil','Hydrocraft.HCMedicallab2','Hydrocraft.HCTredmillgenerator','Hydrocraft.HCWeights','Hydrocraft.HCPunchingbag','Hydrocraft.HCBoxinggloves','liquid'}},
    }
    for _,manual in ipairs({true,false}) do for _,case in ipairs(cases) do
        local holder,inv=S.bag(player);local drink=S.migrated(inv,'Hydrocraft.HCFitnessdrink',1,true)
        local groups={}
        for _,kind in ipairs(case[2]) do groups[#groups+1]={kind=='liquid' and drink or inv:AddItem(kind)} end
        local outputs=S.craft(player,inv,case[1],groups,manual,false,true)
        S.inspect(drink,1.26,123.5*.9,.875*.9,'rotten')
        assert(drink:getContainer()==inv and inv:getCountTypeRecurse('HCCanteenFluid')==1,'Gym duplicated flask')
        assert(#outputs==(case[1]=='Research Fitness Training' and 1 or 0),'Gym unexpected output')
        player:getInventory():Remove(holder)
    end end
    print('[HCRSoft160] eight manual/auto fitness consumer crafts retain flask and consume only .14 L PASS')
end
function HCRLabSoft.show(player)
    if HCRLabSoftTooltip then HCRLabSoftTooltip:removeFromUIManager() end
    local all=player:getInventory():getItems();local item
    for i=0,all:size()-1 do
        local holder=all:get(i);local rows=holder:getModData().HCRSoftCold
        if rows then for _,row in ipairs(rows) do
            if row.kind=='Hydrocraft.HCCanteenFluid' then item=holder:getItemContainer():getItemById(row.id) end
        end end
    end
    assert(item,'Missing fitness sample');getGameTime():setTimeOfDay(12)
    local ui=ISToolTipInv:new(item);ui:initialise();ui:setCharacter(player)
    ui.followMouse=false;ui:setX(40);ui:setY(90);ui:addToUIManager();ui:setVisible(true);HCRLabSoftTooltip=ui
end
function HCRLabSoft.verify(player)
    local count=0;local items=player:getInventory():getItems()
    for i=0,items:size()-1 do
        local bag=items:get(i);local rows=bag:getModData().HCRSoftCold
        if rows then for _,row in ipairs(rows) do
            assert(row.boot~=HCRLabSoftBoot,'Not a cold process')
            local item=assert(bag:getItemContainer():getItemById(row.id),'Missing saved soft drink')
            assert(item:getFullType()==row.kind)
            local raw=assert(item:getModData()[Q.key]);L.validate(raw)
            near(Q.rawAmount(Q.fluid(item)),row.amount,'Cold volume')
            assert(L.matches(raw,Q.amounts(Q.fluid(item))) and L.quality(raw)==L.quality(row.ledger))
            assert(HCRBeerQuality.factory(item)==row.factory,'Cold factory state')
            for _,key in ipairs({'calories','poisonPower','thirstChange','hungChange','fatigueChange','enduranceChange'}) do
                near(L.budget(raw,key),L.budget(row.ledger,key),'Cold '..key)
            end
            count=count+1
        end end
    end
    assert(count>=6);print('[HCRSoft160] COLD PASS '..count)
end
