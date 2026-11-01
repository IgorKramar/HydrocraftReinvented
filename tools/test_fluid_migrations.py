"""Save-stock conservation and server-owned native-water migration regressions."""
import re
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
from test_item_migrations import MOCKS

ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'common/media/lua'
EMPTY='Hydrocraft.HCWaterflask'
FULL=EMPTY+'full'
NATIVE=EMPTY+'Fluid'

FLUID_MOCKS=r'''
Fluid={Water="Water",TaintedWater="TaintedWater",Petrol="Petrol"}
function makeFluid()
    local f={liquids={},capacity=1.4}
    function f:getCapacity() return self.capacity end
    function f:getAmount() local n=0;for _,v in pairs(self.liquids) do n=n+v end;return n end
    function f:getSpecificFluidAmount(kind) return self.liquids[kind] or 0 end
    function f:addFluid(kind,amount)
        if kind~="Water" and kind~="TaintedWater" then return end
        self.liquids[kind]=(self.liquids[kind] or 0)+math.min(amount,self.capacity-self:getAmount())
    end
    function f:copyFluidsFrom(source)
        for kind,amount in pairs(source.liquids) do self:addFluid(kind,amount) end
    end
    return f
end
local originalMake=makeItem
function makeItem(kind,clothing)
    local item=originalMake(kind,clothing)
    item.uses=14
    function item:getCurrentUses() return self.uses end
    function item:getFluidContainer() return self.fluid end
    function item:getWorldItem() return self.world end
    function item:isEquipped() return self.equipped==true end
    if kind=="Hydrocraft.HCWaterflaskFluid" and not missingComponent then item.fluid=makeFluid() end
    return item
end
function instanceItem(kind)
    if missingTarget then return nil end
    return makeItem(kind,kind=="Hydrocraft.HCArmorchainmailWearable")
end
ComponentType={FluidContainer="FluidContainer"}
IsoObjectChange={SWAP_ITEM="SWAP_ITEM"}
GameEntityFactory={TransferComponent=function(source,target,_)
    target.fluid=source.fluid;source.fluid=nil
end}
local originalSquare=square
function square(item)
    local s,o=originalSquare(item)
    local originalSwap=o.swapItem
    o.snapshots={};item.world=o
    function o:getFluidContainer() return self.fluid end
    function o:swapItem(new)
        if self.fluid then GameEntityFactory.TransferComponent(self,self.item,ComponentType.FluidContainer) end
        self.item.world=nil
        originalSwap(self,new);new.world=self
        if new.fluid then GameEntityFactory.TransferComponent(new,self,ComponentType.FluidContainer) end
        if isServer() then self:sendObjectChange(IsoObjectChange.SWAP_ITEM) end
    end
    function o:sendObjectChange(change)
        if failSend then error("test send failure") end
        self.snapshots[#self.snapshots+1]={kind=self.item.kind,
            amount=self.item.fluid and self.item.fluid:getAmount() or -1}
    end
    return s,o
end
'''

class FluidMigrations(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS+FLUID_MOCKS)
        self.lua.execute('function isServer() return false end')
        for name in ['shared/HCR_ItemNames.lua','shared/HCR_WaterFamilies.lua','shared/HCR_FluidMigrations.lua','shared/HCR_ItemMigrations.lua',
                     'shared/HCR_TimedItems.lua','server/HCR_TimedSystems.lua']:
            self.lua.execute((LUA/name).read_text(encoding='utf-8'))

    def migrate(self,kind=FULL,uses=14):
        self.lua.globals().sourceKind=kind
        self.lua.globals().uses=uses
        self.lua.execute('old=makeItem(sourceKind,false);old.uses=uses;new=HCRItemMigrations.newReplacement(old)')
        return self.lua.globals().new

    def test_native_descriptor_is_empty_and_old_classes_are_unchanged(self):
        from apply_playability_fixes import blocks
        text=(ROOT/'common/media/scripts/HydrocraftReinvented/HCR_Leatherworking.txt').read_text(encoding='utf-8')
        items={n:b for _,_,n,b in blocks(text,'item')}
        self.assertRegex(items['HCWaterflask'],r'ItemType\s*=\s*base:normal')
        self.assertRegex(items['HCWaterflaskfull'],r'ItemType\s*=\s*base:drainable')
        descriptor=(ROOT/'common/media/scripts/HydrocraftReinvented/HCR_FluidContainers.txt').read_text()
        self.assertIn('Capacity = 1.4',descriptor)
        self.assertIn('fluid = Water/TaintedWater',descriptor)
        self.assertNotRegex(descriptor,r'\bFluids\s*\{')
        recipes={n:b for _,_,n,b in blocks(text,'craftRecipe')}
        self.assertIn('item 1 '+NATIVE,recipes['Make Waterflask'])
        self.assertIn('item 2 [Hydrocraft.HCLeather]',recipes['Make Waterflask'])

    def test_full_stock_preserves_fourteen_units_as_unpurified_water(self):
        item=self.migrate()
        self.assertAlmostEqual(item.fluid.getAmount(item.fluid),1.4)
        self.assertAlmostEqual(item.fluid.liquids.TaintedWater,1.4)
        self.assertIsNone(item.fluid.liquids.Water)

    def test_partial_and_zero_stock(self):
        for uses in [0,1,7,13]:
            with self.subTest(uses=uses):
                item=self.migrate(uses=uses)
                self.assertAlmostEqual(item.fluid.getAmount(item.fluid),uses*.1)
        self.assertAlmostEqual(self.migrate(EMPTY).fluid.getAmount(self.lua.globals().new.fluid),0)

    def test_existing_fractional_mixture_is_preserved(self):
        self.lua.execute('''old=makeItem("Hydrocraft.HCWaterflask",false);old.fluid=makeFluid()
            old.fluid:addFluid(Fluid.Water,.323);old.fluid:addFluid(Fluid.TaintedWater,.177)
            new=HCRItemMigrations.newReplacement(old)''')
        fluid=self.lua.globals().new.fluid
        self.assertAlmostEqual(fluid.liquids.Water,.323)
        self.assertAlmostEqual(fluid.liquids.TaintedWater,.177)

    def test_world_owned_fluid_is_preserved(self):
        self.lua.execute('''old=makeItem("Hydrocraft.HCWaterflaskfull",false)
            local f=makeFluid();f:addFluid(Fluid.Water,.625)
            old.world={getFluidContainer=function() return f end}
            new=HCRItemMigrations.newReplacement(old)''')
        self.assertAlmostEqual(self.lua.globals().new.fluid.liquids.Water,.625)

    def test_existing_empty_component_overrides_stale_legacy_uses(self):
        for location in ['old.fluid=f', 'old.world={getFluidContainer=function() return f end}']:
            with self.subTest(location=location):
                self.lua.execute('''old=makeItem("Hydrocraft.HCWaterflaskfull",false);old.uses=7
                    local f=makeFluid();'''+location+'''
                    new=HCRItemMigrations.newReplacement(old)''')
                self.assertAlmostEqual(self.lua.eval('new.fluid:getAmount()'),0)

    def test_multiplayer_defers_held_stock_then_migrates_after_unequip(self):
        self.lua.execute('''function isServer() return true end
            old=makeItem("Hydrocraft.HCWaterflaskfull",false);old.uses=7;old.equipped=true
            c=container({old},true);HCRTimed.updateContainer(c,0,0)
            ''')
        self.assertTrue(self.lua.eval('c.items[1]==old'))
        self.assertEqual(self.lua.eval('old.uses'),7)
        self.assertEqual(self.lua.eval('#packets'),0)
        self.lua.execute('old.equipped=false;HCRTimed.updateContainer(c,0,0);HCRTimed.updateContainer(c,1,0)')
        self.assertEqual(self.lua.eval('c.items[1].kind'),NATIVE)
        self.assertAlmostEqual(self.lua.eval('c.items[1].fluid:getAmount()'),.7)
        self.assertEqual(self.lua.eval('#packets'),1)

    def test_server_ground_snapshot_contains_fluid_and_restores_world_owner(self):
        self.lua.execute('''function isServer() return true end
            old=makeItem("Hydrocraft.HCWaterflaskfull",false);old.uses=3
            s,o=square(old);HCRTimed.updateSquare(s,0);HCRTimed.updateSquare(s,1)''')
        self.assertEqual(self.lua.eval('#o.snapshots'),2)
        self.assertEqual(self.lua.eval('o.snapshots[1].amount'),-1)
        self.assertAlmostEqual(self.lua.eval('o.snapshots[2].amount'),.3)
        self.assertAlmostEqual(self.lua.eval('o.fluid:getAmount()'),.3)
        self.assertTrue(self.lua.eval('o.item.fluid==nil and o.item.id==old.id'))

    def test_server_ground_component_owner_restored_even_if_send_throws(self):
        self.lua.execute('''function isServer() return true end
            v=makeItem("Hydrocraft.HCWaterflaskFluid",false);v.fluid:addFluid(Fluid.TaintedWater,.3)
            s,o=square(v);GameEntityFactory.TransferComponent(v,o,ComponentType.FluidContainer)
            failSend=true;sendOK=pcall(HCRFluidMigrations.syncWorldReplacement,o)''')
        self.assertFalse(self.lua.globals().sendOK)
        self.assertAlmostEqual(self.lua.eval('o.fluid:getAmount()'),.3)
        self.assertTrue(self.lua.eval('o.item.fluid==nil'))

    def test_incompatible_or_over_capacity_stock_is_left_intact(self):
        self.assertIsNone(self.migrate(uses=15))
        for liquids in ['{Petrol=.5}','{Water=2}']:
            self.lua.execute('old=makeItem("Hydrocraft.HCWaterflask",false);old.fluid=makeFluid();old.fluid.liquids='+liquids+';new=HCRItemMigrations.newReplacement(old)')
            self.assertIsNone(self.lua.globals().new)

    def test_missing_target_or_component_keeps_original_in_inventory(self):
        for flag in ['missingTarget','missingComponent']:
            self.lua.globals()[flag]=True
            self.lua.execute('old=makeItem("Hydrocraft.HCWaterflaskfull",false);c=container({old},true);HCRTimed.updateContainer(c,0,0)')
            self.assertEqual(self.lua.eval('c.items[1].kind'),FULL)
            self.assertEqual(self.lua.eval('#packets'),0)
            self.lua.globals()[flag]=False

    def test_client_does_not_migrate_or_spawn_a_replacement(self):
        self.lua.execute('function isClient() return true end')
        self.assertIsNone(self.migrate())

    def test_nested_inventory_replacement_once_with_state(self):
        self.lua.execute('''old=makeItem("Hydrocraft.HCWaterflaskfull",false);old.uses=7
            old.favorite=true;old.custom=true;old.name="Grandfather flask";old.data.owner="survivor"
            inner=container({old},true);bag=makeItem("Bag",false);bag.child=inner
            outer=container({bag},true);HCRTimed.updateContainer(outer,0,0);HCRTimed.updateContainer(outer,1,0)''')
        item=self.lua.eval('inner.items[1]')
        self.assertEqual(item.kind,NATIVE)
        self.assertEqual(item.name,'Grandfather flask')
        self.assertEqual(item.data.HCRLegacyCustomName,'Grandfather flask')
        self.assertTrue(item.favorite)
        self.assertEqual(item.data.owner,'survivor')
        self.assertAlmostEqual(item.fluid.getAmount(item.fluid),.7)
        self.assertEqual(self.lua.eval('#packets'),0)  # Single-player needs no packet.

    def test_ground_identity_and_held_references_survive(self):
        self.lua.execute('''old=makeItem("Hydrocraft.HCWaterflaskfull",false)
            s,o=square(old);HCRTimed.updateSquare(s,0);HCRTimed.updateSquare(s,1)''')
        self.assertEqual(self.lua.eval('o.item.id'),self.lua.eval('old.id'))
        self.assertEqual(self.lua.eval('o.swaps'),1)
        self.lua.execute('''held=makeItem("Hydrocraft.HCWaterflaskfull",false);c=container({held},true)
            local p={class="IsoPlayer",primary=held,secondary=held}
            function p:getPrimaryHandItem() return self.primary end
            function p:getSecondaryHandItem() return self.secondary end
            function p:setPrimaryHandItem(v) self.primary=v end
            function p:setSecondaryHandItem(v) self.secondary=v end
            c.getCharacter=function() return p end
            HCRTimed.updateContainer(c,0,0);handsValid=p.primary==c.items[1] and p.secondary==c.items[1]''')
        self.assertTrue(self.lua.globals().handsValid)

if __name__=='__main__':unittest.main()
