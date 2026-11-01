-- Private real three-process chunk unload/reload oracle. No retained Java items.
HCRLabBrewUnloadBoot=HCRLabBrewUnloadBoot or tostring(getTimestampMs())
HCRLabBrewUnload={}
local S,Q,L=HCRLabBrewUnload,HCRFluidQuality,HCRFluidLedger
local function log(s) print('[HCRBrewUnload] '..s) end
local function near(a,b,label) assert(a and math.abs(a-b)<.001,label..' '..tostring(a)..' / '..tostring(b)) end
local function loaded(f) return getCell():getGridSquare(f.x,f.y,f.z) end
local function crate(f)
 local objects=assert(loaded(f),'Origin unloaded'):getObjects()
 for i=0,objects:size()-1 do local o=objects:get(i);if o:getModData().HCRBreweryMPTag==f.run then return o end end
 error('Missing origin crate')
end
local function sample(f)
 local items=crate(f):getContainer():getItems();local found
 for i=0,items:size()-1 do local item=items:get(i);if item:getID()==f.id then assert(not found);found=item end end
 return assert(found,'Lost unloaded sample')
end
local function verify(f,returned)
 local item=sample(f);local fluid=Q.fluid(item);local ledger=assert(item:getModData()[Q.key]);L.validate(ledger)
 near(Q.rawAmount(fluid),1,'Unload litres');near(L.budget(ledger,'poisonPower'),.5,'Unload exact dose')
 assert(L.matches(ledger,Q.amounts(fluid)) and #ledger.lots==2,'Unload composition/lots')
 assert(L.quality(ledger)=='rotten','Unload freshness')
 for _,lot in ipairs(ledger.lots) do assert(lot.food.tainted,'Unload taint') end
 near(fluid:getSpecificFluidAmount(Fluid.Get('HCRBeerWort')),returned and .75 or 1,'Unload wort')
 near(fluid:getSpecificFluidAmount(Fluid.Get('HCRBeer')),returned and .25 or 0,'Unload mature lot')
 local pot=instanceItem('Base.Pot');local native=Q.fluid(pot);native:Empty();native:addFluid('Beer',1)
 near(L.budget(ledger,'calories'),returned and 240+native:getProperties():getCalories()*.25 or 320,'Unload nutrition')
 for _,lot in ipairs(ledger.lots) do
  if lot.fluid=='HCRBeerWort' and lot.litres>.5 then
   near(lot.fermentation.startedAt,f.youngerStart,'Younger clock retained')
   if returned then assert(lot.fermentation.lastHour>=f.unloadedHour+1.24,'Clock failed to resume') end
  end
 end
end
local function emit(command,args)
 args.brewUnload=true;for _,p in pairs(S.state.players) do sendServerCommand(p,'HCRLabTwo',command,args) end
end
local function phase(name)
 S.state.phase=name;S.state.acks={};S.state.since=getTimestampMs()
 emit('phase',{phase=name,f=S.state.f});log('SERVER phase '..name)
end
function S.start()
 local prior=assert(HCRLabBreweryMP.state);assert(prior.complete and not prior.cold,'Complete brewing first')
 local f=L.copy(prior.f);f.boots={server=HCRLabBrewUnloadBoot}
 local now=getGameTime():getWorldAgeHours();local ledger=L.empty()
 for i,volume in ipairs({.25,.75}) do
  local food={age=4,offAge=2,offAgeMax=4,calories=volume*320,poisonPower=volume*.5,tainted=true,baseHunger=-.1,hungChange=-.1}
  local part=HCRFermentation.start(L.batch('HCRBeerWort',volume,food,now),'Hydrocraft.HCRWheatWortBatch',now)
  part.lots[1].fermentation.startedAt=now-(i==1 and 167 or 150)
  if i==2 then f.youngerStart=part.lots[1].fermentation.startedAt end
  ledger=L.mix(ledger,part)
 end
 local common=crate(f):getContainer();local item=instanceItem('Hydrocraft.HCWoodenbucketFluid');common:AddItem(item)
 local fluid=Q.fluid(item);fluid:Empty();fluid:addFluid('HCRBeerWort',1);Q.store(item,fluid,ledger)
 f.id=item:getID();sendAddItemToContainer(common,item)
 S.state={f=f,players=prior.players};verify(f,false);phase('baseline')
end
function S.server(command,p,args)
 local s=S.state;if not s or s.complete or s.failed or args.run~=s.f.run then return end
 if command~='ack' or args.phase~=s.phase then return end
 local role=p:getUsername();s.acks[role]=true
 if s.phase=='baseline' then s.f.boots[role]=args.boot end
 if not (s.acks.HCRLabOwner and s.acks.HCRLabObserver) then return end
 if s.phase=='baseline' then verify(s.f,false);phase('away');log('READY teleport both clients away')
 elseif s.phase=='away' then
  if loaded(s.f) then return end
  s.f.unloadedHour=getGameTime():getWorldAgeHours();phase('absent')
 elseif s.phase=='return' then
  assert(args.absentHours>=1.24,'Insufficient client unload interval');verify(s.f,true)
  crate(s.f):getModData().HCRBrewUnloadSaved=s.f;crate(s.f):transmitModData()
  s.complete=true;emit('complete',{});log('SERVER PASS unload, native elapsed time, independent maturity, exact budgets')
 end
end
function S.client(command,args)
 if command=='complete' then S.localState=nil;log('CLIENT PASS unload/reload')
 elseif command=='phase' then
  local old=S.localState;S.localState={f=args.f,phase=args.phase,ticks=0,stable=0,
   absentStart=old and old.absentStart,absentEnd=old and old.absentEnd}
  log('CLIENT phase '..args.phase)
 end
end
function S.tick()
 local s=isServer() and S.state or S.localState;if not s or s.complete or s.failed then return end
 if isServer() then
  if not s.since then s.failed=true;log('SERVER FAIL incomplete fixture');return end
  if getTimestampMs()-s.since>300000 then s.failed=true;log('SERVER FAIL timeout '..s.phase);return end
  if s.phase=='absent' then
   assert(not loaded(s.f),'Origin reloaded early')
   if getGameTime():getWorldAgeHours()-s.f.unloadedHour>=1.25 then phase('return');log('READY teleport both clients home') end
  end
  return
 end
 s.ticks=s.ticks+1;if s.ticks%30~=0 then return end
 local absent=not loaded(s.f)
 if absent and (s.phase=='away' or s.phase=='absent' or s.phase=='return') then
  s.absentStart=s.absentStart or getGameTime():getWorldAgeHours();s.absentEnd=getGameTime():getWorldAgeHours()
 end
 local ok,why
 if s.phase=='away' or s.phase=='absent' then ok=absent
 else ok,why=pcall(verify,s.f,s.phase=='return') end
 s.stable=ok and s.stable+30 or 0
 if s.stable>=120 and s.stable%120==0 and s.phase~='absent' then
  sendClientCommand(getPlayer(),'HCRLabTwo','ack',{brewUnload=true,run=s.f.run,phase=s.phase,boot=HCRLabBrewUnloadBoot,absentHours=s.absentStart and s.absentEnd-s.absentStart or 0})
 elseif s.ticks%600==0 then log('CLIENT awaiting '..s.phase..' '..tostring(why)) end
end
function S.verifySaved()
 local player=isServer() and getOnlinePlayers():get(0) or getPlayer();local sq=player:getSquare();local saved
 for x=sq:getX()-2,sq:getX()+2 do for y=sq:getY()-2,sq:getY()+2 do local s=getCell():getGridSquare(x,y,sq:getZ())
  if s then for i=0,s:getObjects():size()-1 do local f=s:getObjects():get(i):getModData().HCRBrewUnloadSaved;if f then saved=f end end end
 end end
 assert(saved,'No saved unload fixture');verify(saved,true)
 local role=isServer() and 'server' or player:getUsername();assert(saved.boots[role]~=HCRLabBrewUnloadBoot,'Not cold process')
 log('COLD PASS retained pending lot, mature lot, exact IDs/budgets/clocks')
end
do
 local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
 HCRLabTwo.server=function(c,p,a) if a.brewUnload then return S.server(c,p,a) end;return server(c,p,a) end
 HCRLabTwo.client=function(c,a) if a.brewUnload then return S.client(c,a) end;return client(c,a) end
 HCRLabTwo.tick=function() tick();S.tick() end
end
