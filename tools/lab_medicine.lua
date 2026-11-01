-- Частная проверка дозированных лекарств через настоящие native действия.
require 'HCR_Medicine'
HCRLabMedicine={}
HCRLabMedicineBoot=HCRLabMedicineBoot or tostring(getTimestampMs())
local function near(a,b,label) assert(math.abs(a-b)<.0001,label..': '..tostring(a)..' / '..tostring(b)) end
local function eat(player,item,fraction)
    ISEatFoodAction.complete({item=item,character=player,percentage=fraction,useUtensil=false})
end
function HCRLabMedicine.run(player)
    assert(not isClient() and not isServer())
    local stats,inv=player:getStats(),player:getInventory()
    local oldStats={}
    for _,stat in ipairs({CharacterStat.FOOD_SICKNESS,CharacterStat.POISON,CharacterStat.ENDURANCE,CharacterStat.STRESS}) do oldStats[stat]=stats:get(stat) end
    local lemon=inv:AddItem('Hydrocraft.HCLemongrassExtract')
    assert(lemon:getFoodSicknessChange()==-50,'Native medicine field missing')
    stats:set(CharacterStat.FOOD_SICKNESS,80);stats:set(CharacterStat.POISON,80)
    local tubes=inv:getCountTypeRecurse('HCGlasstesttubecork')
    eat(player,lemon,1)
    near(stats:get(CharacterStat.FOOD_SICKNESS),30,'Native full healing')
    near(stats:get(CharacterStat.POISON),30,'Native poison reduction')
    assert(not lemon:getContainer() and inv:getCountTypeRecurse('HCGlasstesttubecork')==tubes+1)
    local second=inv:AddItem('Hydrocraft.HCLemongrassExtract');eat(player,second,1)
    near(stats:get(CharacterStat.FOOD_SICKNESS),30,'Native medicine cooldown')
    near(stats:get(CharacterStat.POISON),30,'Native poison cooldown')
    assert(inv:getCountTypeRecurse('HCGlasstesttubecork')==tubes+2)
    print('[HCRMedicine160] full -50 sickness/poison, native repeat cooldown, exactly one tube per dose PASS')
    local ginseng=inv:AddItem('Hydrocraft.HCGinsengExtract');local id=ginseng:getID()
    stats:set(CharacterStat.ENDURANCE,.2)
    assert(ginseng:getCurrentUses()==0,'Positive-hunger native fixture changed')
    eat(player,ginseng,.25)
    near(stats:get(CharacterStat.ENDURANCE),.2375,'Partial ginseng endurance')
    assert(ginseng:getID()==id and ginseng:getContainer()==inv and inv:getCountTypeRecurse('HCGlasstesttubecork')==tubes+2)
    eat(player,ginseng,1)
    near(stats:get(CharacterStat.ENDURANCE),.35,'Full ginseng endurance')
    assert(not ginseng:getContainer() and inv:getCountTypeRecurse('HCGlasstesttubecork')==tubes+3)
    local adrenaline=inv:AddItem('Hydrocraft.HCAdrenalin');local bottles=inv:getCountTypeRecurse('HCEyedropperbottle')
    stats:set(CharacterStat.ENDURANCE,.2);stats:set(CharacterStat.STRESS,.1)
    eat(player,adrenaline,.25)
    near(stats:get(CharacterStat.ENDURANCE),.3,'Adrenaline native last-dose snap')
    near(stats:get(CharacterStat.STRESS),.3,'Adrenaline original stress increase')
    assert(not adrenaline:getContainer() and inv:getCountTypeRecurse('HCEyedropperbottle')==bottles+1)
    print('[HCRMedicine160] partial/full ginseng despite zero uses and original adrenaline dose/stress/return PASS')
    local S=HCRLabSpirits
    for i=1,10 do if player:getPerkLevel(Perks.Doctor)>=1 then break end;player:getXp():AddXP(Perks.Doctor,1000) end
    for _,manual in ipairs({true,false}) do
        for _,case in ipairs({{'Ginseng','Base.Ginseng',7},{'Lemongrass','Base.LemonGrass',5}}) do
            local holder,bag=S.bag(player);local herbs={}
            for i=1,case[3] do local herb=bag:AddItem(case[2]);herb:setAge(0);herbs[#herbs+1]=herb end
            local tube=bag:AddItem('Hydrocraft.HCGlasstesttubecork');local juicer=bag:AddItem('Hydrocraft.HCJuicer')
            local output=S.craft(player,bag,'Create '..case[1]..' Extract',{{juicer},herbs,{tube}},manual)[1]
            assert(juicer:getContainer()==bag and not tube:getContainer())
            if case[1]=='Lemongrass' then assert(output:getFoodSicknessChange()==-50)
            else near(output:getEnduranceChangeUnmodified(),.15,'Crafted ginseng effect') end
            inv:Remove(holder)
        end
        local holder,bag=S.bag(player);local box=bag:AddItem('Hydrocraft.HCAdrenalinbox')
        local result=S.craft(player,bag,'Open Box of Adrenalin',{{box}},manual)
        assert(#result==4 and not box:getContainer())
        local bottle=bag:AddItem('Hydrocraft.HCAdrenalinbottle')
        for i=1,5 do
            local empty=bag:AddItem('Hydrocraft.HCSyringeempty')
            local filled=S.craft(player,bag,'Fill Syringe with Adrenalin',{{empty},{bottle}},manual)
            assert(#filled==1 and filled[1]:getFullType()=='Hydrocraft.HCSyringeadrenalin' and not empty:getContainer())
            if i<5 then assert(bottle:getCurrentUses()==5-i and bottle:getContainer()==bag)
            else assert(not bottle:getContainer()) end
        end
        assert(bag:getCountTypeRecurse('HCSyringeadrenalin')==5)
        inv:Remove(holder)
    end
    print('[HCRMedicine160] manual/auto extracts keep effects; boxes yield 4 doses; 5 syringe fills exhaust one bottle PASS')
    for _,kind in ipairs({'Hydrocraft.HCMouthwash','Hydrocraft.HCMouthwash2'}) do
        local item=inv:AddItem(kind);stats:set(CharacterStat.POISON,0);stats:set(CharacterStat.INTOXICATION,0)
        stats:set(CharacterStat.THIRST,.8);stats:set(CharacterStat.HUNGER,.5)
        eat(player,item,1)
        near(stats:get(CharacterStat.THIRST),.6,'Mouthwash original thirst')
        assert(stats:get(CharacterStat.POISON)>0 and stats:get(CharacterStat.INTOXICATION)>0 and not item:getContainer())
    end
    print('[HCRMedicine160] both household mouthwashes retain original poison, alcohol and thirst effects PASS')
    local holder,bag=S.bag(player);holder:setName('HCRLab old medicine cold fixture')
    local old=bag:AddItem('Hydrocraft.HCLemongrassExtract');old:multiplyFoodValues(.5);old:setFoodSicknessChange(0)
    old:setFavorite(true);old:setName('Legacy partial extract');old:setCustomName(true)
    assert(not old:getModData()[HCRMedicine.key])
    holder:getModData().HCRMedicineCold={boot=HCRLabMedicineBoot,id=old:getID(),calories=old:getCalories(),hunger=old:getHungChange()}
    for stat,value in pairs(oldStats) do stats:set(stat,value) end
    print('[HCRMedicine160] saved pre-fix half-dose fixture; cold verification pending')
end
function HCRLabMedicine.verify(player)
    local inv,stats=player:getInventory(),player:getStats();local item,row
    local items=inv:getItems()
    for i=0,items:size()-1 do
        local holder=items:get(i);local saved=holder:getModData().HCRMedicineCold
        if saved then assert(not row,'Ambiguous legacy fixture');row=saved;item=holder:getItemContainer():getItemById(saved.id) end
    end
    assert(row and item and row.boot~=HCRLabMedicineBoot,'Missing cold legacy fixture')
    assert(item:getFoodSicknessChange()==0 and not item:getModData()[HCRMedicine.key],'Not a serialized pre-fix dose')
    assert(item:isFavorite() and item:getName()=='Legacy partial extract')
    near(item:getCalories(),row.calories,'Old nutrition');near(item:getHungChange(),row.hunger,'Old hunger')
    local container=item:getContainer();local tubes=container:getCountTypeRecurse('HCGlasstesttubecork')
    stats:set(CharacterStat.FOOD_SICKNESS,80);stats:set(CharacterStat.POISON,80)
    eat(player,item,1)
    near(stats:get(CharacterStat.FOOD_SICKNESS),55,'Old half-dose healing')
    near(stats:get(CharacterStat.POISON),55,'Old half-dose poison reduction')
    assert(not item:getContainer() and container:getCountTypeRecurse('HCGlasstesttubecork')==tubes+1)
    stats:set(CharacterStat.FOOD_SICKNESS,0);stats:set(CharacterStat.POISON,0)
    print('[HCRMedicine160] COLD PASS serialized old half-dose repairs once, heals 25 and returns one tube')
    local sample=inv:AddItem('Hydrocraft.HCLemongrassExtract')
    getGameTime():setTimeOfDay(12)
    local ui=ISToolTipInv:new(sample);ui:initialise();ui:setCharacter(player)
    ui.followMouse=false;ui:setX(40);ui:setY(90);ui:addToUIManager();ui:setVisible(true)
    HCRLabMedicineTooltip=ui
end
