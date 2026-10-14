"""Regressions for petrol conservation, empty-shell eligibility and repeat craft."""
import json
import re
import unittest
from pathlib import Path
from repair_petrol_containers import MANIFEST, transform
from repair_food_counts import FOOD_SCRIPTS

DATA = json.loads(MANIFEST.read_text(encoding='utf-8'))
ENTRIES = DATA['migrations']


def consume_petrol(cans, requested):
    # Model the native pooled FluidContainer resource: reject before mutation.
    eligible = [can for can in cans if can['fluid'] == 'Petrol']
    if sum(can['litres'] for can in eligible) + 1e-5 < requested:
        return False
    for can in eligible:
        used = min(requested, can['litres'])
        can['litres'] -= used
        requested -= used
    return True


class PetrolContainers(unittest.TestCase):
    def test_all_migrations_present_and_idempotent(self):
        for file in {e['file'] for e in ENTRIES}:
            text = (FOOD_SCRIPTS / file).read_text(encoding='utf-8-sig')
            subset = [e for e in ENTRIES if e['file'] == file]
            self.assertEqual(text, transform(text, subset, check=True))
            self.assertEqual(text, transform(text, subset))

    def test_legacy_charges_and_fuel_conservation(self):
        for entry in ENTRIES:
            if entry['kind'] != 'petrol_portion':
                continue
            qty = re.search(r'PetrolCan\s*=\s*(\d+)', entry['legacy_input'])
            quantity = int(qty[1]) if qty else 1
            self.assertAlmostEqual(entry['litres'], quantity * .125 * 10)
            self.assertIn('mode:keep', entry['after'])
            self.assertNotIn('ItemCount', entry['after'])
            requested = entry['litres']
            cans = [{'fluid': 'Petrol', 'litres': 10.0} for _ in range(3)]
            ids = [id(c) for c in cans]
            self.assertTrue(consume_petrol(cans, requested))
            self.assertAlmostEqual(sum(c['litres'] for c in cans), 30 - requested)
            self.assertEqual(ids, [id(c) for c in cans])
            dry = [{'fluid': 'Petrol', 'litres': 0}, {'fluid': 'Water', 'litres': 10}]
            self.assertFalse(consume_petrol(dry, requested))
            self.assertEqual(dry[1]['litres'], 10)
        cans = [{'fluid': 'Petrol', 'litres': 1.25}]
        self.assertTrue(consume_petrol(cans, 1.25))
        self.assertFalse(consume_petrol(cans, 1.25))

    def test_physical_shell_consumed_once_and_empty_required(self):
        for entry in ENTRIES:
            if entry['kind'] != 'empty_physical':
                continue
            for flag in ['ItemCount', 'ItemIsFluid', 'IsEmpty']:
                self.assertIn(flag, entry['after'])
            self.assertNotIn('-fluid', entry['after'])
            count = int(re.search(r'item (\d+)', entry['before'])[1])
            shells = [{'litres': 0} for _ in range(count)]
            self.assertTrue(all(shell['litres'] == 0 for shell in shells))
            del shells[:count]
            self.assertLess(len(shells), count, 'a used physical shell cannot craft again')
            self.assertFalse(all(shell['litres'] == 0 for shell in [{'litres': .1}]))

    def test_review_conflict_fails_without_guessing(self):
        entry = ENTRIES[0]
        text = f"craftRecipe {entry['recipe']}\n{{\ninputs\n{{\nitem 999 [Base.Bucket],\n}}\n}}"
        with self.assertRaises(RuntimeError):
            transform(text, [entry])


if __name__ == '__main__':
    unittest.main()
