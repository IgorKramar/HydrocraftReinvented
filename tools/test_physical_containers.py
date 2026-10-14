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
        for name in {entry['file'] for field in ('migrations', 'protected_fluid_keep_inputs')
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
