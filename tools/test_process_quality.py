"""Poison and freshness survive non-Food cheese stages and their ageing clock."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text
from test_food_quality import MOCKS as QUALITY
from test_food_callbacks import MOCKS as FOOD

class ProcessQuality(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(QUALITY)
        self.lua.execute(read_text(LUA/'shared/HCR_FoodQuality.lua'))
        self.lua.execute(FOOD)
        self.lua.execute(read_text(LUA/'server/HCR_FoodBridge.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_FluidLedger.lua'))
        self.lua.execute('''
            now=0
            function getGameTime() return {getWorldAgeHours=function() return now end} end
            HCRFluidQuality={sync=function() end,syncStorage=function() end,age=function(item,ledger,hours)
                return HCRFluidLedger.advance(ledger,hours,function(a,b) return b-a end)
            end}
            function stage(kind)
                local item=tool();item.data={}
                function item:getFullType() return 'Hydrocraft.'..kind end
                function item:getModData() return self.data end
                return item
            end
            ISHandcraftAction={performRecipe=function() end}
            ISAddItemInRecipe={complete=function() end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_MashCatalog.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_ProcessQuality.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_FoodTransfers.lua'))

    def test_sixteen_curds_conserve_dose_and_do_not_poison_empty_vat(self):
        self.lua.execute('''
            source=stage('HCVatcheese')
            HCRProcessQuality.write(source,{dose=3.25,quality='rotten',detection=7},1,nil)
            outputs={}
            for i=1,16 do outputs[i]=stage('HCCheesecurd') end
            empty=tool();outputs[17]=empty
            d=data({input({source},1,true,false)},outputs)
            state=HCRFoodTransfers.captureCraft(d)
            HCRFoodTransfers.finishCreate(state,d,nil)
            total=0
            for i=1,16 do local s=HCRProcessQuality.read(outputs[i]);total=total+s.dose;assert(s.quality=='rotten') end
        ''')
        self.assertAlmostEqual(self.lua.globals().total,3.25)

    def test_processing_clock_cannot_restart_at_kneading(self):
        self.lua.execute('''
            source=stage('HCCheesecurd');target=stage('HCCurdkneaded')
            HCRProcessQuality.write(source,{dose=.875,quality='fresh',detection=-1},1,nil)
            now=9*24
            d=data({input({source},1,true,false)},{target})
            state=HCRFoodTransfers.captureCraft(d)
            HCRFoodTransfers.finishCreate(state,d,nil)
            now=11*24
        ''')
        self.assertEqual(self.lua.eval('HCRProcessQuality.read(target).quality'),'rotten')
        self.assertAlmostEqual(self.lua.eval('HCRProcessQuality.read(target).dose'),.875)

    def test_processing_to_food_splits_exact_dose_and_worst_freshness(self):
        self.lua.execute('''
            source=stage('HCCheeserackaged')
            HCRProcessQuality.write(source,{dose=.875,quality='stale',detection=4},1,nil)
            a=food(200,-.2,20);b=food(200,-.2,20)
            d=data({input({source},1,true,false)},{a,b})
            state=HCRFoodTransfers.captureCraft(d)
            HCRFoodTransfers.finishCreate(state,d,nil)
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(a)'),.4375)
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(a)'),'stale')
        self.assertEqual(self.lua.eval('a.calories'),200)

    def test_tainted_vinegar_survives_bottling_partial_use_and_food_output(self):
        self.lua.execute('''
            local state={dose=0,quality='fresh',detection=-1}
            local liquid=HCRFluidLedger.batch('HCRVinegar',20,{tainted=true,poisonPower=.875},0)
            HCRFoodTransfers.addFluids(state,{liquid})
            local bottle=stage('unused');bottle.getFullType=function() return 'Base.Vinegar2' end
            HCRProcessQuality.write(bottle,state,20,nil)
            local saved=HCRProcessQuality.read(bottle)
            assert(saved.tainted and saved.dose==.875/20)
            HCRProcessQuality.keep(bottle,saved,.5)
            assert(HCRProcessQuality.read(bottle).tainted)
            local dish=food(200,-.2,20)
            function dish:setTainted(value) self.tainted=value end
            local d=data({input({bottle},1,true,false)},{dish})
            local used=HCRFoodTransfers.captureCraft(d)
            HCRFoodTransfers.finishCreate(used,d,nil)
            assert(dish.tainted and HCRFoodQuality.dose(dish)==.875/40)
        ''')

    def test_bad_processing_metadata_is_rejected_before_output(self):
        self.lua.execute('''
            source=stage('HCVatcheese')
            source.data.HCRProcessQuality160={version=1,dose=1000001,quality='fresh'}
            d=data({input({source},1,true,false)},{})
            ok=pcall(HCRFoodTransfers.checkCraft,d,0)
        ''')
        self.assertFalse(self.lua.globals().ok)

    def test_checkpoint_keeps_cold_history_only_until_move_and_copies_metadata(self):
        self.lua.execute('''
            cold=true
            HCRFluidQuality.age=function(item,ledger,hours)
                local previous=ledger.storage and ledger.storage.cold
                if previous==nil then previous=cold end
                local result=HCRFluidLedger.advance(ledger,hours,function(a,b) return (b-a)*(previous and .2 or 1) end)
                result.storage={cold=cold,freezer=false,powered=true,temperature=cold and .2 or 1}
                return result
            end
            source=stage('HCCheesecurd')
            HCRProcessQuality.write(source,{dose=.875,quality='fresh',detection=-1},1,nil)
            previous=source.data.HCRProcessQuality160
            now=24;cold=false
            HCRProcessQuality.checkpoint(source)
            assert(source.data.HCRProcessQuality160~=previous)
            assert(previous.clock.storage.cold==true)
            now=11*24
        ''')
        self.assertEqual(self.lua.eval('HCRProcessQuality.read(source).quality'),'rotten')
        self.assertAlmostEqual(self.lua.eval('HCRProcessQuality.read(source).dose'),.875)

    def test_actual_waxed_cheddar_recipe_keeps_near_expiry_clock(self):
        self.lua.execute('''
            source=food(200,-.2,20);source.age=13;source.fresh=14;source.rotten=14;source.poison=0
            source.updateAge=function() end
            target=stage('HCCheeserackfullcheddarwaxed')
            local scripts={input({source},1,true,false)}
            d=data(scripts,{target})
            d.getRecipe=function() return {getInputs=function() return list(scripts) end,
                getName=function() return 'Put Cheese on Rack (Cheese Rack with Waxed Cheddar Cheese)' end} end
            state=HCRFoodTransfers.captureCraft(d)
            assert(state,'Untracked plain cheese still needs a clock')
            HCRFoodTransfers.finishCreate(state,d,nil)
            now=2*24
        ''')
        self.assertEqual(self.lua.eval('HCRProcessQuality.read(target).quality'),'rotten')
