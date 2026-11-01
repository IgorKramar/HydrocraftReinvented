-- Private localhost HCRLabMP; append after lab_mash_mp.lua, never ship in common.
HCRLabBreweryMPBoot=HCRLabBreweryMPBoot or tostring(getTimestampMs())
HCRLabBreweryMP={}
local M,Q,L,F=HCRLabBreweryMP,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local phases={'initial','start_half','start_full','share','pour_full','pour_partial','older','younger','verify'}
local function log(s) print('[HCRBreweryMP] '..s) end
local function near(a,b,why) assert(a and math.abs(a-b)<.001,why..' '..tostring(a)..' / '..tostring(b)) end
local function tag(item,name) item:getModData().HCRBreweryMPTag=name;return item end
local function find(inv,label)
 local found;local items=inv:getItems()
 for i=0,items:size()-1 do local item=items:get(i)
  if item:getModData().HCRBreweryMPTag==label then assert(not found,'Duplicate tagged item');found=item end
 end
 return found
end
local function shared(f)
 local objects=assert(getCell():getGridSquare(f.x,f.y,f.z),'Unloaded brewery square'):getObjects();local found
 for i=0,objects:size()-1 do local o=objects:get(i)
  if o:getModData().HCRBreweryMPTag==f.run then assert(not found);found=o end
 end
 return assert(found,'Missing brewery crate')
end
local function raw(item)
 local ledger=assert(item:getModData()[Q.key],'Missing raw brewery ledger');L.validate(ledger);return ledger
end
local function nativeBeer()
 -- Read the actual native fluid profile independently on each process.
 -- HCRFermentation.snapshot creates authoritative Food metadata and is server-only.
 local item=assert(instanceItem('Base.Pot'));local fluid=Q.fluid(item)
 fluid:Empty();fluid:addFluid('Beer',1);local props=fluid:getProperties()
 return {calories=props:getCalories(),nativeAlcohol=props:getAlcohol()}
end
local function liquid(item,volume,dose,wort,beer)
 local fluid=assert(Q.fluid(item));local ledger=raw(item)
 near(Q.rawAmount(fluid),volume,'Volume');assert(L.matches(ledger,Q.amounts(fluid)),'Native/ledger mismatch')
 near(fluid:getSpecificFluidAmount(Fluid.Get('HCRBeerWort')),wort,'Wort volume')
 near(fluid:getSpecificFluidAmount(Fluid.Get('HCRBeer')),beer,'Beer volume')
 near(L.budget(ledger,'poisonPower'),dose,'Poison dose')
 assert(L.quality(ledger)=='rotten','Worst freshness')
 for _,lot in ipairs(ledger.lots) do assert(lot.food.tainted,'Taint lost') end
 return ledger
end
local function observe(f,phase,player,owner)
 local common=shared(f):getContainer();local inv=player:getInventory()
 local function get(label) return find(common,f.run..'-'..label) or owner and find(inv,f.run..'-'..label) end
 local index=phase=='cold' and 9 or assert(M.indices[phase]);local a,b=get('half'),get('full')
 local bucket=assert(find(common,f.run..'-bucket'))
 if index==1 then
  assert(a and b and a:IsFood() and b:IsFood(),'Initial cooked Foods')
  assert(a:isCooked() and b:isCooked());assert(Q.fluid(bucket):isEmpty())
 end
 for i,label in ipairs({'half','full'}) do
  local started=index>=i+1;local item=i==1 and a or b
  local yeast=assert(get('yeast'..i),'Yeast missing');near(yeast:getCurrentUses(),started and 9 or 10,'One yeast use')
  if started and (owner or index>=4) then
   assert(item and item:getFullType()=='Base.Pot','Exactly one returned pot')
   if f.ids[label] then assert(item:getID()==f.ids[label],'Pot identity changed') end
   if owner and index>=4 then assert(not find(inv,f.run..'-'..label),'Duplicate owner pot') end
  end
 end
 if index>=2 and (owner or index>=4) then
  local beer=index>=8 and .5 or 0
  local volume=index>=6 and .5 or .75
  local ledger=liquid(a,volume,index>=6 and .5 or .75,volume-beer,beer)
  if index<8 then near(L.budget(ledger,'calories'),volume/.75*137,'Half nutrition') end
 end
 if index>=3 and (owner or index>=4) then
  if index>=5 then assert(Q.fluid(b):isEmpty(),'Full donor not empty')
  else local ledger=liquid(b,1.5,1.5,1.5,0);near(L.budget(ledger,'calories'),274,'Full nutrition') end
 end
 if index>=5 then
  local volume=index>=6 and 1.75 or 1.5
  local beer=index>=8 and volume or index>=7 and .25 or 0
  local ledger=liquid(bucket,volume,volume,volume-beer,beer)
  assert(#ledger.lots==(index>=6 and 2 or 1),'Separate lot clocks')
  local native=nativeBeer()
  local expected=index>=8 and native.calories*volume or index>=7 and 274+native.calories*.25 or 274+(index>=6 and 137/3 or 0)
  near(L.budget(ledger,'calories'),expected,'Mature beer nutrition')
  near(L.budget(ledger,'nativeAlcohol'),native.nativeAlcohol*beer,'Alcohol only for mature lots')
 end
 if index>=8 then
  near(L.budget(raw(a),'poisonPower')+L.budget(raw(bucket),'poisonPower'),2.25,'Total dose')
  local native=nativeBeer()
  near(L.budget(raw(a),'calories')+L.budget(raw(bucket),'calories'),native.calories*2.25,'Total beer nutrition')
 end
 if phase=='cold' then
  local role=isServer() and 'server' or owner and 'owner' or 'observer'
  assert(f.boots[role]~=HCRLabBreweryMPBoot,'Cold process not restarted')
  assert(bucket:getID()==f.ids.bucket,'Bucket identity changed')
 end
end
M.indices={};for i,p in ipairs(phases) do M.indices[p]=i end
local function broadcast(command,args)
 args.brewery=true;for _,p in pairs(M.state.players) do sendServerCommand(p,'HCRLabTwo',command,args) end
end
local function phase(index)
 local s=M.state;s.index=index;s.phase=s.cold and (index==1 and 'cold' or nil) or not s.cold and phases[index]
 s.acks={};s.since=getTimestampMs()
 if not s.phase then
  s.complete=true
  if not s.cold then shared(s.f):getModData().HCRBreweryMPSaved=s.f;shared(s.f):transmitModData() end
  broadcast('complete',{cold=s.cold});log('SERVER PASS '..(s.cold and 'cold' or 'all nine phases'));return
 end
 local common=shared(s.f):getContainer();local now=getGameTime():getWorldAgeHours()
 if s.phase=='pour_full' then
  for i,label in ipairs({'half','full'}) do local item=assert(find(common,s.f.run..'-'..label))
   for _,lot in ipairs(raw(item).lots) do lot.fermentation.startedAt=now-(i==1 and 167 or 157);lot.fermentation.lastHour=now end
   Q.sync(item,s.players.owner)
  end
 elseif s.phase=='older' or s.phase=='younger' then
  for _,label in ipairs({'half','bucket'}) do local item=assert(find(common,s.f.run..'-'..label))
   for _,lot in ipairs(raw(item).lots) do
    if s.phase=='younger' or label=='bucket' and lot.litres<.5 then
     lot.fermentation.startedAt=now-168;lot.fermentation.lastHour=now
    end
   end
   Q.capture(item,Q.fluid(item));Q.sync(item,s.players.owner)
  end
 end
 broadcast('phase',{f=s.f,phase=s.phase});log('SERVER phase '..s.phase)
end
function M.start(cold)
 assert(isServer());local pair={};local all=getOnlinePlayers()
 for i=0,all:size()-1 do local p=all:get(i)
  if p:getUsername()=='HCRLabOwner' then pair.owner=p elseif p:getUsername()=='HCRLabObserver' then pair.observer=p end
 end
 assert(pair.owner and pair.observer,'Both clients required');local p=pair.owner;local square=p:getSquare()
 assert(math.abs(p:getX()-pair.observer:getX())<5 and math.abs(p:getY()-pair.observer:getY())<5,'Players apart')
 if cold then
  local saved
  for x=square:getX()-2,square:getX()+2 do for y=square:getY()-2,square:getY()+2 do
   local sq=getCell():getGridSquare(x,y,square:getZ());if sq then local objects=sq:getObjects()
    for i=0,objects:size()-1 do local row=objects:get(i):getModData().HCRBreweryMPSaved
     if row and (not saved or tonumber(row.run)>tonumber(saved.run)) then saved=row end
    end
   end
  end end
  M.state={f=assert(saved,'No saved brewery run'),players=pair,cold=true};phase(1);return
 end
 local run=tostring(getTimestampMs());local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),ids={},boots={server=HCRLabBreweryMPBoot}}
 local crate=tag(IsoObject.new(getCell(),square,'carpentry_01_16'),run)
 local common=ItemContainer.new('crate',square,crate);common:setCapacity(100);crate:setContainer(common)
 local function add(kind,label) local item=tag(assert(instanceItem(kind)),run..'-'..label);common:AddItem(item);return item end
 for i,label in ipairs({'half','full'}) do
  local item=add('Hydrocraft.HCRWheatWortPot',label);item:setCooked(true);item:setAge(0)
  item:setHungChange(item:getBaseHunger()*(i==1 and .5 or 1));item:setCalories(137*i)
  F.store(item,.75*i);F.setQuality(item,'rotten');F.setTainted(item);add('Base.Yeast','yeast'..i)
 end
 local bucket=add('Hydrocraft.HCWoodenbucketFluid','bucket');Q.fluid(bucket):Empty();f.ids.bucket=bucket:getID()
 square:AddTileObject(crate);crate:transmitCompleteItemToClients()
 M.state={f=f,players=pair};phase(1)
end
function M.server(command,player,args)
 local s=M.state;if not s or s.failed or s.complete or args.run~=s.f.run then return end
 if command=='fail' then s.failed=true;log('SERVER FAIL '..tostring(args.reason));return end
 if command~='ack' or args.phase~=s.phase then return end
 local role=player==s.players.owner and 'owner' or player==s.players.observer and 'observer' or nil
 if not role then return end;s.acks[role]=true;if s.phase=='initial' then s.f.boots[role]=args.boot end
 if s.acks.owner and s.acks.observer then
  local ok,why=pcall(observe,s.f,s.phase,s.players.owner,true)
  if not ok then log('SERVER awaiting '..tostring(why));return end
  if s.phase=='share' then for _,label in ipairs({'half','full'}) do s.f.ids[label]=find(shared(s.f):getContainer(),s.f.run..'-'..label):getID() end end
  phase(s.index+1)
 end
end
function M.client(command,args)
 if command=='phase' then M.localState={f=args.f,phase=args.phase,ticks=0,stable=0};log('CLIENT phase '..args.phase)
 elseif command=='complete' then M.localState=nil;log('CLIENT PASS '..(args.cold and 'cold' or 'all nine phases')) end
end
local function act(s,p)
 local f=s.f;local inv=p:getInventory();local common=shared(f):getContainer()
 local function get(label) return (assert(find(common,f.run..'-'..label) or find(inv,f.run..'-'..label),'Missing '..label)) end
 p:setUnlimitedCarry(true);p:setTimedActionInstantCheat(true)
 if s.phase=='start_half' or s.phase=='start_full' then
  local half=s.phase=='start_half';HCRLabDrinksMP.craft(p,common,'Start Wheat Beer Fermentation',{{get(half and 'half' or 'full')},{get(half and 'yeast1' or 'yeast2')}})
 elseif s.phase=='share' then
  for _,label in ipairs({'half','full','yeast1','yeast2'}) do local item=get(label)
   if item:getContainer()==inv then ISTimedActionQueue.add(ISInventoryTransferAction:new(p,item,inv,common)) end
  end
 elseif s.phase=='pour_full' or s.phase=='pour_partial' then
  -- Native fluid UI only accepts InventoryItems held by a player; use the
  -- real inventory actions before pouring, then return both to shared storage.
  local sourceItem=get(s.phase=='pour_full' and 'full' or 'half');local targetItem=get('bucket')
  for _,item in ipairs({sourceItem,targetItem}) do
   ISTimedActionQueue.add(ISInventoryTransferAction:new(p,item,common,inv))
  end
  local source=Q.fluid(sourceItem);local target=Q.fluid(targetItem)
  ISTimedActionQueue.add(ISFluidTransferAction:new(p,ISFluidContainer:new(source),source,ISFluidContainer:new(target),target,s.phase=='pour_full' and 1.5 or .25))
  for _,item in ipairs({sourceItem,targetItem}) do
   ISTimedActionQueue.add(ISInventoryTransferAction:new(p,item,inv,common))
  end
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
 local p=getPlayer();local owner=p:getUsername()=='HCRLabOwner'
 if owner and not s.acted then local ok,why=pcall(act,s,p)
  if not ok then s.failed=true;sendClientCommand(p,'HCRLabTwo','fail',{brewery=true,run=s.f.run,reason=tostring(why)});log('CLIENT FAIL '..tostring(why));return end
 end
 if owner and ISTimedActionQueue.isPlayerDoingAction(p) then s.stable=0;return end
 local ok,why=pcall(observe,s.f,s.phase,p,owner);s.stable=ok and s.stable+30 or 0
 if s.stable>=120 and s.stable%120==0 then
  sendClientCommand(p,'HCRLabTwo','ack',{brewery=true,run=s.f.run,phase=s.phase,boot=HCRLabBreweryMPBoot});log('CLIENT independently observed '..s.phase)
 elseif s.ticks%600==0 then log('CLIENT awaiting '..s.phase..' '..tostring(why)) end
end
do
 local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
 HCRLabTwo.server=function(command,p,args) if args.brewery then return M.server(command,p,args) end;return server(command,p,args) end
 HCRLabTwo.client=function(command,args) if args.brewery then return M.client(command,args) end;return client(command,args) end
 HCRLabTwo.tick=function() tick();M.tick() end
end
