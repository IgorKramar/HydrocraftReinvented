"""Execute every retained ready-plant harvest and validate its dynamic outputs."""
import unittest
from lupa.lua51 import LuaRuntime
from audit_lua_item_ids import declared
from hcr_paths import SCRIPTS, LUA, find_game, read_text


class Harvest(unittest.TestCase):
    def test_every_ready_plant_produces_real_items(self):
        names = declared(SCRIPTS) | declared(find_game() / 'media/scripts')
        plants = sorted(name for name in declared(SCRIPTS)
                        if name.startswith('Hydrocraft.HCPotted') and name.endswith('ready'))
        lua = LuaRuntime()
        lua.execute(read_text(LUA / 'shared/PlantsGrowing.lua'))
        for plant in plants:
            with self.subTest(plant=plant):
                outputs = []
                lua.globals().collect = lambda name: outputs.append(name)
                lua.globals().plantType = plant.split('.')[1]
                lua.execute('''
                  local plant={getType=function() return plantType end}
                  local inputs={size=function() return 1 end, get=function() return plant end}
                  local inv={AddItem=function(_,name) collect(name) end}
                  recipe_NDPlantsHarvest(inputs,nil,{getInventory=function() return inv end})
                ''')
                self.assertTrue(outputs, 'harvest returned no produce or seeds')
                for name in outputs:
                    self.assertTrue(name in names, f'{plant} produces missing {name}')


if __name__ == '__main__':
    unittest.main(verbosity=2)
