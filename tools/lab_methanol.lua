-- Только приватный HCRLab: native handcraft, остатки и сохранение.
require 'HCRLabSpirits'
require 'HCR_MethanolRules'
HCRLabMethanolBoot=HCRLabMethanolBoot or tostring(getTimestampMs())
HCRLabMethanol={}
local M,S,Q,L,E,F=HCRLabMethanol,HCRLabSpirits,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects,HCRFoodQuality
local function near(a,b,why) assert(math.abs(a-b)<.0001,why..' '..tostring(a)..'/'..tostring(b)) end
local function input(inv,kind,litres)
    local old=assert(instanceItem(kind));old:setAge(0);old:setCalories(137)
    F.store(old,.75);F.setQuality(old,'rotten');F.setTainted(old)
    local spec=assert(HCRDrinkFamilies[kind],'Missing source family '..kind)
    local item=inv:AddItem('Base.Pot');local fluid=Q.fluid(item)
    fluid:Empty();fluid:addFluid(spec.fluid,litres)
    Q.store(item,fluid,L.batch(spec.fluid,litres,E.snapshot(old),getGameTime():getWorldAgeHours()))
    return item
end
local function remainder(item)
    near(Q.rawAmount(Q.fluid(item)),.5,'Remaining volume')
    local ledger=assert(item:getModData()[Q.key]);L.validate(ledger)
    near(L.budget(ledger,'calories'),137/3,'Remaining calories')
    near(L.budget(ledger,'poisonPower'),.25,'Remaining poison')
    assert(L.quality(ledger)=='rotten' and ledger.lots[1].food.tainted,'Remaining quality')
end
function M.run(player)
    assert(not isClient() and not isServer(),'Private SP only')
    HCRLabCraft.trainCooking(player,'HCRLab');player:setUnlimitedCarry(true)
    local saved=player:getInventory():AddItem('Base.Bag_Schoolbag')
    saved:getModData().HCRMethanolSaved={boot=HCRLabMethanolBoot,rows={}}
    local count=0
    for _,manual in ipairs({true,false}) do
        for kind in pairs(HCRMethanolRules['Make Methanol'].inputs[0].sourceTypes) do
            local bag,inv=S.bag(player);local source=input(inv,kind,1.5);local id=source:getID()
            local charcoal=inv:AddItem('Base.Charcoal');local fire=inv:AddItem('Base.Lighter')
            local still=inv:AddItem(manual and 'Hydrocraft.HCDistillery' or 'Hydrocraft.HCDistillery2')
            local beforeCoal,beforeFire=charcoal:getCurrentUses(),fire:getCurrentUses()
            local out=S.craft(player,inv,'Make Methanol',{{source},{charcoal},{fire},{still}},manual)
            assert(#out==1 and out[1]:getFullType()=='Hydrocraft.HCMethanol' and out[1]:getCurrentUses()==4,'Methanol count/uses')
            assert(source:getContainer()==inv and source:getID()==id and still:getContainer()==inv,'Kept equipment')
            near(charcoal:getCurrentUses(),beforeCoal-1,'Charcoal charge');near(fire:getCurrentUses(),beforeFire-1,'Fire charge')
            remainder(source)
            if kind=='Hydrocraft.HCVodka' then
                local record=saved:getModData().HCRMethanolSaved.rows
                record[#record+1]={source=source:getID(),output=out[1]:getID()}
                inv:Remove(source);inv:Remove(out[1]);saved:getItemContainer():AddItem(source);saved:getItemContainer():AddItem(out[1])
            end
            player:getInventory():Remove(bag);count=count+1
        end
        local bag,inv=S.bag(player);local old=inv:AddItem('Hydrocraft.HCBarrelLemonFermented')
        local empties={};for i=1,5 do empties[i]=inv:AddItem('Base.Whiskey');Q.fluid(empties[i]):Empty() end
        local charcoal=inv:AddItem('Base.Charcoal');local fire=inv:AddItem('Base.Lighter');local still=inv:AddItem('Hydrocraft.HCDistillery2')
        local out=S.craft(player,inv,'Distill Methanol',{{old},empties,{charcoal},{fire},{still}},manual)
        local bottles,casks=0,0
        for _,item in ipairs(out) do
            if item:getFullType()=='Hydrocraft.HCMethanol' then bottles=bottles+1;assert(item:getCurrentUses()==4)
            elseif item:getFullType()=='Hydrocraft.HCWoodenbarrelFluid' then casks=casks+1;assert(Q.fluid(item):isEmpty())
            else error('Unexpected found-cask output') end
        end
        assert(bottles==5 and casks==1 and #out==6 and not old:getContainer(),'Found-cask outputs')
        for _,item in ipairs(empties) do assert(not item:getContainer(),'Found-cask bottle not consumed') end
        player:getInventory():Remove(bag)
    end
    assert(count==30)
    for _,kind in ipairs({'Hydrocraft.HCTequila','Hydrocraft.HCWhiskeycorn','Hydrocraft.HCApplejack','Hydrocraft.HCMead2'}) do
        local bag,inv=S.bag(player);local source=input(inv,kind,1.5)
        local charcoal=inv:AddItem('Base.Charcoal');local fire=inv:AddItem('Base.Lighter');local still=inv:AddItem('Hydrocraft.HCDistillery')
        assert(not S.craft(player,inv,'Make Methanol',{{source},{charcoal},{fire},{still}},true,true),'Disallowed source accepted')
        near(Q.rawAmount(Q.fluid(source)),1.5,'Refusal consumed liquid');player:getInventory():Remove(bag)
    end
    print('[HCRMethanol160] PASS 30 manual/auto originals, both stills, 2 found casks, 4 refusals; exact remainders/charges')
end
function M.verify(player)
    local items=player:getInventory():getItems();local count=0
    for i=0,items:size()-1 do local bag=items:get(i);local saved=bag:getModData().HCRMethanolSaved
        if saved then
            assert(saved.boot~=HCRLabMethanolBoot,'Process not restarted')
            local inv=bag:getItemContainer();local rows=inv:getItems()
            for _,row in ipairs(saved.rows) do local source,output
                for j=0,rows:size()-1 do local item=rows:get(j)
                    if item:getID()==row.source then source=item end
                    if item:getID()==row.output then output=item end
                end
                remainder(assert(source,'Saved remainder missing'))
                assert(output and output:getFullType()=='Hydrocraft.HCMethanol' and output:getCurrentUses()==4,'Saved output')
                count=count+1
            end
        end
    end
    assert(count>=2);print('[HCRMethanol160] COLD PASS '..count..' native outputs and half-litre remainders')
end
if not HCRLabMethanolWatch then
    HCRLabMethanolWatch=true;local ticks,last=0,nil
    Events.OnTick.Add(function()
        if isClient() or isServer() then return end
        ticks=ticks+1;if ticks%60~=0 then return end
        local r=getFileReader('HCRLabMethanolCommand.txt',false);local line=r and r:readLine();if r then r:close() end
        if line and line~=last then last=line;local seq,command=line:match('^(%d+):(%w+)$')
            if command then local ok,why=pcall(function()
                if command=='run' then M.run(getSpecificPlayer(0)) elseif command=='verify' then M.verify(getSpecificPlayer(0)) else error('Unknown command') end
            end);print('[HCRMethanol160] '..line..' '..(ok and 'PASS' or 'FAIL '..tostring(why))) end
        end
    end)
end
