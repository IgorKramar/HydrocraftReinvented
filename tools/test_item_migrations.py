"""Legacy normal-ID preservation and post-load chainmail migration regressions."""
import json
import re
import unittest
from pathlib import Path

from lupa.lua51 import LuaRuntime

from apply_playability_fixes import blocks

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / 'common/media/lua'
OLD = 'Hydrocraft.HCArmorchainmail'
NEW = OLD + 'Wearable'

MOCKS = r'''
function require(_) end
function isClient() return false end
function isServer() return true end
function instanceof(value, name) return value and value.class==name end
Events={LoadGridsquare={Add=function() end}, EveryTenMinutes={Add=function() end}, OnGameStart={Add=function() end}}
HCRTimedDefinitions={}
function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
local nextId=0
function makeItem(kind, clothing)
    nextId=nextId+1
    local item={kind=kind, clothing=clothing, data={}, condition=20, maxCondition=20,
                favorite=false, repaired=0, custom=false, name="Chainmail Armor",id=nextId}
    function item:getFullType() return self.kind end
    function item:getCategory() return self.child and "Container" or self.clothing and "Clothing" or "Normal" end
    function item:getModData() return self.data end
    function item:setConditionFrom(source) self.condition=self.maxCondition*source.condition/source.maxCondition end
    function item:getHaveBeenRepaired() return self.repaired end
    function item:setHaveBeenRepaired(value) self.repaired=value end
    function item:isFavorite() return self.favorite end
    function item:setFavorite(value) self.favorite=value end
    function item:isCustomName() return self.custom end
    function item:setCustomName(value) self.custom=value end
    function item:getName() return self.name end
    function item:setName(value) self.name=value end
    function item:getItemContainer() return self.child end
    return item
end
function instanceItem(kind)
    if missingTarget then return nil end
    return makeItem(kind,true)
end
function container(items, player)
    local c={items=items,player=player}
    function c:getCharacter() return self.player and {class="IsoPlayer"} end
    function c:getItems() return list(self.items) end
    function c:AddItem(item) self.items[#self.items+1]=item; item.container=self end
    function c:Remove(item)
        for i,v in ipairs(self.items) do if v==item then table.remove(self.items,i); item.container=nil; return end end
        error("absent source")
    end
    for _,item in ipairs(items) do item.container=c end
    return c
end
packets={}
function sendReplaceItemInContainer(c,old,new) packets[#packets+1]={container=c,old=old,new=new} end
function syncItemModData() error("migration should replace item, not publish timer data") end
function square(item)
    local object={item=item}
    function object:getItem() return self.item end
    function object:swapItem(new)
        new.id=self.item.id; self.item=new; self.swaps=(self.swaps or 0)+1
    end
    return {getObjects=function() return list({}) end,getWorldObjects=function() return list({object}) end},object
end
'''


class ItemMigrations(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        self.lua.execute((LUA/'shared/HCR_ItemMigrations.lua').read_text(encoding='utf-8'))
        self.lua.execute((LUA/'shared/HCR_TimedItems.lua').read_text(encoding='utf-8'))
        self.lua.execute((LUA/'server/HCR_TimedSystems.lua').read_text(encoding='utf-8'))

    def fixture(self):
        self.lua.execute('''
            old=makeItem("Hydrocraft.HCArmorchainmail",false)
            old.maxCondition=10;old.condition=7;old.repaired=2;old.favorite=true
            old.custom=true;old.name="Family chainmail";old.data.owner="survivor"
            old.data.nested={note="keep"}
        ''')

    def test_legacy_save_type_stays_normal_and_new_type_is_clothing(self):
        source=(ROOT/'common/media/scripts/HydrocraftReinvented/HCR_Armor.txt').read_text(encoding='utf-8')
        items={name:body for _,_,name,body in blocks(source,'item')}
        old,new=items['HCArmorchainmail'],items['HCArmorchainmailWearable']
        self.assertRegex(old,r'ItemType\s*=\s*base:normal')
        self.assertNotRegex(old,r'ClothingItem\s*=|Obsolete\s*=\s*true')
        self.assertRegex(new,r'ItemType\s*=\s*base:clothing')
        self.assertRegex(new,r'ClothingItem\s*=\s*HCArmorchainmail,')
        recipes={name:body for _,_,name,body in blocks(source,'craftRecipe')}
        self.assertIn('item 1 '+NEW+',',recipes['Make Armor'])
        self.assertIn('['+OLD+';'+NEW+']',recipes['Dismantle Chainmail Armor'])
        self.assertIn('InheritCondition;InheritFavorite',recipes['Prepare Chainmail Armor'])

    def test_migration_preserves_condition_repairs_metadata_name_and_favorite(self):
        self.fixture()
        self.lua.execute('new=HCRItemMigrations.newReplacement(old)')
        item=self.lua.globals().new
        self.assertEqual(item.kind,NEW)
        self.assertEqual(item.condition,14)
        self.assertEqual(item.repaired,2)
        self.assertTrue(item.favorite)
        self.assertEqual(item.name,'Family chainmail')
        self.assertEqual(item.data.owner,'survivor')
        self.assertEqual(item.data.nested.note,'keep')
        self.assertIsNone(self.lua.eval('HCRItemMigrations.newReplacement(new)'))

    def test_unavailable_target_keeps_loaded_stock(self):
        self.fixture()
        self.lua.execute('missingTarget=true; c=container({old},true); HCRTimed.updateContainer(c,0,0)')
        self.assertEqual(self.lua.eval('#c.items'),1)
        self.assertEqual(self.lua.eval('c.items[1].kind'),OLD)
        self.assertEqual(self.lua.eval('#packets'),0)

    def test_post_load_player_inventory_replaces_stock_once(self):
        self.fixture()
        self.lua.execute('c=container({old},true);HCRTimed.updateContainer(c,0,0);HCRTimed.updateContainer(c,1,0)')
        self.assertEqual(self.lua.eval('#c.items'),1)
        self.assertEqual(self.lua.eval('c.items[1].kind'),NEW)
        self.assertEqual(self.lua.eval('#packets'),1)
        self.assertEqual(self.lua.eval('c.items[1].data.owner'),'survivor')

    def test_nested_furniture_stock_uses_addressable_outer_bag_packet(self):
        self.fixture()
        self.lua.execute('''
            child=container({old},false); bag=makeItem("Bag",false);bag.child=child
            outer=container({bag},false);HCRTimed.updateContainer(outer,0,0)
        ''')
        self.assertEqual(self.lua.eval('child.items[1].kind'),NEW)
        self.assertEqual(self.lua.eval('#packets'),1)
        self.assertTrue(self.lua.eval('packets[1].old==bag and packets[1].new==bag'))

    def test_ground_stock_uses_native_world_swap_preserving_identity(self):
        self.fixture()
        self.lua.execute('sq,obj=square(old);oldId=old.id;HCRTimed.updateSquare(sq,0);HCRTimed.updateSquare(sq,1)')
        self.assertEqual(self.lua.eval('obj.item.kind'),NEW)
        self.assertEqual(self.lua.eval('obj.item.id'),self.lua.globals().oldId)
        self.assertEqual(self.lua.eval('obj.swaps'),1)

    def test_free_conversion_callback_preserves_old_stock_state(self):
        self.fixture()
        self.lua.execute('''
            new=instanceItem("Hydrocraft.HCArmorchainmailWearable")
            HCRItemMigrations.PrepareChainmail({getAllConsumedItems=function() return list({old}) end,
                getAllCreatedItems=function() return list({new}) end},nil)
        ''')
        self.assertEqual(self.lua.globals().new.condition,14)
        self.assertEqual(self.lua.globals().new.name,'Family chainmail')
        self.assertEqual(self.lua.globals().new.data.owner,'survivor')

    def test_russian_conversion_and_new_item_are_named(self):
        base=ROOT/'common/media/lua/shared/Translate/RU'
        self.assertTrue(json.loads((base/'ItemName.json').read_text(encoding='utf-8'))[NEW])
        self.assertTrue(json.loads((base/'Recipes.json').read_text(encoding='utf-8'))['Prepare Chainmail Armor'])


if __name__=='__main__':
    unittest.main(verbosity=2)
