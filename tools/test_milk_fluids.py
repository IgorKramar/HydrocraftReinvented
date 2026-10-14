"""Milk volume conversion, preserved HC portions, explicit native fluid consumption."""
import json
import re
import unittest

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, LUA, find_game, read_text
from repair_milk_fluids import MANIFEST, apply, native_lines


class MilkFluids(unittest.TestCase):
    def setUp(self):
        self.manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
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
            self.assertIn(native_lines(row),self.recipes[row['native_recipe']])
        self.assertEqual(next(row['litres'] for row in rows if row['recipe']=='Add Milk From Carton'),0.1)
        self.assertEqual(next(row['litres'] for row in rows if 'Thermos of Coffee' in row['recipe']),0.2)

    def test_legacy_food_alternatives_and_partial_uses_are_unchanged(self):
        for row in self.manifest['migrations']:
            if row['kind']!='split_food_or':continue
            body=self.recipes[row['recipe']]
            original_food=row['input'].replace('[Base.Milk;','[')
            self.assertIn(original_food,body)
            self.assertNotIn('Base.Milk',body)
            self.assertNotIn('flags[ItemCount]',original_food)
            native=self.recipes[row['native_recipe']]
            self.assertNotRegex(native,r'item\s+\d+\s+\[Base\.Milk[^\n]*ItemCount')
            self.assertNotIn('Hydrocraft.HCUHTmilk',native)
            # The duplicate retains all other ingredients, callbacks and output.
            normalized=native.replace('craftRecipe '+row['native_recipe'],'craftRecipe '+row['recipe'],1)
            normalized=normalized.replace(native_lines(row),original_food,1)
            self.assertEqual(normalized.strip(),body.strip())

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
                    if row['recipe'] in names:
                        self.assertIn(row['native_recipe'],names)
                        taught.append(path.name)
            self.assertTrue(taught,row['native_recipe'])
        apply(check=True)


if __name__=='__main__':unittest.main(verbosity=2)
