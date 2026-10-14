"""Drink pack round trips cannot refill or restore partly consumed contents."""
import json
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from hcr_paths import read_text
from repair_food_counts import FOOD_SCRIPTS

class DrinkPackaging(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
        local function fluid(amount, kind, mixture)
            return {isFull=function() return amount >= .3 - .0001 end,
                isMixture=function() return mixture end,
                getPrimaryFluid=function() return kind end}
        end
        function can(amount, kind, mixture)
            return {getFullType=function() return "Base.Pop" end,
                getFluidContainer=function() return fluid(amount,kind,mixture) end}
        end
        function beer(whole, poison, cooked, extra, age)
            return {getFullType=function() return "Hydrocraft.HCBeercan1" end,
                getFluidContainer=function() return nil end, IsFood=function() return true end,
                isWholeFoodItem=function() return whole end,
                getPoisonPower=function() return poison end,
                isCooked=function() return cooked end,isBurnt=function() return false end,
                haveExtraItems=function() return extra end,getSpices=function() return nil end,
                getOffAge=function() return 1000000000 end,getAge=function() return age end}
        end
        function instanceItem(name)
            if name == "Base.Pop" then return can(.3,"ColaDiet",false) end
            return beer(true,0,false,false,0)
        end
        ''')
        self.lua.execute(Path('common/media/lua/shared/HCR_Packaging.lua').read_text())

    def test_full_native_can_allowed(self):
        self.assertTrue(self.lua.eval('HCRPackaging.IsFullFactoryState(can(.3,"ColaDiet",false))'))

    def test_partial_empty_or_refilled_native_can_rejected(self):
        for expression in ('can(.15,"ColaDiet",false)', 'can(0,"ColaDiet",false)',
                           'can(.3,"Water",false)', 'can(.3,"ColaDiet",true)'):
            with self.subTest(expression=expression):
                self.assertFalse(self.lua.eval('HCRPackaging.IsFullFactoryState(' + expression + ')'))

    def test_complete_shelf_stable_food_beer_allowed(self):
        self.assertTrue(self.lua.eval('HCRPackaging.IsFullFactoryState(beer(true,0,false,false,20))'))

    def test_partial_poisoned_cooked_or_modified_food_beer_rejected(self):
        for expression in ('beer(false,0,false,false,0)', 'beer(true,5,false,false,0)',
                           'beer(true,0,true,false,0)', 'beer(true,0,false,true,0)'):
            with self.subTest(expression=expression):
                self.assertFalse(self.lua.eval('HCRPackaging.IsFullFactoryState(' + expression + ')'))

    def test_guard_applies_only_verified_fresh_factory_unpack_cycles(self):
        manifest = json.loads(Path('tools/packaging_migrations.json').read_text())
        recipes = {}
        for path in FOOD_SCRIPTS.glob('*.txt'):
            for _, _, name, body in blocks(read_text(path), 'craftRecipe'):
                recipes[path.name, name] = body
        for entry in manifest['migrations']:
            body = recipes[entry['file'], entry['recipe']]
            self.assertIn('OnTest = HCRPackaging.IsFullFactoryState,', body)
            self.assertNotIn('ItemIsFluid', body)
            self.assertTrue(entry['unpack_recipes'])
            for pair in entry['unpack_recipes']:
                unpack = recipes[pair['file'], pair['recipe']]
                self.assertIn(entry['pack'] + '] flags[ItemCount]', unpack)
                self.assertIn('item ' + str(entry['count']) + ' ' + entry['input_types'][0] + ',', unpack)

if __name__ == '__main__':
    unittest.main(verbosity=2)
