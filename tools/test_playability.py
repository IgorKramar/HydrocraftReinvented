"""Регрессии конкретных репортов сообщества. Требует lupa (Lua 5.1).

Не заменяет проверку в движке. Запуск: python tools/test_playability.py.
"""
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from apply_playability_fixes import blocks
from hcr_paths import LUA, SCRIPTS, read_text

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit('Установите lupa в отдельное dev-окружение: pip install lupa')


class Playability(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.items, cls.recipes = {}, {}
        for path in sorted(SCRIPTS.rglob('*.txt')):
            text = read_text(path)
            for kind, target in [('item', cls.items), ('craftRecipe', cls.recipes)]:
                for _, _, name, body in blocks(text, kind):
                    target[name] = body

    def test_all_lua_compiles_on_51(self):
        lua = LuaRuntime()
        compile_lua = lua.eval('function(s, name) local fn, err = loadstring(s, name); return fn ~= nil, err end')
        for path in LUA.rglob('*.lua'):
            with self.subTest(file=str(path)):
                ok, error = compile_lua(read_text(path), str(path))
                self.assertTrue(ok, error)

    def test_all_items_have_native_type(self):
        for name, body in self.items.items():
            with self.subTest(item=name):
                self.assertRegex(body, r'ItemType\s*=\s*base:\w+')

    def test_pack_pop_consumes_six_whole_cans(self):
        for name, body in self.recipes.items():
            if name.startswith('Pack Pop'):
                self.assertRegex(body, r'item 6 \[[^\]]+\] flags\[ItemCount\]')

    def test_corn_consumes_one_whole_cob(self):
        for name, body in self.recipes.items():
            if name.startswith('Shuck Corn'):
                self.assertRegex(body, r'item 1 \[[^\]]+\] flags\[ItemCount\]')
                self.assertIn('item 20 ', body)
                self.assertIn('time = 40,', body)

    def test_rope_is_returned_once(self):
        body = self.recipes['Unpack Lumber Stack']
        self.assertIn('item 1 Base.Rope,', body)
        self.assertNotIn('recipe_hcrope', body)
        self.assertIn('CanBeDoneFromFloor', body)

    def test_shower_accepts_current_bucket(self):
        self.assertIn('[Base.Bucket]', self.recipes['Build Makeshift Shower'])

    def test_removed_trait_api_does_not_stop_scavenging(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
          CharacterTrait = {HERBALIST = "base:herbalist"}
          CharacterStat = {FATIGUE = "fatigue"}
          Perks = {PlantScavenging = "foraging"}
          function require(_) return true end
          function ZombRand(n) return 0 end
          function getGameTime() return {getMonth = function() return 6 end} end
          found = {}
          local inv = {AddItem = function(_, item) table.insert(found, item); return {} end,
            AddItems = function(_, item, count) for i=1,count do table.insert(found, item) end end}
          player = {getInventory = function() return inv end,
            getPerkLevel = function() return 0 end,
            getStats = function() return {add = function() end} end,
            isOutside = function() return true end, Say = function() end,
            hasTrait = function() return false end}
        ''')
        lua.execute(read_text(LUA / 'shared/HCR_Compatibility.lua'))
        for path in ['FloraHCExtra.lua', 'JunkyardExtra.lua']:
            lua.execute(read_text(LUA / 'server' / path))
        lua.execute('HCFloraGather(nil,nil,player); hcjunksearchsmall(nil,nil,player); hcmetalsearch(nil,nil,player)')
        self.assertGreater(len(lua.globals().found), 0)
        self.assertFalse(lua.eval('HCR.hasTrait(player, "Lucky")'))

    def test_offline_growth_catches_up_without_resetting_age(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('function require(_) return true end')
        lua.execute(read_text(LUA / 'shared/HCR_TimedDefinitions.lua'))
        lua.execute(read_text(LUA / 'shared/HCR_TimedItems.lua'))
        resolve = lua.globals().HCRTimed.resolve
        self.assertEqual(resolve('Hydrocraft.HCPottedtomatosmall', 0, 170),
                         ('Hydrocraft.HCPottedtomatoready', 144))
        self.assertEqual(resolve('Hydrocraft.HCPottedtomatosmall', 0, 200),
                         ('Hydrocraft.HCPottedtomatodead', 192))
        self.assertEqual(resolve('Hydrocraft.HCCheeserackfull', 20, 188),
                         ('Hydrocraft.HCCheeserackaged', 188))
        self.assertEqual(resolve('Hydrocraft.HCBeehive3bActive', 20, 188),
                         ('Hydrocraft.HCBeehive3bfull', 188))
        self.assertEqual(resolve('Hydrocraft.HCPottedtomatosmall', 100, 90),
                         ('Hydrocraft.HCPottedtomatosmall', 90))
        # Многолетнее отсутствие: циклическое дерево считается без тысяч итераций.
        self.assertEqual(resolve('Hydrocraft.HCPottedappletree', 0, 5000),
                         ('Hydrocraft.HCPottedappletree', 4968))

    def test_timed_targets_and_harvest_states_are_defined(self):
        lua = LuaRuntime()
        lua.execute(read_text(LUA / 'shared/HCR_TimedDefinitions.lua'))
        targets = set()
        for name, transition in lua.globals().HCRTimedDefinitions.items():
            self.assertIn(name.split('.', 1)[1], self.items)
            self.assertIn(transition.target.split('.', 1)[1], self.items)
            self.assertGreater(transition.hours, 0)
            targets.add(transition.target.split('.', 1)[1])
        for name in self.items:
            if name.startswith('HCPotted') and name.endswith('ready'):
                self.assertIn(name, targets)

    def test_clothing_assets_are_registered(self):
        media = LUA.parents[0]
        entries = {entry.findtext('path'): entry.findtext('guid')
                   for entry in ET.parse(media / 'fileGuidTable.xml').getroot()}
        for path in (media / 'clothing/clothingItems').glob('*.xml'):
            relative = 'media/' + path.relative_to(media).as_posix()
            self.assertEqual(entries[relative], ET.parse(path).getroot().findtext('m_GUID'))
        self.assertEqual(len(set(entries.values())), len(entries))

    def test_box_packing_consumes_contents(self):
        for body in self.recipes.values():
            self.assertNotRegex(body, r'tags\[Box(?:12|25|50|100)\] mode:keep')

    def test_bridge_passes_kept_inputs_in_recipe_order(self):
        lua = LuaRuntime()
        lua.execute('''
          function require(_) return true end
          function getGameTime() return {getWorldAgeHours=function() return 1 end} end
          HCRTimed = {initialize=function() end}
          HCRFood = {tryOnCreate=function() return false end}
          all = {}; consumed = {}
          results = {size=function() return 0 end}
          recipe = {getAllCreatedItems=function() return results end,
            getAllInputItems=function() return all end,
            getAllConsumedItems=function() return consumed end}
          function HCHuntSmallGame(items) huntingInputs = items end
          Hydrocraft = {OnCreate={GenericFood=function(items) foodInputs=items end}}
        ''')
        lua.execute(read_text(LUA / 'server/zzz_HCR42_RecipeCode.lua'))
        lua.execute('HCR42.HCHuntSmallGame(recipe,{}); HCR42.Hydrocraft_OnCreate_GenericFood(recipe,{})')
        self.assertTrue(lua.eval('huntingInputs == all'))
        self.assertTrue(lua.eval('foodInputs == consumed'))

    def test_food_conversion_consumes_whole_input(self):
        for name in ['Make Hashbrowns', 'Serve in Paper Bag', 'Empty Paper Bag']:
            self.assertNotRegex(self.recipes[name], r'tags\[(?:Potato|ServeInPaperBag|PaperBagFull)\] mode:keep')
            self.assertRegex(self.recipes[name], r'flags\[ItemCount(?:;[^\]]+)?\]')

    def test_stat_units_and_callback_player(self):
        lua = LuaRuntime()
        lua.execute('''
          CharacterStat = {BOREDOM="b", UNHAPPINESS="u", STRESS="s", PANIC="p"}
          function require(_) return true end
          values = {b=50,u=50,s=0.8,p=50}
          player = {getStats = function() return {
            remove=function(_,k,n) values[k]=values[k]-n end,
            add=function(_,k,n) values[k]=values[k]+n end} end}
        ''')
        lua.execute(read_text(LUA / 'server/HCExtra.lua'))
        lua.execute('HCDoStats(player,10,6,5); HCBetaBlocker(nil,nil,player)')
        values = lua.globals()['values']
        self.assertEqual(values.b, 40)
        self.assertEqual(values.u, 44)
        self.assertAlmostEqual(values.s, 0.75)
        self.assertEqual(values.p, 40)


if __name__ == '__main__':
    unittest.main(verbosity=2)
