-- Частный MP oracle: native переливание одновременно с очередью переносов
-- в наружную сумку; ссылки вложенных сосудов, пустой сосуд, refill и cold reload.
require 'HCR_FluidSync'
HCRLabMutationMP={}
HCRLabMutationBoot=HCRLabMutationBoot or tostring(getTimestampMs())
local M,Q,L=HCRLabMutationMP,HCRFluidQuality,HCRFluidLedger
local MODULE='HCRLabTwo'
local function log(s) print('[HCRMutationMP] '..s) end
local function near(a,b,name) assert(a and math.abs(a-b)<.00002,name..' '..tostring(a)..' / '..tostring(b)) end
local function players()
    local out={};local list=getOnlinePlayers()
    for i=0,list:size()-1 do
        local p=list:get(i)
        if p:getUsername()=='HCRLabOwner' then out.owner=p elseif p:getUsername()=='HCRLabObserver' then out.observer=p end
    end
    assert(out.owner and out.observer,'Two real clients required');return out
end
local function emit(command,args)
    args.mutation=true;for _,p in pairs(players()) do sendServerCommand(p,MODULE,command,args) end
end
local function byId(c,id)
    local out;local list=c:getItems()
    for i=0,list:size()-1 do
        local item=list:get(i)
        if item:getID()==id then assert(not out,'Duplicate item ID');out=item end
    end
    return assert(out,'Missing item '..tostring(id))
end
local function refs(f)
    local sq=assert(getCell():getGridSquare(f.x,f.y,f.z),'Square unloaded');local outer
    for i=0,sq:getWorldObjects():size()-1 do
        local item=sq:getWorldObjects():get(i):getItem()
        if item and item:getModData().HCRMutationTag==f.run then assert(not outer,'Duplicate outer bag');outer=item end
    end
    assert(outer,'Missing outer bag');assert(outer:getID()==f.outer,'Outer ID changed')
    local a=byId(outer:getItemContainer(),f.a);local b=byId(outer:getItemContainer(),f.b)
    local source=byId(a:getItemContainer(),f.source);local target=byId(b:getItemContainer(),f.target)
    return {outer=outer,a=a,b=b,ca=a:getItemContainer(),cb=b:getItemContainer(),source=source,target=target,
        sf=Q.fluid(source),tf=Q.fluid(target)}
end
local function verify(f,phase,original)
    local r=refs(f)
    if original then for key,value in pairs(original) do assert(r[key]==value,'Reference replaced: '..key) end end
    local initial=phase=='initial';local final=phase=='pourback' or phase=='cold'
    local sourceAmount=initial and 2 or final and 1.2 or 1
    local targetAmount=initial and 0 or phase=='empty' and 0 or phase=='refill' and .7 or final and .5 or 1
    near(Q.rawAmount(r.sf),sourceAmount,'Source litres');near(Q.rawAmount(r.tf),targetAmount,'Target litres')
    near(r.sf:getSpecificFluidAmount(Fluid.Get('HCRMilk')),initial and 1 or .5,'Source milk')
    near(r.sf:getSpecificFluidAmount(Fluid.Get('Water')),initial and 1 or final and .7 or .5,'Source water')
    assert(r.sf:getPrimaryFluid()==Fluid.Get('Water'),'Equal-volume primary order changed')
    local source=assert(r.source:getModData()[Q.key],'Source ledger absent')
    near(L.budget(source,'calories'),initial and 615 or 307.5,'Source calories')
    near(L.budget(source,'poisonPower'),initial and .875 or .4375,'Source poison')
    assert(L.matches(source,Q.amounts(r.sf)) and L.quality(source)=='fresh','Source quality')
    local target=r.target:getModData()[Q.key]
    if phase=='concurrent' then
        assert(target,'Target ledger absent');near(L.budget(target,'calories'),307.5,'Target calories')
        near(L.budget(target,'poisonPower'),.4375,'Target poison')
        near(r.tf:getSpecificFluidAmount(Fluid.Get('HCRMilk')),.5,'Target milk')
        -- Native Transfer обходит source компоненты с конца: при равенстве
        -- целевой primary должен остаться HCRMilk, исходный — Water.
        assert(r.tf:getPrimaryFluid()==Fluid.Get('HCRMilk'),'Target primary order changed')
        assert(L.matches(target,Q.amounts(r.tf)),'Target marker mismatch')
    else
        assert(not target,'Empty/native-water vessel retained old food')
        if targetAmount>0 then near(r.tf:getSpecificFluidAmount(Fluid.Get('Water')),targetAmount,'Native refill') end
    end
    assert(r.source:getModData().HCRMutationOther=='kept' and r.target:getModData().HCRMutationOther=='kept','Unrelated metadata lost')
    -- getName у FluidContainer всегда возвращает native UI-name жидкости.
    assert(r.source:isFavorite() and r.source:isCustomName(),'Base item state changed')
    if not initial then for _,id in ipairs(f.cups) do byId(r.outer:getItemContainer(),id) end end
    return r
end
local function phase(name)
    local s=M.state;s.phase=name;s.acks={};s.since=getTimestampMs();emit('phase',{phase=name,f=s.f})
    log('SERVER phase '..name)
end
local function transfer(source,target,amount,owner)
    Q.transfer(ISFluidContainer:new(source),ISFluidContainer:new(target),owner,function()
        FluidContainer.Transfer(source,target,amount)
        ISFluidContainer:new(source):sync();ISFluidContainer:new(target):sync()
    end)
end
function M.start()
    assert(isServer(),'Server only');assert(not M.state or M.state.complete,'Previous run incomplete')
    local all=players();local f={run=tostring(getTimestampMs()),x=10656,y=9414,z=0,cups={},
        serverBoot=HCRLabMutationBoot,clientBoots={},instant=all.owner:isTimedActionInstant()}
    local sq=assert(getCell():getGridSquare(f.x,f.y,f.z),'Fixture square absent')
    local outer=instanceItem('Base.Bag_Schoolbag');outer:getModData().HCRMutationTag=f.run;f.outer=outer:getID()
    local a=outer:getItemContainer():AddItem('Base.Bag_Schoolbag')
    local b=outer:getItemContainer():AddItem('Base.Bag_Schoolbag');f.a=a:getID();f.b=b:getID()
    local source=a:getItemContainer():AddItem('Hydrocraft.HCWoodenbucketFluid')
    local target=b:getItemContainer():AddItem('Hydrocraft.HCWoodenbucketFluid');f.source=source:getID();f.target=target:getID()
    source:setName('HCR mutation source');source:setCustomName(true);source:setFavorite(true)
    source:getModData().HCRMutationOther='kept';target:getModData().HCRMutationOther='kept'
    local fluid=Q.fluid(source);fluid:Empty();fluid:addFluid('Water',1);fluid:addFluid('HCRMilk',1)
    Q.fluid(target):Empty()
    sq:AddWorldInventoryItem(outer,.7,.7,0,true)
    Q.store(source,fluid,L.batch('HCRMilk',1,{age=1,offAge=4,offAgeMax=7,calories=615,poisonPower=.875,canBeFrozen=false},getGameTime():getWorldAgeHours()))
    -- Исходный bag snapshot создаётся до захвата ссылок, дальнейшие фазы
    -- не заменяют ни один из уже существующих контейнеров.
    outer:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
    for i=1,4 do
        local cup=all.owner:getInventory():AddItem('Base.Mugl');f.cups[i]=cup:getID();sendAddItemToContainer(all.owner:getInventory(),cup)
    end
    all.owner:setTimedActionInstantCheat(false)
    M.state={f=f,refs=refs(f),mutations=0,ticks=0,since=getTimestampMs()}
    verify(f,'initial',M.state.refs);phase('initial')
end
function M.verifySaved()
    assert(isServer(),'Server only')
    local f=assert(HCRLabTwo.savedNearby(players().owner,'HCRMutationSaved'),'Missing saved mutation fixture')
    assert(f.serverBoot~=HCRLabMutationBoot,'Server did not restart')
    M.state={f=f,cold=true};verify(f,'cold');phase('cold')
end
function M.server(command,player,args)
    local s=M.state;if not s or s.complete or s.failed or args.run~=s.f.run then return end
    local name=player:getUsername();assert(name=='HCRLabOwner' or name=='HCRLabObserver','Unknown client')
    if command=='fail' then s.failed=true;log('SERVER FAIL '..tostring(args.reason));return end
    if command=='queued' and name=='HCRLabOwner' and s.phase=='concurrent' then s.queued=true;return end
    if command~='ack' or args.phase~=s.phase then return end
    s.acks[name]=true
    if s.phase=='initial' then s.f.clientBoots[name]=args.boot end
    if not(s.acks.HCRLabOwner and s.acks.HCRLabObserver) then return end
    verify(s.f,s.phase,s.refs)
    local r=s.refs;local owner=players().owner
    if s.phase=='initial' then phase('concurrent')
    elseif s.phase=='concurrent' then
        assert(s.mutations==4,'Missing concurrent native transfers')
        Q.remove(r.target,owner,function() r.tf:Empty();r.target:syncItemFields() end,false)
        phase('empty')
    elseif s.phase=='empty' then
        Q.addNative(r.target,owner,function() r.tf:addFluid('Water',.7);r.target:syncItemFields() end)
        phase('refill')
    elseif s.phase=='refill' then transfer(r.tf,r.sf,.2,owner);phase('pourback')
    else
        s.complete=true
        if not s.cold then
            r.outer:getModData().HCRMutationSaved=L.copy(s.f)
            r.outer:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
            owner:setTimedActionInstantCheat(s.f.instant)
        end
        emit('complete',{cold=s.cold or false,instant=s.f.instant})
        log(s.cold and 'SERVER PASS cold reload saved IDs/contents/quality' or 'SERVER PASS nested native mutations, four queued transfers, stable references, empty/refill/pourback')
    end
end
function M.client(command,args)
    if command=='phase' then
        local previous=M.localState
        local s={f=args.f,phase=args.phase,since=getTimestampMs(),ticks=0,stable=0}
        if previous and previous.f.run==s.f.run then s.refs=previous.refs end
        M.localState=s;log('CLIENT phase '..s.phase)
        if s.phase=='cold' then assert(s.f.clientBoots[getPlayer():getUsername()]~=HCRLabMutationBoot,'Client did not restart') end
        if s.phase=='concurrent' and getPlayer():getUsername()=='HCRLabOwner' then
            local p=getPlayer();p:setTimedActionInstantCheat(false)
            for _,id in ipairs(s.f.cups) do
                local item=byId(p:getInventory(),id)
                -- Native ContainerID не адресует destination во вложенной
                -- наземной сумке. Очередь идёт в наружную, внутри которой
                -- одновременно меняются жидкости; старый SWAP ломал и её.
                ISTimedActionQueue.add(ISInventoryTransferAction:new(p,item,p:getInventory(),s.refs.outer:getItemContainer()))
            end
            sendClientCommand(p,MODULE,'queued',{mutation=true,run=s.f.run})
        end
    elseif command=='complete' then
        if getPlayer():getUsername()=='HCRLabOwner' then getPlayer():setTimedActionInstantCheat(args.instant) end
        M.localState=nil;log(args.cold and 'CLIENT PASS cold reload saved IDs/contents/quality'
            or 'CLIENT PASS independent queued transfers and exact native contents, references preserved')
    end
end
function M.tick()
    local s=isServer() and M.state or M.localState
    if not s or s.complete or s.failed then return end
    if getTimestampMs()-s.since>180000 then s.failed=true;log('FAIL timeout '..s.phase..' '..tostring(s.reason));return end
    if isServer() then
        if s.phase=='concurrent' and s.queued and s.mutations<4 then
            s.ticks=s.ticks+1
            if s.ticks%5==1 then
                transfer(s.refs.sf,s.refs.tf,.25,players().owner);s.mutations=s.mutations+1
                log('SERVER native mutation '..s.mutations)
            end
        end
        return
    end
    s.ticks=s.ticks+1;if s.ticks%30~=0 then return end
    local ok,result=pcall(verify,s.f,s.phase,s.refs)
    if ok then s.refs=s.refs or result;s.stable=s.stable+30 else s.reason=tostring(result);s.stable=0 end
    if s.stable>=120 and s.stable%120==0 then
        sendClientCommand(getPlayer(),MODULE,'ack',{mutation=true,run=s.f.run,phase=s.phase,boot=HCRLabMutationBoot})
    end
    if s.ticks%600==0 and s.stable==0 then log('CLIENT waiting '..s.phase..' '..tostring(s.reason)) end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args)
        if args.mutation then return M.server(command,player,args) end
        return server(command,player,args)
    end
    HCRLabTwo.client=function(command,args)
        if args.mutation then return M.client(command,args) end
        return client(command,args)
    end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();local ok,err=pcall(M.tick)
        if not ok then local s=isServer() and M.state or M.localState;if s then s.failed=true end;log('FAIL tick '..tostring(err)) end
        ticks=ticks+1;if ticks%60~=0 then return end
        local r=getFileReader('HCRLabMutationCommand.txt',false);if not r then return end
        local line=r:readLine();r:close();if not line or line==last then return end;last=line
        local n,command=line:match('^(%d+):([%w]+)$');if not command then return end
        local pass,reason=pcall(function()
            if command=='start' then M.start() elseif command=='verify' then M.verifySaved() else error('Unknown mutation command') end
        end)
        log(n..':'..command..' '..(pass and 'PASS' or 'FAIL '..tostring(reason)))
    end
end
