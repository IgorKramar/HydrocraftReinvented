"""Коктейли: сохранение классов, фактический выход и полное покрытие входов."""
import json
import re
import unittest
from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from hcr_paths import LUA, REPO, SCRIPTS, read_text


class CocktailFluids(unittest.TestCase):
    def test_all_recipe_fluids_accounted_once_and_actual_litres_fit(self):
        catalog = json.loads((REPO/'tools/cocktail_fluid_catalog.json').read_text(encoding='utf-8'))
        recipes = {name: body for p in SCRIPTS.rglob('*.txt') for _, _, name, body in blocks(read_text(p), 'craftRecipe')}
        items = {name: body for p in SCRIPTS.rglob('*.txt') for _, _, name, body in blocks(read_text(p), 'item')}
        self.assertEqual((len(catalog['families']), len(catalog['products'])), (16, 19))
        for kind, rule in catalog['families'].items():
            self.assertRegex(items[kind.split('.')[1]], r'ItemType\s*=\s*base:food')
            for name, body in recipes.items(): self.assertNotRegex(body, re.escape(kind)+r'\b', name)
        expected = {'Mix Old Fashioned': .125, 'Mix Long Island Iced Tea': .425,
                    'Whiskey and Coke': .1+2/15, 'Whiskey and Coke (Canned Cola)': .4,
                    'Mix Margarita': .225, 'Brew Irish Coffee': .2}
        for name, rule in catalog['products'].items():
            body = recipes[name]; slots = catalog['consumers'][name]['inputs']
            lines = re.findall(r'item [^\n]+\n(?:\s*-fluid [^\n]+\n)?', body.split('inputs', 1)[1].split('outputs', 1)[0])
            volume = 0
            for index, line in enumerate(lines):
                match = re.search(r'-fluid ([\d.]+) \[([^\]]+)\]', line)
                if match:
                    volume += float(match[1]); self.assertEqual(slots[str(index)]['fluids'], match[2].split(';'))
                    self.assertEqual(slots[str(index)]['nativeWine'], rule['marker'])
                    if 'mode:destroy' in line:
                        self.assertTrue(slots[str(index)]['nativeSink']); self.assertEqual(slots[str(index)]['exact'], float(match[1]))
            self.assertAlmostEqual(volume, rule['litres']); self.assertLessEqual(volume, .5)
            if name in expected: self.assertAlmostEqual(volume, expected[name])
            self.assertIn('OnCreate = HCRBarDrinks.create', body)
        for name in catalog['emptyRecipes']:
            self.assertIn('mode:destroy flags[ItemCount;IsEmpty]', recipes[name])
        self.assertEqual(catalog['families']['Hydrocraft.HCCoffeeirish2']['target'], 'Hydrocraft.HCClaymugFluid')

    def test_final_merge_keeps_native_sink_and_native_cola_water_budgets(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('function require() end; HCRDrinkFamilies={}; HCRFluidRecipeRules={}')
        for name in ('HCR_BarCatalog', 'HCR_CocktailCatalog', 'HCR_SoftDrinkCatalog', 'HCR_FluidRecipeQuality'):
            lua.execute(read_text(LUA/f'shared/{name}.lua'))
        lua.execute('''
            local R=HCRFluidRecipeQuality.rules
            assert(R['Whiskey and Coke'].inputs[0].nativeSink and R['Whiskey and Coke'].inputs[0].exact==.1)
            assert(R['Whiskey and Coke'].inputs[1].nativeWine=='HCRWhiskeyCola')
            assert(R['Whiskey and Coke (Canned Cola)'].inputs[1].nativeWine=='HCRWhiskeyCola')
            assert(R['Brew Irish Coffee'].inputs[1].nativeWine=='HCRIrishCoffee')
            assert(R['Brew Irish Coffee'].inputs[3].exact==.1 and not R['Brew Irish Coffee'].inputs[3].nativeSink)
            assert(HCRBarCatalog.products['Mix Margarita'].litres==.225)
        ''')


if __name__ == '__main__': unittest.main()
