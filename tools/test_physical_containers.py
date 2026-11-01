"""Physical B42 container destruction and preserved liquid-input regressions."""
import json
import unittest

from apply_playability_fixes import blocks
from hcr_paths import read_text
from repair_food_counts import FOOD_SCRIPTS, whole_input
from repair_physical_containers import MANIFEST


class PhysicalContainers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        cls.recipes = {}
        for name in {entry['file'] for field in ('migrations', 'protected_fluid_keep_inputs', 'superseded_migrations')
                     for entry in cls.manifest[field]}:
            for _, _, recipe, body in blocks(read_text(FOOD_SCRIPTS / name), 'craftRecipe'):
                cls.recipes[name, recipe] = [line.strip() for line in body.splitlines()]

    def test_named_destroyed_containers_use_whole_item_counts(self):
        for entry in self.manifest['migrations']:
            with self.subTest(file=entry['file'], recipe=entry['recipe']):
                if 'mode:destroy' not in entry['input']:
                    self.assertTrue(entry['upstream_file'])
                    self.assertTrue(entry['upstream_recipe'])
                    self.assertRegex(entry['upstream_input'], r'^\w+(=\d+)?,\Z')
                self.assertNotIn('mode:keep', entry['input'])
                self.assertNotIn('[*]', entry['input'])
                self.assertTrue(entry['fluid_types'])
                for full_type in entry['fluid_types']:
                    self.assertIn(full_type, self.manifest['fluid_declarations'])
                    self.assertTrue(self.manifest['fluid_declarations'][full_type].startswith('generated/items/'))
                self.assertIn(whole_input(entry['input']), self.recipes[entry['file'], entry['recipe']])

    def test_purification_keeps_the_existing_vessel_and_actual_volume(self):
        rules = json.loads(MANIFEST.with_name('water_recipe_rules.json').read_text(encoding='utf-8'))
        rows = [r for r in self.manifest['superseded_migrations'] if r['supersededBy'].startswith('water-')]
        self.assertEqual(len(rows), 4)
        for row in rows:
            lines = self.recipes[row['file'], row['recipe']]
            rule = next(r for r in rules.values() if r['name'] == row['recipe'])
            self.assertTrue(rule['purify'])
            self.assertTrue(rule['water'])
            for vessel in rule['water']:
                self.assertIn('item 1 ['+vessel+'] mode:keep flags[ItemCount],', lines)
            output = lines[lines.index('outputs')+1:]
            self.assertFalse(any(line.startswith('item ') for line in output))

    def test_juice_fills_the_same_empty_vessel(self):
        rules = json.loads(MANIFEST.with_name('juice_recipe_rules.json').read_text(encoding='utf-8'))
        aliases = json.loads(MANIFEST.with_name('soft_drink_catalog.json').read_text(encoding='utf-8'))['emptyAliases']
        rows = [r for r in self.manifest['superseded_migrations'] if r['supersededBy'].startswith('juice-')]
        self.assertEqual(len(rows), 122)
        for row in rows:
            lines = self.recipes[row['file'], row['recipe']]
            token, rule = next((k, r) for k, r in rules.items() if r['name'] == row['recipe'])
            kinds = [rule['target']] + aliases.get(rule['target'], [])
            self.assertIn('item '+str(rule['count'])+' ['+';'.join(kinds)+'] mode:keep flags[ItemCount;IsEmpty],', lines)
            self.assertIn('OnCreate = HCRDrinkRecipes.Create_'+token+',', lines)
            output = lines[lines.index('outputs')+1:]
            self.assertFalse(any(line.startswith('item ') for line in output))

    def test_mashed_potato_cycle_consumes_physical_pot_and_bowls(self):
        for recipe in ('Make Plain Mashed Potatoes', 'Make Creamy Mashed Potatoes'):
            self.assertIn('item 1 [Base.Pot] flags[ItemCount],',
                          self.recipes['HCR_Food Taters.txt', recipe])
        for recipe in ('Make Bowl of Plain Mashed Potatos', 'Make Bowl of Creamy Mashed Potatos'):
            self.assertIn('item 2 [Base.Bowl] flags[ItemCount],',
                          self.recipes['HCR_Food Taters.txt', recipe])

    def test_partial_fluid_providers_are_unchanged(self):
        for entry in self.manifest['protected_fluid_keep_inputs']:
            with self.subTest(file=entry['file'], recipe=entry['recipe']):
                self.assertIn(entry['input'], self.recipes[entry['file'], entry['recipe']])
                self.assertNotIn(whole_input(entry['input']), self.recipes[entry['file'], entry['recipe']])


if __name__ == '__main__':
    unittest.main(verbosity=2)
