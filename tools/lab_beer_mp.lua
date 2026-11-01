-- Только private localhost HCRLabTwo bridge, после lab_two_client.lua.
require 'HCR_BeerQuality'
require 'TimedActions/ISAddItemInRecipe'
HCRLabBeerMP={}
local M,Q,L,F=HCRLabBeerMP,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local phases={'initial','pack','share_pack','unpack','share_cans','add','share_partial','take_partial','finish','share_final','verify'}
local function log(s) print('[HCRBeerMP] '..s) end
local function near(a,b,label) assert(math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function tagged(item,name) item:getModData().HCRBeerMPTag=name;return item end
local function find(inv,name)
    local all=inv:getItems()
    for i=0,all:size()-1 do if all:get(i):getModData().HCRBeerMPTag==name then return all:get(i) end end
end
local function shared(f)
    local square=assert(getCell():getGridSquare(f.x,f.y,f.z),'Beer fixture square absent')
    local all=square:getWorldObjects();local result,count=nil,0
    for i=0,all:size()-1 do
        local item=all:get(i):getItem()
        if item and item:getModData().HCRBeerMPTag==f.run then result=item;count=count+1 end
    end
    assert(count==1,'Beer shared bag absent/duplicated');return result
end
local function outputs(inv,f,kind)
    local result={};local all=inv:getItems()
    for i=0,all:size()-1 do
        local item=all:get(i)
        if item:getFullType()==kind and not f.previous[tostring(item:getID())] then result[#result+1]=item end
    end
    return result
end
local function beer(item)
    assert(HCRBeerQuality.factory(item),'Shared beer lost factory eligibility')
    local fluid=Q.fluid(item);near(Q.rawAmount(fluid),.3,'Shared beer volume')
    local ledger=item:getModData()[Q.key]
    assert(L.matches(ledger,Q.amounts(fluid)),'Shared beer raw ledger mismatch')
    near(L.budget(ledger,'calories'),215,'Shared beer calories');near(L.budget(ledger,'poisonPower'),0,'Shared beer dose')
end
local function portion(item,partial)
    assert(item,'Cooking portion not replicated')
    near(item:getCalories(),partial and 98.8 or 123.5,'Cooking portion calories')
    near(F.dose(item),partial and .3 or .375,'Cooking portion dose')
    near(item:getBaseHunger(),-.05,'Cooking portion original baseline')
    near(item:getHungChange(),partial and -.04 or -.05,'Cooking portion hunger')
    assert(F.quality(item)=='rotten','Cooking portion freshness lost')
end
local function observe(f,phase,player,owner)
    local inv=player:getInventory();local bag=shared(f);local common=bag:getItemContainer()
    if phase=='initial' then
        for i=1,6 do beer(assert(find(common,f.run..'-can'..i))) end
        if owner then
            portion(find(inv,f.run..'-portion'),false)
            assert(player:getPerkLevel(Perks.Cooking)==10,'Client Cooking10 not synchronised')
            for i=1,5 do assert(find(inv,f.run..'-pot'..i),'Cooking fixture not replicated') end
        end
    end
    if phase=='pack' and owner then assert(#outputs(inv,f,'Hydrocraft.HCBeercan1pack')==1,'Pack not replicated') end
    if phase=='share_pack' then assert(#outputs(common,f,'Hydrocraft.HCBeercan1pack')==1,'Shared pack not replicated') end
    if phase=='unpack' and owner then
        local cans=outputs(inv,f,'Hydrocraft.HCBeercan1Fluid');assert(#cans==6,'Unpacked cans not replicated')
        for _,item in ipairs(cans) do beer(item) end
    end
    if phase=='share_cans' or phase=='verify' then
        assert(#outputs(common,f,'Hydrocraft.HCBeercan1pack')==0,'Unpacked pack survived')
        local cans=outputs(common,f,'Hydrocraft.HCBeercan1Fluid');assert(#cans==6,'Shared six cans not replicated')
        for _,item in ipairs(cans) do beer(item) end
        local rejected=assert(find(common,f.run..'-poison'))
        near(L.budget(rejected:getModData()[Q.key],'poisonPower'),.375,'Rejected candidate dose')
        assert(not HCRBeerQuality.factory(rejected),'Poisoned can became factory')
        near(Q.rawAmount(Q.fluid(assert(find(common,f.run..'-empty')))),0,'Empty candidate consumed')
    end
    if (phase=='add' or phase=='take_partial') and owner then
        portion(find(inv,f.run..'-portion'),true)
        assert(#outputs(inv,f,'Hydrocraft.HCAlestienFluid')==0,'Premature empty vessel')
    end
    if phase=='share_partial' then portion(find(common,f.run..'-portion'),true) end
    if phase=='finish' and owner then
        assert(not find(inv,f.run..'-portion'),'Cooking portion not exhausted')
        assert(#outputs(inv,f,'Hydrocraft.HCAlestienFluid')==1,'Final empty vessel absent/duplicated')
        local dishes=outputs(inv,f,'Base.PotOfSoupRecipe');assert(#dishes==5,'Repeated native soup outputs missing')
        local dose=0;for _,item in ipairs(dishes) do dose=dose+F.dose(item) end
        near(dose,.375,'Five soup total dose')
    end
    if phase=='share_final' or phase=='verify' then
        local empties=outputs(common,f,'Hydrocraft.HCAlestienFluid');assert(#empties==1,'Shared final vessel absent/duplicated')
        assert(Q.fluid(empties[1]):isEmpty() and not empties[1]:IsFood(),'Returned vessel is not empty')
        assert(not empties[1]:getModData()[F.key] and not empties[1]:getModData()[F.qualityKey],'Quality leaked into empty vessel')
        local dishes=outputs(common,f,'Base.PotOfSoupRecipe');assert(#dishes==5,'Shared soup outputs missing')
        local dose=0
        for _,item in ipairs(dishes) do assert(F.quality(item)=='rotten');dose=dose+F.dose(item) end
        near(dose,.375,'Shared five soup total dose')
        assert(not find(common,f.run..'-portion'),'Exhausted portion survived')
        if owner then
            for _,kind in ipairs({'Hydrocraft.HCBeercan1pack','Hydrocraft.HCBeercan1Fluid',
                'Hydrocraft.HCAlestienFluid','Base.PotOfSoupRecipe'}) do
                assert(#outputs(inv,f,kind)==0,'Transferred output survived in owner inventory: '..kind)
            end
            assert(not find(inv,f.run..'-portion'),'Exhausted portion survived in owner inventory')
        end
    end
end
local function broadcast(command,args)
    args.beer=true
    for _,player in pairs(M.state.players) do sendServerCommand(player,'HCRLabTwo',command,args) end
end
local function phase(index)
    local state=M.state;state.index=index;state.phase=phases[index];state.acks={};state.since=getTimestampMs()
    if not state.phase then
        state.complete=true;shared(state.f):getModData().HCRBeerMPSaved=state.f
        shared(state.f):getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
        broadcast('complete',{run=state.f.run});log('SERVER PASS all eleven phases; canonical state and both clients agree');return
    end
    broadcast('phase',{f=state.f,phase=state.phase});log('SERVER phase '..state.phase)
end
function M.start()
    assert(isServer(),'Beer MP start belongs to server')
    local players={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do
        local player=all:get(i);local name=player:getUsername()
        if name=='HCRLabOwner' then players.owner=player elseif name=='HCRLabObserver' then players.observer=player end
    end
    assert(players.owner and players.observer,'Both private clients required')
    local player=players.owner
    assert(math.abs(player:getX()-players.observer:getX())<5 and math.abs(player:getY()-players.observer:getY())<5,'Players must be together')
    player:setUnlimitedCarry(true)
    for i=1,20 do if player:getPerkLevel(Perks.Cooking)>=10 then break end;player:getXp():AddXP(Perks.Cooking,10000) end
    assert(player:getPerkLevel(Perks.Cooking)==10,'Cooking10 fixture required')
    local square=player:getSquare();local run=tostring(getTimestampMs())
    local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),previous={}}
    local inv=player:getInventory();local previous=inv:getItems()
    for i=0,previous:size()-1 do f.previous[tostring(previous:get(i):getID())]=true end
    local tableSquare=assert(getCell():getGridSquare(f.x+1,f.y,f.z));local surface=IsoObject.new(getCell(),tableSquare,'carpentry_01_60')
    tableSquare:AddTileObject(surface);surface:transmitCompleteItemToClients()
    assert(player:canUseAsGenericCraftingSurface(surface),'Beer crafting surface unavailable')
    local bag=tagged(instanceItem('Base.Bag_Schoolbag'),run);local common=bag:getItemContainer()
    for i=1,7 do
        local old=instanceItem('Hydrocraft.HCBeercan1');old:setAge(0)
        if i==7 then F.store(old,.375) end
        local item=assert(HCRItemMigrations.newReplacement(old))
        tagged(item,run..(i==7 and '-poison' or '-can'..i));common:AddItem(item)
        if i==7 then f.previous[tostring(item:getID())]=true end
    end
    local empty=tagged(common:AddItem('Hydrocraft.HCBeercan1Fluid'),run..'-empty');f.previous[tostring(empty:getID())]=true
    square:AddWorldInventoryItem(bag,.35,.35,.05,true)
    local food=instanceItem('Hydrocraft.HCBeer1');food:setAge(0);food:setCalories(123.5);F.store(food,.375);F.setQuality(food,'rotten')
    local ledger=L.batch('HCRBeer',.3,HCRFluidEffects.snapshot(food),getGameTime():getWorldAgeHours())
    local values=HCRAlcoholPortions.properties(ledger);local sample=tagged(instanceItem('Hydrocraft.HCRCookingBeer'),run..'-portion')
    for key,value in pairs(values) do if key~='poisonPower' then sample[HCRFluidEffects.fields[key][2]](sample,value) end end
    F.setQuality(sample,'rotten');F.store(sample,.375);inv:AddItem(sample);sendAddItemToContainer(inv,sample)
    for i=1,5 do
        local pot=tagged(instanceItem('Base.Pot'),run..'-pot'..i);Q.fluid(pot):Empty();Q.fluid(pot):addFluid('Water',1.5)
        inv:AddItem(pot);sendAddItemToContainer(inv,pot)
    end
    M.state={f=f,players=players};phase(1)
end
function M.server(command,player,args)
    local state=M.state;if not state or state.failed or state.complete or args.run~=state.f.run then return end
    if command=='fail' then state.failed=true;log('SERVER FAIL client '..tostring(args.reason));return end
    if command~='ack' or args.phase~=state.phase then return end
    local role=player==state.players.owner and 'owner' or player==state.players.observer and 'observer' or nil
    if not role then return end
    state.acks[role]=true
    if state.acks.owner and state.acks.observer then
        local ok,err=pcall(observe,state.f,state.phase,state.players.owner,true)
        if not ok then log('SERVER awaiting canonical state '..tostring(err));return end
        phase(state.index+1)
    end
end
function M.client(command,args)
    if command=='phase' then M.localState={f=args.f,phase=args.phase,ticks=0,stable=0};log('CLIENT phase '..args.phase)
    elseif command=='complete' then M.localState=nil;log('CLIENT PASS all eleven independently verified phases') end
end
local function craft(player,common,name,selected)
    local recipes=getScriptManager():getAllCraftRecipes();local recipe
    for i=0,recipes:size()-1 do if recipes:get(i):getName()==name then recipe=recipes:get(i);break end end
    local surface=assert(ISEntityUI.FindCraftSurface(player,1),'Beer native crafting surface not visible')
    local logic=HandcraftLogic.new(player,nil,surface);local containers=ArrayList.new()
    containers:add(player:getInventory());containers:add(common);logic:setContainers(containers);logic:setRecipe(recipe)
    logic:setManualSelectInputs(true);logic:clearManualInputs()
    local input=ArrayList.new();for _,item in ipairs(selected) do input:add(item) end
    assert(logic:setManualInputsFor(recipe:getInputs():get(0),input),'Beer MP manual selection rejected')
    assert(logic:canPerformCurrentRecipe(),'Beer MP native recipe unavailable')
    ISTimedActionQueue.add(ISHandcraftAction.FromLogic(logic))
end
local function transfer(player,items,destination)
    for _,item in ipairs(items) do ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,item:getContainer(),destination)) end
end
local function act(state,player)
    if state.phase=='initial' or state.phase=='verify' then state.acted=true;return end
    local f=state.f;local common=shared(f):getItemContainer();local inv=player:getInventory()
    local p=state.phase;player:setUnlimitedCarry(true)
    if p=='pack' then
        local cans={};for i=1,6 do cans[i]=assert(find(common,f.run..'-can'..i)) end
        craft(player,common,'Pack Beer',cans)
    elseif p=='share_pack' then transfer(player,outputs(inv,f,'Hydrocraft.HCBeercan1pack'),common)
    elseif p=='unpack' then craft(player,common,'Open Pack of Beer',outputs(common,f,'Hydrocraft.HCBeercan1pack'))
    elseif p=='share_cans' then transfer(player,outputs(inv,f,'Hydrocraft.HCBeercan1Fluid'),common)
    elseif p=='share_partial' then transfer(player,{assert(find(inv,f.run..'-portion'))},common)
    elseif p=='take_partial' then transfer(player,{assert(find(common,f.run..'-portion'))},inv)
    elseif p=='add' or p=='finish' then
        local recipes=getScriptManager():getAllEvolvedRecipes();local recipe
        for i=0,recipes:size()-1 do if recipes:get(i):getFullResultItem()=='Base.PotOfSoupRecipe' then recipe=recipes:get(i);break end end
        local used=assert(find(inv,f.run..'-portion'))
        for i=(p=='add' and 1 or 2),(p=='add' and 1 or 5) do
            local pot=assert(find(inv,f.run..'-pot'..i))
            ISTimedActionQueue.add(ISAddItemInRecipe:new(player,recipe,pot,used))
        end
    elseif p=='share_final' then
        transfer(player,outputs(inv,f,'Hydrocraft.HCAlestienFluid'),common)
        transfer(player,outputs(inv,f,'Base.PotOfSoupRecipe'),common)
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
        local ok,err=pcall(act,state,player)
        if not ok then state.failed=true;log('CLIENT FAIL action '..tostring(err));sendClientCommand(player,'HCRLabTwo','fail',{beer=true,run=state.f.run,reason=tostring(err)});return end
    end
    if owner and ISTimedActionQueue.isPlayerDoingAction(player) then state.stable=0;return end
    local ok,err=pcall(observe,state.f,state.phase,player,owner)
    state.stable=ok and state.stable+30 or 0
    if state.stable>=120 and state.stable%120==0 then
        sendClientCommand(player,'HCRLabTwo','ack',{beer=true,run=state.f.run,phase=state.phase})
        log('CLIENT independently observed '..state.phase)
    elseif state.ticks%600==0 then log('CLIENT waiting '..state.phase..': '..tostring(err)) end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args) if args.beer then return M.server(command,player,args) end;return server(command,player,args) end
    HCRLabTwo.client=function(command,args) if args.beer then return M.client(command,args) end;return client(command,args) end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();M.tick();ticks=ticks+1;if ticks%60~=0 then return end
        local reader=getFileReader('HCRLabBeerMPCommand.txt',false);if not reader then return end
        local line=reader:readLine();reader:close();if not line or line==last then return end;last=line
        local sequence,command=line:match('^(%d+):([%w]+)$');if not command then return end
        local ok,err=pcall(function() assert(command=='start','Unknown beer MP command');M.start() end)
        log(sequence..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(err)))
    end
end
