-- Private localhost test only; never install in the distributable mod.
HCRLabFluidMP = HCRLabFluidMP or {}
local T=HCRLabFluidMP
local MODULE="HCRLabFluidMP"
local OLD="Hydrocraft.HCWaterflaskfull"
local NEW="Hydrocraft.HCWaterflaskFluid"
local function log(s) print("[HCRFluidMP] "..s) end
local function tagged(c,tag)
    local items=c:getItems()
    for i=0,items:size()-1 do
        local v=items:get(i)
        if v:getModData().HCRFluidLabTag==tag then return v end
        if v:getCategory()=="Container" then
            local found=tagged(v:getItemContainer(),tag)
            if found then return found end
        end
    end
end
local function world(f)
    local s=getCell():getGridSquare(f.x,f.y,f.z)
    if not s then return end
    local items=s:getWorldObjects()
    for i=0,items:size()-1 do
        local o=items:get(i)
        if o:getItem() and o:getItem():getID()==f.groundId then return o end
    end
end
local function check(v,amount)
    assert(v and v:getFullType()==NEW,"new native flask missing")
    local fc=v:getFluidContainerFromSelfOrWorldItem()
    assert(fc and math.abs(fc:getAmount()-amount)<.00001,"fluid amount differs")
    assert(math.abs(fc:getSpecificFluidAmount(Fluid.TaintedWater)-amount)<.00001,"taint amount differs")
    assert(v:isFavorite() and v:getModData().HCRFluidLabTag,"saved item state missing")
end
local function countTag(c,tag)
    local n=0;local items=c:getItems()
    for i=0,items:size()-1 do
        local v=items:get(i)
        if v:getModData().HCRFluidLabTag==tag then n=n+1 end
        if v:getCategory()=="Container" then n=n+countTag(v:getItemContainer(),tag) end
    end
    return n
end
local function legacy(tag,uses)
    local v=instanceItem(OLD)
    v:setCurrentUsesFloat(uses*.07)
    assert(v:getCurrentUses()==uses)
    v:setFavorite(true);v:getModData().HCRFluidLabTag=tag
    return v
end
local function observe(p,f,phase)
    assert(countTag(p:getInventory(),f.bagTag)==1 and countTag(p:getInventory(),f.heldTag)==1,"duplicate/missing inventory flask")
    check(tagged(p:getInventory(),f.bagTag),.7)
    local o=world(f)
    check(o and o:getItem(),f.groundAmount or .3)
    assert(math.abs(o:getWorldPosX()-f.px)<.001 and math.abs(o:getWorldPosY()-f.py)<.001,"ground moved")
    local objects=o:getSquare():getWorldObjects();local copies=0
    for i=0,objects:size()-1 do
        local v=objects:get(i):getItem()
        if v and v:getID()==f.groundId then copies=copies+1 end
    end
    assert(copies==1,"ground duplicate/missing world identity")
    local h=tagged(p:getInventory(),f.heldTag)
    if phase=="held" then
        assert(h and h:getFullType()==OLD and h:getCurrentUses()==7,"equipped stock migrated early")
        assert(p:getPrimaryHandItem()==h,"held reference lost")
    else
        check(h,.7)
        assert(not p:getPrimaryHandItem() and not p:getSecondaryHandItem(),"unexpected equip after unequip")
    end
end
local function savedFixture(p,stamp)
    assert(type(stamp)=="string")
    local s=p:getSquare();local objects=s:getWorldObjects();local found
    for i=0,objects:size()-1 do
        local o=objects:get(i)
        if o:getItem() and o:getItem():getModData().HCRFluidLabTag==stamp.."ground" then found=o;break end
    end
    assert(found,"saved ground fixture missing on original player square")
    return {x=s:getX(),y=s:getY(),z=s:getZ(),groundId=found:getItem():getID(),
        bagTag=stamp.."bag",heldTag=stamp.."held",px=s:getX()+.23,py=s:getY()+.67,
        groundAmount=found:getItem():getModData().HCRFluidSavedExpected or .3}
end
local function server(module,command,p,args)
    if module~=MODULE then return end
    local ok,err=pcall(function()
        if command=="begin" then
            assert(not T.serverState,"fixture already exists; restart lab for another run")
            local stamp=tostring(getTimestampMs())
            local f={bagTag=stamp.."bag",heldTag=stamp.."held",groundTag=stamp.."ground"}
            local bag=instanceItem("Base.Bag_Schoolbag")
            local inner=instanceItem("Base.Bag_Schoolbag")
            inner:getItemContainer():AddItem(legacy(f.bagTag,7))
            bag:getItemContainer():AddItem(inner)
            p:getInventory():AddItem(bag);sendAddItemToContainer(p:getInventory(),bag)
            local held=legacy(f.heldTag,7)
            p:getInventory():AddItem(held);sendAddItemToContainer(p:getInventory(),held)
            local s=p:getSquare()
            local ground=legacy(f.groundTag,3)
            s:AddWorldInventoryItem(ground,.23,.67,.05,true)
            local o=ground:getWorldItem()
            f.x=s:getX();f.y=s:getY();f.z=s:getZ();f.groundId=ground:getID()
            f.px=o:getWorldPosX();f.py=o:getWorldPosY()
            T.serverState={f=f,p=p,phase="old"}
            sendServerCommand(p,MODULE,"fixture",f)
            log("SERVER fixture created "..stamp)
        elseif command=="old_seen" then
            local state=T.serverState;assert(state and state.p==p and state.phase=="old")
            local f=state.f
            assert(p:getPrimaryHandItem()==tagged(p:getInventory(),f.heldTag),"server has not observed equip")
            HCRTimed.updateContainer(p:getInventory(),getGameTime():getWorldAgeHours(),0)
            HCRTimed.updateSquare(p:getSquare(),getGameTime():getWorldAgeHours())
            observe(p,f,"held")
            HCRTimed.updateContainer(p:getInventory(),getGameTime():getWorldAgeHours(),0)
            HCRTimed.updateSquare(p:getSquare(),getGameTime():getWorldAgeHours())
            state.phase="held"
            sendServerCommand(p,MODULE,"mutated",{})
            log("SERVER authoritative nested/ground replacement and held deferral verified")
        elseif command=="unequipped" then
            local state=T.serverState;assert(state and state.p==p and state.phase=="held")
            assert(not p:getPrimaryHandItem() and not p:getSecondaryHandItem(),"server has not observed unequip")
            HCRTimed.updateContainer(p:getInventory(),getGameTime():getWorldAgeHours(),0)
            HCRTimed.updateContainer(p:getInventory(),getGameTime():getWorldAgeHours(),0)
            observe(p,state.f,"done");state.phase="done"
            sendServerCommand(p,MODULE,"finished",{})
        elseif command=="passed" then
            local state=T.serverState;assert(state and state.p==p and state.phase=="done")
            observe(p,state.f,"done")
            log("SERVER PASS real client acknowledged; independent quantities/taint/held/ground checks PASS")
        elseif command=="saved" then
            observe(p,savedFixture(p,args.stamp),"done")
            log("SERVER PASS cold reload independently preserves saved native flasks and exact stored volumes")
            sendServerCommand(p,MODULE,"saved_ok",{})
        end
    end)
    if not ok then log("SERVER FAIL "..tostring(err));sendServerCommand(p,MODULE,"failed",{error=tostring(err)}) end
end
local function client(module,command,args)
    if module~=MODULE then return end
    if command=="fixture" then T.clientState={f=args,phase="old",ticks=0}
    elseif command=="mutated" then T.clientState.phase="held";T.clientState.ticks=0
    elseif command=="finished" then T.clientState.phase="done";T.clientState.ticks=0
    elseif command=="failed" then log("CLIENT FAIL "..tostring(args.error));T.clientState=nil
    elseif command=="saved_ok" then log("CLIENT PASS cold reload also confirmed by server") end
end
local function tick()
    local state=T.clientState
    if not state then return end
    state.ticks=state.ticks+1
    local p=getPlayer();local f=state.f
    local ok,err=pcall(function()
        if state.phase=="old" then
            local h=tagged(p:getInventory(),f.heldTag)
            assert(h and h:getFullType()==OLD and world(f),"initial fixture not visible")
            p:setPrimaryHandItem(h);p:updateHandEquips();state.phase="equip_wait";state.ticks=0
        elseif state.phase=="equip_wait" and state.ticks>=60 then
            state.phase="mutation_wait";sendClientCommand(p,MODULE,"old_seen",{})
        elseif state.phase=="held" then
            observe(p,f,"held")
            p:setPrimaryHandItem(nil);p:setSecondaryHandItem(nil)
            p:updateHandEquips()
            state.phase="unequip_wait";state.ticks=0
            log("CLIENT observed exact nested/ground fluids and unchanged held old flask")
        elseif state.phase=="unequip_wait" and state.ticks>=60 then
            state.phase="finish_wait";sendClientCommand(p,MODULE,"unequipped",{})
        elseif state.phase=="done" then
            observe(p,f,"done")
            state.stable=(state.stable or 0)+1
            if state.stable>=120 then
                log("CLIENT PASS native nested .7L, ground .3L, unequipped .7L; taint, position and held references")
                sendClientCommand(p,MODULE,"passed",{});T.clientState=nil
            end
        end
    end)
    if not ok then state.detail=tostring(err);state.stable=0 end
    if state.ticks>3600 then log("CLIENT FAIL timeout "..tostring(state.detail));T.clientState=nil end
end
function T.begin(p)
    assert(isClient() and p and p:isLocalPlayer())
    sendClientCommand(p,MODULE,"begin",{})
end
function T.verifySaved(p,stamp)
    assert(isClient() and p and p:isLocalPlayer())
    local f=savedFixture(p,stamp)
    observe(p,f,"done")
    log("CLIENT PASS cold reload preserves nested .7L, ground "..tostring(f.groundAmount).."L, unequipped .7L; unique IDs/tags and ground offset")
    sendClientCommand(p,MODULE,"saved",{stamp=stamp})
end
if isServer() then Events.OnClientCommand.Add(server)
elseif isClient() then
    Events.OnServerCommand.Add(client);Events.OnTick.Add(tick)
end
