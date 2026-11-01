-- Существующие сосуды обновляются на месте. Старое содержимое не переигрываем:
-- unordered native пакеты требуют нового снимка после каждого расхождения.
require 'HCR_FluidLedger'
require 'HCR_QualitySync'
HCRFluidSync={}
local N,L,S=HCRFluidSync,HCRFluidLedger,HCRQualitySync
local module='HCRFluidState160'
local pending,rates={},{}
local serial=0
local keys={'HCRFluidQuality','HCRProcessQuality160','HCRBeerFactory160','HCRFluidRainCatcher'}

local function equal(a,b,tolerance)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<=(tolerance or 0) end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k],tolerance) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end

function N.pack(fluid)
    if not fluid then return nil end
    local sample=fluid:createFluidSample()
    local state={parts={},capacity=fluid:getCapacity(),locked=fluid:isInputLocked(),
        empty=fluid:canPlayerEmpty(),rain=fluid:getRainCatcher(),name=fluid:getContainerName() or false}
    local supported=sample:getAmount()<=state.capacity+.000001
    for i=0,sample:size()-1 do
        local kind=sample:getFluid(i)
        if not kind:isCategory(FluidCategory.Beverage) or kind:isCategory(FluidCategory.Colors) then supported=false end
        state.parts[#state.parts+1]={name=kind:getFluidTypeString(),litres=fluid:getSpecificFluidAmount(kind)}
    end
    sample:release()
    if not supported then return nil end
    -- При равном объёме native primary fluid — первый добавленный компонент.
    -- Порядок sample сохраняется и в сигнатуре, и при восстановлении.
    return state
end

local function metadata(item)
    local data=item:getModData();local result={}
    for _,key in ipairs(keys) do result[key]=L.copy(data[key]==nil and false or data[key]) end
    return result
end

local function capture(item)
    local fluid=HCRFluidQuality.fluid(item);local state=N.pack(fluid)
    if not state then return nil end
    return {item=item,fluid=fluid,state=state,metadata=metadata(item),revision=item:getModData()[S.key] or 0}
end

local function unchanged(before,item)
    if not item or before.item~=item then return false end
    local now=capture(item)
    return now and now.fluid==before.fluid and now.revision==before.revision
        and equal(now.state,before.state) and equal(now.metadata,before.metadata)
end

local function write(fluid,state)
    -- Headroom не даёт native isFull округлить последние следовые компоненты
    -- до полного сосуда и пропустить их при восстановлении состава.
    fluid:Empty();fluid:setCapacity(state.capacity+1)
    fluid:setInputLocked(false);fluid:setCanPlayerEmpty(true)
    for _,part in ipairs(state.parts) do fluid:addFluid(part.name,part.litres) end
    fluid:setCapacity(state.capacity)
    fluid:setInputLocked(state.locked);fluid:setCanPlayerEmpty(state.empty)
    fluid:setRainCatcher(state.rain);fluid:setContainerName(state.name or nil)
    assert(equal(N.pack(fluid),state,.000001),'Native fluid snapshot was rejected')
end

function N.apply(item,args)
    local before=assert(capture(item),'Unsupported local fluid snapshot')
    local fluid=before.fluid
    local ledger=args.metadata.HCRFluidQuality or L.empty()
    L.validate(ledger)
    local amounts={}
    for _,part in ipairs(args.fluid.parts) do
        if HCRFluidQuality.transport[part.name] then amounts[part.name]=part.litres end
    end
    assert(L.matches(ledger,amounts),'Authoritative fluid metadata mismatch')
    local process=args.metadata.HCRProcessQuality160
    if process and process.clock then L.validate(process.clock) end
    local ok,err=pcall(write,fluid,args.fluid)
    if not ok then write(fluid,before.state);error(err) end
    local data=item:getModData()
    for _,key in ipairs(keys) do data[key]=args.metadata[key] and L.copy(args.metadata[key]) or nil end
    data[S.key]=args.revision
end

local function inRange(player,a)
    return a.location~='player' and math.abs(player:getX()-a.x)<=160 and math.abs(player:getY()-a.y)<=160
end

function N.notify(item)
    if not isServer() or item:IsFood() then return false end
    local a=S.address(item)
    if not a or a.location=='player' or not N.pack(HCRFluidQuality.fluid(item)) then return false end
    local revision=S.bump(item);local players=getOnlinePlayers()
    for i=0,players:size()-1 do
        local player=players:get(i)
        if inRange(player,a) then sendServerCommand(player,module,'changed',{address=a,revision=revision}) end
    end
    return true
end

local function request(row)
    local now=getTimestampMs()
    if row.sent and now-row.sent<250 then return end
    local item=S.resolve(row.address);local before=item and capture(item)
    if not before then return end
    serial=serial+1;row.nonce=serial;row.before=before;row.sent=now
    sendClientCommand(getPlayer(),module,'snapshot',{address=row.address,nonce=serial})
end

function N.changed(args)
    if not isClient() then return end
    local a=args.address
    if a.location=='player' or not getCell():getGridSquare(a.x,a.y,a.z) then return end
    local key=tostring(a.id);local row=pending[key]
    if row and args.revision<=row.highest then return end
    local count,oldestKey,oldest=0,nil,nil
    for k,v in pairs(pending) do
        count=count+1
        if not oldest or v.expires<oldest then oldestKey,oldest=k,v.expires end
    end
    if not row and count>=256 then pending[oldestKey]=nil end
    row={address=L.copy(a),highest=args.revision,expires=getTimestampMs()+30000}
    pending[key]=row;request(row)
end

function N.serve(player,args)
    if not isServer() then return end
    local a=args.address
    if type(a)~='table' or (a.location~='world' and a.location~='container' and a.location~='vehicle')
        or type(a.x)~='number' or type(a.y)~='number' or type(a.z)~='number'
        or type(a.path)~='table' or #a.path>8 or type(args.nonce)~='number'
        or not inRange(player,a) then return end
    local now=getTimestampMs();local id=player:getOnlineID();local rate=rates[id]
    if not rate or now-rate.time>=1000 then rate={time=now,count=0};rates[id]=rate end
    if rate.count>=40 then return end;rate.count=rate.count+1
    local ok,item=pcall(S.resolve,a)
    if not ok or not item or item:IsFood() or not item:getModData()[S.key] then return end
    local actual=S.address(item)
    if not actual or not inRange(player,actual) then return end
    local checked=L.copy(a)
    if a.location=='vehicle' then checked.x,checked.y,checked.z=actual.x,actual.y,actual.z end
    if not equal(checked,actual) then return end
    local saved=capture(item)
    if not saved then return end
    local Q=HCRFluidQuality
    if not L.matches(saved.metadata[Q.key] or L.empty(),Q.amounts(saved.fluid)) then return end
    local revision=S.bump(item)
    sendServerCommand(player,module,'snapshot',{address=a,nonce=args.nonce,revision=revision,
        fluid=saved.state,metadata=saved.metadata})
end

function N.receive(args)
    if not isClient() then return end
    local row=pending[tostring(args.address.id)]
    if not row or row.nonce~=args.nonce or not equal(row.address,args.address) then return end
    local item=S.resolve(row.address)
    local valid=args.revision>=row.highest and row.before and unchanged(row.before,item)
    row.highest=math.max(row.highest,args.revision)
    row.nonce=nil;row.before=nil
    if valid then
        local ok,err=pcall(N.apply,item,args)
        if ok then row.applied=capture(item);return end
        print('[HydrocraftReinvented] Fluid snapshot deferred: '..tostring(err))
    end
    row.applied=nil;request(row)
end

function N.reconcile()
    local now=getTimestampMs()
    for key,row in pairs(pending) do
        if now>=row.expires then pending[key]=nil
        else
            local item=S.resolve(row.address)
            if row.nonce then
                if not row.before or not unchanged(row.before,item) then
                    row.nonce=nil;row.before=nil;request(row)
                elseif now-row.sent>=1500 then
                    -- Медленный ответ остаётся действительным. Новый nonce
                    -- здесь бесконечно отвергал бы сеть с RTT дольше таймера.
                    row.sent=now
                    sendClientCommand(getPlayer(),module,'snapshot',{address=row.address,nonce=row.nonce})
                end
            elseif not row.applied or not unchanged(row.applied,item) then request(row) end
        end
    end
    for id,rate in pairs(rates) do if now-rate.time>10000 then rates[id]=nil end end
end

if Events.OnServerCommand then Events.OnServerCommand.Add(function(name,command,args)
    if name~=module then return end
    if command=='changed' then N.changed(args) elseif command=='snapshot' then N.receive(args) end
end) end
if Events.OnClientCommand then Events.OnClientCommand.Add(function(name,command,player,args)
    if name==module and command=='snapshot' then N.serve(player,args) end
end) end
if Events.OnContainerUpdate then Events.OnContainerUpdate.Add(function()
    if isClient() then N.reconcile() end
end) end
local ticks=0
Events.OnTick.Add(function()
    ticks=ticks+1;if ticks%30==0 then N.reconcile() end
end)
