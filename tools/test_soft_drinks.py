"""Старые напитки сохраняются, новые сосуды не обходят проверки рецептов."""
import json
import re
import unittest
from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from build_soft_drinks import catalogue
from build_water_catalog import props
from hcr_paths import SCRIPTS,LUA,REPO,read_text


class SoftDrinks(unittest.TestCase):
    def test_migrated_food_families_keep_loading_classes_and_close_recipes(self):
        families=catalogue()
        self.assertEqual(len(families),17)
        items={name:props(body) for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'item')}
        for kind,spec in families.items():
            self.assertEqual(items[kind.split('.')[1]]['itemtype'],'base:food')
            target=items[spec['target'].split('.')[1]]
            self.assertEqual(target['itemtype'],'base:normal')
            self.assertAlmostEqual(float(target['capacity']),spec['litres'])
        for path in SCRIPTS.rglob('*.txt'):
            for _,_,name,body in blocks(read_text(path),'craftRecipe'):
                self.assertFalse(set(re.findall(r'Hydrocraft\.\w+',body)) & families.keys(),(path.name,name))

    def test_empty_alias_checks_volume_tracking_capacity_and_destination_identity(self):
        lua=LuaRuntime(unpack_returned_tuples=True)
        lua.execute('function require() end; HCRDrinkFamilies={}; HCRJuiceRecipeRules={}; HCRFluidLedger={}; HCRFluidEffects={}; HCRFluidQuality={fluid=function(i) return i.fluid end,active=function(i) return i.tracked end}')
        for file in ('HCR_SoftDrinkCatalog.lua','HCR_DrinkVessels.lua','HCR_DrinkRecipes.lua'):
            lua.execute((LUA/'shared'/file).read_text(encoding='utf-8'))
        lua.execute('''
            local rule={target='Base.PopBottle',litres=1}
            local item={kind='Hydrocraft.HCSodacolaFluid',amount=0,capacity=2}
            function item:getFullType() return self.kind end
            item.fluid={isEmpty=function() return item.amount==0 end,getCapacity=function() return item.capacity end}
            assert(HCRDrinkVessels.matches(rule.target,item) and HCRDrinkRecipes.test(rule,item))
            item.amount=.1;assert(not HCRDrinkRecipes.test(rule,item));item.amount=0
            item.tracked=true;assert(not HCRDrinkRecipes.test(rule,item));item.tracked=false
            item.capacity=.2;assert(not HCRDrinkRecipes.test(rule,item));item.capacity=2
            item.kind='Base.Pot';assert(not HCRDrinkVessels.matches(rule.target,item))
            assert(HCRDrinkRecipes.test(rule,item)) -- OnTest вызывается также для фруктов/инструментов.
        ''')

    def test_fitness_keeps_canteen_and_consumes_one_of_eight_blender_charges(self):
        recipes={name:body for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'craftRecipe')}
        body=recipes['Mix Fitness Drink']
        self.assertIn('HCCanteenFluid] mode:keep flags[ItemCount;IsEmpty]',body)
        self.assertIn('item 1 [Hydrocraft.HCBlenderpowered],',body)
        self.assertRegex(body,r'outputs\s*\{\s*\}')
        for name in ('Exercise hard on Treadmill','Exercise hard with Weights','Exercise hard with Punching Bag'):
            self.assertIn('-fluid 0.14 [HCRFitness]',recipes[name])
            self.assertRegex(recipes[name],r'outputs\s*\{\s*\}')

    def test_soda_factory_pack_and_empty_grenade_shell_remain_explicit(self):
        config=json.loads((REPO/'tools/soft_drink_catalog.json').read_text(encoding='utf-8'))
        self.assertEqual(len(config['vessels']),3)
        self.assertEqual(config['packing'],{'Pack Pop (Pack of Pop 3)':'Hydrocraft.HCPop6Fluid'})
        body=next(b for _,_,n,b in blocks(read_text(SCRIPTS/'HydrocraftReinvented/HCR_Weapons Explosives.txt'),'craftRecipe') if n=='Make Chlorgas Grenade')
        self.assertIn(';Hydrocraft.HCSodacolaFluid;',body)
        self.assertIn('flags[ItemCount;ItemIsFluid;IsEmpty]',body)

if __name__=='__main__': unittest.main()
