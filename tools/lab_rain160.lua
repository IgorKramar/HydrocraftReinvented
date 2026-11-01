-- Explicit offline private lab. Changes weather inputs, never fills test vessels.
HCRLabRain160=HCRLabRain160 or {}
local T=HCRLabRain160
local function finish(ok,detail)
    local s=T.state
    if not s then return end
    s.rain:setAdminValue(s.rainValue);s.rain:setEnableAdmin(s.rainEnabled);s.rain:setFinalValue(s.rainFinal)
    s.snow:setAdminValue(s.snowValue);s.snow:setEnableAdmin(s.snowEnabled);s.snow:setFinalValue(s.snowFinal)
    for _,o in ipairs(s.objects) do o:getSquare():transmitRemoveItemFromSquare(o) end
    T.state=nil
    print("[HCRRain160] "..(ok and "PASS " or "FAIL ")..tostring(detail))
end
local function tick()
    local s=T.state
    if not s then return end
    local ok,err=pcall(function()
        s.ticks=s.ticks+1
        s.rain:setFinalValue(1);s.snow:setFinalValue(false)
        local f=s.objects[1]:getFluidContainer()
        local amount=f:getAmount()
        assert(s.objects[2]:getFluidContainer():isEmpty(),"RainFactor0 control filled")
        assert(s.objects[3]:getFluidContainer():isEmpty(),"indoor control filled")
        assert(math.abs(f:getSpecificFluidAmount(Fluid.TaintedWater)-amount)<.00001,"rain was not tainted")
        if amount>=.12 then
            local steps=amount/.012
            assert(math.abs(amount-f:getCapacity())<.00001 or math.abs(steps-math.floor(steps+.5))<.001,
                "native rain increment differs")
            finish(true,"real native ticks gained "..amount.."L tainted; RainFactor0 and indoor controls remain empty; weather restored")
        elseif s.ticks>1800 then error("native rain timeout, amount="..amount..", valid="..tostring(s.objects[1]:isValidEngineEntity())) end
    end)
    if not ok then finish(false,err) end
end
function T.begin(p,profile)
    assert(profile=="HCRLab" and not isClient() and not isServer() and not T.state)
    local outside=p:getSquare();assert(outside:isOutside(),"stand outdoors in the private lab")
    local inside
    for dx=-45,45 do
        for dy=-45,45 do
            local square=getCell():getGridSquare(outside:getX()+dx,outside:getY()+dy,outside:getZ())
            if square and not square:isOutside() and square:getFloor() then inside=square;break end
        end
        if inside then break end
    end
    assert(inside,"no loaded indoor control square")
    local climate=getClimateManager()
    local rain=climate:getClimateFloat(3);local snow=climate:getClimateBool(0)
    local s={rain=rain,snow=snow,rainEnabled=rain:isEnableAdmin(),rainValue=rain:getAdminValue(),rainFinal=rain:getFinalValue(),
        snowEnabled=snow:isEnableAdmin(),snowValue=snow:getAdminValue(),snowFinal=climate:getPrecipitationIsSnow(),objects={},ticks=0}
    T.state=s
    local ok,err=pcall(function()
        for i=1,3 do
            local item=instanceItem("Hydrocraft.HCWaterflaskFluid")
            local square=i==3 and inside or outside
            square:AddWorldInventoryItem(item,.25+i*.15,.5,0)
            local o=item:getWorldItem();assert(o)
            s.objects[#s.objects+1]=o
            local f=o:getFluidContainer();assert(f and f:isEmpty() and f:getRainCatcher()==1)
            if i==2 then f:setRainCatcher(0) end
        end
        rain:setAdminValue(1);rain:setEnableAdmin(true);rain:setFinalValue(1)
        snow:setAdminValue(false);snow:setEnableAdmin(true);snow:setFinalValue(false)
        print("[HCRRain160] native rainfall started; waiting for actual entity simulation")
    end)
    if not ok then finish(false,err) end
end
T.observe=tick -- Also permits explicit observation after a developer hot reload.
if not T.installed then T.installed=true;Events.OnTick.Add(tick) end
