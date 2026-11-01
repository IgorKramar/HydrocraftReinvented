-- Только приватный localhost HCRLabMP, после lab_two_client.lua.
-- Клиенты действуют штатными timed actions и отдельно читают сырые партии.
require 'HCR_MilkCocktailCatalog'
require 'HCR_SoftDrinkCatalog'
require 'TimedActions/ISDrinkFluidAction'
require 'TimedActions/ISEquipWeaponAction'
require 'HCR_Medicine'
-- Hot reload меняет oracle, но никогда не оборачивает старый trace повторно.
HCRLabDrinksHooks=HCRLabDrinksHooks or {eat=ISEatFoodAction.complete,
    drink=ISDrinkFluidAction.updateEat,drinkComplete=ISDrinkFluidAction.complete}
HCRLabDrinksMP={}
HCRLabDrinksMPBoot=HCRLabDrinksMPBoot or tostring(getTimestampMs())
local M,Q,L,F=HCRLabDrinksMP,HCRFluidQuality,HCRFluidLedger,HCRFoodQuality
local phases={'initial','make','share_make','cups','share_cups','bottles','share_bottles',
    'drink','share_drink','med_old','med_repeat','ginseng_part','ginseng_full','adrenaline','share_med','dilute','share_dilute','verify'}
local medicines={
    med_old={label='lemonOld',fraction=1,sickness=-25,poison=-25,tubes=1},
    med_repeat={label='lemonNew',fraction=1,sickness=0,poison=0,tubes=2},
    ginseng_part={label='ginseng',fraction=.25,endurance=.0375,tubes=2,remaining=true},
    ginseng_full={label='ginseng',fraction=1,endurance=.1125,tubes=3},
    adrenaline={label='adrenaline',fraction=.25,endurance=.1,stress=.2,tubes=3},
}
local function seedMedicine(player,spec)
    local stats=player:getStats()
    if spec.sickness then stats:set(CharacterStat.FOOD_SICKNESS,40);stats:set(CharacterStat.POISON,40) end
    if spec.endurance then
        -- Проверка лечения уже завершена: её остаточное отравление не должно
        -- убить тестового персонажа во время следующих независимых измерений.
        stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.FOOD_SICKNESS,0)
        stats:set(CharacterStat.ENDURANCE,.2)
    end
    if spec.stress then stats:set(CharacterStat.STRESS,.1) end
end
local function healthyFixture(player)
    assert(not player:isDead(),'Private test character died; restore the lab checkpoint')
    player:getBodyDamage():RestoreToFullHealth();player:setHealth(100)
    player:getStats():set(CharacterStat.POISON,0)
    player:getStats():set(CharacterStat.FOOD_SICKNESS,0)
end
local function log(s) print('[HCRDrinksMP] '..s) end
local function near(a,b,label,tolerance) assert(a and math.abs(a-b)<(tolerance or .002),label..' '..tostring(a)..' / '..tostring(b)) end
local function raw(item) local value=assert(item:getModData()[Q.key],'Missing raw ledger');L.validate(value);return value end
local function tag(item,name) item:getModData().HCRDrinksMPTag=name;return item end
local function find(inv,name)
    local items=inv:getItems()
    for i=0,items:size()-1 do if items:get(i):getModData().HCRDrinksMPTag==name then return items:get(i) end end
end
local function byId(inv,id)
    local result;local items=inv:getItems()
    for i=0,items:size()-1 do if items:get(i):getID()==id then assert(not result,'Duplicate ID');result=items:get(i) end end
    return (assert(result,'Missing item '..tostring(id)))
end
local function shared(f)
    local world=assert(getCell():getGridSquare(f.x,f.y,f.z)):getObjects();local found
    for i=0,world:size()-1 do local item=world:get(i)
        if item and item:getModData().HCRDrinksMPTag==f.run then assert(not found);found=item end
    end
    return (assert(found,'Missing shared crate'))
end
function M.savedNearby(player)
    local origin=player:getSquare();local saved
    for x=origin:getX()-2,origin:getX()+2 do for y=origin:getY()-2,origin:getY()+2 do
        local square=getCell():getGridSquare(x,y,origin:getZ())
        if square then
            local objects=square:getObjects()
            for i=0,objects:size()-1 do
                local row=objects:get(i):getModData().HCRDrinksMPSaved
                if row and (not saved or tonumber(row.run)>tonumber(saved.run)) then saved=row end
            end
        end
    end end
    return saved
end
local function outputs(inv,f,kind)
    local result={};local items=inv:getItems()
    for i=0,items:size()-1 do local item=items:get(i)
        if item:getFullType()==kind and not f.previous[tostring(item:getID())] then result[#result+1]=item end
    end
    table.sort(result,function(a,b) return a:getID()<b:getID() end);return result
end
local function liquid(item,marker,amount,calories,dose,quality,alcohol)
    local fluid=assert(Q.fluid(item));local value=raw(item)
    near(Q.rawAmount(fluid),amount,'Volume');near(fluid:getSpecificFluidAmount(Fluid.Get(marker)),amount,'Marker')
    assert(L.matches(value,Q.amounts(fluid)),'Physical/ledger mismatch')
    near(L.budget(value,'calories'),calories,'Calories');near(L.budget(value,'poisonPower'),dose,'Poison')
    assert(L.quality(value)==quality,'Freshness')
    if alcohol then near(L.budget(value,'nativeAlcohol'),alcohol,'Alcohol') end
end
local function checkGroup(inv,f,kind,count,marker,volume,calories,dose,quality,alcohol)
    local rows=outputs(inv,f,kind);assert(#rows==count,'Wrong output count '..kind..' '..#rows)
    for _,item in ipairs(rows) do liquid(item,marker,volume,calories,dose,quality,alcohol) end
    return rows
end
local function energy(item,expected)
    local remaining=Q.rawAmount(Q.fluid(item))
    -- Native anim progress может закончиться с долями миллилитра сверх 1/4.
    -- Проверяем порцию отдельно, а сохранение свойств — по реальному объёму.
    near(remaining,expected or .225,'Native quarter drink volume',expected and .00001 or .001)
    liquid(item,'HCREnergy',remaining,1000*remaining,.8*remaining/.3,'fresh')
    return 1-remaining/.3
end
local function observe(f,p,player,owner)
    local inv,common=player:getInventory(),shared(f):getContainer()
    assert(not player:isDead(),'Private test character died during '..p)
    if owner and (p=='initial' or p=='make' or p=='share_make' or p=='cups' or p=='share_cups'
        or p=='bottles' or p=='share_bottles' or p=='drink' or p=='share_drink' or p=='med_old' or p=='med_repeat') then
        local unused=byId(inv,f.ginsengId)
        assert(unused:getModData().HCRDrinksMPTag==f.run..'-ginseng','Unused medicine changed before '..p)
    end
    if owner then assert(not player:isGodMod() and not player:isUnlimitedEndurance(),'Admin flags overwrite physiological effects') end
    if isClient() and M.localState and M.localState.bagRef then
        assert(shared(f)==M.localState.bagRef and common==M.localState.containerRef,'Storage replaced queued destination')
    end
    local function get(label) return (assert(find(inv,f.run..'-'..label),'Missing fixture '..label)) end
    if p=='initial' and owner then
        liquid(get('milk'),'HCRMilkSoy',1,1000,.8,'stale')
        liquid(get('energy'),'HCREnergy',.3,300,.8,'fresh')
    elseif p=='make' and owner then
        checkGroup(inv,f,'Base.Pot',1,'HCREggnog',.35,f.makeCalories,.205,'stale',f.makeAlcohol)
        liquid(get('milk'),'HCRMilkSoy',.9,900,.72,'stale')
        near(Q.rawAmount(Q.fluid(get('whiskey'))),.75,'Remaining whiskey')
        assert(not find(inv,f.run..'-egg') and not find(inv,f.run..'-pot'),'Consumed ingredient survived')
    elseif p=='cups' and owner then
        checkGroup(inv,f,'Base.Mugl',4,'HCREggnog',.2,f.cupCalories,.06,'rotten')
        liquid(get('cupSource'),'HCREggnog',.7,700,.14,'rotten')
        assert(not find(inv,f.run..'-chocolate'),'Chocolate survived')
        for i=1,4 do assert(not find(inv,f.run..'-mug'..i),'Consumed mug survived') end
    elseif p=='bottles' and owner then
        checkGroup(inv,f,'Hydrocraft.HCMonkeyTailbottleFluid',2,'HCRMonkeyTail',1,1000,.2,'stale')
        near(Q.rawAmount(Q.fluid(get('bottleA')))+Q.rawAmount(Q.fluid(get('bottleB'))),.25,'Pooled remainder')
        local calories,dose=0,0
        for _,name in ipairs({'bottleA','bottleB'}) do local item=get(name)
            if not Q.fluid(item):isEmpty() then
                local value=raw(item);calories=calories+L.budget(value,'calories');dose=dose+L.budget(value,'poisonPower')
                assert(L.quality(value)=='stale' and L.matches(value,Q.amounts(Q.fluid(item))),'Pooled donor quality/composition')
            else assert(not item:getModData()[Q.key],'Empty donor retained a ledger') end
        end
        near(calories,250,'Pooled calorie remainder');near(dose,.05,'Pooled poison remainder')
        for i=1,2 do assert(not find(inv,f.run..'-bottle'..i),'Consumed bottle survived') end
    elseif p=='drink' and owner then
        local item=get('energy');assert(item:getID()==f.energyId,'Drink changed ID')
        local fraction=energy(item)
        if isClient() then
            assert(M.localState.effectsReceived,'Owner has not observed native effect packets')
        else
            -- Изменение от каждого глотка измерено до/после native вызова:
            -- расход калорий между кадрами не входит в эффект напитка.
            -- Клиент отдельно наблюдает итоговые native packets, без записи stats.
            near(f.drinkTrace.calories,300*fraction,'Server calorie gain from native drink')
        end
    end
    local medicine=medicines[p]
    if medicine and owner then
        local item=find(inv,f.run..'-'..medicine.label)
        if medicine.remaining then
            assert(item and item:getID()==f.ginsengId,'Partial medicine disappeared/changed ID')
            near(item:getEnduranceChangeUnmodified(),.1125,'Remaining ginseng dose')
        else assert(not item,'Consumed medicine survived') end
        assert(#outputs(inv,f,'Hydrocraft.HCGlasstesttubecork')==medicine.tubes,'Wrong returned tube count')
        if p=='adrenaline' then assert(#outputs(inv,f,'Hydrocraft.HCEyedropperbottle')==1,'Wrong adrenaline bottle count') end
        if isClient() then
            assert(M.localState.effectsReceived,'Owner has not observed native medicine packets')
            if p=='med_repeat' then
                -- Проверяем до ACK, а не только в первом кадре после seeded 40:
                -- поздний ошибочный пакет не должен скрыться за effectsReceived.
                local stats=player:getStats()
                assert(stats:get(CharacterStat.FOOD_SICKNESS)>=39.5
                    and stats:get(CharacterStat.POISON)>=39.5,'Late repeat healing on client')
            end
        else
            local trace=assert(f.medTraces[p])
            assert(trace.calls==1,'Medicine action duplicated '..p)
            for _,key in ipairs({'sickness','poison','endurance','stress'}) do
                if medicine[key] then near(trace[key],medicine[key],'Server medicine '..p..' '..key) end
            end
        end
    end
    local index=0;for i,name in ipairs(phases) do if name==p then index=i end end
    if p=='cold' then index=#phases end
    if index>=3 then
        local rows=checkGroup(common,f,'Base.Pot',1,'HCREggnog',.35,f.makeCalories,.205,'stale',f.makeAlcohol)
        assert(rows[1]:getID()==f.makeId,'Shared pot ID')
    end
    if index>=5 then
        local rows=checkGroup(common,f,'Base.Mugl',4,'HCREggnog',.2,f.cupCalories,.06,'rotten')
        for i,item in ipairs(rows) do assert(item:getID()==f.cupIds[i],'Shared mug ID') end
    end
    if index>=7 then
        local rows=checkGroup(common,f,'Hydrocraft.HCMonkeyTailbottleFluid',2,'HCRMonkeyTail',1,1000,.2,'stale')
        for i,item in ipairs(rows) do assert(item:getID()==f.bottleIds[i],'Shared bottle ID') end
    end
    if index>=9 then energy(byId(common,f.energyId),assert(f.energyRemaining)) end
    local function diluted(container)
        local rows=checkGroup(container,f,'Base.Milk',1,'HCRMilk',.85,173,.625,'rotten')
        local tainted=false;for _,lot in ipairs(raw(rows[1]).lots) do tainted=tainted or lot.food.tainted end
        assert(tainted,'Diluted milk lost taint')
        if f.dilutedId then assert(rows[1]:getID()==f.dilutedId,'Diluted carton identity') end
    end
    if p=='dilute' and owner then
        diluted(inv)
        assert(not find(inv,f.run..'-concentrate') and not find(inv,f.run..'-carton'),'Dilution inputs survived')
        assert(#outputs(inv,f,'Hydrocraft.HCEvaporatedmilkopenempty')==1,'Dilution empty tin count')
        near(Q.rawAmount(Q.fluid(get('dilutionWater'))),.3,'Dilution water remainder')
    end
    if p=='share_dilute' or p=='verify' or p=='cold' then diluted(common) end
    if p=='verify' or p=='cold' then
        for name,spec in pairs(medicines) do
            local trace=assert(f.medTraces[name],'Missing server medicine trace '..name)
            assert(trace.calls==1,'Medicine action duplicated '..name)
            for _,key in ipairs({'sickness','poison','endurance','stress'}) do
                if spec[key] then near(trace[key],spec[key],'Server medicine '..name..' '..key) end
            end
        end
        for kind,ids in pairs(f.medReturnIds) do
            local rows=outputs(common,f,kind);assert(#rows==#ids,'Returned medicine vessel count')
            for i,item in ipairs(rows) do assert(item:getID()==ids[i],'Returned medicine vessel identity') end
            if owner then assert(#outputs(inv,f,kind)==0,'Returned medicine vessel duplicated in owner') end
        end
        assert(#outputs(common,f,f.energyType)==0,'New energy can duplicated in shared bag')
        assert(f.drinkTrace and f.drinkTrace.calls>0,'No server native drink trace')
        local fraction=1-f.energyRemaining/.3
        near(f.drinkTrace.endurance,.1*fraction,'Server endurance applied once')
        near(f.drinkTrace.fatigue,-.15*fraction,'Server fatigue applied once')
        near(f.drinkTrace.poison,.8*fraction,'Server poison applied once')
        near(f.drinkTrace.calories,300*fraction,'Server calories applied once')
        if owner then
            assert(#outputs(inv,f,'Base.Milk')==0,'Diluted carton duplicated')
            assert(#outputs(inv,f,'Base.Mugl')==0 and #outputs(inv,f,'Base.Pot')==0
                and #outputs(inv,f,'Hydrocraft.HCMonkeyTailbottleFluid')==0,'Transferred output duplicated')
            assert(not find(inv,f.run..'-energy'),'Transferred can duplicated')
            assert(#outputs(inv,f,f.energyType)==0,'New energy can duplicated in owner inventory')
            local items=inv:getItems();for i=0,items:size()-1 do assert(items:get(i):getID()~=f.energyId,'Original energy can remained in owner inventory') end
        end
        if p=='cold' then local role=isServer() and 'server' or owner and 'owner' or 'observer'
            assert(f.boots[role]~=HCRLabDrinksMPBoot,'Process was not restarted '..role)
        end
    end
end
local function broadcast(command,args)
    args.drinks=true;for _,player in pairs(M.state.players) do sendServerCommand(player,'HCRLabTwo',command,args) end
end
local function phase(index)
    local state=M.state;state.index=index
    if state.cold then state.phase=index==1 and 'cold' or nil else state.phase=phases[index] end
    state.acks={};state.since=getTimestampMs()
    if not state.phase then
        state.complete=true
        if not state.cold then local bag=shared(state.f);bag:getModData().HCRDrinksMPSaved=state.f
            bag:transmitModData()
        end
        broadcast('complete',{cold=state.cold});log('SERVER PASS '..(state.cold and 'cold reload' or 'all '..#phases..' phases'));return
    end
    if state.phase=='drink' then
        local stats=state.players.owner:getStats()
        state.players.owner:getNutrition():setCalories(0)
        stats:set(CharacterStat.HUNGER,.8);stats:set(CharacterStat.ENDURANCE,.2)
        stats:set(CharacterStat.FATIGUE,.7);stats:set(CharacterStat.POISON,0)
        state.f.drinkTrace={calls=0,endurance=0,fatigue=0,poison=0,calories=0}
    end
    if medicines[state.phase] then
        seedMedicine(state.players.owner,medicines[state.phase])
        state.f.medTraces[state.phase]={calls=0,endurance=0,stress=0,sickness=0,poison=0}
    elseif state.phase=='share_med' then
        state.players.owner:getStats():set(CharacterStat.POISON,0)
        state.players.owner:getStats():set(CharacterStat.FOOD_SICKNESS,0)
    end
    broadcast('phase',{f=state.f,phase=state.phase});log('SERVER phase '..state.phase)
end
function M.start(cold)
    assert(isServer());local pair={};local all=getOnlinePlayers()
    for i=0,all:size()-1 do local p=all:get(i)
        if p:getUsername()=='HCRLabOwner' then pair.owner=p elseif p:getUsername()=='HCRLabObserver' then pair.observer=p end
    end
    assert(pair.owner and pair.observer,'Both clients required');local player=pair.owner;local square=player:getSquare()
    player:setGodMod(false);player:setUnlimitedEndurance(false)
    assert(math.abs(player:getX()-pair.observer:getX())<5 and math.abs(player:getY()-pair.observer:getY())<5,'Players apart')
    if cold then
        local saved=M.savedNearby(player)
        M.state={f=assert(saved,'No saved run'),players=pair,cold=true};phase(1);return
    end
    assert(not HCRLabDrinksMedicineUsed,'Restart private server before repeating native medicine cooldown test')
    assert(getServerOptions():getBoolean('SleepAllowed') and getServerOptions():getBoolean('SleepNeeded'),
        'Private Energy effect test needs native fatigue enabled (SleepAllowed/SleepNeeded)')
    healthyFixture(player)
    local run=tostring(getTimestampMs());local f={run=run,x=square:getX(),y=square:getY(),z=square:getZ(),previous={},medTraces={},boots={server=HCRLabDrinksMPBoot}}
    -- Неудачные прогоны не должны занимать штатный лимит 50 кг на клетке.
    -- Завершённые cold fixtures и любые чужие предметы остаются на месте.
    local world=square:getWorldObjects();local obsolete={}
    for i=0,world:size()-1 do local object=world:get(i);local item=object:getItem()
        if item and item:getModData().HCRDrinksMPTag and not item:getModData().HCRDrinksMPSaved then
            obsolete[#obsolete+1]=object
        end
    end
    for _,object in ipairs(obsolete) do square:transmitRemoveItemFromSquare(object) end
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    player:setGodMod(false);player:setUnlimitedEndurance(false)
    for _,name in ipairs({'Make Eggnog Pot','Make Eggnog Cuppa','Make Monkey Tail Bottle'}) do player:learnRecipe(name) end
    local surfaceSquare=assert(getCell():getGridSquare(f.x+1,f.y,f.z))
    local surface;local objects=surfaceSquare:getObjects()
    for i=0,objects:size()-1 do local object=objects:get(i)
        if object:getSpriteName()=='carpentry_01_60' then surface=object;break end
    end
    if not surface then
        surface=IsoObject.new(getCell(),surfaceSquare,'carpentry_01_60')
        surfaceSquare:AddTileObject(surface);surface:transmitCompleteItemToClients()
    end
    local inv=player:getInventory();local bag=tag(IsoObject.new(getCell(),square,'carpentry_01_16'),run)
    local common=ItemContainer.new('crate',square,bag);common:setCapacity(100);bag:setContainer(common)
    square:AddTileObject(bag);bag:transmitCompleteItemToClients()
    local function add(kind,label,prepare)
        local item=instanceItem(kind);if item:IsFood() then item:setAge(0) end
        if prepare then prepare(item) end;tag(item,run..'-'..label);inv:AddItem(item);sendAddItemToContainer(inv,item);return item
    end
    add('Base.HandTorch','light',function(item) item:setUsedDelta(1);item:setActivated(true) end)
    local function batch(kind,label,marker,litres,calories,dose,quality)
        return add(kind,label,function(item)
            local fluid=Q.fluid(item);fluid:Empty();fluid:addFluid(marker,litres)
            local food=instanceItem('Hydrocraft.HCRFluidSample');food:setCalories(calories);food:setHungChange(-.1)
            food:setBaseHunger(-.1);food:setOffAge(2);food:setOffAgeMax(4);food:setAge(quality=='rotten' and 5 or 3)
            food:setPoisonPower(0);local snapshot=HCRFluidEffects.snapshot(food);snapshot.poisonPower=dose
            Q.store(item,fluid,L.batch(marker,litres,snapshot,getGameTime():getWorldAgeHours()))
        end)
    end
    batch('Base.Milk','milk','HCRMilkSoy',1,1000,.8,'stale')
    add('Hydrocraft.HCEvaporatedmilkopen','concentrate',function(item)
        item:setHungChange(item:getBaseHunger()*.5);item:setCalories(173)
        F.store(item,.625);F.setQuality(item,'rotten');F.setTainted(item)
    end)
    add('Hydrocraft.HCMilkempty','carton')
    add('Base.WaterBottle','dilutionWater',function(item) Q.fluid(item):Empty();Q.fluid(item):addFluid('Water',1) end)
    local whiskey=add('Base.Whiskey','whiskey')
    local egg=add('Base.Egg','egg',function(i) F.store(i,.125) end)
    f.makeCalories=100+Q.fluid(whiskey):getProperties():getCalories()*.25+egg:getCalories()
    f.makeAlcohol=Q.fluid(whiskey):getProperties():getAlcohol()*.25
    add('Base.Pot','pot',function(i) Q.fluid(i):Empty() end)
    batch('Base.Pot','cupSource','HCREggnog',1.5,1500,.3,'rotten')
    local chocolate=add('Base.Chocolate','chocolate',function(i) F.store(i,.08) end)
    f.cupCalories=(800+chocolate:getCalories())/4
    for i=1,4 do add('Base.Mugl','mug'..i,function(item) Q.fluid(item):Empty() end) end
    batch('Base.Pot','bottleA','HCRMonkeyTail',1.5,1500,.3,'stale')
    batch('Base.Pot','bottleB','HCRMonkeyTail',.75,750,.15,'stale')
    for i=1,2 do add('Base.Whiskey','bottle'..i,function(item) Q.fluid(item):Empty() end) end
    local old=instanceItem('Hydrocraft.HCEnergydrink');old:setAge(0);F.store(old,.8)
    local energy=assert(HCRItemMigrations.newReplacement(old));tag(energy,run..'-energy');inv:AddItem(energy);sendAddItemToContainer(inv,energy)
    f.energyId=energy:getID();f.energyType=energy:getFullType()
    add('Hydrocraft.HCLemongrassExtract','lemonOld',function(item) item:multiplyFoodValues(.5);item:setFoodSicknessChange(0) end)
    add('Hydrocraft.HCLemongrassExtract','lemonNew')
    f.ginsengId=add('Hydrocraft.HCGinsengExtract','ginseng'):getID()
    add('Hydrocraft.HCAdrenalin','adrenaline')
    local items=inv:getItems();for i=0,items:size()-1 do f.previous[tostring(items:get(i):getID())]=true end
    M.state={f=f,players=pair};phase(1)
end
function M.server(command,player,args)
    local state=M.state;if not state or state.failed or state.complete or args.run~=state.f.run then return end
    if command=='fail' then state.failed=true;log('SERVER FAIL '..tostring(args.reason));return end
    if command~='ack' or args.phase~=state.phase then return end
    local role=player==state.players.owner and 'owner' or player==state.players.observer and 'observer' or nil
    if not role then return end;state.acks[role]=true
    if state.phase=='initial' then state.f.boots[role]=args.boot end
    if state.acks.owner and state.acks.observer then
        local ok,reason=pcall(observe,state.f,state.phase,state.players.owner,true)
        if not ok then log('SERVER awaiting '..tostring(reason));return end
        local kinds={make={'makeId','Base.Pot'},cups={'cupIds','Base.Mugl'},bottles={'bottleIds','Hydrocraft.HCMonkeyTailbottleFluid'}}
        local spec=kinds[state.phase]
        if spec then local rows=outputs(state.players.owner:getInventory(),state.f,spec[2]);local ids={}
            for _,item in ipairs(rows) do ids[#ids+1]=item:getID() end;state.f[spec[1]]=state.phase=='make' and ids[1] or ids
        end
        if state.phase=='dilute' then state.f.dilutedId=outputs(state.players.owner:getInventory(),state.f,'Base.Milk')[1]:getID() end
        if state.phase=='drink' then
            state.f.energyRemaining=Q.rawAmount(Q.fluid(byId(state.players.owner:getInventory(),state.f.energyId)))
        end
        if state.phase=='adrenaline' then
            state.f.medReturnIds={}
            for _,kind in ipairs({'Hydrocraft.HCGlasstesttubecork','Hydrocraft.HCEyedropperbottle'}) do
                local ids={};for _,item in ipairs(outputs(state.players.owner:getInventory(),state.f,kind)) do ids[#ids+1]=item:getID() end
                state.f.medReturnIds[kind]=ids
            end
        end
        phase(state.index+1)
    end
end
function M.client(command,args)
    if command=='phase' then M.localState={f=args.f,phase=args.phase,ticks=0,stable=0};log('CLIENT phase '..args.phase)
    elseif command=='effect' then
        local state=M.localState
        if state and state.f.run==args.run and state.phase==args.phase then state.expectedEffects=args.values end
    elseif command=='complete' then M.localState=nil;log('CLIENT PASS '..(args.cold and 'cold reload' or 'all '..#phases..' phases')) end
end
local statKeys={endurance=CharacterStat.ENDURANCE,fatigue=CharacterStat.FATIGUE,
    poison=CharacterStat.POISON,sickness=CharacterStat.FOOD_SICKNESS,stress=CharacterStat.STRESS}
local function effectValues(player,keys)
    local values={};for key in pairs(keys) do
        if key=='calories' then values[key]=player:getNutrition():getCalories()
        elseif statKeys[key] then values[key]=player:getStats():get(statKeys[key]) end
    end
    return values
end
local function reportEffects(player,keys)
    local state=HCRLabDrinksMP.state
    sendServerCommand(player,'HCRLabTwo','effect',{drinks=true,run=state.f.run,phase=state.phase,values=effectValues(player,keys)})
end
local function observeEffects(state,player)
    if not state.expectedEffects or state.effectsReceived then return end
    local actual=effectValues(player,state.expectedEffects)
    if state.phase=='med_repeat' then
        -- Cooldown ничего не изменяет, поэтому немедленного native пакета нет.
        -- Клиент не должен получить повторное лечение: исходные 40 остаются
        -- около 40 или растут от яда. Отдельный server trace требует ровно 0.
        if actual.sickness<39.5 or actual.poison<39.5 then
            state.effectsPending='Unexpected repeat healing '..actual.sickness..' / '..actual.poison
            return
        end
        state.effectsReceived=true;log('CLIENT observed native cooldown without repeat healing');return
    end
    for key,value in pairs(state.expectedEffects) do
        -- При cooldown лекарство ничего не меняет и отдельного пакета нет:
        -- обычное серверное обновление может уже содержать следующий tick.
        -- Для малой дозы Energy сохраняется более строгая граница 0,01.
        local tolerance=key=='calories' and 2 or key=='sickness' and .15
            or key=='poison' and (medicines[state.phase] and .15 or .01) or .003
        if math.abs(actual[key]-value)>tolerance then state.effectsPending=key..' '..actual[key]..' / '..value;return end
    end
    state.effectsReceived=true;log('CLIENT observed native effects '..state.phase)
end
local function craft(player,common,name,groups)
    player:learnRecipe(name);local recipe;local recipes=getScriptManager():getAllCraftRecipes()
    for i=0,recipes:size()-1 do if recipes:get(i):getName()==name then recipe=recipes:get(i);break end end
    local surface=assert(ISEntityUI.FindCraftSurface(player,1),'Native work surface missing')
    local logic=HandcraftLogic.new(player,nil,surface)
    local containers=ArrayList.new();containers:add(player:getInventory());containers:add(common)
    logic:setContainers(containers);logic:setRecipe(assert(recipe));logic:setManualSelectInputs(true);logic:clearManualInputs()
    for slot,group in ipairs(groups) do local items=ArrayList.new();for _,item in ipairs(group) do items:add(item) end
        assert(logic:setManualInputsFor(recipe:getInputs():get(slot-1),items),'Manual slot '..slot)
    end
    if not logic:canPerformCurrentRecipe() then
        local light=player:getSecondaryHandItem()
        log('Craft light dark='..tostring(player:tooDarkToRead())..' secondary='..tostring(light)
            ..' emitting='..tostring(light and light:isEmittingLight()))
        log('Craft diagnostics '..name..' valid='..tostring(logic:isValidRecipeForCharacter(recipe))
            ..' range='..tostring(logic:isCharacterInRangeOfWorkbench())..' inputs='..tostring(logic:areAllInputItemsSatisfied()))
        log('Craft stages consume='..tostring(logic:getRecipeData():canConsumeInputs(logic:getSourceResources()))
            ..' outputs='..tostring(logic:getRecipeData():createRecipeOutputs(true,nil,player)))
        for slot,group in ipairs(groups) do for _,item in ipairs(group) do
            local input=recipe:getInputs():get(slot-1)
            log('Slot '..slot..' '..item:getFullType()..' canUse='..tostring(input:canUseItem(item,player))
                ..' uses='..tostring(item:getCurrentUses())..' fluid='..tostring(Q.rawAmount(Q.fluid(item)))
                ..' cached='..tostring(logic:getRecipeData():getDataForInputScript(input):isCachedCanConsume())
                ..' routine='..tostring(input:doesItemPassRoutineStatusTests(item,player))
                ..' food='..tostring(input:doesItemPassFoodAndCookingTests(item)))
        end end
        error('Native craft unavailable '..name)
    end
    ISTimedActionQueue.add(ISHandcraftAction.FromLogic(logic))
end
M.craft=craft
local function act(state,player)
    local f,p=state.f,state.phase;local inv=player:getInventory();local common=shared(f):getContainer()
    local function get(label) return (assert(find(inv,f.run..'-'..label),'Missing fixture '..label)) end
    local function transfer(id) local item=byId(inv,id);ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,inv,common)) end
    player:setUnlimitedCarry(true);player:setTimedActionInstantCheat(true)
    player:setGodMod(false);player:setUnlimitedEndurance(false)
    if p=='initial' then
        healthyFixture(player)
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player,get('light'),1,false,false))
    end
    if p=='make' then craft(player,common,'Make Eggnog Pot',{{get('milk')},{get('egg')},{get('whiskey')},{get('pot')}})
    elseif p=='dilute' then craft(player,common,'Dilute Evaporated Milk',{{get('concentrate')},{get('dilutionWater')},{get('carton')}})
    elseif p=='share_dilute' then transfer(f.dilutedId)
    elseif p=='share_make' then transfer(f.makeId)
    elseif p=='cups' then craft(player,common,'Make Eggnog Cuppa',{{get('cupSource')},{get('chocolate')},{get('mug1'),get('mug2'),get('mug3'),get('mug4')}})
    elseif p=='share_cups' then
        state.bagRef=shared(f);state.containerRef=common
        for _,id in ipairs(f.cupIds) do transfer(id) end
    elseif p=='bottles' then craft(player,common,'Make Monkey Tail Bottle',{{get('bottleA'),get('bottleB')},{get('bottle1'),get('bottle2')}})
    elseif p=='share_bottles' then
        state.bagRef=shared(f);state.containerRef=common
        for _,id in ipairs(f.bottleIds) do transfer(id) end
    elseif p=='drink' then
        local stats=player:getStats();stats:set(CharacterStat.HUNGER,.8);stats:set(CharacterStat.ENDURANCE,.2)
        stats:set(CharacterStat.FATIGUE,.7);stats:set(CharacterStat.POISON,0);player:getNutrition():setCalories(0)
        ISTimedActionQueue.add(ISDrinkFluidAction:new(player,get('energy'),.25))
    elseif p=='share_drink' then transfer(f.energyId)
    elseif medicines[p] then
        local spec=medicines[p];seedMedicine(player,spec)
        ISTimedActionQueue.add(ISEatFoodAction:new(player,get(spec.label),spec.fraction))
    elseif p=='share_med' then
        player:getStats():set(CharacterStat.POISON,0);player:getStats():set(CharacterStat.FOOD_SICKNESS,0)
        state.transfers={};for _,ids in pairs(f.medReturnIds) do for _,id in ipairs(ids) do state.transfers[#state.transfers+1]=id end end
    end
    state.acted=true
end
function M.tick()
    if isServer() then local state=M.state
        if state and not state.failed and not state.complete and getTimestampMs()-state.since>180000 then state.failed=true;log('SERVER FAIL timeout '..state.phase) end
        return
    end
    local state=M.localState;if not state or state.failed or not getPlayer() then return end
    if getPlayer():getUsername()=='HCRLabOwner' then observeEffects(state,getPlayer()) end
    state.ticks=state.ticks+1;if state.ticks%30~=0 then return end
    local player=getPlayer();local owner=player:getUsername()=='HCRLabOwner'
    if owner and not state.acted then local ok,reason=pcall(act,state,player)
        if not ok then state.failed=true;sendClientCommand(player,'HCRLabTwo','fail',{drinks=true,run=state.f.run,reason=tostring(reason)});log('CLIENT FAIL '..tostring(reason));return end
    end
    if owner and ISTimedActionQueue.isPlayerDoingAction(player) then state.stable=0;return end
    if owner and (state.phase=='drink' or medicines[state.phase]) and not state.firstStats then
        state.firstStats=true;local stats=player:getStats()
        log('Owner native action finished '..state.phase..' calories='..player:getNutrition():getCalories()
            ..' endurance='..stats:get(CharacterStat.ENDURANCE)..' fatigue='..stats:get(CharacterStat.FATIGUE)
            ..' poison='..stats:get(CharacterStat.POISON)..' sickness='..stats:get(CharacterStat.FOOD_SICKNESS)
            ..' stress='..stats:get(CharacterStat.STRESS))
    end
    if owner and state.transfers then
        local common=shared(state.f):getContainer()
        if state.pendingTransfer then
            local arrived=false;local items=common:getItems()
            for i=0,items:size()-1 do if items:get(i):getID()==state.pendingTransfer then arrived=true end end
            if not arrived then
                if state.ticks%600==0 then log('CLIENT awaiting native transfer '..state.pendingTransfer) end
                return
            end
            state.pendingTransfer=nil
        end
        if #state.transfers>0 then
            local id=table.remove(state.transfers,1);local item=byId(player:getInventory(),id)
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player,item,player:getInventory(),common))
            state.pendingTransfer=id;state.stable=0;return
        end
        state.transfers=nil
    end
    local pending={make='Base.Pot',cups='Base.Mugl',bottles='Hydrocraft.HCMonkeyTailbottleFluid',dilute='Base.Milk'}
    if owner and pending[state.phase] and #outputs(player:getInventory(),state.f,pending[state.phase])==0 then
        if state.ticks%600==0 then log('CLIENT awaiting native output '..state.phase) end
        state.stable=0;return
    end
    local ok,reason=pcall(observe,state.f,state.phase,player,owner);state.stable=ok and state.stable+30 or 0
    if state.stable>=120 and state.stable%120==0 then sendClientCommand(player,'HCRLabTwo','ack',{drinks=true,run=state.f.run,phase=state.phase,boot=HCRLabDrinksMPBoot})
        log('CLIENT independently observed '..state.phase)
    elseif state.ticks%600==0 or (owner and state.firstStats and state.ticks<=360 and not ok) then
        log('CLIENT awaiting '..state.phase..' '..tostring(reason)..' '..tostring(state.effectsPending))
    end
end
do
    local native=HCRLabDrinksHooks.eat
    ISEatFoodAction.complete=function(self,...)
        local state=HCRLabDrinksMP.state;local trace=isServer() and state and not state.complete and state.f.medTraces[state.phase]
        if not trace or not self.item:getModData().HCRDrinksMPTag then return native(self,...) end
        if state.phase=='med_old' then HCRLabDrinksMedicineUsed=true end
        local stats=self.character:getStats();local keys={sickness=CharacterStat.FOOD_SICKNESS,poison=CharacterStat.POISON,endurance=CharacterStat.ENDURANCE,stress=CharacterStat.STRESS}
        local before={};for key,stat in pairs(keys) do before[key]=stats:get(stat) end
        local result=native(self,...);trace.calls=trace.calls+1
        for key,stat in pairs(keys) do trace[key]=trace[key]+stats:get(stat)-before[key] end
        reportEffects(self.character,medicines[state.phase])
        return result
    end
end
do
    local native=HCRLabDrinksHooks.drinkComplete
    ISDrinkFluidAction.complete=function(self,...)
        local result=native(self,...)
        local state=HCRLabDrinksMP.state
        if isServer() and state and state.phase=='drink' and self.item:getID()==state.f.energyId then
            reportEffects(self.character,{calories=true,endurance=true,fatigue=true,poison=true})
        end
        return result
    end
end
do
    local native=HCRLabDrinksHooks.drink
    ISDrinkFluidAction.updateEat=function(self,...)
        local state=HCRLabDrinksMP.state;local trace=isServer() and state and not state.complete
            and self.item:getID()==state.f.energyId and state.f.drinkTrace
        if not trace then return native(self,...) end
        local stats=self.character:getStats();local endurance=stats:get(CharacterStat.ENDURANCE)
        local fatigue,poison=stats:get(CharacterStat.FATIGUE),stats:get(CharacterStat.POISON)
        local calories=self.character:getNutrition():getCalories()
        local result=native(self,...);trace.calls=trace.calls+1
        trace.endurance=trace.endurance+stats:get(CharacterStat.ENDURANCE)-endurance
        trace.fatigue=trace.fatigue+stats:get(CharacterStat.FATIGUE)-fatigue
        trace.poison=trace.poison+stats:get(CharacterStat.POISON)-poison
        trace.calories=trace.calories+self.character:getNutrition():getCalories()-calories
        return result
    end
end
do
    local server,client,tick=HCRLabTwo.server,HCRLabTwo.client,HCRLabTwo.tick
    HCRLabTwo.server=function(command,player,args) if args.drinks then return M.server(command,player,args) end;return server(command,player,args) end
    HCRLabTwo.client=function(command,args) if args.drinks then return M.client(command,args) end;return client(command,args) end
    local ticks,last=0,nil
    HCRLabTwo.tick=function()
        tick();M.tick();ticks=ticks+1;if ticks%60~=0 then return end
        local reader=getFileReader('HCRLabDrinksMPCommand.txt',false);if not reader then return end
        local line=reader:readLine();reader:close();if not line or line==last then return end;last=line
        local sequence,command=line:match('^(%d+):([%w]+)$');if not command then return end
        local ok,reason=pcall(function() assert(command=='start' or command=='verify');M.start(command=='verify') end)
        log(sequence..':'..command..' '..(ok and 'PASS' or 'FAIL '..tostring(reason)))
    end
end
