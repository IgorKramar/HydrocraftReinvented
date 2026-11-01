-- Только отдельный localhost lab: настоящая выгрузка участка на трёх процессах.
-- Между уходом и возвратом держим только координаты/числа, не Java item ссылки.
require 'HCR_FluidQuality'
HCRLabStorageUnload={}
local S,Q,L=HCRLabStorageUnload,HCRFluidQuality,HCRFluidLedger
local MODULE='HCRLabTwo'
local function log(s) print('[HCRStorageUnload] '..s) end
local function near(a,b,label) assert(a and math.abs(a-b)<.00015,label..' '..tostring(a)..' / '..tostring(b)) end
local function players()
    local found={};local list=getOnlinePlayers()
    for i=0,list:size()-1 do
        local p=list:get(i);local name=p:getUsername()
        if name=='HCRLabOwner' then found.owner=p end
        if name=='HCRLabObserver' then found.observer=p end
    end
    assert(found.owner and found.observer,'Both private clients required')
    return found
end
local function emit(command,args)
    args.storage=true
    for _,p in pairs(players()) do sendServerCommand(p,MODULE,command,args) end
end
local function candidates()
    local p=players().owner;local found={}
    for dx=-55,55 do for dy=-55,55 do
        local sq=getCell():getGridSquare(math.floor(p:getX())+dx,math.floor(p:getY())+dy,0)
        if sq then
            for i=0,sq:getObjects():size()-1 do
                local object=sq:getObjects():get(i)
                local fridge,freezer
                for n=0,object:getContainerCount()-1 do
                    local c=object:getContainerByIndex(n)
                    if c:isFridge() then fridge=c end
                    if c:isFreezer() then freezer=c end
                end
                if fridge and freezer then
                    found[#found+1]={fridge=fridge,freezer=freezer,x=sq:getX(),y=sq:getY(),z=sq:getZ(),distance=dx*dx+dy*dy}
                end
            end
        end
    end end
    table.sort(found,function(a,b) return a.distance<b.distance end)
    return found
end
function S.probe()
    assert(isServer(),'Probe belongs to server')
    local found=candidates();assert(#found>0,'No actual refrigerator/freezer nearby')
    for i=1,math.min(5,#found) do
        local f=found[i]
        log('fridge/freezer '..f.x..','..f.y..','..f.z..' powered='..tostring(f.fridge:isPowered()))
    end
end
local function phase(name)
    S.state.phase=name;S.state.acks={};S.state.since=getTimestampMs()
    emit('phase',{phase=name,f=S.state.f});log('SERVER phase '..name)
end
local function loaded(f) return getCell():getGridSquare(f.x,f.y,f.z) end
local function locate(f)
    local sq=assert(loaded(f),'Origin is not loaded');local found={}
    local function visit(c)
        for i=0,c:getItems():size()-1 do
            local item=c:getItems():get(i);local label=item:getModData().HCRUnloadTag
            if label and f.samples[label] then
                assert(not found[label],'Duplicate storage sample');found[label]=item
            end
            if instanceof(item,'InventoryContainer') then visit(item:getItemContainer()) end
        end
    end
    for i=0,sq:getObjects():size()-1 do
        local object=sq:getObjects():get(i)
        for n=0,object:getContainerCount()-1 do visit(object:getContainerByIndex(n)) end
    end
    for i=0,sq:getWorldObjects():size()-1 do
        local item=sq:getWorldObjects():get(i):getItem()
        if item and instanceof(item,'InventoryContainer') then visit(item:getItemContainer()) end
    end
    return found
end
local function verify(f,returned)
    local found=locate(f)
    for label,spec in pairs(f.samples) do
        local item=assert(found[label],'Missing storage sample '..label)
        assert(item:getID()==spec.id,'Storage sample identity changed')
        local fluid=assert(Q.fluid(item),'Missing fluid component')
        near(Q.rawAmount(fluid),1,'Storage litres')
        near(fluid:getSpecificFluidAmount(Fluid.Get('HCRMilk')),1,'Storage contents')
        -- Читаем фактически полученные metadata. Q.capture вычислил бы возраст
        -- заново и тем самым скрыл отсутствие server re-registration.
        local ledger=assert(item:getModData()[Q.key],'Missing stored ledger')
        assert(#ledger.lots==1,'Storage lot count')
        local lot=ledger.lots[1]
        near(L.budget(ledger,'calories'),615,'Storage calories')
        near(L.budget(ledger,'poisonPower'),.875,'Storage exact poison')
        local expected=spec.age+(spec.frozen and 0 or (lot.lastHour-spec.hour)*spec.factor*f.rot/24)
        assert(math.abs(lot.age-expected)<.00001,'Storage elapsed age '..tostring(lot.age)..' / '..tostring(expected))
        assert((lot.food.frozen or false)==spec.frozen,'Storage frozen state')
        local env=Q.environment(item)
        assert(env.cold==spec.cold and env.freezer==spec.frozen,'Storage environment changed')
        if spec.cold then assert(env.operationalPowered and env.gridPowered and not env.powered,'Stable native grid required') end
        if returned then
            assert(lot.lastHour>=f.unloadedHour+.24,'Storage observer did not resume after unload')
            assert(lot.lastHour<=getGameTime():getWorldAgeHours()+.01,'Storage clock is in future')
        end
    end
    return true
end
function S.start()
    assert(isServer(),'Seed belongs to server')
    assert(not S.state or S.state.complete or S.state.failed,'Storage run already active')
    local target=assert(candidates()[1],'No actual refrigerator')
    for _,p in pairs(players()) do
        assert(math.abs(p:getX()-target.x)<12 and math.abs(p:getY()-target.y)<12,'Move both clients near refrigerator before seeding')
    end
    assert(target.fridge:isPowered() and target.freezer:isPowered(),'Native refrigerator must have grid power')
    local hour=getGameTime():getWorldAgeHours()
    assert(getSandboxOptions():getElecShutModifier()*24>hour+3,'Grid shutdown too close')
    local f={run=tostring(getTimestampMs()),x=target.x,y=target.y,z=target.z,samples={},
        rot=({1.7,1.4,1,.7,.4})[SandboxVars.FoodRotSpeed or 3]}
    local factor=({.4,.3,.2,.1,.03,0})[SandboxVars.FridgeFactor or 3]
    assert(factor>0,'Positive refrigerator ageing required for oracle')
    local function sample(container,label,cold,frozen)
        local item=container:AddItem('Hydrocraft.HCWoodenbucketFluid');local fluid=Q.fluid(item)
        local key=f.run..'-'..label;item:getModData().HCRUnloadTag=key
        fluid:Empty();fluid:addFluid('HCRMilk',1)
        Q.store(item,fluid,L.batch('HCRMilk',1,{age=1,offAge=4,offAgeMax=7,calories=615,
            poisonPower=.875,canBeFrozen=frozen,frozen=frozen,freezingTime=frozen and 100 or 0},hour))
        f.samples[key]={id=item:getID(),age=1,hour=hour,cold=cold,frozen=frozen,factor=cold and factor or 1}
        return item
    end
    local cold=sample(target.fridge,'fridge',true,false)
    local frozen=sample(target.freezer,'freezer',true,true)
    sendAddItemToContainer(target.fridge,cold);sendAddItemToContainer(target.freezer,frozen)
    local bag=instanceItem('Base.Bag_Schoolbag')
    local inner=bag:getItemContainer():AddItem('Base.Bag_Schoolbag')
    local warm=sample(inner:getItemContainer(),'nested-ground',false,false)
    getCell():getGridSquare(f.x,f.y,f.z):AddWorldInventoryItem(bag,.4,.4,0,true)
    -- Новое положение ground bag записывается до исходной сетевой проверки.
    Q.store(warm,Q.fluid(warm),warm:getModData()[Q.key]);Q.sync(warm)
    S.state={f=f};verify(f,false);phase('baseline')
end
function S.server(command,player,args)
    local state=S.state
    if not state or state.failed or state.complete or args.run~=state.f.run then return end
    local role=player:getUsername()
    if role~='HCRLabOwner' and role~='HCRLabObserver' then return end
    if command=='fail' then state.failed=true;log('SERVER FAIL '..role..' '..tostring(args.reason));return end
    if command~='ack' or args.phase~=state.phase then return end
    if state.phase=='return' and (not args.absentHours or args.absentHours<.24) then
        state.failed=true;log('SERVER FAIL insufficient independently observed client unload interval');return
    end
    state.acks[role]=true;log('SERVER independent '..role..' ACK '..state.phase)
    if not (state.acks.HCRLabOwner and state.acks.HCRLabObserver) then return end
    if state.phase=='baseline' then
        verify(state.f,false);phase('away');log('READY: teleport both clients at least 1024 tiles away')
    elseif state.phase=='away' then
        if loaded(state.f) then return end
        state.f.unloadedHour=getGameTime():getWorldAgeHours()
        phase('absent');log('SERVER origin unloaded; waiting native world time')
    elseif state.phase=='return' then
        local ok,err=pcall(verify,state.f,true)
        if not ok then state.failed=true;log('SERVER FAIL '..tostring(err));return end
        state.complete=true;log('SERVER PASS actual unload/reload, cold/freezer/nested ground, conserved budgets and resumed ageing')
        emit('complete',{run=state.f.run})
    end
end
function S.client(command,args)
    if command=='phase' then
        local old=S.localState
        if old and old.failed and old.f.run==args.f.run then return end
        S.localState={f=args.f,phase=args.phase,ticks=0,stable=0}
        if old and old.f.run==args.f.run then
            S.localState.absentStart=old.absentStart;S.localState.absentEnd=old.absentEnd
        end
        log('CLIENT phase '..args.phase)
    elseif command=='complete' then S.localState=nil;log('CLIENT PASS independently observed actual unload and restored samples') end
end
function S.tick()
    local state=isServer() and S.state or S.localState
    if not state or state.failed or state.complete then return end
    if isServer() then
        if getTimestampMs()-state.since>300000 then state.failed=true;log('SERVER FAIL timeout '..state.phase);return end
        if state.phase=='absent' then
            if loaded(state.f) then state.failed=true;log('SERVER FAIL origin reloaded before elapsed interval');return end
            if getGameTime():getWorldAgeHours()-state.f.unloadedHour>=.25 then
                phase('return');log('READY: teleport both clients back near '..state.f.x..','..state.f.y..','..state.f.z)
            end
        end
        return
    end
    state.ticks=state.ticks+1;if state.ticks%30~=0 then return end
    local ok=false
    if (state.phase=='away' or state.phase=='absent' or state.phase=='return') and not loaded(state.f) then
        state.absentStart=state.absentStart or getGameTime():getWorldAgeHours()
        state.absentEnd=getGameTime():getWorldAgeHours()
    end
    if state.phase=='absent' and loaded(state.f) then
        state.failed=true;log('CLIENT FAIL origin reloaded during absent interval')
        sendClientCommand(getPlayer(),MODULE,'fail',{run=state.f.run,storage=true,reason='origin reloaded during absent interval'});return
    end
    if state.phase=='away' or state.phase=='absent' then ok=not loaded(state.f)
    elseif loaded(state.f) then
        local found=locate(state.f);local count=0
        for label in pairs(state.f.samples) do if found[label] then count=count+1 end end
        if count==3 then ok=pcall(verify,state.f,state.phase=='return') end
    end
    state.stable=ok and state.stable+30 or 0
    if state.stable>=120 and state.stable%120==0 and state.phase~='absent' then
        sendClientCommand(getPlayer(),MODULE,'ack',{run=state.f.run,phase=state.phase,storage=true,
            absentHours=state.absentStart and state.absentEnd-state.absentStart or 0})
    end
end
-- Загружать после HCRLabTwoCases. Используем уже зарегистрированный bridge:
-- native reloadLuaFile не регистрирует новые Events во время rewriteEvents.
do
    local previousServer,previousClient,previousTick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args)
        if args.storage then return S.server(command,player,args) end
        return previousServer(command,player,args)
    end
    HCRLabTwo.client=function(command,args)
        if args.storage then return S.client(command,args) end
        return previousClient(command,args)
    end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        previousTick();S.tick()
        ticks=ticks+1;if ticks%60~=0 then return end
        local reader=getFileReader('HCRLabStorageCommand.txt',false)
        if not reader then return end
        local line=reader:readLine();reader:close()
        if not line or line==last then return end
        last=line;local sequence,command=line:match('^(%d+):([%w]+)$')
        if not command then return end
        local ok,err=pcall(function()
            assert(command=='probe' or command=='start','Unknown storage command')
            S[command]()
        end)
        log(sequence..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(err)))
    end
end
