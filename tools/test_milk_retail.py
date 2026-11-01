"""Старые молочные запасы сохраняют классы, новые рецепты — физический объём."""
import json
import re
import unittest
from apply_playability_fixes import blocks
from build_water_catalog import props
from hcr_paths import REPO, SCRIPTS, read_text


class MilkRetail(unittest.TestCase):
    def test_legacy_classes_and_shelf_lives_remain_loadable(self):
        items={name:props(body) for path in SCRIPTS.rglob('*.txt')
               for _,_,name,body in blocks(read_text(path),'item')}
        for name in ('HCUHTmilk','HCPlasticcanmilk','HCDetergentmilk'):
            self.assertEqual(items[name]['itemtype'],'base:food')
            self.assertEqual(float(items[name]['daysfresh']),250)
            self.assertEqual(float(items[name]['daystotallyrotten']),500)
        carton=items['HCUHTmilkFluid']
        self.assertEqual(carton['itemtype'],'base:normal')
        self.assertEqual(float(carton['capacity']),1)
        self.assertEqual(float(carton['weight']),.1)
        self.assertEqual(carton['icon'],'HCUHTmilk')

    def test_only_producer_is_now_a_conserving_fill(self):
        recipes={name:body for path in SCRIPTS.rglob('*.txt')
                 for _,_,name,body in blocks(read_text(path),'craftRecipe')}
        for name,body in recipes.items():
            output=re.search(r'outputs\s*\{([^}]*)\}',body)
            if output:
                self.assertNotRegex(output[1],r'Hydrocraft\.(?:HCUHTmilk|HCPlasticcanmilk|HCDetergentmilk)\b',name)
        rule=json.loads((REPO/'tools/milk_chains.json').read_text(encoding='utf-8'))['Fill Empty Soap Can With UHT Milk']
        self.assertEqual(rule['litres'],1.4)
        self.assertEqual(rule['vesselType'],'Hydrocraft.HCDetergentemptyFluid')
        self.assertNotIn(rule['vesselSlot'],rule['slots'])
        self.assertEqual(rule['output'],'')

    def test_uht_and_soy_use_canonical_native_recipes(self):
        recipes={name:body for path in SCRIPTS.rglob('*.txt')
                 for _,_,name,body in blocks(read_text(path),'craftRecipe')}
        manifest=json.loads((REPO/'tools/milk_fluid_migrations.json').read_text(encoding='utf-8'))
        counterparts={row['recipe']:row['native_recipe'] for row in manifest['migrations'] if row['kind']=='split_food_or'}
        for name,body in recipes.items():
            self.assertNotRegex(body,r'Hydrocraft\.HCUHTmilk\b',name)
        self.assertEqual(len(counterparts),9)
        for name,native in counterparts.items():
            self.assertEqual(name,native)
            self.assertRegex(recipes[name],r'\[HCRMilk;CowMilk;SheepMilk;AnimalMilk(?:;HCRMilkChocolate)?;HCRMilkSoy\]')

    def test_jug_capacity_and_chocolate_consumer_boundary(self):
        items={name:props(body) for path in SCRIPTS.rglob('*.txt')
               for _,_,name,body in blocks(read_text(path),'item')}
        for name in ('HCMilkjug','HCMilkjugchocolate'):
            self.assertEqual(items[name]['itemtype'],'base:food')
            self.assertEqual(float(items[name+'emptyFluid']['capacity']),2)
        rules=json.loads((REPO/'tools/milk_chains.json').read_text(encoding='utf-8'))
        chocolate={name for name,spec in rules.items() if 'HCRMilkChocolate' in spec.get('fluids',[])}
        self.assertEqual(chocolate,{'Pour Milk into Bowl'}|set((
            'Make Eggnog Pot','Make Monkey Tail Pot','Prepare Cornbread','Make Nacho Cheese',
            'Make Frosting','Make Fruit Cake Batter','Make Pot of Rice Pudding')))
        carton=rules['Pour into Carton']
        self.assertEqual(carton['litres'],1)
        self.assertEqual(carton['slots'],[0])
        self.assertNotIn('foodSlot',carton)

    def test_dilution_returns_one_empty_tin(self):
        recipes={name:body for p in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(p),'craftRecipe')}
        output=re.search(r'outputs\s*\{([^}]+)\}',recipes['Dilute Evaporated Milk'])[1]
        self.assertEqual(re.findall(r'item (\d+) ([\w.]+),',output),
                         [('1','Base.Milk'),('1','Hydrocraft.HCEvaporatedmilkopenempty')])
