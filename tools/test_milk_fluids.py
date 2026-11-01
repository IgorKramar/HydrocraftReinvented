"""Milk volume conversion, preserved HC portions, explicit native fluid consumption."""
import json
import re
import unittest

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, LUA, find_game, read_text
from repair_milk_fluids import MANIFEST, apply, native_lines
from build_milk_chains import fluid, MILK


class MilkFluids(unittest.TestCase):
    def setUp(self):
        self.manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
        self.chains=json.loads(MANIFEST.with_name('milk_chains.json').read_text(encoding='utf-8'))
        self.recipes={name:body for path in SCRIPTS.rglob('*.txt')
                      for _,_,name,body in blocks(read_text(path),'craftRecipe')}

    def test_source_portions_map_to_actual_carton_litres(self):
        native=read_text(find_game()/'media/scripts/generated/items/normal.txt')
        milk=next(body for _,_,name,body in blocks(native,'item') if name=='Milk')
        self.assertRegex(milk,r'Capacity\s*=\s*1\.0')
        self.assertRegex(milk,r'fluid\s*=\s*CowMilk:1\.0')
        rows=self.manifest['migrations']
        self.assertEqual(len(rows),13)
        self.assertEqual(sum(row['kind']=='split_food_or' for row in rows),9)
        for row in rows:
            if row['kind']=='whole_carton_conversion':continue
            amount=re.search(r'Milk;(\d+)',row['source']['input'])
            expected=int(amount[1])/10 if amount else 1.0
            self.assertEqual(row['litres'],expected)
            if row.get('superseded_by')=='brewed_drinks':
                rule=json.loads(MANIFEST.with_name('brewed_drink_rules.json').read_text(encoding='utf-8'))[row['native_recipe']]
                body=self.recipes[row['native_recipe']]
                self.assertIn(f"-fluid {rule['litres']/2:g} [HCRMilk;CowMilk;SheepMilk;AnimalMilk]",body)
                self.assertIn('HCRBrewedDrinks.create',body)
                continue
            chain=self.chains.get(row['native_recipe'])
            self.assertIn(fluid(chain['litres'],chain.get('fluids',MILK)) if chain else native_lines(row),self.recipes[row['native_recipe']])
        self.assertEqual(next(row['litres'] for row in rows if row['recipe']=='Add Milk From Carton'),0.1)
        self.assertEqual(next(row['litres'] for row in rows if 'Thermos of Coffee' in row['recipe']),0.2)

    def test_milk_and_soy_share_one_recipe_with_real_volume(self):
        for row in self.manifest['migrations']:
            if row['kind']!='split_food_or':continue
            self.assertEqual(row['superseded_by'],'unified_milk_1_6')
            self.assertEqual(row['recipe'],row['native_recipe'])
            self.assertNotIn(row['previous_native_recipe'],self.recipes)
            self.assertIn('Hydrocraft.HCSoymilk',row['legacy_food_body'])
            native=self.recipes[row['native_recipe']]
            self.assertNotRegex(native,r'item\s+\d+\s+\[Base\.Milk[^\n]*ItemCount')
            self.assertNotRegex(native,r'Hydrocraft\.(?:HCUHTmilk|HCSoymilk|HCEvaporatedmilkopen)\b')
            chain=self.chains[row['recipe']]
            litres=.2 if 'Hot Chocolate' in row['recipe'] else .1
            self.assertEqual(chain['litres'],litres)
            self.assertIn('HCRMilkSoy',chain['fluids'])
            self.assertIn(fluid(litres,chain['fluids']),native)
            if row['recipe'] in ('Make Eggnog Pot','Make Monkey Tail Pot'):
                rule=json.loads(MANIFEST.with_name('milk_cocktail_catalog.json').read_text(encoding='utf-8'))['products'][row['native_recipe']]
                self.assertIn('OnCreate = HCRBarDrinks.create',native)
                self.assertIn('item 1 '+rule['target']+',',native)
                self.assertIn('item 1 [Base.Pot] mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty]',native)
                continue
            # All non-milk ingredients and outputs retain the previous native route.
            def without_milk(body):
                body=re.sub(r'craftRecipe [^\n]+','craftRecipe canonical',body)
                body=re.sub(r'item 1 \[\*\] mode:keep flags\[ItemIsFluid;HandcraftOnly\],\s*-fluid [\d.]+ \[[^\]]+\] mode:primary,','MILK',body,count=1)
                body=re.sub(r'(?m)^\s*(?:Icon|Tooltip) = [^\n]+\n','\n',body)
                body=re.sub(r'(\[Base\.(?:Mugl|Pot)\](?: mode:destroy)? flags\[)ItemCount;ItemIsFluid;IsEmpty',r'\1ItemCount',body)
                return re.sub(r'\s+',' ',body).strip()
            self.assertEqual(without_milk(native),without_milk(row['legacy_native_body']))
            if row['recipe'] in ('Make Cup of Hot Chocolate','Make Pot of Rice Pudding'):
                self.assertIn('flags[ItemCount;ItemIsFluid;IsEmpty]',native)

    def test_empty_carton_transform_is_whole_and_variants_are_taught(self):
        self.assertIn('item 1 [Base.Milk] mode:destroy flags[ItemCount],',self.recipes['Pour Out Milk'])
        for row in self.manifest['migrations']:
            if row['kind']!='split_food_or':continue
            native=self.recipes[row['native_recipe']]
            if not re.search(r'NeedToBeLearn\s*=\s*true',native):continue
            taught=[]
            for path in SCRIPTS.rglob('*.txt'):
                for match in re.finditer(r'LearnedRecipes\s*=\s*([^,]+)',read_text(path)):
                    names=[name.strip() for name in match[1].split(';')]
                    self.assertNotIn(row['previous_native_recipe'],names)
                    if row['recipe'] in names:
                        self.assertIn(row['native_recipe'],names)
                        taught.append(path.name)
            self.assertTrue(taught,row['native_recipe'])
        apply(check=True)


if __name__=='__main__':unittest.main(verbosity=2)
