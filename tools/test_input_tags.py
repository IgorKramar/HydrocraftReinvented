"""Registered custom tags must stay separate; generic boxes accept only clean stock."""
import json
import re
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, LUA, read_text, find_game

ROOT=Path(__file__).resolve().parents[1]


class InputTags(unittest.TestCase):
    def test_early_registry_uses_namespace_and_is_idempotent(self):
        lua=LuaRuntime()
        lua.execute('''
            tags={};calls=0
            ResourceLocation={of=function(id) return id:lower() end}
            ItemTag={get=function(id) return tags[id] end,register=function(id)
                assert(id:match("^hydrocraft:"));tags[id]={id=id};calls=calls+1
            end}
        ''')
        source=read_text(ROOT/'common/media/registries.lua')
        lua.execute(source);lua.execute(source)
        self.assertEqual(lua.globals().calls,9)
        self.assertFalse(lua.eval('tags["hydrocraft:potato"]==tags["hydrocraft:paperbagfull"]'))

    def test_every_migrated_assignment_and_lookup_is_namespaced(self):
        manifest=json.loads((ROOT/'tools/tag_migrations.json').read_text(encoding='utf-8'))
        for row in manifest['item_assignments']:
            items={n:b for _,_,n,b in blocks(read_text(SCRIPTS/'HydrocraftReinvented'/row['file']),'item')}
            self.assertIn(row['after'],items[row['item']])
        getters=read_text(LUA/'server/Recipe_GetItemTypes.lua')
        for old,new in manifest['custom_tags'].items():
            self.assertNotIn('getItemsTag("'+old+'")',getters)
        taters=read_text(SCRIPTS/'HydrocraftReinvented/HCR_Food Taters.txt')
        self.assertEqual(taters.count('[Base.Potato] tags[hydrocraft:potato]'),6)
        for file in ('HCR_Industrial.txt','HCR_Fishing.txt'):
            text=read_text(SCRIPTS/'HydrocraftReinvented'/file)
            self.assertNotIn('tags[BucketConcrete]',text)
            self.assertIn('[Base.BucketConcreteFull;Base.BucketCarvedConcreteFull],',text)

    def test_box_whitelist_is_author_reviewed_normal_nonfluid(self):
        manifest=json.loads((ROOT/'tools/boxing_materials.json').read_text(encoding='utf-8'))
        types={r['full_type'] for r in manifest['materials']}
        self.assertEqual(len(types),35)
        self.assertNotIn('Hydrocraft.BoxOfThings',types)
        definitions={}
        for source_root in (find_game()/'media/scripts',SCRIPTS):
            for path in source_root.rglob('*.txt'):
                source=read_text(path)
                module=re.search(r'\bmodule\s+(\w+)',source)
                if module:
                    for _,_,name,body in blocks(source,'item'):
                        definitions[module[1]+'.'+name]=body
        for full_type in types:
            self.assertRegex(definitions[full_type],r'ItemType\s*=\s*base:normal')
            self.assertNotIn('FluidContainer',definitions[full_type])
        script=read_text(SCRIPTS/'HydrocraftReinvented/HCR_Box.txt')
        for _,_,name,body in blocks(script,'craftRecipe'):
            if not name.startswith('Store '):continue
            self.assertIn('OnTest = HCRBox.IsStatelessMaterial',body)
            self.assertIn('flags[ItemCount;IsExclusive]',body)
            self.assertNotIn('tags[Box',body)
            selector=re.search(r'item\s+\d+\s+\[([^]]+)\]',body)[1]
            self.assertEqual(set(selector.split(';')),types)

    def test_box_guard_rejects_state_loss_and_nonmaterials(self):
        lua=LuaRuntime()
        lua.execute('''
            next=nil
            function makeItem(kind)
                local item={kind=kind,data={},condition=10,color={r=1,g=1,b=1,a=1},category="Item"}
                function item.color:getR() return self.r end
                function item.color:getG() return self.g end
                function item.color:getB() return self.b end
                function item.color:getAlphaFloat() return self.a end
                function item:getFullType() return self.kind end
                function item:getCategory() return self.category end
                function item:getFluidContainer() return self.fluid end
                function item:isCustomName() return self.custom or false end
                function item:isFavorite() return self.favorite or false end
                function item:isCustomWeight() return self.weighted or false end
                function item:isWet() return self.wet or false end
                function item:getCondition() return self.condition end
                function item:getConditionMax() return 10 end
                function item:getHaveBeenRepaired() return self.repairs or 0 end
                function item:getModData() return self.data end
                function item:getActualWeight() return self.weight or 0.1 end
                function item:getName() return self.name or "Staples" end
                function item:getCurrentUses() return self.uses or 1 end
                function item:getDisplayCategory() return "Material" end
                function item:getColor() return self.color end
                return item
            end
            function instanceItem(kind) return makeItem(kind) end
        ''')
        lua.execute(read_text(LUA/'shared/HCR_Boxing.lua'))
        lua.execute('item=makeItem("Hydrocraft.HCStaples")')
        self.assertTrue(lua.eval('HCRBox.IsStatelessMaterial(item,nil)'))
        for edit in ['item.condition=9','item.favorite=true','item.custom=true','item.data.note="stock"',
                     'item.repairs=1','item.fluid={}','item.weighted=true','item.wet=true','item.color.r=.5','item.color.a=.5',
                     'item.uses=2','item.name="Keep my name"','item.weight=.2',
                     'item.category="Food"','item.kind="Base.Potato"','item.kind="Hydrocraft.BoxOfThings"']:
            lua.execute('item=makeItem("Hydrocraft.HCStaples");'+edit)
            self.assertFalse(lua.eval('HCRBox.IsStatelessMaterial(item,nil)'),edit)


if __name__=='__main__':unittest.main(verbosity=2)
