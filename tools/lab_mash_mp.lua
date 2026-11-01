-- Только localhost HCRLabMP: реальная очередь действий и независимые наблюдатели.
HCRLabMashMPBoot=HCRLabMashMPBoot or tostring(getTimestampMs())
HCRLabMashMP={}
local M,Q,L,F=HCRLabMashMP,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local phases={'initial','fill','mature','distill','share','chemical','share_chemical','verify'}
local function log(s) print('[HCRMashMP] '..s) end
local function near(a,b,why) assert(a and math.abs(a-b)<.001,why..' '..tostring(a)..' / '..tostring(b)) end
local function tag(item,name) item:getModData().HCRMashMPTag=name;return item end
local function find(inv,label)
    local items=inv:getItems();for i=0,items:size()-1 do local item=items:get(i)
        if item:getModData().HCRMashMPTag==label then return item end
    end
end
local function shared(f)
    local objects=assert(getCell():getGridSquare(f.x,f.y,f.z)):getObjects();local found
    for i=0,objects:size()-1 do local item=objects:get(i)
        if item:getModData().HCRMashMPTag==f.run then assert(not found);found=item end
    end
    return assert(found,'Missing shared mash crate')
end
local function raw(item) local ledger=assert(item:getModData()[Q.key],'Missing raw mash ledger');L.validate(ledger);return ledger end
local function liquid(item,marker,litres,calories,dose)
    local ledger=raw(item);local fluid=assert(Q.fluid(item))
    near(Q.rawAmount(fluid),litres,'Litres');near(fluid:getSpecificFluidAmount(Fluid.Get(marker)),litres,'Native marker')
    assert(L.matches(ledger,Q.amounts(fluid)),'Native/ledger mismatch')
    near(L.budget(ledger,'calories'),calories,'Calories');near(L.budget(ledger,'poisonPower'),dose,'Poison')
    assert(L.quality(ledger)=='rotten','Freshness');local taint=false
    for _,lot in ipairs(ledger.lots) do taint=taint or lot.food.tainted end
    assert(taint,'Taint')
end
local function outputs(inv,f)
    local rows={};local items=inv:getItems()
    for i=0,items:size()-1 do local item=items:get(i)
        if item:getFullType()=='Hydrocraft.HCVodkaFluid' and not f.previous[tostring(item:getID())] then rows[#rows+1]=item end
    end
    return rows
end
local function chemicalOutputs(inv,f)
    local rows={};local items=inv:getItems()
    for i=0,items:size()-1 do local item=items:get(i)
        if item:getFullType()=='Hydrocraft.HCMethanol' and not f.previous[tostring(item:getID())] then rows[#rows+1]=item end
    end
    return rows
end
local function observe(f,p,player,owner)
    local inv=player:getInventory();local common=shared(f):getContainer()
    local function get(label) return assert(find(common,f.run..'-'..label),'Missing '..label) end
    liquid(get('legacy'),'HCRMashPotatoReady',20,0,.875)
    assert(raw(get('legacy')).lots[1].fermentation.kind=='Hydrocraft.HCBarrelpotato','Legacy barrel needs no waiting')
    local cask=get('cask');assert(cask:getID()==f.caskId,'Cask replaced')
    if p=='initial' then
        assert(Q.fluid(cask):isEmpty(),'Initial cask not empty')
        for i=1,6 do liquid(get('pot'..i),'HCRMashPotato',.25,137,.125) end
        near(Q.rawAmount(Q.fluid(get('water'))),20,'Initial water')
    elseif p=='fill' or p=='mature' then
        local marker=p=='fill' and 'HCRMashPotato' or 'HCRMashPotatoReady'
        liquid(cask,marker,20,822,.75)
        local kind=p=='fill' and 'Hydrocraft.HCRFermentPotato' or 'Hydrocraft.HCBarrelpotato'
        for _,lot in ipairs(raw(cask).lots) do assert(lot.fermentation.kind==kind,'Stage') end
        for i=1,6 do assert(Q.fluid(get('pot'..i)):isEmpty(),'Donor pot not empty') end
        near(Q.rawAmount(Q.fluid(get('water'))),1.5,'Water after fill')
    elseif p=='distill' then
        if owner then
            local rows=outputs(inv,f);assert(#rows==20,'Twenty native outputs')
            for _,item in ipairs(rows) do liquid(item,'HCRVodka',1,f.calories,.75/20) end
        end
    else
        local rows=outputs(common,f);assert(#rows==20,'Twenty shared outputs')
        local ids={};for _,item in ipairs(rows) do
            assert(not ids[item:getID()],'Duplicate output ID');ids[item:getID()]=true
            assert(f.ids[tostring(item:getID())],'Output identity changed')
            liquid(item,'HCRVodka',1,f.calories,.75/20)
        end
        if owner then assert(#outputs(inv,f)==0,'Owner duplicate bottles') end
    end
    if p=='distill' or p=='share' or p=='verify' or p=='cold' then
        assert(Q.fluid(cask):isEmpty(),'Distillation consumed cask')
        near(Q.rawAmount(Q.fluid(get('water'))),1.5,'Unselected water unchanged')
        near(Q.rawAmount(Q.fluid(get('cooling'))),0,'Six litres cooling water')
        for i=1,6 do assert(Q.fluid(get('pot'..i)):isEmpty(),'Pot after distillation') end
    end
    if p=='cold' then
        local role=isServer() and 'server' or owner and 'owner' or 'observer'
        assert(f.boots[role]~=HCRLabMashMPBoot,'Cold process not restarted '..role)
    end
    local after=p=='chemical' or p=='share_chemical' or p=='verify' or p=='cold'
    liquid(get('chemicalSource'),'HCRVodka',after and .5 or 1.5,after and 137/3 or 137,after and .25 or .75)
    if p=='chemical' and owner then
        local rows=chemicalOutputs(inv,f);assert(#rows==1 and rows[1]:getCurrentUses()==4,'Native methanol output')
    elseif p=='share_chemical' or p=='verify' or p=='cold' then
        local rows=chemicalOutputs(common,f)
        assert(#rows==1 and rows[1]:getCurrentUses()==4 and rows[1]:getID()==f.chemicalId,'Shared methanol identity/uses')
        if owner then assert(#chemicalOutputs(inv,f)==0,'Duplicated methanol') end
    end
end
local function broadcast(command,args)
    args.mash=true;for _,p in pairs(M.state.players) do sendServerCommand(p,'HCRLabTwo',command,args) end
end
local function phase(index)
    local state=M.state;state.index=index;state.phase=state.cold and (index==1 and 'cold' or nil) or not state.cold and phases[index]
    state.acks={};state.since=getTimestampMs()
    if not state.phase then
        state.complete=true
        if not state.cold then shared(state.f):getModData().HCRMashMPSaved=state.f;shared(state.f):transmitModData() end
        broadcast('complete',{cold=state.cold});log('SERVER PASS '..(state.cold and 'cold' or 'all eight phases'));return
    end
    if state.phase=='mature' then
        local cask=find(shared(state.f):getContainer(),state.f.run..'-cask');local now=getGameTime():getWorldAgeHours()
        for _,lot in ipairs(raw(cask).lots) do lot.fermentation.startedAt=now-336;lot.fermentation.lastHour=now end
        Q.capture(cask,Q.fluid(cask));Q.sync(cask,state.players.owner)
    end
    broadcast('phase',{f=state.f,phase=state.phase});log('SERVER phase '..state.phase)
end
function M.start(cold)
    assert(isServer());local pair={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do local p=all:get(i)
        if p:getUsername()=='HCRLabOwner' then pair.owner=p elseif p:getUsername()=='HCRLabObserver' then pair.observer=p end
    end
    assert(pair.owner and pair.observer,'Both clients required');local player=pair.owner;local square=player:getSquare()
    assert(math.abs(player:getX()-pair.observer:getX())<5 and math.abs(player:getY()-pair.observer:getY())<5,'Players apart')
    if cold then
        local saved
        for x=square:getX()-2,square:getX()+2 do for y=square:getY()-2,square:getY()+2 do
            local sq=getCell():getGridSquare(x,y,square:getZ());if sq then local objects=sq:getObjects()
                for i=0,objects:size()-1 do local row=objects:get(i):getModData().HCRMashMPSaved
                    if row and (not saved or tonumber(row.run)>tonumber(saved.run)) then saved=row end
                end
            end
        end end
        M.state={f=assert(saved,'No saved mash run'),players=pair,cold=true};phase(1);return
    end
    local run=tostring(getTimestampMs());local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),previous={},boots={server=HCRLabMashMPBoot}}
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true);player:getBodyDamage():RestoreToFullHealth()
    local crate=tag(IsoObject.new(getCell(),square,'carpentry_01_16'),run)
    local common=ItemContainer.new('crate',square,crate);common:setCapacity(100);crate:setContainer(common)
    local function add(kind,label) local item=tag(assert(instanceItem(kind)),run..'-'..label);common:AddItem(item);return item end
    f.caskId=add('Hydrocraft.HCWoodenbarrelFluid','cask'):getID()
    for i=1,6 do
        local kind=i<=3 and 'Hydrocraft.HCPotofpotatomashcooked' or 'Hydrocraft.HCPotofpotatomash'
        local item=add(kind,'pot'..i);item:setHungChange(item:getBaseHunger()*.5);item:setCalories(137)
        if i>3 then item:setCooked(true) end
        F.store(item,.125);F.setQuality(item,'rotten');F.setTainted(item)
    end
    HCRProcessQuality.write(add('Hydrocraft.HCBarrelpotato','legacy'),{quality='rotten',dose=.875,tainted=true,detection=4},1,nil)
    Q.fluid(add('Hydrocraft.HCWoodenbarrelFluid','water')):addFluid('Water',20)
    Q.fluid(add('Hydrocraft.HCWoodenbarrelFluid','cooling')):addFluid('Water',6)
    add('Base.Charcoal','charcoal');add('Base.Lighter','fire')
    add('Base.Charcoal','chemicalCharcoal');add('Base.Lighter','chemicalFire')
    local source=add('Base.Pot','chemicalSource');local old=instanceItem('Hydrocraft.HCVodka')
    old:setCalories(137);F.store(old,.75);F.setQuality(old,'rotten');F.setTainted(old)
    Q.fluid(source):addFluid('HCRVodka',1.5)
    Q.store(source,Q.fluid(source),L.batch('HCRVodka',1.5,HCRFluidEffects.snapshot(old),getGameTime():getWorldAgeHours()))
    for i=1,20 do local item=add('Base.Whiskey','bottle'..i);Q.fluid(item):setCanPlayerEmpty(true);Q.fluid(item):Empty() end
    square:AddTileObject(crate);crate:transmitCompleteItemToClients()
    local inv=player:getInventory();local still=tag(instanceItem('Hydrocraft.HCDistillery2'),run..'-still');inv:AddItem(still);sendAddItemToContainer(inv,still)
    local light=tag(instanceItem('Base.HandTorch'),run..'-light');light:setUsedDelta(1);light:setActivated(true);inv:AddItem(light);sendAddItemToContainer(inv,light)
    for _,name in ipairs({'Fill Barrel with Potato Mash','Distill Bottle of Vodka'}) do player:learnRecipe(name) end
    local items=inv:getItems();for i=0,items:size()-1 do f.previous[tostring(items:get(i):getID())]=true end
    f.calories=instanceItem('Hydrocraft.HCVodka'):getCalories()
    M.state={f=f,players=pair};phase(1)
end
function M.server(command,player,args)
    local s=M.state;if not s or s.failed or s.complete or args.run~=s.f.run then return end
    if command=='fail' then s.failed=true;log('SERVER FAIL '..tostring(args.reason));return end
    if command~='ack' or args.phase~=s.phase then return end
    local role=player==s.players.owner and 'owner' or player==s.players.observer and 'observer' or nil
    if not role then return end;s.acks[role]=true
    if s.phase=='initial' then s.f.boots[role]=args.boot end
    if s.acks.owner and s.acks.observer then
        local ok,why=pcall(observe,s.f,s.phase,s.players.owner,true)
        if not ok then log('SERVER awaiting '..tostring(why));return end
        if s.phase=='distill' then s.f.ids={};for _,item in ipairs(outputs(player==s.players.owner and player:getInventory() or s.players.owner:getInventory(),s.f)) do s.f.ids[tostring(item:getID())]=true end end
        if s.phase=='chemical' then s.f.chemicalId=chemicalOutputs(s.players.owner:getInventory(),s.f)[1]:getID() end
        phase(s.index+1)
    end
end
function M.client(command,args)
    if command=='phase' then M.localState={f=args.f,phase=args.phase,ticks=0,stable=0};log('CLIENT phase '..args.phase)
    elseif command=='complete' then M.localState=nil;log('CLIENT PASS '..(args.cold and 'cold' or 'all eight phases')) end
end
local function act(s,player)
    local f=s.f;local inv=player:getInventory();local common=shared(f):getContainer()
    local function get(label)
        -- Native очередь переносит частично использованные топливо/огонь
        -- из общего контейнера к игроку для следующего действия.
        return (assert(find(common,f.run..'-'..label) or find(inv,f.run..'-'..label),'Missing input '..label))
    end
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    if s.phase=='initial' then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player,assert(find(inv,f.run..'-light')),50,false,false))
    elseif s.phase=='fill' then
        local pots={};for i=1,6 do pots[i]=get('pot'..i) end
        HCRLabDrinksMP.craft(player,common,'Fill Barrel with Potato Mash',{{get('cask')},pots,{get('water')}})
    elseif s.phase=='distill' then
        local bottles={};for i=1,20 do bottles[i]=get('bottle'..i) end
        HCRLabDrinksMP.craft(player,common,'Distill Bottle of Vodka',{{get('cask')},{get('charcoal')},{get('fire')},bottles,{get('cooling')},{assert(find(inv,f.run..'-still'))}})
    elseif s.phase=='share' then
        for _,item in ipairs(outputs(inv,f)) do ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,inv,common)) end
    elseif s.phase=='chemical' then
        HCRLabDrinksMP.craft(player,common,'Make Methanol',{{get('chemicalSource')},{get('chemicalCharcoal')},{get('chemicalFire')},{assert(find(inv,f.run..'-still'))}})
    elseif s.phase=='share_chemical' then
        for _,item in ipairs(chemicalOutputs(inv,f)) do ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,inv,common)) end
    end
    s.acted=true
end
function M.tick()
    if isServer() then local s=M.state
        if s and not s.failed and not s.complete and getTimestampMs()-s.since>180000 then s.failed=true;log('SERVER FAIL timeout '..s.phase) end
        return
    end
    local s=M.localState;if not s or s.failed or not getPlayer() then return end
    s.ticks=s.ticks+1;if s.ticks%30~=0 then return end
    local player=getPlayer();local owner=player:getUsername()=='HCRLabOwner'
    if owner and not s.acted then local ok,why=pcall(act,s,player)
        if not ok then s.failed=true;sendClientCommand(player,'HCRLabTwo','fail',{mash=true,run=s.f.run,reason=tostring(why)});log('CLIENT FAIL '..tostring(why));return end
    end
    if owner and ISTimedActionQueue.isPlayerDoingAction(player) then s.stable=0;return end
    local ok,why=pcall(observe,s.f,s.phase,player,owner);s.stable=ok and s.stable+30 or 0
    if s.stable>=120 and s.stable%120==0 then
        sendClientCommand(player,'HCRLabTwo','ack',{mash=true,run=s.f.run,phase=s.phase,boot=HCRLabMashMPBoot});log('CLIENT independently observed '..s.phase)
    elseif s.ticks%600==0 then log('CLIENT awaiting '..s.phase..' '..tostring(why)) end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args) if args.mash then return M.server(command,player,args) end;return server(command,player,args) end
    HCRLabTwo.client=function(command,args) if args.mash then return M.client(command,args) end;return client(command,args) end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();M.tick();ticks=ticks+1;if ticks%60~=0 then return end
        local r=getFileReader('HCRLabMashMPCommand.txt',false);local line=r and r:readLine();if r then r:close() end
        if line and line~=last then last=line;local seq,command=line:match('^(%d+):(%w+)$')
            if command then local ok,why=pcall(function() assert(command=='start' or command=='verify');M.start(command=='verify') end)
                log(line..' '..(ok and 'PASS' or 'FAIL '..tostring(why)))
            end
        end
    end
end
