-- Частный MP oracle: надписи в трёх миграциях, world FC и настоящем tooltip.
require 'HCR_ItemNames'
HCRLabItemNames={boot=tostring(getTimestampMs())}
local N,Q=HCRLabItemNames,HCRFluidQuality
local function log(text) print('[HCRNamesMP] '..text) end
local function players()
    local result={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do
        local p=all:get(i)
        if p:getUsername()=='HCRLabOwner' then result.owner=p
        elseif p:getUsername()=='HCRLabObserver' then result.observer=p end
    end
    assert(result.owner and result.observer,'Both private clients required');return result
end
local function find(f,tag)
    local sq=assert(getCell():getGridSquare(f.x,f.y,f.z),'Fixture square not loaded')
    local objects=sq:getWorldObjects()
    for i=0,objects:size()-1 do
        local item=objects:get(i):getItem()
        if item:getModData().HCRNamesTag==f.run..'-'..tag then return item end
    end
    error('World sample absent: '..tag)
end
local function observe(f,cold,role)
    local bag=find(f,'bag');local result={};local items=bag:getItemContainer():getItems()
    for i=0,items:size()-1 do
        local item=items:get(i);result[item:getModData().HCRNamesIndex]=item
    end
    result[5]=find(f,'world')
    for i,row in ipairs(f.rows) do
        local item=assert(result[i],'Named vessel missing')
        assert(item:getID()==row.id,'Vessel identity changed')
        assert(item:getFullType()==row.target,'Vessel migration missing')
        assert(item:isCustomName() and HCRItemNames.custom(item)==row.name,'Custom label lost '..i)
        assert(item:getModData().HCRLegacyCustomName==row.name,'Archive lost '..i)
        assert(item:getName()~=row.name,'Fixture must exercise native FC naming')
        assert(math.abs(Q.rawAmount(Q.fluid(item))-row.amount)<.0001,'Contents changed '..i)
    end
    if cold then assert(f.boots[role] and f.boots[role]~=N.boot,'Process did not restart '..role) end
    return result
end
local function show(items)
    if N.tooltips then for _,tip in ipairs(N.tooltips) do tip:removeFromUIManager() end end
    N.tooltips={}
    for i=1,5 do
        local tip=ISToolTipInv:new(items[i]);tip:initialise();tip.followMouse=false
        tip:setCharacter(getPlayer());tip:setX(20+((i-1)%3)*420);tip:setY(70+math.floor((i-1)/3)*310)
        tip.backgroundColor.a=.96;tip:addToUIManager();N.tooltips[#N.tooltips+1]=tip
    end
end
function N.start(cold)
    assert(isServer());local pair=players();local sq=pair.owner:getSquare();local f
    if cold then f=assert(HCRLabTwo.savedNearby(pair.owner,'HCRNamesSaved'))
    else
        f={run=tostring(getTimestampMs()),x=sq:getX(),y=sq:getY(),z=sq:getZ(),boots={server=N.boot},rows={}}
        local bag=instanceItem('Base.Bag_Schoolbag');bag:getModData().HCRNamesTag=f.run..'-bag'
        -- LexState сохраняет символы Lua literal через byte cast. Unicode
        -- приходит через native UTF-8 Reader, как реальная надпись из интерфейса.
        local reader=assert(getFileReader('HCRLabNamesLabels.txt',false),'Missing UTF-8 fixture labels')
        local labels={};for i=1,5 do labels[i]=assert(reader:readLine(),'Missing label '..i) end;reader:close()
        local fixtures={
            {'Hydrocraft.HCWaterflask',labels[1],0,'Hydrocraft.HCWaterflaskFluid'},
            {'Hydrocraft.HCWaterflaskfull',labels[2],1.4,'Hydrocraft.HCWaterflaskFluid'},
            {'Hydrocraft.HCClingmugapplejuice',labels[3],.2,'Base.Mugl'},
            {'Hydrocraft.HCBarrelgrape',labels[4],20,'Hydrocraft.HCWoodenbarrelFluid'},
            {'Hydrocraft.HCWaterflaskfull',labels[5],1.4,'Hydrocraft.HCWaterflaskFluid'},
        }
        for i,row in ipairs(fixtures) do
            local source=assert(instanceItem(row[1]));source:setName(row[2]);source:setCustomName(true)
            source:getModData().HCRNamesIndex=i
            if i==5 then
                source:getModData().HCRNamesTag=f.run..'-world'
                sq:AddWorldInventoryItem(source,.6,.6,.05,true)
                HCRTimed.updateSquare(sq,getGameTime():getWorldAgeHours())
                local item=find(f,'world')
                f.rows[i]={id=item:getID(),name=row[2],amount=row[3],target=row[4]}
            else
                local item=assert(HCRItemMigrations.newReplacement(source),'Migration failed '..i)
                bag:getItemContainer():AddItem(item)
                f.rows[i]={id=item:getID(),name=row[2],amount=row[3],target=row[4]}
            end
        end
        sq:AddWorldInventoryItem(bag,.4,.4,.05,true)
    end
    observe(f,cold,'server')
    N.state={f=f,cold=cold,players=pair,acks={}}
    for _,p in pairs(pair) do sendServerCommand(p,'HCRLabTwo','names',{names=true,f=f,cold=cold}) end
    log('SERVER fixtures ready '..(cold and 'cold' or 'fresh'))
end
function N.server(command,player,args)
    local state=N.state
    if not state or command~='namesack' or args.run~=state.f.run then return end
    local role=player==state.players.owner and 'owner' or player==state.players.observer and 'observer'
    if not role then return end
    observe(state.f,state.cold,'server');state.acks[role]=true
    if not state.cold then state.f.boots[role]=args.boot end
    if state.acks.owner and state.acks.observer then
        local bag=find(state.f,'bag');bag:getModData().HCRNamesSaved=state.f
        bag:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
        log('SERVER PASS '..(state.cold and 'cold' or 'fresh'));N.state=nil
    end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args)
        if args.names then return N.server(command,player,args) end
        return server(command,player,args)
    end
    HCRLabTwo.client=function(command,args)
        if args.names then N.localState={f=args.f,cold=args.cold,stable=0,ticks=0};return end
        return client(command,args)
    end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();ticks=ticks+1;if ticks%30~=0 then return end
        if isClient() and N.localState then
            local state=N.localState;state.ticks=state.ticks+30
            local role=getPlayer():getUsername()=='HCRLabOwner' and 'owner' or 'observer'
            local ok,items=pcall(observe,state.f,state.cold,role)
            state.stable=ok and state.stable+30 or 0
            if state.stable>=120 then
                show(items);sendClientCommand(getPlayer(),'HCRLabTwo','namesack',{names=true,run=state.f.run,boot=N.boot})
                log('CLIENT PASS '..(state.cold and 'cold' or 'fresh'));N.localState=nil
            elseif state.ticks%600==0 then log('CLIENT waiting '..tostring(items)) end
        end
        if not isServer() then return end
        local reader=getFileReader('HCRLabNamesCommand.txt',false)
        local line=reader and reader:readLine();if reader then reader:close() end
        if line and line~=last then
            last=line;local seq,command=line:match('^(%d+):(%w+)$')
            if command then
                local ok,why=pcall(function() assert(command=='run' or command=='verify');N.start(command=='verify') end)
                log(seq..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(why)))
            end
        end
    end
end
