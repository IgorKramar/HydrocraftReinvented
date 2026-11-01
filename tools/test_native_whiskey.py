"""Native Whiskey сохраняет свой состав, а нулевая партия — только качество."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, read_text
import test_process_quality as process
import test_fluid_boundaries as boundaries


class NativeWhiskey(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            function isClient() return false end
            function isServer() return false end
            function getGameTime() return {getWorldAgeHours=function() return 10 end} end
            HCRFluidQuality={};HCRFoodQuality={}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidLedger.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_FluidEffects.lua'))
        self.lua.execute('''
            function instanceItem(kind)
                local item={values={offAge=1e9,offAgeMax=1e9},IsFood=function() return true end,
                    getFullType=function() return kind end,setOnEat=function() end}
                for key,pair in pairs(HCRFluidEffects.fields) do
                    local name=key
                    item[pair[1]]=function(self)
                        local value=self.values[name]
                        if value~=nil then return value end
                        if name=='alcoholic' or name=='canBeFrozen' or name=='tainted'
                          or name=='cooked' or name=='burnt' or name=='frozen' or name=='dangerousUncooked' then return false end
                        return 0
                    end
                    item[pair[2]]=function(self,v) self.values[name]=v end
                end
                return item
            end
            function HCRFoodQuality.setQuality(item,state)
                item:setOffAge(1);item:setOffAgeMax(2)
                item:setAge(state=='rotten' and 3 or state=='stale' and 1.5 or 0)
            end
            function HCRFoodQuality.reconcile() end
            function HCRFoodQuality.active() return false end
            native={getProperties=function() return {getHungerChange=function() return -.4 end} end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_NativeWhiskey.lua'))

    def test_native_whiskey_has_no_duplicate_food_or_alcohol_budget(self):
        self.lua.execute('''
            ledger=HCRNativeWhiskey.ledger(native,{dose=3.75,quality='rotten',tainted=true},20)
            assert(ledger.lots[1].food.tainted)
            assert(HCRFluidLedger.matches(ledger,{}))
            assert(HCRFluidLedger.volume(ledger)==0)
            assert(ledger.lots[1].food.spoilHunger==-.4)
            for _,name in ipairs({'hungChange','thirstChange','calories','carbohydrates','proteins','lipids','nativeAlcohol','alcoholPower'}) do
                assert(HCRFluidLedger.budget(ledger,name)==0,name)
            end
            assert(HCRFluidLedger.quality(ledger)=='rotten')
            local left,moved=HCRFluidLedger.withdrawNative(ledger,{},{},.15)
            assert(math.abs(HCRFluidLedger.budget(left,'poisonPower')-.159375)<1e-10)
            assert(math.abs(HCRFluidLedger.budget(moved,'poisonPower')-.028125)<1e-10)
            local mixed=HCRFluidLedger.mix(HCRFluidLedger.empty(),moved)
            assert(mixed.lots[1].food.tainted)
            local _,drunk=HCRFluidLedger.split(mixed,.3,1.5)
            assert(math.abs(HCRFluidLedger.budget(drunk,'poisonPower')-.005625)<1e-10)
        ''')

    def test_spoilage_uses_hunger_without_feeding_or_repeating_native_alcohol(self):
        self.lua.execute('''
            local ledger=HCRNativeWhiskey.ledger(native,{dose=3.75,quality='rotten'},20)
            ledger.lots[1].units=.25
            local body={timer=123.75}
            function body:getHealthFromFoodTimer() return self.timer end
            function body:setHealthFromFoodTimer(v) self.timer=v end
            function body:JustAteFood(food,fraction)
                assert(not food:isAlcoholic() and food:getCalories()==0)
                assert(food:getAge()>=food:getOffAgeMax())
                spoil=5*math.abs(food:getHungChange()*10)*fraction
                self.timer=0
            end
            local player={getBodyDamage=function() return body end,
                getStats=function() return {add=function() error('Duplicate hunger/thirst') end} end,
                Eat=function() error('Duplicate native calories') end}
            function HCRFluidEffects.poison(_,dose) exact=(exact or 0)+dose end
            HCRFluidEffects.consume(player,HCRFluidEffects.prepare(ledger),false)
            assert(spoil==5 and body.timer==123.75)
            assert(math.abs(exact-.046875)<1e-10)
        ''')

    def test_native_sink_slots_preserve_existing_milk_rule(self):
        self.lua.execute('''
            local milk={slots={[0]=true},fluids={'HCRMilk'},nativeMilk=true}
            local rules={['Make Eggnog Pot']=milk}
            HCRNativeWhiskey.install(rules)
            assert(rules['Make Eggnog Pot'].inputs[0].nativeMilk)
            assert(rules['Make Eggnog Pot'].inputs[2].fluids[1]=='Whiskey')
            assert(not milk.inputs)
            assert(rules.MakeMolotovCocktail.inputs[0].nativeSink)
            assert(rules.DisinfectRag.inputs[1].nativeSink)
            assert(rules.DouseCottonInAlcohol.inputs[1].nativeSink)
            assert(not rules['Disinfect Diaper'].inputs[1].nativeSink)
        ''')


class NativeWhiskeyMedical(unittest.TestCase):
    setUp=boundaries.FluidBoundaries.setUp
    def test_disinfection_removes_quality_without_ingestion(self):
        self.lua.execute('''
            HCRNativeWhiskey={medical=function(i) return i==item end}
            function HCRFluidQuality.remove(i,player,operation,consume)
                assert(i==item and player==character and consume==false)
                removed=true;return operation()
            end
            calls=0
            local result=ISDisinfect.complete({alcohol=item,character=character})
            assert(result=='native' and calls==1 and removed)
        ''')


class MashQuality(unittest.TestCase):
    setUp=process.ProcessQuality.setUp
    def test_all_eight_distillery_barrels_keep_quality_into_twenty_food_bottles(self):
        self.lua.execute('''
            for _,kind in ipairs({'potato','blueagave','apple','peach','pumpkin','juniper','flour','corn'}) do
                local inputs={food(100,-.2,20),food(100,-.2,20),food(100,-.2,20)}
                for _,item in ipairs(inputs) do HCRFoodQuality.store(item,0) end
                HCRFoodQuality.setQuality(inputs[2],'rotten')
                HCRFoodQuality.store(inputs[2],.875)
                local barrel=stage('HCBarrel'..kind)
                local d=data({input(inputs,3,true,false)},{barrel})
                local state=HCRFoodTransfers.captureCraft(d)
                HCRFoodTransfers.finishCreate(state,d,nil)
                assert(HCRProcessQuality.read(barrel).quality=='rotten')
                assert(HCRProcessQuality.read(barrel).dose==.875)
                local bottles={};for i=1,20 do bottles[i]=food(395,-.2,20) end
                d=data({input({barrel},1,true,false)},bottles)
                state=HCRFoodTransfers.captureCraft(d)
                HCRFoodTransfers.finishCreate(state,d,nil)
                local total=0
                for _,bottle in ipairs(bottles) do
                    assert(HCRFoodQuality.quality(bottle)=='rotten' and bottle:getCalories()==395)
                    total=total+HCRFoodQuality.dose(bottle)
                end
                assert(math.abs(total-.875)<1e-10)
            end
        ''')


if __name__=='__main__': unittest.main()
