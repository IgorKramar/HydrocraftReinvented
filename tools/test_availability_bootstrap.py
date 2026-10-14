"""Availability restorations use real placed pools and preserve recipe gates."""
import json
import re
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import HERE, LUA, SCRIPTS, find_game, read_text
from audit_lua_item_ids import declared
from apply_playability_fixes import blocks
from reachability_support import callback_outputs

class AvailabilityBootstrap(unittest.TestCase):
    def test_real_native_pools_weights_and_idempotency(self):
        game=find_game()
        manifest=json.loads(read_text(HERE/'availability_bootstrap.json'))
        names=declared(SCRIPTS)|declared(game/'media/scripts')
        distributions=read_text(game/'media/lua/server/Items/Distributions.lua')
        lua=LuaRuntime(unpack_returned_tuples=True)
        # Unrelated world-clutter junk references do not participate in these item pools.
        lua.execute('function require(_) end; ClutterTables = {}; BagsAndContainers = {}')
        lua.execute(read_text(game/'media/lua/server/Items/ProceduralDistributions.lua'))
        script=read_text(LUA/'server/Items/HCR_AvailabilityLoot.lua')
        self.assertEqual(len(manifest['seeds']),23)
        before={row['pool']:len(lua.globals().ProceduralDistributions.list[row['pool']]['items'])
                for row in manifest['seeds']}
        lua.execute(script)
        for row in manifest['seeds']:
            self.assertIn(row['item'],names)
            self.assertNotIn(row['item'],manifest['excluded'])
            self.assertNotRegex(row['item'],r'(dead|male|female)$')
            self.assertIn(row['weight'],(.1,.2))
            self.assertRegex(distributions,r'"'+re.escape(row['pool'])+'"')
            values=lua.globals().ProceduralDistributions.list[row['pool']]['items']
            self.assertEqual(len(values)%2,0)
            matches=[values[i+1] for i in range(1,len(values)+1,2) if values[i]==row['item']]
            self.assertEqual(matches,[row['weight']])
        after={pool:len(lua.globals().ProceduralDistributions.list[pool]['items']) for pool in before}
        lua.execute(script)
        self.assertEqual(after,{pool:len(lua.globals().ProceduralDistributions.list[pool]['items']) for pool in before})

    def test_trip_hammer_anvil_is_consumed_and_gates_unchanged(self):
        body=next(body for _,_,name,body in blocks(read_text(SCRIPTS/'HydrocraftReinvented/HCR_Industrial.txt'),'craftRecipe') if name=='Build Trip Hammer')
        self.assertIn('SkillRequired = Woodwork:8;Mechanics:3',body)
        self.assertIn('NeedToBeLearn = true',body)
        self.assertIn('time = 1000',body)
        line=next(line.strip() for line in body.splitlines() if 'item 1 [Hydrocraft.HCAnvil;' in line)
        self.assertEqual(line,'item 1 [Hydrocraft.HCAnvil;Base.BlacksmithAnvil;Base.BenchAnvil;Base.BlockAnvil],')
        self.assertIn('item 1 Hydrocraft.HCTriphammer,',body)
        self.assertIn('item 12 [Base.Nails]',body)
        self.assertIn('item 2 [Hydrocraft.HCWoodbeam]',body)
        self.assertIn('item 4 [Base.Plank]',body)
        self.assertNotIn('item 1 Hydrocraft.HCAnvil,',body)

    def test_existing_rewards_are_linked_to_live_callbacks(self):
        outputs=callback_outputs()
        self.assertIn('Hydrocraft.HCRubberscrap',set().union(*outputs.values()))
        bridge=read_text(LUA/'server/zzz_HCR42_RecipeCode.lua')
        self.assertIn('HCR42["HC_ToyStatModifier"]',bridge)
        music=read_text(SCRIPTS/'HydrocraftReinvented/HCR_Music.txt')
        self.assertIn('OnCreate = HCR42.HC_ToyStatModifier',music)

if __name__=='__main__':unittest.main(verbosity=2)
