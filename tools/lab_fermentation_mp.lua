-- Private localhost, после lab_two_client.lua. Все действия выполняет клиент.
require 'HCR_FermentationRecipes'
require 'TimedActions/ISAddItemInRecipe'
require 'TimedActions/ISEquipWeaponAction'
HCRLabFermentMP={}
HCRLabFermentMPBoot=HCRLabFermentMPBoot or tostring(getTimestampMs())
local M,Q,L,F,P=HCRLabFermentMP,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality,HCRProcessQuality
local phases={'initial','juice','prepare','wine','sharewine','vinegar','sharevinegar','spice','sharedish','verify'}
local function log(s) print('[HCRFermentMP] '..s) end
local function near(a,b,label) assert(a and math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function tag(item,name) item:getModData().HCRFermentMPTag=name;return item end
local function find(inv,name)
    local items=inv:getItems()
    for i=0,items:size()-1 do if items:get(i):getModData().HCRFermentMPTag==name then return items:get(i) end end
end
local function byId(inv,id)
    local items=inv:getItems();local found
    for i=0,items:size()-1 do if items:get(i):getID()==id then assert(not found,'Duplicate item ID');found=items:get(i) end end
    return found
end
local function shared(f)
    local square=assert(getCell():getGridSquare(f.x,f.y,f.z),'Fermentation square absent')
    local objects=square:getObjects();local bag
    for i=0,objects:size()-1 do
        local item=objects:get(i)
        if item and item:getModData().HCRFermentMPTag==f.run then assert(not bag,'Duplicate fermentation bag');bag=item end
    end
    return assert(bag,'Fermentation shared bag absent')
end
local function outputs(inv,f,kind)
    local rows={};local items=inv:getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item:getFullType()==kind and not f.previous[tostring(item:getID())] then rows[#rows+1]=item end
    end
    return rows
end
local function liquid(item,volume,marker,dose,quality,calories)
    assert(item,'Missing fermentation vessel');local fluid=assert(Q.fluid(item))
    near(Q.rawAmount(fluid),volume,'Litres');near(fluid:getSpecificFluidAmount(Fluid.Get(marker)),volume,'Native marker')
    local ledger=assert(item:getModData()[Q.key],'Raw ledger missing');L.validate(ledger)
    assert(L.matches(ledger,Q.amounts(fluid)),'Native/raw ledger mismatch')
    near(L.budget(ledger,'poisonPower'),dose,'Poison');assert(L.quality(ledger)==quality,'Freshness')
    if calories then near(L.budget(ledger,'calories'),calories,'Calories') end
    return ledger
end
local function observe(f,phase,player,owner)
    local common=shared(f):getContainer();local inv=player:getInventory()
    local function get(label) return assert(find(common,f.run..'-'..label),'Missing shared '..label) end
    local cask=get('cask');assert(cask:getFullType()=='Hydrocraft.HCWoodenbarrelFluid','Empty cask migration')
    local wine=get('wine');local vinegar=get('vinegar')
    if phase=='initial' then
        assert(Q.fluid(cask):isEmpty(),'Cask already full')
        liquid(wine,20,'HCRWineRed',3.25,'stale',9620)
        liquid(vinegar,20,'HCRVinegar',2.625,'rotten',0)
        for i=2,5 do liquid(get('bucket'..i),4,'HCRJuiceGrape',.25,'fresh',0) end
    elseif phase=='juice' then
        liquid(get('bucket1'),4,'HCRJuiceGrape',2,'rotten',136)
    else
        local ledger=liquid(cask,20,'HCRMustRed',3,'rotten',136)
        for _,lot in ipairs(ledger.lots) do
            assert(lot.fermentation and lot.fermentation.barrel and lot.fermentation.kind=='Hydrocraft.HCBarrelgrape','Must clocks')
            if f.startedAt then near(lot.fermentation.startedAt,f.startedAt,'Saved must clock') end
        end
        for i=1,5 do assert(Q.fluid(get('bucket'..i)):isEmpty(),'Donor bucket not empty') end
    end
    local function wines(container)
        local rows=outputs(container,f,'Base.Wine2');assert(#rows==20,'Twenty wine bottles missing')
        for _,item in ipairs(rows) do
            local ledger=liquid(item,1,'HCRWineRed',3.25/20,'stale',481)
            assert(not item:isSealed(),'Wine bottle sealed')
            for _,lot in ipairs(ledger.lots) do assert(lot.fermentation and not lot.fermentation.barrel,'Bottled clock resumed') end
            if f.wineIds then assert(f.wineIds[tostring(item:getID())],'Wine identity changed') end
        end
    end
    if phase=='wine' then if owner then wines(inv) end
    elseif phase=='sharewine' or phase=='vinegar' or phase=='sharevinegar' or phase=='spice' or phase=='sharedish' or phase=='verify' then
        wines(common);assert(Q.fluid(wine):isEmpty(),'Wine donor not empty')
        if owner then assert(#outputs(inv,f,'Base.Wine2')==0,'Duplicate wine output') end
    end
    if phase=='vinegar' and owner then assert(#outputs(inv,f,'Base.Vinegar2')==20,'New vinegar bottles missing') end
    if phase=='sharevinegar' or phase=='sharedish' or phase=='verify' then
        local rows=outputs(common,f,'Base.Vinegar2');assert(#rows==20,'Twenty shared vinegar bottles missing')
        local total=0
        for _,item in ipairs(rows) do
            local state=P.read(item);assert(state.quality=='rotten' and state.tainted,'Vinegar quality/taint')
            total=total+state.dose
            if f.vinegarIds then assert(f.vinegarIds[tostring(item:getID())],'Vinegar identity changed') end
        end
        near(total,phase=='sharevinegar' and 2.625 or 2.625-2.625/200,'Vinegar total dose')
        assert(Q.fluid(vinegar):isEmpty(),'Vinegar donor not empty')
    end
    if (phase=='spice' and owner) or phase=='sharedish' or phase=='verify' then
        local container=phase=='spice' and inv or common
        local dishes=outputs(container,f,'Base.Sandwich');assert(#dishes==1,'One sandwich missing')
        local dish=dishes[1];assert(F.tainted(dish) and F.quality(dish)=='rotten','Sandwich taint/freshness')
        near(F.dose(dish),2.625/200,'Sandwich exact dose')
        if f.dishId then assert(dish:getID()==f.dishId,'Sandwich identity changed') end
    end
end
local function broadcast(command,args)
    args.ferment=true
    for _,player in pairs(M.state.players) do sendServerCommand(player,'HCRLabTwo',command,args) end
end
local function phase(index)
    local state=M.state;state.index=index
    if state.cold then state.phase=index==1 and 'verify' or nil else state.phase=phases[index] end
    state.acks={};state.since=getTimestampMs()
    if not state.phase then
        state.complete=true
        if not state.cold then
            shared(state.f):getModData().HCRFermentMPSaved=state.f
            shared(state.f):transmitModData()
        end
        broadcast('complete',{cold=state.cold,run=state.f.run});log('SERVER PASS '..(state.cold and 'cold' or 'all ten phases'));return
    end
    broadcast('phase',{f=state.f,phase=state.phase});log('SERVER phase '..state.phase)
end
function M.savedNearby(player)
    local origin=player:getSquare();local saved
    for x=origin:getX()-2,origin:getX()+2 do for y=origin:getY()-2,origin:getY()+2 do
        local square=getCell():getGridSquare(x,y,origin:getZ())
        if square then
            local objects=square:getObjects()
            for i=0,objects:size()-1 do
                local row=objects:get(i):getModData().HCRFermentMPSaved
                if row and (not saved or tonumber(row.run)>tonumber(saved.run)) then saved=row end
            end
        end
    end end
    return saved
end
function M.start(cold)
    assert(isServer(),'Fermentation MP server only')
    local players={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do local player=all:get(i)
        if player:getUsername()=='HCRLabOwner' then players.owner=player elseif player:getUsername()=='HCRLabObserver' then players.observer=player end
    end
    assert(players.owner and players.observer,'Both private clients required')
    local player=players.owner;local inv=player:getInventory()
    if cold then
        local f=assert(M.savedNearby(player),'Saved fermentation fixture absent')
        assert(f.serverBoot~=HCRLabTwoBoot,'Cold server was not restarted')
        M.state={f=f,players=players,cold=true};phase(1);return
    end
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    player:getBodyDamage():RestoreToFullHealth();player:getStats():set(CharacterStat.POISON,0)
    player:getStats():set(CharacterStat.FOOD_SICKNESS,0)
    for i=1,20 do if player:getPerkLevel(Perks.Cooking)>=10 then break end;player:getXp():AddXP(Perks.Cooking,10000) end
    for _,name in ipairs({'Prepare Wine Barrels','Fill Bottles with Wine','Fill Vinegar Bottles with Vinegar'}) do player:learnRecipe(name) end
    local square=player:getSquare();local run=tostring(getTimestampMs())
    local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),previous={},boots={},serverBoot=HCRLabTwoBoot}
    local obsolete={};local nearby=square:getObjects()
    for i=0,nearby:size()-1 do
        local object=nearby:get(i);local md=object:getModData()
        if md.HCRFermentMPTag and not md.HCRFermentMPSaved then obsolete[#obsolete+1]=object end
    end
    for _,object in ipairs(obsolete) do square:transmitRemoveItemFromSquare(object) end
    local surfaceSquare=assert(getCell():getGridSquare(f.x+1,f.y,f.z))
    local surface;local objects=surfaceSquare:getObjects()
    for i=0,objects:size()-1 do
        if objects:get(i):getSpriteName()=='carpentry_01_60' then surface=objects:get(i);break end
    end
    if not surface then
        surface=IsoObject.new(getCell(),surfaceSquare,'carpentry_01_60')
        surfaceSquare:AddTileObject(surface);surface:transmitCompleteItemToClients()
    end
    local bag=tag(IsoObject.new(getCell(),square,'carpentry_01_16'),run)
    local common=ItemContainer.new('crate',square,bag);common:setCapacity(100);bag:setContainer(common)
    local function add(kind,label)
        local item=tag(assert(instanceItem(kind)),run..'-'..label);common:AddItem(item)
        f.previous[tostring(item:getID())]=true;return item
    end
    add('Hydrocraft.HCWoodenbarrel','cask')
    add('Hydrocraft.HCWoodenbucketFluid','bucket1');add('Hydrocraft.HCJuicer','juicer');add('Base.Yeast','yeast')
    for i=2,5 do P.write(add('Hydrocraft.HCWoodenbucketgrape','bucket'..i),{quality='fresh',dose=.25},1) end
    for i=1,16 do
        local item=add('Base.Grapes','grape'..i);item:setAge(0);item:setCalories(i);F.store(item,.125)
        if i==1 then F.setQuality(item,'rotten') end
    end
    local wine=add('Hydrocraft.HCBarrelgrape','wine')
    P.write(wine,{quality='stale',dose=3.25,detection=4},1)
    wine:getModData().StartTime=getGameTime():getWorldAgeHours()-336
    local vinegar=add('Hydrocraft.HCBarrelvinegar','vinegar')
    P.write(vinegar,{quality='rotten',dose=2.625,detection=4,tainted=true},1)
    for i=1,20 do
        local bottle=add('Base.Wine','wineempty'..i);Q.fluid(bottle):setCanPlayerEmpty(true);Q.fluid(bottle):Empty()
        add('Hydrocraft.HCVinegarempty','vinegarempty'..i)
    end
    square:AddTileObject(bag);bag:transmitCompleteItemToClients()
    local bread=tag(instanceItem('Base.BreadSlices'),run..'-bread');bread:setAge(0);inv:AddItem(bread);sendAddItemToContainer(inv,bread)
    local light=tag(instanceItem('Base.HandTorch'),run..'-light');light:setUsedDelta(1);light:setActivated(true)
    inv:AddItem(light);sendAddItemToContainer(inv,light)
    local items=inv:getItems();for i=0,items:size()-1 do f.previous[tostring(items:get(i):getID())]=true end
    M.state={f=f,players=players};phase(1)
end
function M.server(command,player,args)
    local state=M.state;if not state or state.failed or state.complete or args.run~=state.f.run then return end
    if command=='fail' then state.failed=true;log('SERVER FAIL '..tostring(args.reason));return end
    if command~='ack' or args.phase~=state.phase then return end
    local role=player==state.players.owner and 'owner' or player==state.players.observer and 'observer' or nil
    if not role then return end;state.acks[role]=true
    if state.phase=='initial' then state.f.boots[role]=args.boot end
    if state.cold then assert(args.boot~=state.f.boots[role],'Cold client was not restarted') end
    if state.acks.owner and state.acks.observer then
        local ok,why=pcall(observe,state.f,state.phase,state.players.owner,true)
        if not ok then log('SERVER awaiting '..tostring(why));return end
        local f=state.f;local inv=state.players.owner:getInventory()
        if state.phase=='prepare' then
            f.startedAt=find(shared(f):getContainer(),f.run..'-cask'):getModData()[Q.key].lots[1].fermentation.startedAt
        elseif state.phase=='wine' or state.phase=='vinegar' then
            local ids={};local kind=state.phase=='wine' and 'Base.Wine2' or 'Base.Vinegar2'
            for _,item in ipairs(outputs(inv,f,kind)) do ids[tostring(item:getID())]=true end
            f[state.phase=='wine' and 'wineIds' or 'vinegarIds']=ids
        elseif state.phase=='spice' then f.dishId=outputs(inv,f,'Base.Sandwich')[1]:getID() end
        phase(state.index+1)
    end
end
function M.client(command,args)
    if command=='phase' then M.localState={f=args.f,phase=args.phase,ticks=0,stable=0};log('CLIENT phase '..args.phase)
    elseif command=='complete' then M.localState=nil;log('CLIENT PASS '..(args.cold and 'cold' or 'all ten phases')) end
end
local function craft(player,common,name,groups)
    player:learnRecipe(name);local recipes=getScriptManager():getAllCraftRecipes();local recipe
    for i=0,recipes:size()-1 do if recipes:get(i):getName()==name then recipe=recipes:get(i);break end end
    local surface=assert(ISEntityUI.FindCraftSurface(player,1),'Fermentation work surface missing')
    local logic=HandcraftLogic.new(player,nil,surface);local containers=ArrayList.new()
    containers:add(player:getInventory());containers:add(common);logic:setContainers(containers);logic:setRecipe(assert(recipe))
    logic:setManualSelectInputs(true);logic:clearManualInputs()
    for slot,group in ipairs(groups) do
        local items=ArrayList.new();for _,item in ipairs(group) do items:add(item) end
        assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),items),'Fermentation manual slot '..slot)
    end
    assert(logic:canPerformCurrentRecipe(),'Native fermentation recipe unavailable '..name)
    ISTimedActionQueue.add(ISHandcraftAction.FromLogic(logic))
end
local function act(state,player)
    local f,p=state.f,state.phase;local inv=player:getInventory();local common=shared(f):getContainer()
    local function get(label)
        local item=find(common,f.run..'-'..label)
        assert(item,'Missing ingredient '..label);return item
    end
    local function transfer(items,dest)
        for _,item in ipairs(items) do ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,item:getContainer(),dest)) end
    end
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    if p=='initial' then
        local light=find(inv,f.run..'-light')
        if light then ISTimedActionQueue.add(ISEquipWeaponAction:new(player,light,50,false,false)) end
    elseif p=='juice' then
        local grapes={};for i=1,16 do grapes[i]=get('grape'..i) end
        craft(player,common,'Juice Grapes Into Wooden Bucket',{{get('bucket1')},grapes,{get('juicer')}})
    elseif p=='prepare' then
        local buckets={};for i=1,5 do buckets[i]=get('bucket'..i) end
        craft(player,common,'Prepare Wine Barrels',{{get('cask')},buckets,{get('yeast')}})
    elseif p=='wine' or p=='vinegar' then
        local bottles={};for i=1,20 do bottles[i]=get(p..'empty'..i) end
        craft(player,common,p=='wine' and 'Fill Bottles with Wine' or 'Fill Vinegar Bottles with Vinegar',{{get(p)},bottles})
    elseif p=='sharewine' or p=='sharevinegar' then transfer(outputs(inv,f,p=='sharewine' and 'Base.Wine2' or 'Base.Vinegar2'),common)
    elseif p=='spice' then
        local used=outputs(common,f,'Base.Vinegar2')[1];transfer({used},inv)
        local definitions=getScriptManager():getAllEvolvedRecipes();local recipe
        for i=0,definitions:size()-1 do if definitions:get(i):getFullResultItem()=='Base.Sandwich' then recipe=definitions:get(i);break end end
        ISTimedActionQueue.add(ISAddItemInRecipe:new(player,assert(recipe),assert(find(inv,f.run..'-bread')),used))
    elseif p=='sharedish' then
        transfer(outputs(inv,f,'Base.Vinegar2'),common);transfer(outputs(inv,f,'Base.Sandwich'),common)
    end
    state.acted=true
end
function M.tick()
    if isServer() then
        local state=M.state
        if state and not state.failed and not state.complete and getTimestampMs()-state.since>180000 then state.failed=true;log('SERVER FAIL timeout '..state.phase) end
        return
    end
    local state=M.localState;if not state or state.failed or not getPlayer() then return end
    state.ticks=state.ticks+1;if state.ticks%30~=0 then return end
    local player=getPlayer();local owner=player:getUsername()=='HCRLabOwner'
    if owner and not state.acted then
        local ok,why=pcall(act,state,player)
        if not ok then state.failed=true;sendClientCommand(player,'HCRLabTwo','fail',{ferment=true,run=state.f.run,reason=tostring(why)});log('CLIENT FAIL '..tostring(why));return end
    end
    if owner and ISTimedActionQueue.isPlayerDoingAction(player) then state.stable=0;return end
    local ok,why=pcall(observe,state.f,state.phase,player,owner);state.stable=ok and state.stable+30 or 0
    if state.stable>=120 and state.stable%120==0 then
        sendClientCommand(player,'HCRLabTwo','ack',{ferment=true,run=state.f.run,phase=state.phase,boot=HCRLabFermentMPBoot})
        log('CLIENT independently observed '..state.phase)
    elseif state.ticks%600==0 then log('CLIENT awaiting '..state.phase..' '..tostring(why)) end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args) if args.ferment then return M.server(command,player,args) end;return server(command,player,args) end
    HCRLabTwo.client=function(command,args) if args.ferment then return M.client(command,args) end;return client(command,args) end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();M.tick();ticks=ticks+1;if ticks%60~=0 then return end
        local reader=getFileReader('HCRLabFermentMPCommand.txt',false);if not reader then return end
        local line=reader:readLine();reader:close();if not line or line==last then return end;last=line
        local sequence,command=line:match('^(%d+):([%w]+)$');if not command then return end
        local ok,why=pcall(function() assert(command=='start' or command=='verify');M.start(command=='verify') end)
        log(sequence..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(why)))
    end
end
