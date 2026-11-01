"""Кулинарный алкоголь не получает свойства полной бутылки при разливе."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text


class AlcoholPortions(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('function require() end; HCRFluidEffects={}; HCRFoodQuality={}')
        for name in ('HCR_FluidLedger','HCR_MilkBowl','HCR_AlcoholPortions'):
            self.lua.execute(read_text(LUA/f'shared/{name}.lua'))
        self.lua.execute('''
            L=HCRFluidLedger
            function bottle(litres,hunger,calories)
                return L.batch('HCRGin',litres,{hungChange=hunger,baseHunger=-.2,
                    calories=calories,poisonPower=.875,alcoholic=true,alcoholPower=2,
                    offAge=1000000000,offAgeMax=1000000000,canBeFrozen=false},0)
            end
        ''')

    def test_partial_pour_retains_original_hunger_baseline_and_dose(self):
        self.lua.execute('''
            local _,portion=L.split(bottle(1,-.2,2142),.2,1)
            result=HCRAlcoholPortions.properties(portion)
        ''')
        r=self.lua.globals().result
        self.assertAlmostEqual(r.calories,428.4)
        self.assertAlmostEqual(r.poisonPower,.175)
        self.assertAlmostEqual(r.hungChange,-.04)
        self.assertAlmostEqual(r.baseHunger,-.2)
        self.assertAlmostEqual(2*r.hungChange/r.baseHunger,.4)
        self.assertEqual(r.offAgeMax,1000000000)
        self.assertTrue(r.alcoholic)

    def test_dilution_and_partial_legacy_stock_do_not_amplify_alcohol(self):
        self.lua.execute('''
            local left=bottle(.5,-.1,1071)
            local _,part=L.split(left,.1,.5)
            local water=L.batch('HCRGin',.1,{thirstChange=-.05,calories=0,nativeAlcohol=0},0)
            result=HCRAlcoholPortions.properties(L.mix(part,water))
        ''')
        r=self.lua.globals().result
        self.assertAlmostEqual(r.calories,214.2)
        self.assertAlmostEqual(2*r.hungChange/r.baseHunger,.2)
        self.assertAlmostEqual(r.poisonPower,.175)

    def test_low_hunger_herbal_portion_keeps_four_uses_and_original_alcohol_reference(self):
        self.lua.execute('''
            local bottle=L.batch('HCRAbsinthe',1,{hungChange=-.05,baseHunger=-.05,
                calories=82,poisonPower=.875,alcoholic=true,alcoholPower=2,
                offAge=1000000000,offAgeMax=1000000000,canBeFrozen=false},0)
            local _,portion=L.split(bottle,.8,1)
            result=HCRAlcoholPortions.properties(portion)
        ''')
        r=self.lua.globals().result
        self.assertAlmostEqual(r.hungChange,-.04)
        self.assertAlmostEqual(r.baseHunger,-.05)
        self.assertAlmostEqual(r.calories,65.6)
        self.assertAlmostEqual(r.poisonPower,.7)
        self.assertAlmostEqual(2*r.hungChange/r.baseHunger,1.6)

    def test_unsupported_effects_refused_before_any_input_changes(self):
        self.lua.execute('''
            for key,value in pairs({nativeAlcohol=.4,alcoholPower=5,burnt=true,tainted=true,
                frozen=true,freezingTime=1,foodSicknessChange=-1}) do
                local ledger=bottle(1,-.2,2142)
                ledger.lots[1].food[key]=value
                assert(not pcall(HCRAlcoholPortions.properties,ledger),key)
                assert(ledger.lots[1].food[key]==value and L.volume(ledger)==1)
            end
        ''')

    def test_existing_spoilage_is_preserved_without_a_new_expiry_clock(self):
        self.lua.execute('''
            local ledger=bottle(1,-.2,2142)
            ledger.lots[1].age=1.001;ledger.lots[1].food.offAge=0;ledger.lots[1].food.offAgeMax=1
            result=HCRAlcoholPortions.properties(ledger)
        ''')
        r=self.lua.globals().result
        self.assertGreaterEqual(r.age,r.offAgeMax)

    def test_evolved_returns_one_vessel_only_when_portion_is_gone(self):
        self.lua.execute('''
            function isServer() return true end
            local additions,syncs=0,0
            local container={AddItem=function(_,item) additions=additions+1 end}
            function sendAddItemToContainer(c,item) assert(c==container);syncs=syncs+1 end
            function instanceItem()
                return {IsFood=function() return false end,
                    getFluidContainer=function() return {isEmpty=function() return true end} end,
                    copyConditionStatesFrom=function() end}
            end
            local item={replacement='Hydrocraft.HCAlestienFluid',container=container,uses=5}
            function item:getReplaceOnUse() return self.replacement end
            function item:getReplaceOnUseFullType() return self.replacement end
            function item:setReplaceOnUse(v) self.replacement=v end
            function item:getContainer() return self.container end
            function item:getCurrentUses() return self.uses end
            local function consume()
                assert(item.replacement==nil)
                item.uses=item.uses-1
                if item.uses==0 then item.container=nil end
                return 'result'
            end
            for i=1,4 do
                assert(HCRAlcoholPortions.evolved(item,consume)=='result')
                assert(additions==0 and syncs==0 and item.replacement=='Hydrocraft.HCAlestienFluid')
            end
            HCRAlcoholPortions.evolved(item,consume);assert(additions==1 and syncs==1)
            item.container=container;item.uses=5
            assert(not pcall(HCRAlcoholPortions.evolved,item,function() error('native failure') end))
            assert(item.replacement=='Hydrocraft.HCAlestienFluid' and additions==1 and syncs==1)
        ''')
