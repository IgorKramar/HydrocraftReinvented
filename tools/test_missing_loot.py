"""Execute reachable loot registration and verify intact item/weight pairs."""
import json
import unittest

from lupa.lua51 import LuaRuntime

from audit_lua_item_ids import declared
from hcr_paths import LUA, SCRIPTS, find_game, read_text
from repair_missing_loot import MANIFEST, apply


class MissingLoot(unittest.TestCase):
    def test_manifest_entries_are_absent_not_arbitrary_replacements(self):
        names = declared(SCRIPTS) | declared(find_game() / 'media/scripts')
        manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['removals']), 20)
        for entry in manifest['removals']:
            self.assertNotIn(entry['item'], names)
            self.assertNotIn('replacement', entry)
        apply(check=True)

    def test_executed_distribution_pools_keep_item_weight_pairing(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            function require(_) end
            function lazy()
                return setmetatable({items={}}, {__index=function(t,k)
                    local value=lazy();rawset(t,k,value);return value
                end})
            end
            SuburbsDistributions=lazy();Distributions={lazy()}
            ProceduralDistributions={list=lazy()}
            Events={OnPreMapLoad={Add=function() end},OnLoad={Add=function(fn) fn() end}}
            function getTexture() end
            captured={}
            function capture(lists)
                for _,items in ipairs(lists) do captured[#captured+1]=items end
            end
            function insertItemListsInProcDistribution(_,lists) capture(lists) end
            function insertItemListsInDistribution(_,_,lists) capture(lists) end
            function insertItemListsInDistributionSafely(_,_,lists) capture(lists) end
            function insertJunkListsInProcDistribution(_,lists) capture(lists) end
            function setDistributionRolls() end
        ''')
        lua.execute(read_text(LUA/'server/Items/Distributions_HC.lua'))
        lua.execute(read_text(LUA/'server/Items/ProceduralDistributions_HC.lua'))
        pools = []
        for _, table in lua.globals().captured.items():
            pools.append(table)

        def collect(table):
            for key, value in table.items():
                if key == 'items':
                    pools.append(value)
                elif hasattr(value, 'items'):
                    collect(value)

        collect(lua.globals().SuburbsDistributions)
        names = declared(SCRIPTS) | declared(find_game()/'media/scripts')
        self.assertGreater(len(pools), 100)
        pairs = 0
        for table in pools:
            self.assertEqual(len(table) % 2, 0, 'orphaned numeric weight or ID: '+str(list(table.values())[-12:]))
            for i in range(1, len(table)+1, 2):
                self.assertIsInstance(table[i], str)
                self.assertIsInstance(table[i+1], (int,float))
                full_type = table[i] if '.' in table[i] else 'Base.' + table[i]
                self.assertTrue(full_type in names, 'absent active loot ID: '+full_type)
                pairs += 1
        self.assertGreater(pairs, 1000)
        # An empty obsolete shoe-box pool stays empty, with no invented footwear.
        self.assertEqual(len(lua.globals().SuburbsDistributions['HCShoebox']['items']), 0)

    def test_art_box_callback_cannot_select_removed_styrofoam(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(read_text(LUA/'server/HCLoot.lua'))
        lua.execute('''
            seen={}
            function ZombRand(_) return 5 end
            function HCItemGet(_,items)
                for _,item in ipairs(items) do seen[item]=true end
            end
            recipe_hclootart(nil,nil,{getInventory=function() return {AddItem=function() end} end})
        ''')
        self.assertIsNone(lua.globals().seen['Hydrocraft.HCStyrofoamball'])
        self.assertIsNone(lua.globals().seen['Hydrocraft.HCStyrofoamblock'])
        self.assertTrue(lua.globals().seen['Hydrocraft.HCPaintbrush'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
