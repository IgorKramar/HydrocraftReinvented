"""Точная доза переживает partial Eat, native округление, callbacks и ошибки."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, read_text

MOCKS='''
function require() end
function isClient() return client or false end
function isServer() return false end
HCRFluidEffects={poisonCarrier=function() return {} end,
    poison=function(_,dose) consumed=(consumed or 0)+dose end}
ISEatFoodAction={complete=function(self) return self.operation() end,eat=function(self) return self.operation() end}
function fixture()
    local f={data={},power=0,age=0,fresh=3,rotten=7}
    function f:IsFood() return true end
    function f:getModData() return self.data end
    function f:getPoisonPower() return self.power end
    function f:setPoisonPower(n) self.power=math.floor(n) end
    function f:getPoisonDetectionLevel() return self.detection or -1 end
    function f:setPoisonDetectionLevel(n) self.detection=n end
    function f:getAge() return self.age end
    function f:setAge(n) self.age=n end
    function f:getOffAge() return self.fresh end
    function f:setOffAge(n) self.fresh=n end
    function f:getOffAgeMax() return self.rotten end
    function f:setOffAgeMax(n) self.rotten=n end
    function f:getOnEat() return self.onEat end
    function f:setOnEat(name) self.onEat=name end
    function f:isTainted() return self.tainted or false end
    function f:setTainted(value) self.tainted=value end
    function f:getFullType() return self.kind or 'Base.Salad' end
    function f:getReplaceOnCooked() return self.cookedTargets end
    function f:getCookingTime() return self.cookingTime or 0 end
    function f:isCookable() return self.cookable or false end
    function f:getMinutesToCook() return self.minutesToCook or 20 end
    return f
end
'''


class FoodQuality(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        self.lua.execute(read_text(LUA/'shared/HCR_FoodQuality.lua'))

    def test_taint_survives_native_save_which_omits_the_flag(self):
        self.lua.execute('''
            f=fixture();HCRFoodQuality.setTainted(f)
            f.tainted=false -- native save/load и полный сетевой снимок.
            client=true;HCRFoodQuality.reconcile(f)
            assert(f:isTainted() and HCRFoodQuality.tainted(f))
            assert(not f.data[HCRFoodQuality.taintKey].cleared)
        ''')

    def test_heating_clears_taint_without_clearing_poison_or_freshness(self):
        self.lua.execute('''
            f=fixture();HCRFoodQuality.setTainted(f)
            HCRFoodQuality.store(f,.625);HCRFoodQuality.setQuality(f,'rotten')
            f.cookingTime=10;HCRFoodQuality.reconcile(f);assert(f:isTainted())
            f.cookingTime=10.1;HCRFoodQuality.reconcile(f)
            assert(not f:isTainted() and f.data[HCRFoodQuality.taintKey].cleared)
            assert(HCRFoodQuality.dose(f)==.625 and HCRFoodQuality.quality(f)=='rotten')
            f.cookingTime=0;f.tainted=true;client=true;HCRFoodQuality.reconcile(f)
            assert(not f:isTainted()) -- старый native flag не отменяет очистку.
        ''')

    def test_already_cooked_contaminated_food_requires_new_cooking_progress(self):
        self.lua.execute('''
            f=fixture();f.cookable=true;f.cookingTime=30
            HCRFoodQuality.setTainted(f);f.tainted=false
            HCRFoodQuality.reconcile(f);assert(f:isTainted())
            f.cookingTime=30.1;HCRFoodQuality.reconcile(f);assert(not f:isTainted())
        ''')

    def test_native_cooked_replacement_clears_but_rotten_replacement_retains_taint(self):
        self.lua.execute('''
            f=fixture();f.kind='Hydrocraft.Raw';f.cookable=true;f.minutesToCook=6
            f.cookedTargets={size=function() return 1 end,get=function() return 'Cooked' end}
            HCRFoodQuality.setTainted(f)
            f.kind='Hydrocraft.Rotten';f.cookingTime=0;HCRFoodQuality.reconcile(f);assert(f:isTainted())
            f.kind='Hydrocraft.Cooked';HCRFoodQuality.reconcile(f);assert(not f:isTainted())
        ''')

    def test_full_bite_clears_taint_before_native_empty_container_copy(self):
        self.lua.execute('''
            f=fixture();HCRFoodQuality.setTainted(f)
            HCRFoodQuality.eat(f,{},function()
                HCRFoodQuality.OnEat(f,{},1)
                assert(f.data[HCRFoodQuality.taintKey]==nil)
            end)
        ''')

    def test_repeated_partial_bites_keep_fractional_dose(self):
        self.lua.execute('''
            food=fixture();HCRFoodQuality.store(food,.7)
            for i=1,100 do
                HCRFoodQuality.eat(food,{},function()
                    assert(food.power==0)
                    HCRFoodQuality.OnEat(food,{},.01)
                    food:setPoisonPower(food.power*.99)
                end)
            end
        ''')
        self.assertAlmostEqual(self.lua.globals().consumed+self.lua.eval('HCRFoodQuality.dose(food)'),.7)
        self.assertEqual(self.lua.globals().food.power,1)

    def test_actual_native_fraction_replaces_requested_fraction_and_chains_callback(self):
        self.lua.execute('''
            food=fixture();HCRFoodQuality.store(food,2.5)
            function previous(_,_,fraction) priorCalls=(priorCalls or 0)+1;priorFraction=fraction end
            food:setOnEat('previous')
            action={item=food,character={},operation=function()
                HCRFoodQuality.OnEat(food,{},1);return true
            end}
            result=ISEatFoodAction.complete(action)
        ''')
        self.assertTrue(self.lua.globals().result)
        self.assertEqual(self.lua.globals().consumed,2.5)
        self.assertEqual(self.lua.globals().priorCalls,1)
        self.assertEqual(self.lua.globals().food.onEat,'previous')
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(food)'),0)

    def test_failure_before_native_callback_restores_dose_and_handler(self):
        self.lua.execute('food=fixture();HCRFoodQuality.store(food,.125)')
        with self.assertRaises(Exception):
            self.lua.execute("HCRFoodQuality.eat(food,{},function() error('native failed') end)")
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(food)'),.125)
        self.assertIsNone(self.lua.globals().food.onEat)
        self.lua.execute('HCRFoodQuality.eat(food,{},function() HCRFoodQuality.OnEat(food,{},.5) end)')
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(food)'),.0625)

    def test_large_dose_uses_serializable_marker_without_losing_actual_value(self):
        self.lua.execute('food=fixture();HCRFoodQuality.store(food,1000.125)')
        self.assertEqual(self.lua.globals().food.power,127)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(food)'),1000.125)

    def test_client_does_not_apply_poison(self):
        self.lua.execute('''
            food=fixture();HCRFoodQuality.store(food,.25);client=true
            HCRFoodQuality.eat(food,{},function() calls=1 end)
        ''')
        self.assertEqual(self.lua.globals().calls,1)
        self.assertIsNone(self.lua.globals().consumed)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(food)'),.25)

    def test_new_food_full_snapshot_and_existing_food_stats_use_distinct_routes(self):
        self.lua.execute('''
            function isServer() return true end
            HCRQualitySync={bump=function() end}
            function instanceof(owner,kind) return owner.player and kind=='IsoPlayer' end
            local owner={player=true}
            local container={getCharacter=function() return owner end}
            local item=fixture()
            function item:getContainer() return container end
            function item:getWorldItem() return nil end
            function sendReplaceItemInContainer(where,before,after)
                assert(where==container and before==item and after==item)
                replacements=(replacements or 0)+1
            end
            function sendItemStats(value) assert(value==item);stats=(stats or 0)+1 end
            HCRFluidQuality={sync=function(value) assert(value==item);metadata=(metadata or 0)+1 end}
            HCRFoodQuality.fullSnapshot(item,owner)
            assert(replacements==1 and stats==nil and metadata==nil)
            HCRFoodQuality.sync(item,owner)
            assert(replacements==1 and stats==1 and metadata==1)
            local world={sendObjectChange=function(_,change) changes=(changes or 0)+1 end}
            function item:getWorldItem() return world end
            function item:getContainer() return nil end
            IsoObjectChange={SWAP_ITEM='swap'}
            HCRFoodQuality.fullSnapshot(item,owner)
            assert(changes==1 and replacements==1 and stats==1)
        ''')

    def test_unbounded_dose_is_rejected_before_eating(self):
        self.lua.execute('food=fixture()')
        for value in (float('nan'),float('inf'),1e20,-1):
            with self.assertRaises(Exception):
                self.lua.globals().HCRFoodQuality.store(self.lua.globals().food,value)
        self.assertIsNone(self.lua.globals().food.onEat)

    def test_native_condition_copy_does_not_share_later_dose_mutations(self):
        self.lua.execute('''
            source=fixture();HCRFoodQuality.store(source,.875)
            cooked=fixture()
            for key,value in pairs(source.data) do
                if key:sub(1,10)=='condition:' then cooked.data[key]=value end
            end
            HCRFoodQuality.store(cooked,.125)
        ''')
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(source)'),.875)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(cooked)'),.125)

    def test_final_bite_clears_poison_before_native_empty_dish_copy(self):
        self.lua.execute('''
            source=fixture();HCRFoodQuality.store(source,.875)
            HCRFoodQuality.eat(source,{},function()
                HCRFoodQuality.OnEat(source,{},1)
                empty=fixture()
                for key,value in pairs(source.data) do
                    if key:sub(1,10)=='condition:' then empty.data[key]=value end
                end
            end)
        ''')
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(empty)'),0)

    def test_native_replacement_marker_and_detection_are_restored_from_metadata(self):
        self.lua.execute('''
            source=fixture();source.detection=4;HCRFoodQuality.store(source,.875)
            cooked=fixture();cooked.data=source.data
            HCRFoodQuality.reconcile(cooked)
        ''')
        self.assertEqual(self.lua.globals().cooked.power,1)
        self.assertEqual(self.lua.globals().cooked.detection,4)

    def test_rotten_nonperishable_gets_serializable_floor_without_billion_day_age(self):
        self.lua.execute('''
            food=fixture();food.fresh=1000000000;food.rotten=1000000000;food.age=123
            HCRFoodQuality.setQuality(food,'rotten')
            assert(HCRFoodQuality.active(food))
            saved=food.data
            reloaded=fixture();reloaded.fresh=1000000000;reloaded.rotten=1000000000
            reloaded.age=food.age;reloaded.data=saved
            HCRFoodQuality.reconcile(reloaded)
        ''')
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(reloaded)'),'rotten')
        self.assertAlmostEqual(self.lua.globals().reloaded.age,1.001)
        self.assertEqual(self.lua.globals().reloaded.rotten,1)

    def test_stale_nonperishable_and_no_stale_interval_are_representable(self):
        for limit in (1,1000000000):
            self.lua.globals().limit=limit
            self.lua.execute('''
                food=fixture();food.fresh=limit;food.rotten=limit
                HCRFoodQuality.setQuality(food,'stale')
            ''')
            self.assertEqual(self.lua.eval('HCRFoodQuality.quality(food)'),'stale')
            self.assertLess(self.lua.globals().food.age,limit)

    def test_freshness_floor_does_not_rejuvenate_naturally_rotten_food(self):
        self.lua.execute("food=fixture();food.age=9;HCRFoodQuality.setQuality(food,'stale')")
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(food)'),'rotten')

    def test_eating_last_rotten_portion_does_not_contaminate_empty_dish(self):
        self.lua.execute('''
            food=fixture();HCRFoodQuality.setQuality(food,'rotten')
            HCRFoodQuality.eat(food,{},function()
                HCRFoodQuality.OnEat(food,{},1)
                empty={}
                for k,v in pairs(food.data) do empty[k]=v end
            end)
        ''')
        self.assertIsNone(self.lua.eval('empty[HCRFoodQuality.qualityKey]'))

    def test_rotten_replacement_adapts_its_own_nonperishable_scale(self):
        for client in (False,True):
            self.lua.globals().client=False
            self.lua.execute('''
                source=fixture();HCRFoodQuality.setQuality(source,'rotten')
                replacement=fixture();replacement.fresh=1000000000;replacement.rotten=1000000000
                replacement.age=source.age;replacement.data[HCRFoodQuality.qualityKey]=source.data[HCRFoodQuality.qualityKey]
            ''')
            self.lua.globals().client=client
            self.lua.execute('HCRFoodQuality.reconcile(replacement)')
            self.assertEqual(self.lua.eval('HCRFoodQuality.quality(replacement)'),'rotten')
            self.assertAlmostEqual(self.lua.globals().replacement.age,1.001)
            self.assertEqual(self.lua.globals().source.rotten,7)
            self.assertIsNone(self.lua.eval('source.data[HCRFoodQuality.qualityKey].offAgeMax'))


if __name__=='__main__': unittest.main()
