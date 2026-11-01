"""All legacy water stocks and recipe boundaries, including ground-owned FC."""
import json
import math
import re
import struct
import unittest
from pathlib import Path

from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from build_water_catalog import collect
from convert_water_recipes import water_guard
from hcr_paths import LUA, SCRIPTS
from test_item_migrations import MOCKS
from test_fluid_migrations import FLUID_MOCKS


class WaterFamilies(unittest.TestCase):
    def test_all_old_classes_and_remaining_stocks_are_preserved(self):
        records, targets, migrations = collect()
        self.assertEqual(len(targets), 82)
        self.assertEqual(len(migrations), 122)
        self.assertIn('HCWoodenbarrelFluid',records)
        self.assertNotIn('HCWoodenbarrelFluid',migrations)
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(MOCKS+FLUID_MOCKS)
        lua.globals().float32 = lambda x: struct.unpack('f', struct.pack('f', x))[0]
        lua.globals().capacities = lua.table_from({'Hydrocraft.'+k+'Fluid':v['capacity'] for k,v in targets.items()})
        lua.execute('''
            function isServer() return false end
            function instanceItem(kind)
                local item=makeItem(kind,false)
                if capacities[kind] then
                    item.fluid=makeFluid();item.fluid.capacity=capacities[kind]
                    local add=item.fluid.addFluid
                    function item.fluid:addFluid(kind, amount)
                        add(self,kind,amount);self.liquids[kind]=float32(self.liquids[kind])
                    end
                end
                return item
            end
        ''')
        for name in ('HCR_WaterFamilies','HCR_FluidMigrations','HCR_ItemMigrations'):
            lua.execute((LUA/'shared'/f'{name}.lua').read_text(encoding='utf-8'))
        for kind, spec in migrations.items():
            max_uses = math.floor(1/float(records[kind]['properties'].get('usedelta','.03125'))+.5)
            for uses in set((0,1,max(0,max_uses-1),max_uses)):
                with self.subTest(kind=kind, uses=uses):
                    lua.globals().kind='Hydrocraft.'+kind
                    lua.globals().uses=uses
                    lua.execute('old=makeItem(kind,false);old.uses=uses;old.favorite=true;old.data.note="keep";new=HCRItemMigrations.newReplacement(old)')
                    new=lua.globals().new
                    self.assertIsNotNone(new)
                    self.assertEqual(new.kind,'Hydrocraft.'+spec['target'])
                    self.assertAlmostEqual(new.fluid.getAmount(new.fluid),uses*spec['unitLitres'],delta=.00001)
                    self.assertTrue(new.favorite)
                    self.assertEqual(new.data.note,'keep')
                    self.assertEqual(lua.globals().old.uses,uses)

    def test_plain_water_works_without_next_global(self):
        lua=LuaRuntime()
        lua.execute('function require() end; next=nil; Fluid={Get=function(x) return x end}')
        lua.execute((LUA/'shared/HCR_FluidQuality.lua').read_text(encoding='utf-8'))
        lua.execute('''
            HCRFluidQuality.transport={HCRJuiceApple=true}
            item={getModData=function() return {} end}
            fluid={getSpecificFluidAmount=function() return 0 end}
        ''')
        self.assertFalse(lua.eval('HCRFluidQuality.active(item,fluid)'))
        lua.execute('fluid.getSpecificFluidAmount=function() return .01 end')
        self.assertTrue(lua.eval('HCRFluidQuality.active(item,fluid)'))


class WaterRecipes(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            Fluid={Water="Water",TaintedWater="TaintedWater"}
            HCRFluidQuality={fluid=function(i) return i.fluid end,
                active=function(i) return i.tracked or false end,sync=function() end}
            function fixture(kind,amount,ground)
                local i={kind=kind,amount=amount,ground=ground,capacity=1.4,tainted=amount}
                function i:getFullType() return self.kind end
                function i:getWorldItem() return self.ground end
                function i:syncItemFields() end
                local f={}
                function f:getAmount() return i.amount end
                function f:getCapacity() return i.capacity end
                function f:isEmpty() return i.amount==0 end
                function f:getSpecificFluidAmount(kind)
                    return kind=="TaintedWater" and i.tainted or i.amount-i.tainted
                end
                function f:Empty() i.amount=0;i.tainted=0 end
                function f:addFluid(kind,n) i.amount=i.amount+n;if kind=="TaintedWater" then i.tainted=i.tainted+n end end
                i.fluid=f
                return i
            end
            function data(item) return {getAllInputItems=function() return {
                size=function() return 1 end,get=function() return item end} end} end
        ''')
        for name in ('HCR_WaterRecipeRules','HCR_FluidRecipes'):
            self.lua.execute((LUA/'shared'/f'{name}.lua').read_text(encoding='utf-8'))
        self.rules=json.loads(Path('tools/water_recipe_rules.json').read_text(encoding='utf-8'))

    def rule(self,name):
        token=next(k for k,v in self.rules.items() if v['name']==name)
        return self.lua.globals().HCRWaterRecipeRules[token]

    def test_every_empty_alternative_is_guarded_on_the_ground(self):
        for path in SCRIPTS.rglob('*.txt'):
            for _,_,name,body in blocks(path.read_text(encoding='utf-8-sig'),'craftRecipe'):
                token=water_guard(body)
                if not token:continue
                for line in body.splitlines():
                    if 'IsEmpty' not in line:continue
                    for selection in re.findall(r'item \d+ \[([^]]+)\]',line):
                        for kind in selection.split(';'):
                            with self.subTest(recipe=name, kind=kind):
                                self.assertIn(kind,self.rules[token]['empty'])
                                item=self.lua.globals().fixture(kind,.1,True)
                                self.assertFalse(self.lua.globals().HCRFluidRecipes.test(self.rule(name),item,None))

    def test_purification_retains_identity_actual_volume_and_rejects_quality(self):
        rule=self.rule('Purify Water')
        kind=next(iter(rule.water))
        item=self.lua.globals().fixture(kind,.37,True)
        create=self.lua.globals().HCRFluidRecipes.create
        create(rule,self.lua.globals().data(item),None)
        self.assertAlmostEqual(item.amount,.37)
        self.assertEqual(item.tainted,0)
        item.tracked=True
        self.assertFalse(self.lua.globals().HCRFluidRecipes.test(rule,item,None))

    def test_dropper_adds_only_one_use_and_refuses_overflow(self):
        rule=self.rule('Put Water In Beaker (Beaker With Water)')
        # Old return-dropper callback is independently covered by the native lab.
        rule.previousCreate=None
        item=self.lua.globals().fixture('Hydrocraft.HCGlassbeakerFluid',1.2,False)
        self.lua.globals().HCRFluidRecipes.create(rule,self.lua.globals().data(item),None)
        self.assertAlmostEqual(item.amount,1.3)
        item.amount=1.35
        self.assertFalse(self.lua.globals().HCRFluidRecipes.test(rule,item,None))


if __name__=='__main__':unittest.main(verbosity=2)
