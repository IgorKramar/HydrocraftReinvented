"""Надпись игрока переживает native FC UI-name и временный tooltip render."""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime
import test_fluid_migrations as migrations

LUA=Path(__file__).resolve().parents[1]/'common/media/lua'


class NamesMigration(unittest.TestCase):
    setUp=migrations.FluidMigrations.setUp

    def test_existing_fluid_name_does_not_replace_the_players_label(self):
        self.lua.execute('''
            old=makeItem("Hydrocraft.HCWaterflaskfull",false)
            old.fluid=makeFluid();old.fluid:addFluid(Fluid.Water,.4)
            old.custom=true;old.name="Семейная фляга №2"
            old.getName=function() return "Leather Flask (Water)" end
            new=HCRItemMigrations.newReplacement(old)
            assert(new.name=="Семейная фляга №2")
            assert(new.data.HCRLegacyCustomName=="Семейная фляга №2")
            assert(math.abs(new.fluid:getAmount()-.4)<1e-8)
        ''')

    def test_moddata_retains_label_when_native_sync_replaces_private_name(self):
        self.lua.execute('''
            old=makeItem("Hydrocraft.HCWaterflaskfull",false)
            old.custom=true;old.name="Leather Flask (Water)"
            old.data.customName="Походная вода"
            new=HCRItemMigrations.newReplacement(old)
            assert(new.name=="Походная вода")
            assert(new.data.HCRLegacyCustomName=="Походная вода")
        ''')


class NamesTooltip(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require(_) end
            function getText(key,name)
                if key=="Tooltip_HCR_VesselName" then return "Label: "..name end
                if key=="Tooltip_HCR_Liquid_stale" then return "Stale" end
                if key=="existing" then return "Existing note" end
                error("Unexpected translation: "..key)
            end
            item={data={customName="Мой запас"},custom=true,fluid={},tooltip="existing"}
            function item:isCustomName() return self.custom end
            function item:getModData() return self.data end
            function item:getDisplayName() return "Water Flask (Water)" end
            function item:getTooltip() return self.tooltip end
            function item:setTooltip(value) self.tooltip=value end
            function item:IsFood() return false end
            HCRProcessQuality={carrier=function() return false end,key="process"}
            HCRFoodQuality={reconcile=function() end,qualityKey="quality"}
            HCRFluidQuality={fluid=function(i) return i.fluid end,
                active=function(i) return i.tracked end,capture=function() return {ledger={}} end}
            HCRFluidLedger={quality=function() return "stale" end}
            ISToolTipInv={render=function(self)
                seen=self.item:getTooltip()
                if fail then error("render failed") end
                return "rendered"
            end}
            ISInventoryPane={refreshContainer=function() end,doContextualDblClick=function() end}
        ''')
        for name in ('shared/HCR_ItemNames.lua','client/HCR_FluidTooltip.lua','client/HCR_FoodQualityTooltip.lua'):
            self.lua.execute((LUA/name).read_text(encoding='utf-8'))

    def test_empty_untracked_vessel_shows_one_unicode_label_and_restores_tooltip(self):
        self.lua.execute('assert(ISToolTipInv.render({item=item})=="rendered")')
        self.assertEqual(self.lua.globals().seen,'Label: Мой запас | Existing note')
        self.assertEqual(self.lua.globals().item.tooltip,'existing')

    def test_quality_and_current_rename_are_visible_without_using_stale_archive(self):
        self.lua.execute('''
            item.tracked=true;item.data.customName="Новая надпись"
            item.data.HCRLegacyCustomName="Старый запас"
            ISToolTipInv.render({item=item})
        ''')
        self.assertEqual(self.lua.globals().seen,'Label: Новая надпись | Stale | Existing note')

    def test_render_failure_restores_persistent_tooltip(self):
        self.lua.execute('fail=true;assert(not pcall(ISToolTipInv.render,{item=item}))')
        self.assertEqual(self.lua.globals().item.tooltip,'existing')

    def test_nonfluid_and_removed_custom_flag_do_not_show_archive(self):
        self.lua.execute('''
            item.fluid=nil;ISToolTipInv.render({item=item});assert(seen=="existing")
            item.fluid={};item.custom=false;item.data.HCRLegacyCustomName="Old label"
            ISToolTipInv.render({item=item});assert(seen=="existing")
        ''')


if __name__=='__main__': unittest.main()
