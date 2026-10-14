"""Pinned keep semantics, protected charges/components, and exact migration counts."""
import json
import unittest
from collections import defaultdict

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, read_text
from repair_tool_keeps import MANIFEST, apply, kept_input


class ToolKeeps(unittest.TestCase):
    def test_all_selected_tools_are_source_kept_and_migrated_exactly(self):
        manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        apply(check=True)
        self.assertEqual(sum(row['occurrences'] for row in manifest['migrations']), 141)
        source_lines = role_lines = 0
        for row in manifest['migrations']:
            if row['basis'] == 'upstream_keep':
                self.assertTrue(row['source'])
                self.assertTrue(all(source['input'] == 'keep Tongs,' for source in row['source']))
                source_lines += row['occurrences']
            else:
                self.assertEqual(row['basis'], 'B42_tool_role_review')
                self.assertFalse(row['source'], 'Do not imply upstream proof for new port recipes')
                self.assertTrue(row['rationale'])
                self.assertEqual(row['native_reference']['version'], '42.21')
                role_lines += row['occurrences']
            self.assertEqual(row['input'], 'item 1 tags[base:tongs;base:crudetongs],')
            self.assertFalse(any(':/' in str(value) for value in row.values()))
        self.assertEqual(source_lines, 133)
        self.assertEqual(role_lines, 8)

    def test_fire_charges_and_construction_components_remain_consumed(self):
        manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        protected = manifest['protected']
        self.assertEqual(sum('tags[base:startfire]' in row['input'] for row in protected), 114)
        self.assertTrue(any(row['recipe'] == 'Make Gem Cutter Wheel' and
                            row['source'][0]['input'] == 'Tongs,' for row in protected))
        by_file = defaultdict(list)
        for row in protected:
            by_file[row['file']].append(row)
        for file, rows in by_file.items():
            recipes = defaultdict(list)
            for _, _, name, body in blocks(read_text(SCRIPTS/'HydrocraftReinvented'/file), 'craftRecipe'):
                recipes[name].extend(line.strip() for line in body.splitlines())
            for row in rows:
                self.assertIn(row['input'], recipes[row['recipe']], row)

    def test_explicit_destroy_mode_is_never_overridden(self):
        with self.assertRaises(ValueError):
            kept_input('item 1 tags[base:tongs] mode:destroy,')


if __name__ == '__main__':
    unittest.main(verbosity=2)
