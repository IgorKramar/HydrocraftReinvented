-- Частный localhost oracle: реальные native timed actions и два независимых клиента.
require 'HCR_FluidQuality'
require 'HCR_FoodQuality'
require 'HCR_TimedItems'
require 'Entity/TimedActions/ISHandcraftAction'
if isClient() then
    require 'Entity/TimedActions/ISHandcraftAction'
    require 'TimedActions/ISInventoryTransferAction'
    require 'TimedActions/ISEatFoodAction'
    require 'Fluids/ISFluidTransferAction'
    require 'ISUI/AdminPanel/ISServerSandboxOptionsUI'
end
HCRLabTwo={}
local T,Q,L,F=HCRLabTwo,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local MODULE='HCRLabTwo'
local function log(s) print('[HCRLabTwo] '..s) end
if not HCRLabTwoTraceInstalled then
    HCRLabTwoTraceInstalled=true
    for _,method in ipairs({'start','serverStart','complete','performRecipe','stop'}) do
        local original=ISHandcraftAction[method];local label=method
        ISHandcraftAction[method]=function(self,...)
            print('[HCRLabTwoAction] '..label..' '..tostring(self.craftRecipe and self.craftRecipe:getName()))
            return original(self,...)
        end
    end
end
local function near(a,b,label) assert(a and math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function tag(item,name) item:getModData().HCRLabTwoTag=name;return item end
local function find(container,name)
    local items=container:getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getModData().HCRLabTwoTag==name then return item end
        if item:getCategory()=='Container' then
            local found=find(item:getItemContainer(),name);if found then return found end
        end
    end
end
local function world(f,name)
    local square=assert(getCell():getGridSquare(f.x,f.y,f.z),'Fixture square not loaded')
    local objects=square:getWorldObjects();local result,count=nil,0
    for i=0,objects:size()-1 do
        local item=objects:get(i):getItem()
        if item and item:getModData().HCRLabTwoTag==name then result=item;count=count+1 end
    end
    assert(count==1,'World tag missing or duplicated: '..name)
    return result
end
function T.savedNearby(player,key)
    -- Native движение/сохранение может округлить 10655 до 10654,99.
    -- Образец остаётся на своей клетке; проверка использует его saved x/y/z.
    local origin=player:getSquare();local saved
    for x=origin:getX()-2,origin:getX()+2 do for y=origin:getY()-2,origin:getY()+2 do
        local square=getCell():getGridSquare(x,y,origin:getZ())
        if square then local worldItems=square:getWorldObjects()
            for i=0,worldItems:size()-1 do local item=worldItems:get(i):getItem()
                local row=item and item:getModData()[key]
                if row and (not saved or tonumber(row.run)>tonumber(saved.run)) then saved=row end
            end
        end
    end end
    if saved then log('SERVER selected saved '..key..' run='..saved.run) end
    return saved
end
local function bowl(container,f)
    local items=container:getItems();local result,count=nil,0
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getFullType()=='Hydrocraft.HCRMilkBowl' and not f.previousBowls[tostring(item:getID())] then
            result=item;count=count+1
        end
    end
    assert(count<=1,'Duplicate new milk bowl')
    if result and f.bowlId then assert(result:getID()==f.bowlId,'Milk bowl identity changed') end
    return result
end
local function checkBowl(item,partial,cold)
    assert(item,'New milk bowl not visible')
    local fraction=partial and .75 or 1
    near(item:getCalories(),300*fraction,'Bowl calories')
    near(item:getBaseHunger(),-.12,'Bowl base hunger')
    near(item:getHungChange(),-.12*fraction,'Bowl remaining hunger')
    near(F.dose(item),.375*fraction,'Bowl exact poison')
    assert(F.quality(item)=='stale','Bowl freshness')
    near(item:getOffAge(),0,'Bowl offAge');near(item:getOffAgeMax(),4,'Bowl offAgeMax')
    assert(item:getAge()>=.999 and item:getAge()<(cold and 4 or 1.1),'Bowl age')
end
local function carton(container,f)
    local items=container:getItems();local result,count=nil,0
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getFullType()=='Base.Milk' and not f.previousCartons[tostring(item:getID())] then
            result=item;count=count+1
        end
    end
    assert(count<=1,'Duplicate native milk carton')
    if result and f.cartonId then assert(result:getID()==f.cartonId,'Carton identity changed') end
    return result
end
local function checkFluid(item,volume,calories,dose,marker)
    local fluid=assert(Q.fluid(item),'Missing fluid component')
    near(Q.rawAmount(fluid),volume,'Fluid amount')
    near(fluid:getSpecificFluidAmount(Fluid.Get(marker)),volume,'Fluid composition')
    if calories then
        local ledger=Q.capture(item,fluid).ledger
        near(L.budget(ledger,'calories'),calories,'Fluid calories')
        near(L.budget(ledger,'poisonPower'),dose,'Fluid exact poison')
        assert(L.quality(ledger)=='stale','Fluid freshness')
    end
end
local function observe(f,phase,player,owner)
    local bag=world(f,f.bag);local nested=find(bag:getItemContainer(),f.old)
    if phase=='initial' then
        assert(nested,'Initial flask missing')
        if nested:getFullType()=='Hydrocraft.HCWaterflaskFluid' then
            -- Фоновая миграция может успеть до двухсекундного ACK клиентов.
            checkFluid(nested,.7,nil,nil,'TaintedWater')
        else assert(nested:getFullType()=='Hydrocraft.HCWaterflaskfull','Initial old flask') end
    else
        assert(nested and nested:getFullType()=='Hydrocraft.HCWaterflaskFluid','Nested flask migration')
        checkFluid(nested,.7,nil,nil,'TaintedWater')
    end
    if phase=='craft' and owner then
        checkBowl(bowl(player:getInventory(),f),false)
        checkFluid(find(player:getInventory(),f.milk),.7,700,.875,'HCRMilk')
    end
    if phase=='share' or phase=='share_partial' then
        checkBowl(bowl(bag:getItemContainer(),f),phase=='share_partial')
    elseif phase=='eat' and owner then
        local item=bowl(player:getInventory(),f);checkBowl(item,true)
        assert(player:getPrimaryHandItem()==item,'Existing held Food reference changed')
    elseif phase=='pour' or phase=='saved' then
        checkFluid(world(f,f.source),.6,600,.75,'HCRCoffee')
        checkFluid(world(f,f.target),.2,200,.25,'HCRCoffee')
        checkBowl(bowl(bag:getItemContainer(),f),true,phase=='saved')
        if phase=='saved' then checkFluid(carton(bag:getItemContainer(),f),1,1000,1.25,'HCRMilk') end
    elseif phase=='carton' and owner then
        checkFluid(assert(carton(player:getInventory(),f),'New native carton not visible'),1,1000,1.25,'HCRMilk')
        checkFluid(find(player:getInventory(),f.cartonSource),0,nil,nil,'HCRMilk')
    elseif phase=='share_carton' then
        checkFluid(assert(carton(bag:getItemContainer(),f),'Shared native carton not visible'),1,1000,1.25,'HCRMilk')
    elseif phase=='sandbox_off' or phase=='sandbox_restore' then
        local expected=phase=='sandbox_restore' and f.originalMeth or false
        assert(HCRSandbox.value('EnableMeth')==expected,'Native Sandbox value differs')
        local all=getScriptManager():getAllCraftRecipes();local matched=false
        for i=0,all:size()-1 do
            local rec=all:get(i)
            if rec:getName()=='Make Homemade Crystal Meth' then
                assert(HCRSandbox.recipeEnabled(rec)==expected,'Sandbox recipe gate differs');matched=true
            end
        end
        assert(matched,'Missing Sandbox fixture recipe')
    end
    return true
end
local phases={'initial','migrated','craft','share','eat','share_partial','carton','share_carton','pour','sandbox_off','sandbox_restore'}
local function broadcast(command,args)
    for _,player in pairs(T.state.players) do sendServerCommand(player,MODULE,command,args) end
end
local function phase(index)
    local state=T.state;state.index=index;state.phase=phases[index];state.acks={};state.started=getTimestampMs()
    if not state.phase then
        state.complete=true
        local bag=world(state.f,state.f.bag)
        bag:getModData().HCRLabTwoSaved=state.f
        bag:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
        log(state.cold and 'SERVER PASS cold reload: two real clients independently agree with saved world fixtures' or
            'SERVER PASS owner craft/held Food, both clients shared Food/FC/world fluids and native Sandbox restore; canonical state agrees')
        broadcast('complete',{run=state.f.run,cold=state.cold==true});return
    end
    if state.phase=='migrated' then
        HCRTimed.updateSquare(getCell():getGridSquare(state.f.x,state.f.y,state.f.z),getGameTime():getWorldAgeHours())
    end
    broadcast('phase',{f=state.f,phase=state.phase})
    log('SERVER phase '..state.phase)
end
local function batch(item,marker,volume,calories,dose)
    local sample=instanceItem('Hydrocraft.HCMilkjug')
    sample:setAge(4);sample:setOffAge(3);sample:setOffAgeMax(7)
    sample:setBaseHunger(-.4);sample:setHungChange(-.4);sample:setCalories(calories)
    F.store(sample,dose)
    local fluid=Q.fluid(item);fluid:setCanPlayerEmpty(true);fluid:Empty();fluid:addFluid(marker,volume)
    Q.store(item,fluid,L.batch(marker,volume,HCRFluidEffects.snapshot(sample),getGameTime():getWorldAgeHours()))
end
function T.start()
    assert(isServer(),'Start belongs to server')
    local all=getOnlinePlayers();local players={}
    for i=0,all:size()-1 do
        local player=all:get(i)
        if player:getUsername()=='HCRLabOwner' then players.owner=player end
        if player:getUsername()=='HCRLabObserver' then players.observer=player end
    end
    assert(players.owner and players.observer,'Both real clients must be present')
    assert(math.abs(players.owner:getX()-players.observer:getX())<5 and math.abs(players.owner:getY()-players.observer:getY())<5,'Clients are not together')
    local player=players.owner;local square=player:getSquare();local run=tostring(getTimestampMs())
    player:setUnlimitedCarry(true) -- Только lab: повторные fixtures не должны падать на землю.
    local tableSquare=assert(getCell():getGridSquare(square:getX()+1,square:getY(),square:getZ()))
    local tableObject
    for i=0,tableSquare:getObjects():size()-1 do
        local object=tableSquare:getObjects():get(i)
        if object:getModData().HCRLabTwoTable then tableObject=object end
    end
    if not tableObject then
        tableObject=IsoObject.new(getCell(),tableSquare,'carpentry_01_60')
        tableObject:getModData().HCRLabTwoTable=true
        tableSquare:AddTileObject(tableObject);tableObject:transmitCompleteItemToClients()
    end
    if not tableObject:isGenericCraftingSurface() then
        tableObject:setSprite(getSprite('carpentry_01_60'));tableObject:transmitUpdatedSpriteToClients()
    end
    assert(player:canUseAsGenericCraftingSurface(tableObject),'Native lab table is not usable')
    local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),
        bag=run..'-bag',old=run..'-old',milk=run..'-milk',empty=run..'-empty',source=run..'-source',target=run..'-target',
        cartonSource=run..'-cartonSource',cartonEmpty=run..'-cartonEmpty',previousBowls={},previousCartons={},
        originalMeth=HCRSandbox.value('EnableMeth'),serverBoot=assert(HCRLabTwoBoot,'Missing server boot identity'),clientBoots={}}
    assert(f.originalMeth==true,'Sandbox lab requires original enabled setting')
    local existing=player:getInventory():getItems()
    for i=0,existing:size()-1 do
        local item=existing:get(i)
        if item:getFullType()=='Hydrocraft.HCRMilkBowl' then f.previousBowls[tostring(item:getID())]=true end
        if item:getFullType()=='Base.Milk' then f.previousCartons[tostring(item:getID())]=true end
    end
    local outer=tag(instanceItem('Base.Bag_Schoolbag'),f.bag)
    local inner=outer:getItemContainer():AddItem('Base.Bag_Schoolbag')
    local old=tag(inner:getItemContainer():AddItem('Hydrocraft.HCWaterflaskfull'),f.old)
    old:setCurrentUsesFloat(.49);old:setFavorite(true)
    square:AddWorldInventoryItem(outer,.23,.67,.05,true)
    local milk=tag(instanceItem('Base.Milk'),f.milk);batch(milk,'HCRMilk',1,1000,1.25)
    player:getInventory():AddItem(milk);sendAddItemToContainer(player:getInventory(),milk)
    f.previousCartons[tostring(milk:getID())]=true
    local empty=tag(player:getInventory():AddItem('Base.Bowl'),f.empty);sendAddItemToContainer(player:getInventory(),empty)
    local cartonMilk=tag(instanceItem('Hydrocraft.HCWoodenbucketFluid'),f.cartonSource);batch(cartonMilk,'HCRMilk',1,1000,1.25)
    player:getInventory():AddItem(cartonMilk);sendAddItemToContainer(player:getInventory(),cartonMilk)
    local cartonEmpty=tag(player:getInventory():AddItem('Hydrocraft.HCMilkempty'),f.cartonEmpty)
    sendAddItemToContainer(player:getInventory(),cartonEmpty)
    for _,entry in ipairs({{f.source,.8},{f.target,0}}) do
        local item=tag(instanceItem('Base.WaterBottle'),entry[1]);Q.fluid(item):Empty()
        if entry[2]>0 then batch(item,'HCRCoffee',.8,800,1) end
        square:AddWorldInventoryItem(item,.4,.4,.05,true)
    end
    T.state={players=players,f=f};phase(1)
end
function T.server(command,player,args)
    if not isServer() or not T.state then return end
    local state=T.state
    if state.failed or state.complete then return end
    if command~='ack' or args.run~=state.f.run or args.phase~=state.phase then return end
    local role=player==state.players.owner and 'owner' or player==state.players.observer and 'observer' or nil
    if not role then return end
    if not args.boot or state.cold and args.boot==state.f.clientBoots[role] then
        state.failed=true;log('SERVER FAIL client process was not restarted: '..role);return
    end
    if not state.cold then state.f.clientBoots[role]=args.boot end
    state.acks[role]=true;log('SERVER independent '..role..' ACK '..state.phase)
    if state.acks.owner and state.acks.observer then
        local ok,err=pcall(observe,state.f,state.phase,state.players.owner,true)
        if not ok then log('SERVER rejects premature '..state.phase..' ack: '..tostring(err));return end
        if state.phase=='craft' then state.f.bowlId=bowl(state.players.owner:getInventory(),state.f):getID() end
        if state.phase=='carton' then state.f.cartonId=carton(state.players.owner:getInventory(),state.f):getID() end
        phase(state.index+1)
    end
end
function T.client(command,args)
    if command=='phase' then
        if getPlayer():getUsername()=='HCRLabOwner' then getPlayer():setUnlimitedCarry(true) end
        T.localState={f=args.f,phase=args.phase,ticks=0,stable=0}
        log('CLIENT '..getPlayer():getUsername()..' phase '..args.phase)
    elseif command=='complete' then log(args.cold and 'CLIENT PASS independently verified saved fixtures after restart' or 'CLIENT PASS all eleven phases');T.localState=nil end
end
local function recipe(name)
    local all=getScriptManager():getAllCraftRecipes()
    for i=0,all:size()-1 do if all:get(i):getName()==name then return all:get(i) end end
    error('Missing recipe '..name)
end
local function act(state,player)
    state.acted=true
    local phase,f=state.phase,state.f
    if phase=='craft' or phase=='carton' then
        local surface=phase=='carton' and ISEntityUI.FindCraftSurface(player,1) or nil
        if phase=='carton' then assert(surface,'Native work surface not available') end
        local logic=HandcraftLogic.new(player,nil,surface);local containers=ArrayList.new()
        containers:add(player:getInventory());logic:setContainers(containers)
        local rec=recipe(phase=='carton' and 'Pour into Carton' or 'Pour Milk into Bowl')
        player:learnRecipe(rec:getName());logic:setRecipe(rec)
        logic:setManualSelectInputs(true);logic:clearManualInputs()
        for slot,name in ipairs(phase=='carton' and {f.cartonSource,f.cartonEmpty} or {f.milk,f.empty}) do
            local selected=ArrayList.new()
            local item=assert(find(player:getInventory(),name),'Missing selected input')
            selected:add(item)
            assert(logic:setManualInputsFor(rec:getInputs():get(slot-1),selected),'Native manual selection failed')
        end
        assert(logic:canPerformCurrentRecipe(),'Native recipe is unavailable: '..rec:getName())
        local action=ISHandcraftAction.FromLogic(logic)
        log('OWNER queues native craft duration='..tostring(action.maxTime)..' valid='..tostring(action:isValid()))
        ISTimedActionQueue.add(action)
    elseif phase=='share' or phase=='share_partial' or phase=='share_carton' then
        local item=assert(phase=='share_carton' and carton(player:getInventory(),f) or bowl(player:getInventory(),f),'Missing carried output before share')
        player:setPrimaryHandItem(nil);player:setSecondaryHandItem(nil);player:updateHandEquips()
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,player:getInventory(),world(f,f.bag):getItemContainer()))
    elseif phase=='eat' then
        local bag=world(f,f.bag);local item=assert(bowl(bag:getItemContainer(),f),'Shared bowl missing before eat')
        ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,bag:getItemContainer(),player:getInventory()))
        state.waitEat=true
    elseif phase=='pour' then
        local source=Q.fluid(world(f,f.source));local target=Q.fluid(world(f,f.target))
        ISTimedActionQueue.add(ISFluidTransferAction:new(player,ISFluidContainer:new(source),source,ISFluidContainer:new(target),target,.2))
    elseif phase=='sandbox_off' or phase=='sandbox_restore' then
        assert(player:getAccessLevel()=='Admin' or player:getAccessLevel()=='admin','Sandbox test requires native admin role')
        local ui=ISServerSandboxOptionsUI:new(80,40,1100,620)
        ui:initialise();ui:addToUIManager()
        local control=assert(ui.controls['Hydrocraft.EnableMeth'],'Sandbox control missing')
        control.selected[1]=phase=='sandbox_restore' and f.originalMeth or false
        ui:onButtonApply()
    end
end

function T.verifySaved()
    assert(isServer(),'Saved check belongs to server')
    local players={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do
        local player=all:get(i)
        if player:getUsername()=='HCRLabOwner' then players.owner=player end
        if player:getUsername()=='HCRLabObserver' then players.observer=player end
    end
    assert(players.owner and players.observer,'Cold check needs both real clients')
    local square=players.owner:getSquare();local f
    for x=square:getX()-2,square:getX()+2 do for y=square:getY()-2,square:getY()+2 do
        local s=getCell():getGridSquare(x,y,square:getZ())
        if s then for i=0,s:getWorldObjects():size()-1 do
            local item=s:getWorldObjects():get(i):getItem()
            local saved=item and item:getModData().HCRLabTwoSaved
            if saved and (not f or tonumber(saved.run)>tonumber(f.run)) then f=saved end
        end end
    end end
    assert(f,'No completed saved two-client fixture')
    assert(f.serverBoot and f.serverBoot~=HCRLabTwoBoot,'Server process was not restarted')
    assert(f.clientBoots and f.clientBoots.owner and f.clientBoots.observer,'Missing saved client boot identities')
    T.state={players=players,f=f,phase='saved',index=#phases,acks={},started=getTimestampMs(),cold=true}
    broadcast('phase',{f=f,phase='saved'})
    log('SERVER waiting for independent cold-load checks')
end
function T.tick()
    if isServer() then
        if T.state and not T.state.complete and not T.state.failed and getTimestampMs()-T.state.started>180000 then
            T.state.failed=true;log('SERVER FAIL timeout '..tostring(T.state.phase))
        end
        return
    end
    local state=T.localState;if not state or state.failed or not getPlayer() then return end
    state.ticks=state.ticks+1
    if state.ticks%30~=0 then return end
    local player=getPlayer();local owner=player:getUsername()=='HCRLabOwner'
    if owner and not state.acted then
        local ok,err=pcall(act,state,player)
        if not ok then state.failed=true;log('CLIENT FAIL action '..tostring(err));return end
    end
    local ok,err=pcall(function()
        if state.waitEat then
            local item=bowl(player:getInventory(),state.f)
            if item and not ISTimedActionQueue.isPlayerDoingAction(player) then
                player:setPrimaryHandItem(item);player:updateHandEquips()
                ISTimedActionQueue.add(ISEatFoodAction:new(player,item,.25));state.waitEat=false
            end
        end
        if owner and ISTimedActionQueue.isPlayerDoingAction(player) then
            state.stable=0;state.detail='native action in progress';return
        end
        -- Отсутствие ещё не пришедшего результата ожидаемо; assert в каждом
        -- кадре засоряет native журнал и не даёт дополнительного доказательства.
        local shared=world(state.f,state.f.bag):getItemContainer()
        if owner and (state.phase=='craft' or state.phase=='eat') and not bowl(player:getInventory(),state.f)
            or (state.phase=='share' or state.phase=='share_partial') and not bowl(shared,state.f)
            or owner and state.phase=='carton' and not carton(player:getInventory(),state.f)
            or state.phase=='share_carton' and not carton(shared,state.f) then
            state.stable=0;state.detail='native output not replicated yet';return
        end
        observe(state.f,state.phase,player,owner)
        state.stable=state.stable+30
        if state.stable>=120 and state.stable%120==0 then
            log('CLIENT '..player:getUsername()..' independently observed '..state.phase)
            sendClientCommand(player,MODULE,'ack',{run=state.f.run,phase=state.phase,boot=HCRLabTwoBoot})
            state.sent=true
        end
    end)
    if not ok then state.detail=tostring(err);state.stable=0 end
    if state.ticks%600==0 and not state.sent then log('CLIENT waiting '..state.phase..': '..tostring(state.detail)) end
    if state.ticks>10800 then state.failed=true;log('CLIENT FAIL timeout '..tostring(state.detail)) end
end
