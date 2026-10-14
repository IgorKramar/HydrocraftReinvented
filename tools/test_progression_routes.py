"""Community blocker transitions must have real materials, tools and teaching routes."""
import json
import re
import unittest
from pathlib import Path

from apply_playability_fixes import blocks
from audit_lua_item_ids import declared
from hcr_paths import SCRIPTS, LUA, find_game, read_text

ROOT = Path(__file__).resolve().parents[1]


def recipes():
    return {name:body for path in SCRIPTS.rglob('*.txt')
            for _,_,name,body in blocks(read_text(path),'craftRecipe')}


class ProgressionRoutes(unittest.TestCase):
    def test_restored_transitions_keep_source_counts_and_are_taught(self):
        manifest=json.loads((ROOT/'tools/progression_route_migrations.json').read_text(encoding='utf-8'))
        current=recipes()
        books={name:body for _,_,name,body in blocks(read_text(SCRIPTS/'HydrocraftReinvented/Books.txt'),'item')}
        expected={'Make Smelter':['item 50 [Base.ClayBrick]', 'item 4 [Base.BucketConcreteFull;Base.BucketCarvedConcreteFull]'],
                  'Make Lever':['item 1 [Hydrocraft.HCSteelrod;Base.SteelBar]',
                                'item 1 [Hydrocraft.HCSteelingot;Base.SteelIngot]', 'item 1 [Base.Screws]'],
                  'Make Copper Pipe':['item 1 [Hydrocraft.HCCoppersheetlarge]',
                                      'item 1 [Hydrocraft.HCWeldingset;Base.BlowTorch]'],
                  'Make Steel Pruning Shears':['item 1 [Hydrocraft.HCSteelingot;Base.SteelIngot]']}
        for row in manifest['restored']:
            body=current[row['recipe']]
            self.assertTrue(row['source_inputs'])
            self.assertIn('item '+str(row['count'])+' '+row['output']+',',body.split('outputs',1)[1])
            self.assertIn(row['recipe'],books[row['book'].split('.')[1]])
            self.assertIn('CanBeDoneFromFloor',body)
            for material in expected[row['recipe']]:self.assertIn(material+',',body)
        # Concrete was four uses in the original drainable input, not four buckets.
        self.assertNotIn('ItemCount',current['Make Smelter'])

    def test_native_material_ids_and_existing_loot_locations_are_real(self):
        game=find_game()
        names=declared(SCRIPTS)|declared(game/'media/scripts')
        source=read_text(SCRIPTS/'HydrocraftReinvented/HCR_ProgressionTransitions.txt')
        for name in re.findall(r'\bBase\.\w+',source):self.assertIn(name,names)
        native=read_text(game/'media/lua/server/Items/ProceduralDistributions.lua')
        placements=read_text(game/'media/lua/server/Items/Distributions.lua')
        for location in ['CrateTailoring','ToolStoreFarming','GardenStoreMisc']:
            self.assertRegex(native,r'\b'+location+r'\s*=\s*\{')
            self.assertIn('name="'+location+'"',re.sub(r'\s+','',placements))
        self.assertRegex(native,r'"CopperScrap",\s*[1-9]')
        self.assertRegex(native,r'"SmithingHammer",\s*[1-9]')
        self.assertRegex(native,r'"SteelIngot",\s*[1-9]')
        self.assertRegex(native,r'"ClayBrick",\s*[1-9]')

    def test_copper_and_hammer_paths_do_not_require_orphaned_mod_tools(self):
        current=recipes()
        for name,count in [('Forge Copper Sheet',1),('Forge Large Copper Sheet',2)]:
            self.assertIn('item '+str(count)+' [Hydrocraft.HCCopperingot;Base.CopperIngot;Base.CopperScrap],',current[name])
            self.assertIn('Base.SmithingHammer] mode:keep',current[name])
            self.assertIn('Base.StoneAnvil] mode:keep',current[name])
        for name in ['Forge Steel Crank','Make Small Rolling Mill','Make Iron Smithy Hammer','Make Steel Smithy Hammer']:
            self.assertIn('Base.SmithingHammer] mode:keep',current[name])
        for name in ['Make Lever','Make Steel Pruning Shears']:
            self.assertIn('tags[base:tongs;base:crudetongs] mode:keep',current[name])
        # No new native copper/steel metallurgy was invented to fix the bridge.
        added=read_text(SCRIPTS/'HydrocraftReinvented/HCR_ProgressionTransitions.txt')
        self.assertNotRegex(added,r'item\s+\d+\s+Base\.(?:SteelIngot|CopperScrap|CopperSheet)\s*,')


if __name__=='__main__':unittest.main(verbosity=2)
