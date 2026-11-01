-- Частный server oracle: native Food.update греет реальные предметы,
-- мировое время и cookingTime тест не меняет.
require 'HCR_FoodQuality'
HCRLabFoodTaint=HCRLabFoodTaint or {}
local T,F=HCRLabFoodTaint,HCRFoodQuality
local function log(s) print('[HCRFoodTaint] '..s) end
function T.start()
    assert(isServer());local player
    local players=getOnlinePlayers()
    for i=0,players:size()-1 do if players:get(i):getUsername()=='HCRLabOwner' then player=players:get(i) end end
    assert(player,'Private owner required')
    local square=assert(getCell():getGridSquare(math.floor(player:getX()),math.floor(player:getY())-1,0))
    local crate=IsoObject.new(getCell(),square,'carpentry_01_16')
    local container=ItemContainer.new('crate',square,crate);container:setCapacity(100)
    container:setCustomTemperature(2);crate:setContainer(container)
    crate:getModData().HCRFoodTaintNative=true
    square:AddTileObject(crate);crate:transmitCompleteItemToClients()
    local hot={}
    for i=1,3 do
        local food=assert(instanceItem(i==2 and 'Base.Steak' or 'Base.Sandwich'))
        food:setAge(0);food:setIsCookable(i==2)
        if i==2 then food:setMinutesToCook(6);food:setMinutesToBurn(100) end
        container:AddItem(food);food:setHeat(2)
        if i==3 then food:setCookingTime(30) end
        F.setTainted(food);F.store(food,.625);F.setQuality(food,'stale')
        assert(F.tainted(food),'Premature clearing of already cooked food')
        hot[#hot+1]=food;sendAddItemToContainer(container,food)
    end
    local control=assert(instanceItem('Base.Sandwich'));control:setAge(0)
    player:getInventory():AddItem(control);F.setTainted(control)
    sendAddItemToContainer(player:getInventory(),control)
    T.state={hot=hot,control=control,container=container,started=getTimestampMs(),done={}}
    log('START native cooking: uncookable, cookable, reheated; cold control')
end
function T.tick()
    if not isServer() then return end
    local state=T.state;if not state then return end
    assert(getTimestampMs()-state.started<180000,'Native heating timeout')
    local all=true
    for i,food in ipairs(state.hot) do
        if not F.tainted(food) then
            assert(not food:isTainted(),'Sidecar cleared before native Food.update')
            F.reconcile(food)
            assert(food:getModData()[F.taintKey].cleared,'Missing cleared tombstone')
            assert(math.abs(F.dose(food)-.625)<.000001,'Heating erased poison')
            assert(F.quality(food)=='stale','Heating erased freshness')
            if not state.done[i] then
                state.done[i]=true;log('Native heating PASS '..i..' cookingTime='..food:getCookingTime())
            end
        else all=false end
    end
    assert(F.tainted(state.control) and state.control:isTainted(),'Cold food lost taint')
    if all then
        state.container:setCustomTemperature(1)
        log('ALL PASS native heating and cold control');T.state=nil
    end
end
do
    local ticks,last=0,nil
    local previous=HCRLabTwo.tick
    HCRLabTwo.tick=function()
        previous()
        if not isServer() then return end
        ticks=ticks+1;if ticks%30~=0 then return end
        local reader=getFileReader('HCRLabFoodTaintCommand.txt',false)
        local line=reader and reader:readLine();if reader then reader:close() end
        if line and line~=last then
            last=line
            if line:match('^%d+:run$') then
                local ok,why=pcall(HCRLabFoodTaint.start)
                if not ok then log('FAIL start '..tostring(why));HCRLabFoodTaint.state=nil end
            end
        end
        local ok,why=pcall(HCRLabFoodTaint.tick)
        if not ok then log('FAIL '..tostring(why));HCRLabFoodTaint.state=nil end
    end
end
