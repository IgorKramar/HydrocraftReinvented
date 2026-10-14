"""Source proportions, native fluid inputs, and retained-container regressions."""
import json
import unittest
from apply_playability_fixes import blocks
from hcr_paths import read_text
from repair_liquid_inputs import MANIFEST
from repair_food_counts import FOOD_SCRIPTS

class LiquidInputs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text())
        cls.recipes = {}
        for filename in {e['file'] for e in cls.manifest['migrations']}:
            for _, _, name, body in blocks(read_text(FOOD_SCRIPTS / filename), 'craftRecipe'):
                cls.recipes[filename, name] = body

    def test_reviewed_migrations_applied(self):
        for e in self.manifest['migrations']:
            with self.subTest(recipe=e['recipe'], before=e['before']):
                body = self.recipes[e['file'], e['recipe']]
                if e['after']:
                    self.assertIn(e['after'], body)
                self.assertNotIn(e['before'], body)

    def test_portions_match_original_fraction_of_bottle(self):
        for e in self.manifest['migrations']:
            if e['kind'] != 'portion':
                continue
            count = int(e['legacy_input'].replace('=', ';').split(';')[1])
            self.assertAlmostEqual(e['litres'], count * .05)
            self.assertIn('mode:keep flags[ItemIsFluid;HandcraftOnly]', e['after'])
            self.assertIn(f"[{e['fluid']}]", e['after'])

    def test_empty_bottles_are_consumed_not_free_contents(self):
        for e in self.manifest['migrations']:
            if e['kind'] == 'empty_container':
                self.assertIn('flags[ItemCount;ItemIsFluid;IsEmpty]', e['after'])
                self.assertIn('Empty', e['legacy_input'])

    def test_native_and_legacy_whiskey_routes_are_both_available(self):
        for v in self.manifest['variants']:
            if v['fluid'] != 'Whiskey':
                continue
            body = self.recipes[v['file'], v['recipe']]
            self.assertIn('-fluid 0.1 [Whiskey]', body)
            self.assertIn('mode:keep flags[ItemIsFluid;HandcraftOnly]', body)
            original = self.recipes[v['file'], v['recipe'].replace(' (Bottled Whiskey)', '')]
            self.assertIn('Hydrocraft.HCWhiskey1', original)
            self.assertNotIn('Base.Whiskey', original)

    def test_bleach_route_consumes_whole_source_bottle_contents(self):
        for v in self.manifest['variants']:
            if v['fluid'] != 'Bleach':
                continue
            body = self.recipes[v['file'], v['recipe']]
            self.assertIn('-fluid 1 [Bleach]', body)
            self.assertIn('Base.Bleach] mode:keep', body)
            original = self.recipes[v['file'], v['recipe'].replace(' (Bleach)', '')]
            self.assertNotIn('Base.Bleach', original)
            self.assertTrue('Base.Soap2' in original or 'Hydrocraft.HCMethanol' in original)

    def test_cleaning_liquid_uses_original_two_percent_of_half_litre(self):
        for v in self.manifest['variants']:
            if v['fluid'] == 'CleaningLiquid':
                self.assertAlmostEqual(v['litres'], .5 * .02)
                self.assertIn('-fluid 0.01 [CleaningLiquid]', self.recipes[v['file'], v['recipe']])

    def test_whiskey_coke_consumes_native_can_contents(self):
        native = self.recipes['HCR_Food Bar.txt', 'Whiskey and Coke (Canned Cola)']
        self.assertIn('-fluid 0.3 [Cola;ColaDiet]', native)
        self.assertIn('Base.Pop;Base.Pop2] mode:keep', native)
        legacy = self.recipes['HCR_Food Bar.txt', 'Whiskey and Coke']
        self.assertIn('Hydrocraft.HCSodacola', legacy)
        self.assertNotIn('Base.Pop', legacy)

if __name__ == '__main__':
    unittest.main(verbosity=2)
