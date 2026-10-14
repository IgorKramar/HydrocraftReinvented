"""Timer transitions and live recipe callbacks are conditional producer edges."""
import tempfile
import unittest
from pathlib import Path
from reachability_support import timer_edges, callback_outputs, apply_timer_edges


class IndirectReachability(unittest.TestCase):
    def test_timer_target_requires_reachable_source(self):
        reachable={'Hydrocraft.Seedling'}
        edges={'Hydrocraft.Seedling':'Hydrocraft.Ready','Hydrocraft.Ready':'Hydrocraft.Dead'}
        declared={'Hydrocraft.Seedling','Hydrocraft.Ready','Hydrocraft.Dead'}
        self.assertTrue(apply_timer_edges(reachable,edges,declared))
        self.assertIn('Hydrocraft.Ready',reachable)
        self.assertNotIn('Hydrocraft.Dead',reachable)
        self.assertTrue(apply_timer_edges(reachable,edges,declared))
        empty=set()
        self.assertFalse(apply_timer_edges(empty,edges,declared))

    def test_current_shared_timer_table_is_loaded(self):
        edges=timer_edges()
        self.assertEqual(edges['Hydrocraft.HCBeehive3bActive'],'Hydrocraft.HCBeehive3bfull')
        self.assertEqual(edges['Hydrocraft.HCPottedoregano'],'Hydrocraft.HCPottedoreganoready')
        self.assertGreater(len(edges),260)

    def test_only_linked_callback_additions_are_outputs(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);scripts=root/'scripts';scripts.mkdir();lua=root/'lua';(lua/'server').mkdir(parents=True)
            (scripts/'test.txt').write_text('''module Hydrocraft {
                craftRecipe Dismantle
                {
                    OnCreate = HCR42.dismantle,
                    inputs { item 1 [Hydrocraft.Machine], }
                }
            }''',encoding='utf-8')
            (lua/'server/zzz_HCR42_RecipeCode.lua').write_text('HCR42["dismantle"] = wrap("actualDismantle")',encoding='utf-8')
            (lua/'server/callback.lua').write_text('''function actualDismantle(items, result, player)
                if items:get(0):getFullType() == "Hydrocraft.Machine" then
                    player:getInventory():AddItems("Hydrocraft.Scrap",3)
                end
            end
            function removedAnimalRecipe()
                player:getInventory():AddItem("Hydrocraft.LegacyAnimal")
            end''',encoding='utf-8')
            outputs=callback_outputs(scripts,lua)
            self.assertEqual(outputs,{'Dismantle':{'Hydrocraft.Scrap'}})

    def test_current_callback_materials_have_live_producers(self):
        from hcr_paths import SCRIPTS, read_text
        from apply_playability_fixes import blocks
        materials={'Hydrocraft.'+name for _,_,name,_ in blocks(
            read_text(SCRIPTS/'HydrocraftReinvented/HCR_CallbackMaterials.txt'),'item')}
        produced=set().union(*callback_outputs().values())
        self.assertEqual(len(materials),9)
        self.assertFalse(materials-produced)


if __name__=='__main__':unittest.main(verbosity=2)
