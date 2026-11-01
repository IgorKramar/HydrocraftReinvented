"""Порция для evolved: реальные бюджеты и ближайшие сроки каждой партии."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, read_text


class MilkBowl(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('function require() end; HCRFluidEffects={}; HCRFoodQuality={}')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidLedger.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_MilkBowl.lua'))
        self.lua.execute('''
            L=HCRFluidLedger
            function batch(age,fresh,rot,calories)
                return L.batch('HCRMilk',1,{age=age,offAge=fresh,offAgeMax=rot,
                    calories=calories or 100,poisonPower=.875,canBeFrozen=false,
                    cooked=false,hungChange=-.5,baseHunger=-.5,thirstChange=-.5},0)
            end
        ''')

    def test_partial_pour_preserves_extensive_properties(self):
        self.lua.execute('''
            local _,portion=L.split(batch(3.75,4,7,615),.3,1)
            result=HCRMilkBowl.properties(portion)
        ''')
        r=self.lua.globals().result
        self.assertAlmostEqual(r.calories,184.5)
        self.assertAlmostEqual(r.hungChange,-.15)
        self.assertAlmostEqual(r.baseHunger,-.15)
        self.assertAlmostEqual(r.poisonPower,.2625)
        self.assertAlmostEqual(r.offAge-r.age,.25)
        self.assertAlmostEqual(r.offAgeMax-r.age,3.25)
        self.assertFalse(r.canBeFrozen)
        self.assertFalse(r.cooked)

    def test_modified_nonpersistent_effect_is_refused_without_mutation(self):
        self.lua.execute('''
            local ledger=batch(0,4,7)
            ledger.lots[1].food.alcoholPower=.5
            assert(not HCRMilkBowl.supported(ledger))
            assert(ledger.lots[1].food.alcoholPower==.5)
            assert(L.volume(ledger)==1)
        ''')

    def test_thaw_and_taint_cannot_be_lost_in_native_food_save(self):
        self.lua.execute('''
            for _,key in ipairs({'tainted','frozen','alcoholic'}) do
                local ledger=batch(0,4,7);ledger.lots[1].food[key]=true
                assert(not HCRMilkBowl.supported(ledger))
            end
            local ledger=batch(0,4,7);ledger.lots[1].food.freezingTime=1
            assert(not HCRMilkBowl.supported(ledger))
            ledger.lots[1].food.freezingTime=0
            ledger.lots[1].food.canBeFrozen=true
            ledger.lots[1].food.fatigueChange=-.5
            assert(HCRMilkBowl.supported(ledger))
            assert(not HCRMilkBowl.properties(ledger).canBeFrozen)
            assert(HCRMilkBowl.properties(ledger).fatigueChange==-.5)
        ''')

    def test_distinct_lots_cannot_extend_either_deadline(self):
        self.lua.execute('''
            result=HCRMilkBowl.properties(L.mix(batch(1.9,2,4),batch(6.4,10,11)))
        ''')
        r=self.lua.globals().result
        self.assertAlmostEqual(r.offAge-r.age,.1)
        self.assertLessEqual(r.offAgeMax-r.age,2.1+.000001)
        self.assertGreater(r.offAgeMax-r.age,1.1)

    def test_old_uht_opened_portion_has_short_shelf_life(self):
        self.lua.execute('result=HCRMilkBowl.properties(batch(200,250,500))')
        r=self.lua.globals().result
        self.assertEqual((r.age,r.offAge,r.offAgeMax),(0,4,7))

    def test_stale_milk_keeps_exact_remaining_life(self):
        self.lua.execute('result=HCRMilkBowl.properties(batch(6.9,4,7))')
        r=self.lua.globals().result
        self.assertGreater(r.age,r.offAge)
        self.assertAlmostEqual(r.offAgeMax-r.age,.1)

    def test_rotten_milk_stays_rotten_on_bounded_clock(self):
        self.lua.execute('result=HCRMilkBowl.properties(batch(1000,4,7))')
        r=self.lua.globals().result
        self.assertGreater(r.age,r.offAgeMax)
        self.assertLess(r.age,2)

    def test_many_ages_and_shelf_lives_never_rejuvenate(self):
        self.lua.execute('''
            for a=0,27 do
                for b=0,11 do
                    local ageA=a/4;local ageB=b/4
                    local r=HCRMilkBowl.properties(L.mix(batch(ageA,4,7),batch(ageB,2,4)))
                    local fresh=math.min(4-ageA,2-ageB)
                    local rotten=math.min(7-ageA,4-ageB)
                    assert(r.offAge-r.age<=fresh+.000001 or fresh<=0)
                    assert(r.offAgeMax-r.age<=rotten+.000001)
                    if fresh>0 then assert(r.age<r.offAge) end
                end
            end
        ''')
