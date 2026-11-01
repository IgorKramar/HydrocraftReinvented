-- Только приватный localhost lab. Часы идут вперёд штатными тиками;
-- обе стороны и сервер независимо наблюдают выгруженный участок и отключение.
require 'HCR_FluidQuality'
HCRLabStoragePower={}
local P,Q,L=HCRLabStoragePower,HCRFluidQuality,HCRFluidLedger
local MODULE='HCRLabTwo'
local function log(s) print('[HCRStoragePower] '..s) end
local function hour() return getGameTime():getWorldAgeHours() end
local function near(a,b,name) assert(a and math.abs(a-b)<.00015,name..' '..tostring(a)..' / '..tostring(b)) end
local function players()
    local result={};local list=getOnlinePlayers()
    for i=0,list:size()-1 do
        local p=list:get(i)
        if p:getUsername()=='HCRLabOwner' then result.owner=p end
        if p:getUsername()=='HCRLabObserver' then result.observer=p end
    end
    assert(result.owner and result.observer,'Both private clients required');return result
end
local function emit(command,args)
    args.storagePower=true
    for _,p in pairs(players()) do sendServerCommand(p,MODULE,command,args) end
end
local function speed(value) getGameTime():setMinutesPerDay(value) end
local function phase(name)
    local s=P.state;s.phase=name;s.acks={};s.since=getTimestampMs()
    speed((name=='approach' or name=='absent') and 1 or s.f.minutes)
    emit('phase',{phase=name,f=s.f});log('SERVER phase '..name..' hour='..hour())
end
local function fail(reason)
    local s=isServer() and P.state or P.localState
    if not s then return end
    speed(s.f.minutes);log((isServer() and 'SERVER' or 'CLIENT')..' FAIL '..tostring(reason))
    if isServer() and s.phase~='restore' then
        s.aborted=true;s.failed=nil;phase('restore')
    else
        s.failed=true
        if not isServer() then
            sendClientCommand(getPlayer(),MODULE,'fail',{storagePower=true,run=s.f.run,reason=tostring(reason)})
        end
    end
end
local function optionMatch(f,restore)
    local o=getSandboxOptions()
    return o:getElecShutModifier()==(restore and f.oldCut or f.cutDay)
        and o:getTimeSinceApo()==(restore and f.oldApo or f.apo)
        and SandboxVars.ElecShutModifier==(restore and f.oldCut or f.cutDay)
        and SandboxVars.TimeSinceApo==(restore and f.oldApo or f.apo)
end
local function configure(f,restore)
    assert(getPlayer():getUsername()=='HCRLabOwner','Only lab owner configures server')
    local o=SandboxOptions.new();o:copyValuesFrom(getSandboxOptions())
    o:getOptionByName('ElecShutModifier'):setValue(restore and f.oldCut or f.cutDay)
    o:getOptionByName('TimeSinceApo'):setValue(restore and f.oldApo or f.apo)
    o:sendToServer()
end
local function square(f) return getCell():getGridSquare(f.x,f.y,f.z) end
local function containers(f)
    local sq=assert(square(f),'Origin is unloaded');local fridge,freezer
    for i=0,sq:getObjects():size()-1 do
        local obj=sq:getObjects():get(i)
        for n=0,obj:getContainerCount()-1 do
            local c=obj:getContainerByIndex(n)
            if c:isFridge() then fridge=c end
            if c:isFreezer() then freezer=c end
        end
    end
    assert(fridge and freezer,'Actual fridge/freezer required');return fridge,freezer
end
local function locate(f)
    local sq=assert(square(f),'Origin unloaded');local found={}
    local function visit(c)
        for i=0,c:getItems():size()-1 do
            local item=c:getItems():get(i);local tag=item:getModData().HCRPowerTag
            if tag and f.samples[tag] then assert(not found[tag],'Duplicate sample');found[tag]=item end
            if instanceof(item,'InventoryContainer') then visit(item:getItemContainer()) end
        end
    end
    for i=0,sq:getObjects():size()-1 do
        local obj=sq:getObjects():get(i)
        for n=0,obj:getContainerCount()-1 do visit(obj:getContainerByIndex(n)) end
    end
    for i=0,sq:getWorldObjects():size()-1 do
        local item=sq:getWorldObjects():get(i):getItem()
        if item and instanceof(item,'InventoryContainer') then visit(item:getItemContainer()) end
    end
    return found
end
-- Независимая интегральная формула; не вызывает Q.capture/Q.age/C.advance.
local function coldHours(from,to,cut,factor)
    if to<=from then return 0 end
    return math.max(0,math.min(to,cut)-from)*factor+math.max(0,to-math.max(from,cut))
end
local function verify(f,returned)
    local found=locate(f)
    for tag,spec in pairs(f.samples) do
        local item=assert(found[tag],'Missing '..tag);assert(item:getID()==spec.id,'ID changed')
        local fluid=assert(Q.fluid(item),'Missing fluid')
        near(Q.rawAmount(fluid),1,'Litres');near(fluid:getSpecificFluidAmount(Fluid.Get('HCRMilk')),1,'Milk')
        local ledger=assert(item:getModData()[Q.key],'Missing actual received ledger')
        assert(#ledger.lots==1,'Lot count');local lot=ledger.lots[1]
        near(L.budget(ledger,'calories'),615,'Calories');near(L.budget(ledger,'poisonPower'),.875,'Dose')
        local from=spec.hour
        if spec.freezer then from=math.max(from,f.cut+1.5) end
        local elapsed=spec.cold and coldHours(from,lot.lastHour,f.ageCut,f.factor)
            or math.max(0,lot.lastHour-from)
        near(lot.age,spec.age+elapsed*f.rot/24,'Elapsed age '..spec.name)
        local freezing=spec.freezer and math.max(0,100-math.max(0,lot.lastHour-f.cut)*100/1.5) or 0
        near(lot.food.freezingTime or 0,freezing,'Freezing '..spec.name)
        assert((lot.food.frozen or false)==(spec.freezer and freezing>0),'Frozen flag')
        local env=Q.environment(item)
        assert(env.cold==spec.cold and env.freezer==spec.freezer,'Environment changed')
        assert(not env.powered,'Generator would invalidate grid oracle')
        if spec.cold then
            assert(env.operationalPowered==not returned and env.gridPowered==not returned,'Native power state')
        end
        if returned then
            assert(lot.lastHour>=f.cut+2,'Storage did not resume after cutoff')
            assert(lot.lastHour<=hour()+.05,'Ledger is in future')
        end
    end
    return true
end
local function seed(f)
    local fridge,freezer=containers(f)
    assert(fridge:isPowered() and freezer:isPowered(),'Grid must be on before seed')
    assert(hour()<f.cut-1,'Not enough time before cutoff');f.samples={}
    local function sample(c,name,cold,frozen)
        local item=c:AddItem('Hydrocraft.HCWoodenbucketFluid');local fluid=Q.fluid(item)
        local tag=f.run..'-'..name;item:getModData().HCRPowerTag=tag
        fluid:Empty();fluid:addFluid('HCRMilk',1)
        local now=hour()
        Q.store(item,fluid,L.batch('HCRMilk',1,{age=1,offAge=4,offAgeMax=7,calories=615,
            poisonPower=.875,canBeFrozen=frozen,frozen=frozen,freezingTime=frozen and 100 or 0},now))
        f.samples[tag]={id=item:getID(),hour=now,age=1,cold=cold,freezer=frozen,name=name}
        return item
    end
    local a=sample(fridge,'fridge',true,false);local b=sample(freezer,'freezer',true,true)
    sendAddItemToContainer(fridge,a);sendAddItemToContainer(freezer,b)
    local bag=instanceItem('Base.Bag_Schoolbag');local inner=bag:getItemContainer():AddItem('Base.Bag_Schoolbag')
    local c=sample(inner:getItemContainer(),'nested-ground',false,false)
    square(f):AddWorldInventoryItem(bag,.6,.6,0,true)
    Q.store(c,Q.fluid(c),c:getModData()[Q.key]);Q.sync(c)
    verify(f,false);phase('baseline')
end
function P.start(apo)
    assert(isServer(),'Start belongs to server')
    assert(not P.state or P.state.complete,'Previous power test incomplete')
    local all=players();local o=getSandboxOptions()
    local cutoff=(math.floor(hour()/24)+2)*24
    local f={run=tostring(getTimestampMs()),apo=apo,cut=cutoff,ageCut=cutoff+(apo-1)*30*24,
        cutDay=cutoff/24+(apo-1)*30,oldCut=o:getElecShutModifier(),oldApo=o:getTimeSinceApo(),
        minutes=getGameTime():getMinutesPerDay(),x=10656,y=9413,z=0,
        factor=({.4,.3,.2,.1,.03,0})[SandboxVars.FridgeFactor or 3],
        rot=({1.7,1.4,1,.7,.4})[SandboxVars.FoodRotSpeed or 3]}
    assert(f.factor>0,'Positive cold factor required');containers(f)
    for _,p in pairs(all) do
        assert(math.abs(p:getX()-f.x)<12 and math.abs(p:getY()-f.y)<12,'Clients must start near fridge')
    end
    P.state={f=f,god={}}
    for name,p in pairs(all) do P.state.god[name]=p:isGodMod();p:setGodMod(true) end
    phase('configure')
    log('PLAN run='..f.run..' cut='..f.cut..' ageCut='..f.ageCut..' apo='..apo..' minutes='..f.minutes)
end
function P.server(command,player,args)
    local s=P.state
    if not s or s.complete or args.run~=s.f.run then return end
    if command=='fail' then fail(args.reason);return end
    if s.failed or command~='ack' or args.phase~=s.phase then return end
    local name=player:getUsername();assert(name=='HCRLabOwner' or name=='HCRLabObserver','Unknown client')
    s.acks[name]=true
    if not(s.acks.HCRLabOwner and s.acks.HCRLabObserver) then return end
    if s.phase=='configure' then
        assert(optionMatch(s.f,false),'Server options mismatch');phase('approach')
    elseif s.phase=='hold' then seed(s.f)
    elseif s.phase=='baseline' then verify(s.f,false);phase('away');log('READY teleport away')
    elseif s.phase=='away' and not square(s.f) then
        assert(hour()<s.f.cut,'Origin unloaded too late');s.f.absent=hour();phase('absent')
    elseif s.phase=='stop' then phase('return');log('READY teleport return')
    elseif s.phase=='return' then
        verify(s.f,true);log('SERVER verified all restored samples');phase('restore')
    elseif s.phase=='restore' then
        assert(optionMatch(s.f,true),'Original server options not restored');speed(s.f.minutes)
        for name,p in pairs(players()) do p:setGodMod(s.god[name]) end
        s.complete=true;emit('complete',{run=s.f.run,aborted=s.aborted or false})
        log(s.aborted and 'SERVER ABORT original options and lab flags restored'
            or 'SERVER PASS actual unloaded grid cutoff apo='..s.f.apo..' conserved IDs/budgets, thaw/age, original options restored')
    end
end
function P.client(command,args)
    if command=='phase' then
        local old=P.localState
        P.localState={f=args.f,phase=args.phase,ticks=0,stable=0,since=getTimestampMs(),
            absentStart=old and old.absentStart,absentEnd=old and old.absentEnd}
        local s=P.localState
        if s.phase=='configure' then P.savedGod=getPlayer():isGodMod();getPlayer():setGodMod(true) end
        speed((s.phase=='approach' or s.phase=='absent') and 1 or s.f.minutes)
        if (s.phase=='configure' or s.phase=='restore') and getPlayer():getUsername()=='HCRLabOwner' then
            configure(s.f,s.phase=='restore')
        end
        log('CLIENT phase '..s.phase..' hour='..hour())
    elseif command=='complete' then
        speed(P.localState.f.minutes);getPlayer():setGodMod(P.savedGod);P.localState=nil
        log(args.aborted and 'CLIENT ABORT original options and lab flags restored'
            or 'CLIENT PASS independently observed unloaded cutoff, raw restored samples, options restored')
    elseif command=='abort' then
        if P.localState then speed(P.localState.f.minutes);P.localState.failed=true end
    end
end
function P.tick()
    local s=isServer() and P.state or P.localState
    if not s or s.complete or s.failed then return end
    if getTimestampMs()-s.since>300000 then
        fail('timeout '..s.phase..' '..tostring(s.reason))
        return
    end
    if isServer() then
        if s.phase=='approach' and hour()>=s.f.cut-3 then phase('hold') end
        if s.phase=='absent' then
            assert(not square(s.f),'Server origin reloaded during absence')
            if hour()>=s.f.cut+2.5 then phase('stop') end
        end
        return
    end
    s.ticks=s.ticks+1;if s.ticks%30~=0 then return end
    if (s.phase=='absent' or s.phase=='stop') and square(s.f) then
        fail('origin reloaded during absence')
        return
    end
    if (s.phase=='away' or s.phase=='absent' or s.phase=='stop' or s.phase=='return') and not square(s.f) then
        s.absentStart=s.absentStart or hour();s.absentEnd=hour()
    end
    local ok,reason=pcall(function()
        if s.phase=='configure' or s.phase=='restore' then
            assert(optionMatch(s.f,s.phase=='restore'),'Waiting native Sandbox update')
            speed(s.f.minutes) -- applySettings может восстановить стандартный темп.
        elseif s.phase=='hold' then assert(hour()<s.f.cut-1,'Client clock too far ahead')
        elseif s.phase=='away' or s.phase=='absent' or s.phase=='stop' then
            assert(not square(s.f),'Origin still loaded')
            if s.phase=='away' then assert(hour()<s.f.cut,'Client unloaded too late') end
            if s.phase=='stop' then
                assert(hour()>s.f.cut+2,'Waiting native time sync')
                assert(s.absentStart<s.f.cut and s.absentEnd>s.f.cut+2,'Cutoff not observed while unloaded')
            end
        elseif s.phase=='baseline' or s.phase=='return' then verify(s.f,s.phase=='return')
        else return false end
        return true
    end)
    s.reason=not ok and tostring(reason) or nil
    s.stable=ok and reason and s.stable+30 or 0
    if s.stable>=120 and s.stable%120==0 and s.phase~='approach' and s.phase~='absent' then
        sendClientCommand(getPlayer(),MODULE,'ack',{storagePower=true,run=s.f.run,phase=s.phase})
    end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args)
        if args.storagePower then return P.server(command,player,args) end
        return server(command,player,args)
    end
    HCRLabTwo.client=function(command,args)
        if args.storagePower then return P.client(command,args) end
        return client(command,args)
    end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick()
        local ok,err=pcall(P.tick)
        if not ok then
            fail('tick '..tostring(err))
        end
        ticks=ticks+1;if ticks%60~=0 then return end
        local r=getFileReader('HCRLabPowerCommand.txt',false);if not r then return end
        local line=r:readLine();r:close();if not line or line==last then return end;last=line
        local n,cmd=line:match('^(%d+):([%w]+)$');if not cmd then return end
        local success,why=pcall(function()
            if cmd=='base' then P.start(1) elseif cmd=='offset' then P.start(2)
            elseif cmd=='restore' then assert(P.state,'No saved options');P.state.failed=nil;P.state.aborted=true;phase('restore')
            else error('Unknown power command') end
        end)
        log(n..':'..cmd..' '..(success and 'PASS' or 'FAIL '..tostring(why)))
    end
end
