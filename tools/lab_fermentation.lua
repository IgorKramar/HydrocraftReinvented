-- Только private lab: проверка на настоящих FluidContainer и Food B42.
-- Часы передаются функции явно; время мира и сохранения не переставляются.
require 'HCR_Fermentation'
require 'HCR_FluidTransform'
require 'HCR_DrinkFluids'
HCRLabFermentation={}
local M,B,X,L,Q=HCRLabFermentation,HCRFermentation,HCRFluidTransform,HCRFluidLedger,HCRFluidQuality
local function near(a,b,label)
    assert(math.abs(a-b)<.00001,label..': '..tostring(a)..' / '..tostring(b))
end
local function barrel(kind,litres,start,dose,quality)
    local marker=B.stages[kind].marker
    local food=B.snapshot('Hydrocraft.HCBarrelvinegar',quality or 'fresh')
    food.poisonPower=dose or .875;food.poisonDetectionLevel=4
    local ledger=L.batch(marker,litres,food,start)
    ledger.lots[1].fermentation=HCRFermentationClock.new(kind,start,start,true)
    return ledger
end
local function check(fluid,ledger,label)
    assert(L.matches(ledger,Q.amounts(fluid)),label..' native/ledger mismatch')
end
local function vessel(ledger,water)
    local item=instanceItem('Hydrocraft.HCWoodenbucketFluid')
    local fluid=Q.fluid(item);fluid:Empty()
    local capacity=fluid:getCapacity();fluid:setCapacity(capacity+1)
    if water then fluid:addFluid('Water',water) end
    for _,lot in ipairs(ledger.lots) do if lot.litres>0 then fluid:addFluid(lot.fluid,lot.litres) end end
    fluid:setCapacity(capacity)
    check(fluid,ledger,'Initial')
    return item,fluid
end
function M.run()
    assert(isServer(),'Private server oracle only')
    for _,pair in ipairs({{'grape','wine'},{'grapegreen','winewhite'},{'honey','mead'},{'rice','sake'}}) do
        local ledger=barrel('Hydrocraft.HCBarrel'..pair[1],2,0,.875,'stale')
        local item,fluid=vessel(ledger,1)
        local sourceRef=fluid
        fluid:setContainerName('Fermentation_fixture');fluid:setRainCatcher(.125)
        fluid:setInputLocked(true);fluid:setCanPlayerEmpty(false)
        local ready,changed=B.plan(ledger,336,true,B.snapshot)
        assert(changed and X.rewrite(fluid,ledger,ready));check(fluid,ready,'Ready')
        assert(Q.fluid(item)==sourceRef and fluid:isInputLocked() and not fluid:canPlayerEmpty()
            and fluid:getContainerName()=='Fermentation_fixture','Native identity/settings')
        near(fluid:getRainCatcher(),.125,'Rain catcher')
        near(fluid:getSpecificFluidAmount(Fluid.Water),1,'Other native water')
        near(L.budget(ready,'poisonPower'),.875,'Ready poison');assert(L.quality(ready)=='stale')
        local vinegar=B.plan(ready,672,true,B.snapshot)
        assert(X.rewrite(fluid,ready,vinegar));check(fluid,vinegar,'Vinegar')
        near(L.budget(vinegar,'poisonPower'),.875,'Vinegar poison')
        assert(L.quality(vinegar)=='stale' and L.budget(vinegar,'calories')==0)
        print('[HCRFermentationLab] PASS '..pair[1]..' -> '..pair[2]..' -> vinegar')
    end
    -- Одна партия почти закончилась: native adjust удаляет её след,
    -- но перепостроение обязано восстановить положительный объём.
    local a=barrel('Hydrocraft.HCBarrelgrape',.99995,0,.3)
    local b=barrel('Hydrocraft.HCBarrelgrape',.00005,300,.2)
    local before=L.mix(a,b);local item,fluid=vessel(before,2.99995)
    before=L.alignVolumes(before,Q.amounts(fluid))
    local after=B.plan(before,336,true,B.snapshot)
    assert(X.rewrite(fluid,before,after));check(fluid,after,'Sub-pruning trace')
    near(Q.rawAmount(fluid),3.99995,'Near-full total')
    near(L.budget(after,'poisonPower'),.5,'Trace poison')
    assert(fluid:getSpecificFluidAmount(Fluid.Get('HCRMustRed'))>0,'Trace disappeared')
    print('[HCRFermentationLab] PASS near-full and sub-pruning trace')
    -- Уже восемь компонентов; девятый блокируется до изменения смеси.
    before=L.mix(barrel('Hydrocraft.HCBarrelgrape',.5,0,.3),barrel('Hydrocraft.HCBarrelgrape',.5,300,.2))
    item,fluid=vessel(before)
    for _,name in ipairs({'Water','HCRMilk','HCRJuiceApple','HCRJuiceLemon','HCRJuiceOrange','HCRJuiceLime','HCRCoffee'}) do
        fluid:addFluid(name,.1)
    end
    local initial=X.contents(fluid)
    after=B.plan(before,336,true,B.snapshot)
    local ok,why=X.rewrite(fluid,before,after)
    assert(not ok and why=='components','Ninth component was accepted')
    local same=X.contents(fluid);assert(#same==#initial,'Rejected mixture changed')
    for i,part in ipairs(initial) do assert(same[i].name==part.name);near(same[i].litres,part.litres,'Rejected amount') end
    print('[HCRFermentationLab] PASS ninth component rejected without mutation')
    -- Настоящий server Q.capture меняет фазу и хранит итог до любого расхода.
    local now=getGameTime():getWorldAgeHours()
    local cask=instanceItem('Hydrocraft.HCWoodenbarrelFluid')
    local cf=Q.fluid(cask);cf:addFluid('HCRMustRed',2)
    local stock=barrel('Hydrocraft.HCBarrelgrape',2,now-336,.875,'rotten')
    cask:getModData()[Q.key]=stock
    local captured=Q.capture(cask,cf)
    assert(captured.ledger.lots[1].fluid=='HCRWineRed','Capture did not mature cask')
    check(cf,captured.ledger,'Capture maturity')
    assert(cask:getModData()[Q.key].lots[1].fluid=='HCRWineRed','Maturity was not committed')
    near(L.budget(captured.ledger,'poisonPower'),.875,'Capture poison')
    assert(L.quality(captured.ledger)=='rotten','Capture washed rotten quality')
    local portable=instanceItem('Hydrocraft.HCWoodenbucketFluid');local pf=Q.fluid(portable)
    Q.transfer(ISFluidContainer:new(cf),ISFluidContainer:new(pf),nil,function() FluidContainer.Transfer(cf,pf,1) end)
    local kept,moved=cask:getModData()[Q.key],portable:getModData()[Q.key]
    assert(kept.lots[1].fermentation.barrel and not moved.lots[1].fermentation.barrel,'Pour storage mode')
    near(L.budget(kept,'poisonPower'),.4375,'Kept dose');near(L.budget(moved,'poisonPower'),.4375,'Moved dose')
    check(cf,kept,'Kept cask');check(pf,moved,'Moved portable')
    print('[HCRFermentationLab] PASS server capture and native pour preserve separate clocks')
    local tap=IsoObject.new(getCell(),nil,'fixtures_sinks_01_16')
    tap:getModData().waterAmount=1;tap:getModData().waterMaxAmount=1
    assert(not tap:getFluidContainer() and tap:getPrimaryFluid()==Fluid.Water,'Expected native virtual tap')
    near(tap:getFluidAmount(),1,'Virtual tap reserve')
    local test=barrel('Hydrocraft.HCBarrelgrape',1,now,.1)
    local testItem,testFluid=vessel(test)
    for _,name in ipairs({'HCRMilk','HCRCoffee','HCRJuiceLemon','HCRJuiceLime','HCRJuiceApple'}) do
        testFluid:addFluid(name,.1)
        test=L.mix(test,L.batch(name,.1,{calories=0},now))
    end
    test=L.alignVolumes(test,Q.amounts(testFluid));Q.store(testItem,testFluid,test)
    assert(B.checkMixture(test,testFluid,nil),'Fixture should have exactly eight future components')
    assert(not B.checkMixture(test,testFluid,nil,B.waterComponents(tap)),'Virtual tap omitted water slot')
    local debited=false;local amount=Q.rawAmount(testFluid)
    local accepted=pcall(Q.addNative,testItem,nil,function() debited=true;tap:transferFluidTo(testFluid,.1) end,nil,tap)
    assert(not accepted and not debited,'Virtual tap mutation escaped preflight')
    near(tap:getFluidAmount(),1,'Untouched tap reserve');near(Q.rawAmount(testFluid),amount,'Untouched destination')
    print('[HCRFermentationLab] PASS virtual tap refused before native debit (expected preflight exception)')
    print('[HCRFermentationLab] ALL PASS')
end
if not HCRLabFermentationWatcherInstalled then
    HCRLabFermentationWatcherInstalled=true
    local ticks,last=0,nil
    local function poll()
        if not isServer() then return end
        local reader=getFileReader('HCRLabFermentationCommand.txt',false)
        if not reader then return end
        local line=reader:readLine();reader:close()
        if not line or line==last then return end;last=line
        local sequence,command=line:match('^(%d+):([%w]+)$')
        if command~='run' then return end
        local ok,reason=pcall(HCRLabFermentation.run)
        print('[HCRFermentationLab] '..sequence..':run '..(ok and 'PASS' or 'FAIL '..tostring(reason)))
    end
    Events.OnTick.Add(function() ticks=ticks+1;if ticks%60==0 then poll() end end)
    Events.OnServerStarted.Add(poll)
end
