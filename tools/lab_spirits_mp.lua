-- Private localhost oracle, загружать после lab_two_client.lua.
require 'HCR_SpiritCatalog'
require 'HCR_NativeWhiskey'
HCRLabSpiritsMP={}
HCRLabSpiritsMPBoot=HCRLabSpiritsMPBoot or tostring(getTimestampMs())
local M,Q,L,F=HCRLabSpiritsMP,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local phases={'initial','native','share_native','gin','share_gin','pour','share_glass','cocktail','share_final','verify'}
local function log(s) print('[HCRSpiritsMP] '..s) end
local function near(a,b,label) assert(a and math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function tag(item,name) item:getModData().HCRSpiritsMPTag=name;return item end
local function find(inv,name)
    local items=inv:getItems()
    for i=0,items:size()-1 do if items:get(i):getModData().HCRSpiritsMPTag==name then return items:get(i) end end
end
local function byId(inv,id)
    local items=inv:getItems();local found
    for i=0,items:size()-1 do if items:get(i):getID()==id then assert(not found,'Duplicate ID');found=items:get(i) end end
    return (assert(found,'Item ID not replicated '..tostring(id)))
end
local function shared(f)
    local square=assert(getCell():getGridSquare(f.x,f.y,f.z));local items=square:getWorldObjects();local result
    for i=0,items:size()-1 do
        local item=items:get(i):getItem()
        if item and item:getModData().HCRSpiritsMPTag==f.run then assert(not result,'Duplicate shared bag');result=item end
    end
    return (assert(result,'Shared bag not replicated'))
end
local function outputs(inv,f,kind)
    local result={};local items=inv:getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        -- Последующий DrinksMP добавляет собственные Whiskey-ингредиенты.
        -- Они не являются выходами этого прогона; обычные немеченые копии
        -- по-прежнему учитываются, чтобы не скрыть реальное дублирование.
        local foreign=item:getModData().HCRDrinksMPTag
        if item:getFullType()==kind and not f.previous[tostring(item:getID())] and not foreign then
            result[#result+1]=item
        end
    end
    table.sort(result,function(a,b) return a:getID()<b:getID() end);return result
end
local function checkLiquid(item,marker,amount,calories,dose)
    local fluid=assert(Q.fluid(item));near(Q.rawAmount(fluid),amount,'Raw fluid volume')
    near(fluid:getSpecificFluidAmount(Fluid.Get(marker)),amount,'Fluid identity')
    local raw=assert(item:getModData()[Q.key]);L.validate(raw)
    assert(L.matches(raw,Q.amounts(fluid)),'Raw ledger does not match native fluid')
    near(L.budget(raw,'calories'),calories,'Ledger calories');near(L.budget(raw,'poisonPower'),dose,'Ledger dose')
    assert(L.quality(raw)=='rotten','Spoilage lost')
    if marker=='Whiskey' then
        near(L.volume(raw),0,'Native whiskey must have zero-volume quality')
        assert(raw.lots[1].food.spoilHunger~=nil,'Native spoil effect lost')
    end
    return raw
end
local function observe(f,p,player,owner)
    local function taint(ledger)
        if not f.tainted then return end -- сохранённые старые fixtures.
        local found=false
        for _,lot in ipairs(ledger.lots) do found=found or lot.food.tainted or false end
        assert(found,'Distillation/cocktail lost taint')
    end
    local function liquid(...) taint(checkLiquid(...)) end
    local common=shared(f):getItemContainer();local inv=player:getInventory()
    if p=='initial' and owner then
        assert(player:getPerkLevel(Perks.Cooking)==10,'Cooking level not replicated')
        for _,name in ipairs({'flour','juniper'}) do
            local barrel=assert(find(inv,f.run..'-'..name));local raw=assert(barrel:getModData()[HCRProcessQuality.key])
            near(raw.dose,.75,'Mash dose')
        end
    elseif p=='native' and owner then
        local rows=outputs(inv,f,'Base.Whiskey');assert(#rows==20,'Twenty native bottles missing')
        for _,item in ipairs(rows) do liquid(item,'Whiskey',1,0,.0375) end
        assert(not find(inv,f.run..'-flour'),'Native distill barrel survived')
    elseif p=='gin' and owner then
        local rows=outputs(inv,f,'Hydrocraft.HCGin3Fluid');assert(#rows==20,'Twenty HC bottles missing')
        for _,item in ipairs(rows) do liquid(item,'HCRGin',1,2142,.0375) end
        assert(not find(inv,f.run..'-juniper'),'HC distill barrel survived')
    elseif p=='pour' and owner then
        local rows=outputs(inv,f,'Hydrocraft.HCGlassshortFluid');assert(#rows==1,'Glass absent/duplicated')
        liquid(rows[1],'HCRWhiskey',.1,f.nativeCalories*.1,.00375)
        assert(not find(inv,f.run..'-glass'),'Empty pour vessel survived')
    elseif p=='cocktail' and owner then
        local rows=outputs(inv,f,'Hydrocraft.HCDrinkoldfashionedFluid');assert(#rows==1,'Cocktail not replicated')
        taint(assert(rows[1]:getModData()[Q.key]))
        near(L.budget(assert(rows[1]:getModData()[Q.key]),'poisonPower'),.00375,'Cocktail dose');assert(L.quality(assert(rows[1]:getModData()[Q.key]))=='rotten')
        assert(#outputs(common,f,'Hydrocraft.HCGlassshortFluid')==0 and #outputs(inv,f,'Hydrocraft.HCGlassshortFluid')==0,'Consumed glass survived')
    end
    local afterPour=p=='share_glass' or p=='cocktail' or p=='share_final' or p=='verify' or p=='cold'
    if p=='share_native' or p=='share_gin' or afterPour then
        assert(#outputs(common,f,'Base.Whiskey')==1,'Shared native bottle missing/duplicated')
        liquid(byId(common,f.nativeId),'Whiskey',afterPour and .9 or 1,0,afterPour and .03375 or .0375)
    end
    if p=='share_gin' or afterPour then
        assert(#outputs(common,f,'Hydrocraft.HCGin3Fluid')==1,'Shared HC bottle missing/duplicated')
        liquid(byId(common,f.ginId),'HCRGin',1,2142,.0375)
    end
    if p=='share_glass' then
        assert(#outputs(common,f,'Hydrocraft.HCGlassshortFluid')==1,'Shared glass missing/duplicated')
        liquid(byId(common,f.glassId),'HCRWhiskey',.1,f.nativeCalories*.1,.00375)
    end
    if p=='share_final' or p=='verify' or p=='cold' then
        local rows=outputs(common,f,'Hydrocraft.HCDrinkoldfashionedFluid');assert(#rows==1,'Shared cocktail missing/duplicated')
        taint(assert(rows[1]:getModData()[Q.key]))
        near(L.budget(assert(rows[1]:getModData()[Q.key]),'poisonPower'),.00375,'Shared cocktail dose');assert(L.quality(assert(rows[1]:getModData()[Q.key]))=='rotten')
        assert(rows[1]:getID()==f.cocktailId,'Cocktail ID changed')
        assert(#outputs(common,f,'Hydrocraft.HCGlassshortFluid')==0,'Shared consumed glass survived')
        if owner then
            local native=outputs(inv,f,'Base.Whiskey');local gin=outputs(inv,f,'Hydrocraft.HCGin3Fluid')
            assert(#native==19 and #gin==19,'Transferred bottle duplicated/lost')
            for _,item in ipairs(native) do liquid(item,'Whiskey',1,0,.0375) end
            for _,item in ipairs(gin) do liquid(item,'HCRGin',1,2142,.0375) end
            assert(#outputs(inv,f,'Hydrocraft.HCDrinkoldfashionedFluid')==0 and #outputs(inv,f,'Hydrocraft.HCGlassshortFluid')==0,'Transferred/consumed output survived')
        end
        if p=='cold' then
            local role=isServer() and 'server' or owner and 'owner' or 'observer'
            assert(f.boots[role]~=HCRLabSpiritsMPBoot,'Process not restarted '..role)
        end
    end
end
local function broadcast(command,args)
    args.spirits=true;for _,player in pairs(M.state.players) do sendServerCommand(player,'HCRLabTwo',command,args) end
end
local function phase(index)
    local state=M.state;state.index=index
    if state.cold then state.phase=index==1 and 'cold' or nil else state.phase=phases[index] end
    state.acks={};state.since=getTimestampMs()
    if not state.phase then
        state.complete=true
        if not state.cold then
            local bag=shared(state.f);bag:getModData().HCRSpiritsMPSaved=state.f
            bag:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
        end
        broadcast('complete',{cold=state.cold});log('SERVER PASS '..(state.cold and 'cold reload' or 'all ten phases'));return
    end
    broadcast('phase',{f=state.f,phase=state.phase});log('SERVER phase '..state.phase)
end
local function players()
    local result={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do
        local player=all:get(i)
        if player:getUsername()=='HCRLabOwner' then result.owner=player
        elseif player:getUsername()=='HCRLabObserver' then result.observer=player end
    end
    assert(result.owner and result.observer,'Both private clients required');return result
end
function M.start(cold)
    assert(isServer());local pair=players();local player=pair.owner;local square=player:getSquare()
    assert(math.abs(player:getX()-pair.observer:getX())<5 and math.abs(player:getY()-pair.observer:getY())<5,'Players must be together')
    if cold then
        local saved=HCRLabTwo.savedNearby(player,'HCRSpiritsMPSaved')
        M.state={f=assert(saved,'No saved spirit run'),players=pair,cold=true};phase(1);return
    end
    assert(player:getPerkLevel(Perks.Cooking)==10,'Native Cooking10 fixture required')
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    local run=tostring(getTimestampMs());local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),previous={},boots={server=HCRLabSpiritsMPBoot}}
    f.tainted=true
    local surfaceSquare=assert(getCell():getGridSquare(f.x+1,f.y,f.z));local surface
    for i=0,surfaceSquare:getObjects():size()-1 do
        local object=surfaceSquare:getObjects():get(i)
        if object:getSpriteName()=='carpentry_01_60' then surface=object;break end
    end
    if not surface then
        surface=IsoObject.new(getCell(),surfaceSquare,'carpentry_01_60')
        surfaceSquare:AddTileObject(surface);surface:transmitCompleteItemToClients()
    end
    local bag=tag(instanceItem('Base.Bag_Schoolbag'),run);square:AddWorldInventoryItem(bag,.45,.45,.05,true)
    local inv=player:getInventory()
    local function add(kind,label,prepare)
        local item=instanceItem(kind);if item:IsFood() then item:setAge(0) end
        if HCRBarCatalog and HCRBarCatalog.families[kind] then item=assert(HCRItemMigrations.newReplacement(item)) end
        tag(item,run..'-'..label)
        if prepare then prepare(item) end
        inv:AddItem(item);sendAddItemToContainer(inv,item);return item
    end
    for n,kind in ipairs({'flour','juniper'}) do
        add('Hydrocraft.HCBarrel'..kind,kind,function(i) HCRProcessQuality.write(i,{dose=.75,quality='rotten',detection=4,tainted=true},1,nil) end)
        add('Base.Charcoal','coal'..n);add('Base.Lighter','fire'..n)
        add('Base.Bucket','water'..n,function(i) Q.fluid(i):Empty();Q.fluid(i):addFluid('Water',6) end)
        for k=1,20 do add('Base.Whiskey','bottle'..n..'-'..k,function(i) Q.fluid(i):Empty() end) end
    end
    add('Hydrocraft.HCDistillery2','still');add('Hydrocraft.HCGlassshortempty','glass')
    add('Base.Spoon','spoon');add('Hydrocraft.HCBitters','bitters');add('Base.Sugar','sugar');add('Hydrocraft.HCSlicedorange','orange')
    player:learnRecipe('Mix Old Fashioned')
    local all=inv:getItems();for i=0,all:size()-1 do f.previous[tostring(all:get(i):getID())]=true end
    f.nativeCalories=Q.fluid(instanceItem('Base.Whiskey')):getProperties():getCalories()
    M.state={f=f,players=pair};phase(1)
end
function M.server(command,player,args)
    local state=M.state;if not state or state.failed or state.complete or args.run~=state.f.run then return end
    if command=='fail' then state.failed=true;log('SERVER FAIL client '..tostring(args.reason));return end
    if command~='ack' or args.phase~=state.phase then return end
    local role=player==state.players.owner and 'owner' or player==state.players.observer and 'observer' or nil
    if not role then return end;state.acks[role]=true
    if state.phase=='initial' then state.f.boots[role]=args.boot end
    if state.acks.owner and state.acks.observer then
        local ok,reason=pcall(observe,state.f,state.phase,state.players.owner,true)
        if not ok then log('SERVER awaiting '..tostring(reason));return end
        local inv=state.players.owner:getInventory()
        local kinds={native={'nativeId','Base.Whiskey'},gin={'ginId','Hydrocraft.HCGin3Fluid'},pour={'glassId','Hydrocraft.HCGlassshortFluid'},cocktail={'cocktailId','Hydrocraft.HCDrinkoldfashionedFluid'}}
        local capture=kinds[state.phase];if capture then state.f[capture[1]]=outputs(inv,state.f,capture[2])[1]:getID() end
        phase(state.index+1)
    end
end
function M.client(command,args)
    if command=='phase' then M.localState={f=args.f,phase=args.phase,ticks=0,stable=0};log('CLIENT phase '..args.phase)
    elseif command=='complete' then M.localState=nil;log('CLIENT PASS '..(args.cold and 'cold reload' or 'all ten phases')) end
end
local function craft(player,common,name,groups)
    local recipes=getScriptManager():getAllCraftRecipes();local recipe
    for i=0,recipes:size()-1 do if recipes:get(i):getName()==name then recipe=recipes:get(i);break end end
    player:learnRecipe(name)
    local surface=assert(ISEntityUI.FindCraftSurface(player,1));local logic=HandcraftLogic.new(player,nil,surface)
    local containers=ArrayList.new();containers:add(player:getInventory());containers:add(common)
    logic:setContainers(containers);logic:setRecipe(recipe);logic:setManualSelectInputs(true);logic:clearManualInputs()
    for slot,group in ipairs(groups) do
        local items=ArrayList.new();for _,item in ipairs(group) do items:add(item) end
        assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),items),'MP manual slot '..slot..' '..name)
    end
    assert(logic:canPerformCurrentRecipe(),'Native recipe unavailable '..name)
    ISTimedActionQueue.add(ISHandcraftAction.FromLogic(logic))
end
local function act(state,player)
    local f,p=state.f,state.phase;local inv=player:getInventory();local common=shared(f):getItemContainer()
    local function get(name) return (assert(find(inv,f.run..'-'..name),'Fixture missing '..name)) end
    local function transfer(id) local item=byId(inv,id);ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,inv,common)) end
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    if p=='native' or p=='gin' then
        local n=p=='native' and 1 or 2;local bottles={};for k=1,20 do bottles[k]=get('bottle'..n..'-'..k) end
        craft(player,common,p=='native' and 'Distill Bottle of Whiskey' or 'Distill Bottle of Gin',
            {{get(p=='native' and 'flour' or 'juniper')},{get('coal'..n)},{get('fire'..n)},bottles,{get('water'..n)},{get('still')}})
    elseif p=='share_native' then transfer(f.nativeId)
    elseif p=='share_gin' then transfer(f.ginId)
    elseif p=='pour' then craft(player,common,'Pour Short Glass of Whiskey (Bottled Whiskey)',{{get('glass')},{byId(common,f.nativeId)}})
    elseif p=='share_glass' then transfer(f.glassId)
    elseif p=='cocktail' then craft(player,common,'Mix Old Fashioned',{{get('spoon')},{byId(common,f.glassId)},{get('bitters')},{get('sugar')},{get('orange')}})
    elseif p=='share_final' then transfer(f.cocktailId) end
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
        local ok,reason=pcall(act,state,player)
        if not ok then state.failed=true;sendClientCommand(player,'HCRLabTwo','fail',{spirits=true,run=state.f.run,reason=tostring(reason)});log('CLIENT FAIL '..tostring(reason));return end
    end
    if owner and ISTimedActionQueue.isPlayerDoingAction(player) then state.stable=0;return end
    local ok,reason=pcall(observe,state.f,state.phase,player,owner);state.stable=ok and state.stable+30 or 0
    if state.stable>=120 and state.stable%120==0 then
        sendClientCommand(player,'HCRLabTwo','ack',{spirits=true,run=state.f.run,phase=state.phase,boot=HCRLabSpiritsMPBoot})
        log('CLIENT independently observed '..state.phase)
    elseif state.ticks%600==0 then log('CLIENT awaiting '..state.phase..' '..tostring(reason)) end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args) if args.spirits then return M.server(command,player,args) end;return server(command,player,args) end
    HCRLabTwo.client=function(command,args) if args.spirits then return M.client(command,args) end;return client(command,args) end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();M.tick();ticks=ticks+1;if ticks%60~=0 then return end
        local reader=getFileReader('HCRLabSpiritsMPCommand.txt',false);if not reader then return end
        local line=reader:readLine();reader:close();if not line or line==last then return end;last=line
        local sequence,command=line:match('^(%d+):([%w]+)$');if not command then return end
        local ok,reason=pcall(function() assert(command=='start' or command=='verify');M.start(command=='verify') end)
        log(sequence..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(reason)))
    end
end
