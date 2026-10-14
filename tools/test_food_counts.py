"""Source-backed whole-food migration and preserved partial-use regressions."""
import json
import re
import unittest

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, read_text
from repair_food_counts import FOOD_SCRIPTS, MANIFEST, whole_input
from repair_liquid_inputs import MANIFEST as LIQUID_MANIFEST


class WholeFoodMigration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        cls.liquids = json.loads(LIQUID_MANIFEST.read_text(encoding='utf-8'))
        cls.recipes = {}
        for filename in {row['file'] for key in ('migrations', 'protected_partial_inputs')
                         for row in cls.manifest[key]}:
            for _, _, name, body in blocks(read_text(FOOD_SCRIPTS / filename), 'craftRecipe'):
                cls.recipes[filename, name] = body

    def test_all_reviewed_whole_inputs_are_consumed_by_item_count(self):
        for row in self.manifest['migrations']:
            with self.subTest(file=row['file'], recipe=row['recipe'], input=row['input']):
                lines = self.recipes[row['file'], row['recipe']].splitlines()
                self.assertIn(whole_input(row['input']), [line.strip() for line in lines])
                self.assertNotIn(row['input'], [line.strip() for line in lines])

    def test_source_evidence_preserves_whole_item_quantities(self):
        self.assertEqual(self.manifest['commit'], '917d37d4ed526f429e1525316c9fab487bbf7257')
        for row in self.manifest['migrations']:
            count = int(re.search(r'item\s+(\d+)', row['input'])[1])
            self.assertTrue(row['source'])
            self.assertFalse(row['file'].startswith(('/', 'C:')))
            for source in row['source']:
                original = source['input'].rstrip(',').strip()
                self.assertNotIn(';', original, source)
                self.assertFalse(original.startswith(('keep ', 'destroy ')), source)
                source_count = int(original.rsplit('=', 1)[1]) if '=' in original else 1
                self.assertEqual(source_count, count, source)

    def test_partial_ingredients_are_not_changed_to_whole_items(self):
        for row in self.manifest['protected_partial_inputs']:
            with self.subTest(file=row['file'], recipe=row['recipe']):
                lines = self.recipes[row['file'], row['recipe']].splitlines()
                reviewed = [e for e in self.liquids['migrations']
                            if (e['file'], e['recipe'], e['before'], e['kind']) ==
                            (row['file'], row['recipe'], row['input'],
                             'separate_native_fluid_variant')]
                if not reviewed:
                    self.assertIn(row['input'], [line.strip() for line in lines])
                    self.assertNotIn(whole_input(row['input']), [line.strip() for line in lines])
                    continue
                self.assertEqual(len(reviewed), 1)
                after = reviewed[0]['after']
                self.assertIn(after, [line.strip() for line in lines])
                self.assertNotIn('ItemCount', after)
                old_count, old_types = re.search(r'item (\d+) \[([^]]+)\]', row['input']).groups()
                new_count, new_types = re.search(r'item (\d+) \[([^]]+)\]', after).groups()
                self.assertEqual(new_count, old_count)
                # Every legacy Hydrocraft food alternative remains a partial use.
                self.assertEqual(new_types.split(';'),
                                 [t for t in old_types.split(';') if t.startswith('Hydrocraft.')])
                removed = set(old_types.split(';')) - set(new_types.split(';'))
                self.assertTrue(removed)
                for native_type in removed:
                    # Only these source-reviewed liquor/can conversions supersede
                    # the old exact-row assertion; arbitrary recipe edits still fail.
                    fluid, per_unit = {'Base.Whiskey': ('Whiskey', .05),
                                       'Base.Pop': ('Cola;ColaDiet', .3),
                                       'Base.Pop2': ('Cola;ColaDiet', .3)}[native_type]
                    variants = [v for v in self.liquids['variants']
                                if v['file'] == row['file'] and v['fluid'] == fluid
                                and v['recipe'].startswith(row['recipe'] + ' (')
                                and native_type in v['body']]
                    self.assertEqual(len(variants), 1)
                    variant = variants[0]
                    self.assertAlmostEqual(variant['litres'], int(old_count) * per_unit)
                    body = self.recipes[row['file'], variant['recipe']]
                    self.assertIn('mode:keep flags[ItemIsFluid;HandcraftOnly]', body)
                    self.assertIn(f"-fluid {variant['litres']:g} [{fluid}],", body)


if __name__ == '__main__':
    unittest.main(verbosity=2)
