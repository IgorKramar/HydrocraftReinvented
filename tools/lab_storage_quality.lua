-- Только private HCRLab: настоящие холодильники, freezer и сохранение ledger.
require "HCR_FluidQuality"
require "HCR_ProcessQuality"
HCRLabStorage=HCRLabStorage or {}
local S=HCRLabStorage
local Q,L,P=HCRFluidQuality,HCRFluidLedger,HCRProcessQuality
local function near(a,b,label) assert(math.abs(a-b)<.001,label..": "..tostring(a).." != "..tostring(b)) end
local function milk(container,label,freeze)
    local item=container:AddItem("Hydrocraft.HCWoodenbucketFluid")
    local fluid=Q.fluid(item);fluid:Empty();fluid:addFluid("HCRMilk",1)
    Q.store(item,fluid,L.batch("HCRMilk",1,{age=0,offAge=4,offAgeMax=7,
        calories=615,poisonPower=.875,canBeFrozen=freeze or false},getGameTime():getWorldAgeHours()))
    item:getModData().HCRLabStorage160=label
    return item
end
local function ageBack(item,hours)
    for _,lot in ipairs(item:getModData()[Q.key].lots) do lot.lastHour=lot.lastHour-hours end
end
local function closeAge(item)
    local ledger=Q.capture(item,Q.fluid(item)).ledger
    Q.store(item,Q.fluid(item),ledger)
    return ledger
end

function S.run(player)
    local fridge,freezer
    for _,entry in ipairs(S.targets) do
        if not fridge and entry.container:isFridge() then fridge=entry.container end
        if not freezer and entry.container:isFreezer() then freezer=entry.container end
    end
    assert(fridge and freezer,"Missing actual cold containers")
    local option=getSandboxOptions():getOptionByName("ElecShutModifier")
    local previous=option:getValue()
    local generator
    local created={}
    local function sample(container,label,freeze)
        local item=milk(container,label,freeze);created[#created+1]=item;return item
    end
    local warm,cold
    local steps={function()
        option:setValue(-1)
    end,function()
        assert(not fridge:isPowered(),"Grid did not shut down")
        warm=sample(fridge,"generator-on")
        ageBack(warm,48)
        local sq=fridge:getSourceGrid()
        generator=IsoGenerator.new(instanceItem("Base.Generator"),getCell(),sq)
        generator:setConnected(true);generator:setFuel(100);generator:setActivated(true)
    end,function()
        assert(fridge:isPowered() and fridge:getSourceGrid():haveElectricity(),"Actual generator did not power fridge")
        near(closeAge(warm).lots[1].age,2,"Generator ON preserves previous warm days")
        cold=sample(fridge,"generator-off")
        ageBack(cold,48)
        generator:setActivated(false)
    end,function()
        assert(not fridge:isPowered() and not fridge:getSourceGrid():haveElectricity(),"Actual generator did not shut down")
        local fridgeFactor=({.4,.3,.2,.1,.03,0})[SandboxVars.FridgeFactor or 3]
        local rot=({1.7,1.4,1,.7,.4})[SandboxVars.FoodRotSpeed or 3]
        near(closeAge(cold).lots[1].age,2*fridgeFactor*rot,"Generator OFF preserves previous cold days")
        print("[HCRStorage160] actual generator ON/OFF preserves previous 48-hour intervals PASS")
        option:setValue(math.max(previous,math.ceil(getGameTime():getWorldAgeHours()/24)+5))
    end,function()
        assert(fridge:isPowered() and freezer:isPowered(),"Actual grid unavailable")
        local fridgeFactor=({.4,.3,.2,.1,.03,0})[SandboxVars.FridgeFactor or 3]
        local rot=({1.7,1.4,1,.7,.4})[SandboxVars.FoodRotSpeed or 3]
        local fresh=sample(fridge,"grid-fridge")
        local env=Q.environment(fresh)
        assert(not env.powered and env.operationalPowered and env.gridPowered,"Native grid flags")
        ageBack(fresh,24)
        near(closeAge(fresh).lots[1].age,fridgeFactor*rot,"Grid fridge aging")
        local frozen=sample(freezer,"grid-freezer",true)
        ageBack(frozen,24)
        local ledger=closeAge(frozen)
        assert(ledger.lots[1].food.frozen,"Powered freezer failed")
        near(ledger.lots[1].age,4*fridgeFactor*rot/24,"Time until frozen")
        local unfrozenMilk=sample(freezer,"milk-cant-freeze")
        ageBack(unfrozenMilk,24)
        ledger=closeAge(unfrozenMilk)
        assert(not ledger.lots[1].food.frozen,"Milk ignored CantFreeze")
        near(ledger.lots[1].age,fridgeFactor*rot,"Unfreezable milk remains chilled")
        print("[HCRStorage160] native grid fridge/freezer and CantFreeze PASS")
        local bag=fridge:AddItem("Base.Bag_Schoolbag");created[#created+1]=bag
        local nested=sample(bag:getItemContainer(),"nested-fridge")
        assert(Q.environment(nested).cold,"Nested fridge lost outer container")
        ageBack(nested,24);ledger=closeAge(nested)
        near(ledger.lots[1].age,fridgeFactor*rot,"Nested cold aging")
        fridge:Remove(bag);player:getInventory():AddItem(bag)
        closeAge(nested)
        ageBack(nested,24);ledger=closeAge(nested)
        near(ledger.lots[1].age,(fridgeFactor+1)*rot,"Warm backpack aging after fridge")
        near(L.budget(ledger,"poisonPower"),.875,"Cold transitions exact poison")
        near(L.budget(ledger,"calories"),615,"Cold transitions nutrition")
        print("[HCRStorage160] nested bag cold-to-warm and unchanged dose/nutrition PASS")
    end}
    local stage,tick=0,0
    local function cleanup()
        if generator then
            generator:setActivated(false);generator:setConnected(false)
            generator:getSquare():transmitRemoveItemFromSquare(generator)
        end
        option:setValue(previous)
        for _,item in ipairs(created) do if item:getContainer() then item:getContainer():Remove(item) end end
    end
    local step
    step=function()
        tick=tick+1;if tick%3~=0 then return end
        stage=stage+1
        local ok,reason=pcall(steps[stage])
        if not ok or stage==#steps then
            Events.OnTick.Remove(step);cleanup()
            print("[HCRStorage160] actual storage run "..(ok and "PASS" or "FAIL "..tostring(reason)))
        end
    end
    Events.OnTick.Add(step)
    print("[HCRStorage160] actual storage run STARTED; final result follows")
end

local function stamp(item,label,ledger)
    item:getModData().HCRLabStorage160={label=label,age=ledger.lots[1].age,
        hour=ledger.lots[1].lastHour,cold=Q.environment(item).cold,
        frozen=ledger.lots[1].food.frozen or false}
end

function S.seed(player)
    local fridge,freezer
    for _,entry in ipairs(S.targets) do
        if not fridge and entry.container:isFridge() then fridge=entry.container end
        if not freezer and entry.container:isFreezer() then freezer=entry.container end
    end
    assert(fridge and freezer and fridge:isPowered() and freezer:isPowered())
    local item=milk(fridge,"saved-fridge")
    ageBack(item,48);stamp(item,"saved-fridge",closeAge(item))
    item=milk(freezer,"saved-freezer",true)
    ageBack(item,24);stamp(item,"saved-freezer",closeAge(item))
    local bag=fridge:AddItem("Base.Bag_Schoolbag")
    local nested=bag:getItemContainer():AddItem("Base.Bag_Schoolbag")
    item=milk(nested:getItemContainer(),"saved-nested-cold")
    ageBack(item,48);stamp(item,"saved-nested-cold",closeAge(item))
    local ground=instanceItem("Base.Bag_Schoolbag")
    nested=ground:getItemContainer():AddItem("Base.Bag_Schoolbag")
    player:getSquare():AddWorldInventoryItem(ground,.45,.45,0)
    item=milk(nested:getItemContainer(),"saved-nested-ground")
    assert(not Q.environment(item).cold,"Ground bag unexpectedly cold")
    ageBack(item,48);stamp(item,"saved-nested-ground",closeAge(item))
    local curd=fridge:AddItem("Hydrocraft.HCCheesecurd")
    curd:getModData()[P.key]={version=1,dose=.875,quality="fresh",detection=-1,
        clock=L.batch("HCRMilk",1,{age=2,offAge=10,offAgeMax=10,canBeFrozen=false},getGameTime():getWorldAgeHours())}
    P.checkpoint(curd);stamp(curd,"saved-process",P.read(curd).clock)
    print("[HCRStorage160] seeded FIVE save fixtures: fridge, freezer, two nested bags, Normal curd clock")
end

function S.verify(player)
    local found={}
    local function visit(container)
        local items=container:getItems()
        for i=0,items:size()-1 do
            local item=items:get(i)
            local spec=item:getModData().HCRLabStorage160
            if type(spec)=="table" then
                assert(not found[spec.label],"Duplicate save fixture "..spec.label)
                found[spec.label]=true
                local process=item:getModData()[P.key]
                local ledger=process and P.read(item).clock or Q.capture(item,Q.fluid(item)).ledger
                local elapsed=getGameTime():getWorldAgeHours()-spec.hour
                local factor=spec.cold and ({.4,.3,.2,.1,.03,0})[SandboxVars.FridgeFactor or 3] or 1
                local rot=({1.7,1.4,1,.7,.4})[SandboxVars.FoodRotSpeed or 3]
                near(ledger.lots[1].age,spec.age+(spec.frozen and 0 or elapsed*factor*rot/24),spec.label.." saved age")
                assert(Q.environment(item).cold==spec.cold,spec.label.." wrong reloaded storage")
                if process then
                    near(P.read(item).dose,.875,"Saved Normal dose")
                    assert(not item:IsFood(),"Normal curd changed class")
                else
                    near(Q.rawAmount(Q.fluid(item)),1,"Saved litres")
                    near(L.budget(ledger,"poisonPower"),.875,"Saved exact dose")
                    near(L.budget(ledger,"calories"),615,"Saved nutrition")
                    assert((ledger.lots[1].food.frozen or false)==spec.frozen,"Saved frozen state")
                end
                print("[HCRStorage160] cold-save "..spec.label.." PASS")
            end
            if instanceof(item,"InventoryContainer") then visit(item:getItemContainer()) end
        end
    end
    visit(player:getInventory())
    for _,entry in ipairs(S.targets) do visit(entry.container) end
    local origin=player:getSquare()
    for dx=-2,2 do for dy=-2,2 do
        local sq=getCell():getGridSquare(origin:getX()+dx,origin:getY()+dy,origin:getZ())
        if sq then
            local objects=sq:getWorldObjects()
            for i=0,objects:size()-1 do
                local item=objects:get(i):getItem()
                if item and instanceof(item,"InventoryContainer") then visit(item:getItemContainer()) end
            end
        end
    end end
    local count=0;for _ in pairs(found) do count=count+1 end
    assert(count==5,"Missing cold-save fixtures "..count)
    print("[HCRStorage160] FIVE native cold-save storage fixtures PASS")
end

function S.probe(player,profile)
    assert(profile=="HCRLab" and not isClient() and not isServer())
    local square=player:getSquare()
    local found={}
    for dx=-45,45 do for dy=-45,45 do
        local sq=getCell():getGridSquare(square:getX()+dx,square:getY()+dy,square:getZ())
        if sq then
            local objects=sq:getObjects()
            for i=0,objects:size()-1 do
                local object=objects:get(i)
                for n=0,object:getContainerCount()-1 do
                    local container=object:getContainerByIndex(n)
                    if container:isFridge() or container:isFreezer() then
                        found[#found+1]={container=container,distance=dx*dx+dy*dy}
                    end
                end
            end
        end
    end end
    table.sort(found,function(a,b) return a.distance<b.distance end)
    S.targets=found
    for i=1,math.min(8,#found) do
        local c=found[i].container;local sq=c:getSourceGrid()
        print("[HCRStorage160] "..i.." "..c:getType().." at "..sq:getX()..","..sq:getY()..","..sq:getZ()
            .." powered="..tostring(c:isPowered()).." grid="..tostring(sq:hasGridPower())
            .." generator="..tostring(sq:haveElectricity()).." temp="..c:getTemperature())
    end
    print("[HCRStorage160] nearby cold containers="..#found.." now="..getGameTime():getWorldAgeHours()
        .." shutdown="..getSandboxOptions():getElecShutModifier())
    local reader=getFileReader("HCRLabStorageMode.txt",false)
    if reader then
        local mode=reader:readLine();reader:close()
        if mode=="run" then S.run(player)
        elseif mode=="seed" then S.seed(player)
        elseif mode=="verify" then S.verify(player)
        elseif mode~="probe" then error("Unknown private storage mode") end
    end
end
