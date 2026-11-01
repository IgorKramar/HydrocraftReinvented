-- Изменение условий хранения не заменяет сумку и ссылки queued actions.
require "HCR_FluidLedger"
HCRQualitySync = {}
local S,L=HCRQualitySync,HCRFluidLedger
S.key="HCRQualityRevision160"
local module="HCRQualityStorage160"
local pending={}
local function child(container,id)
    if not container then return nil end
    local items=container:getItems()
    for i=0,items:size()-1 do if items:get(i):getID()==id then return items:get(i) end end
end

function S.bump(item)
    local data=item:getModData()
    data[S.key]=(data[S.key] or 0)+1
    return data[S.key]
end

function S.address(item)
    local root=item
    local path={}
    while root:getContainer() and root:getContainer():getContainingItem() do
        table.insert(path,1,root:getID())
        root=root:getContainer():getContainingItem()
        if #path>8 then return nil end
    end
    local a={id=item:getID(),kind=item:getFullType(),root=root:getID(),path=path}
    local world=root:getWorldItem()
    local container=root:getContainer()
    if world then
        local square=world:getSquare();if not square then return nil end
        a.location="world";a.x,a.y,a.z=square:getX(),square:getY(),square:getZ()
    elseif container then
        local owner=container:getCharacter()
        if owner and instanceof(owner,"IsoPlayer") then
            a.location="player";a.player=owner:getOnlineID()
        else
            local part=container:getVehiclePart()
            local parent=container:getParent()
            local square=container:getSourceGrid()
            if not square then return nil end
            a.x,a.y,a.z=square:getX(),square:getY(),square:getZ()
            if part then
                a.location="vehicle";a.vehicle=part:getVehicle():getId();a.part=part:getId()
            elseif parent then
                a.location="container";a.object=parent:getObjectIndex()
                for n=0,parent:getContainerCount()-1 do
                    if parent:getContainerByIndex(n)==container then a.container=n;break end
                end
                if a.object<0 or a.container==nil then return nil end
            else return nil end
        end
    else return nil end
    return a
end

function S.resolve(a)
    local root
    if a.location=="player" then
        for n=0,getNumActivePlayers()-1 do
            local player=getSpecificPlayer(n)
            if player and player:getOnlineID()==a.player then root=child(player:getInventory(),a.root);break end
        end
    else
        local square=getCell():getGridSquare(a.x,a.y,a.z)
        if not square then return nil end
        if a.location=="world" then
            local items=square:getWorldObjects()
            for n=0,items:size()-1 do local item=items:get(n):getItem()
                if item and item:getID()==a.root then root=item;break end
            end
        elseif a.location=="container" then
            local objects=square:getObjects()
            local object=a.object>=0 and a.object<objects:size() and objects:get(a.object)
            root=object and a.container<object:getContainerCount() and child(object:getContainerByIndex(a.container),a.root)
        elseif a.location=="vehicle" then
            local vehicle=getVehicleById(a.vehicle)
            local part=vehicle and vehicle:getPartById(a.part)
            root=part and child(part:getItemContainer(),a.root)
        end
    end
    for _,id in ipairs(a.path) do
        if not root or not instanceof(root,"InventoryContainer") then return nil end
        root=child(root:getItemContainer(),id)
    end
    if root and root:getID()==a.id and root:getFullType()==a.kind then return root end
end

function S.send(item)
    if not isServer() then return end
    local a=S.address(item)
    if not a then return false end
    local Q,P=HCRFluidQuality,HCRProcessQuality
    local data=item:getModData()
    local args={address=a,revision=S.bump(item),liquid=L.copy(data[Q.key] or false),
        process=L.copy(P and data[P.key] or false),rain=data.HCRFluidRainCatcher or false,
        amount=Q.rawAmount(Q.fluid(item))}
    local players=getOnlinePlayers()
    for n=0,players:size()-1 do
        local player=players:get(n)
        -- Это запас вокруг максимальной области B42 (96 клеток), а не
        -- имитация native relevance. Невыгруженные клиентом клетки игнорируются.
        if (a.player and player:getOnlineID()==a.player) or (not a.player
            and math.abs(player:getX()-a.x)<=160 and math.abs(player:getY()-a.y)<=160) then
            sendServerCommand(player,module,"storage",args)
        end
    end
    return true
end

function S.apply(args)
    local item=S.resolve(args.address)
    if not item then return false end
    local data=item:getModData()
    local revision=data[S.key] or 0
    if revision>=args.revision then return true,revision end
    local Q,P=HCRFluidQuality,HCRProcessQuality
    local fluid=Q.fluid(item)
    if math.abs(Q.rawAmount(fluid)-args.amount)>.00001 then return false end
    local ledger=args.liquid or L.empty()
    L.validate(ledger)
    if not L.matches(ledger,Q.amounts(fluid)) then return false end
    if args.process and args.process.clock then L.validate(args.process.clock) end
    data[Q.key]=args.liquid and L.copy(args.liquid) or nil
    if P then data[P.key]=args.process and L.copy(args.process) or nil end
    data.HCRFluidRainCatcher=args.rain~=false and args.rain or nil
    data[S.key]=args.revision
    return true
end

function S.receive(args)
    if not isClient() then return end
    local a=args.address
    if a.location~="player" and not getCell():getGridSquare(a.x,a.y,a.z) then return end
    local key=tostring(a.id)
    local previous=pending[key]
    if previous and previous.highestSeen>args.revision then return end
    local count=0;local oldestKey,oldest
    for k,row in pairs(pending) do
        count=count+1
        if not oldest or row.untilTime<oldest then oldestKey,oldest=k,row.untilTime end
    end
    if count>=256 and not previous then pending[oldestKey]=nil end
    -- Native Add/Replace идёт по другому каналу. Даже уже применённый patch
    -- хранится кратко: поздний старый native snapshot не отменяет свежий clock.
    pending[key]={args=L.copy(args),untilTime=getTimestampMs()+30000,highestSeen=args.revision}
    local _,seen=S.apply(args)
    if seen and seen>args.revision then pending[key].highestSeen=seen end
end

function S.reconcile()
    local now=getTimestampMs()
    for key,row in pairs(pending) do
        if now>=row.untilTime then pending[key]=nil
        elseif row.highestSeen==row.args.revision then
            local _,seen=S.apply(row.args)
            if seen and seen>row.highestSeen then row.highestSeen=seen end
        end
    end
end

if Events.OnServerCommand then Events.OnServerCommand.Add(function(name,command,args)
    if name==module and command=="storage" then S.receive(args) end
end) end
if Events.OnContainerUpdate then Events.OnContainerUpdate.Add(function()
    if isClient() then S.reconcile() end
end) end
local ticks=0
Events.OnTick.Add(function()
    if not isClient() then return end
    ticks=ticks+1;if ticks%30==0 then S.reconcile() end
end)
