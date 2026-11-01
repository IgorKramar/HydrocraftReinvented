"""Native milk uses whole-container cached properties; conserve the actual fraction."""
import unittest
import test_fluid_recipe_quality as base


class NativeMilk(unittest.TestCase):
    setUp=base.FluidRecipeQuality.setUp
    def test_native_and_tracked_milk_are_debited_once_at_the_same_fraction(self):
        self.lua.execute('''
            function getGameTime() return {getWorldAgeHours=function() return 48 end} end
            HCRNativeMilk={snapshot=function() return {calories=615,poisonPower=0,offAge=4,offAgeMax=7} end}
            HCRFluidRecipeQuality.rules.Test.nativeMilk=true
            source.amount=1.5
            result,removed=HCRFluidRecipeQuality.perform(data,{},function()
                source.amount=.75;source.tracked=.25;return true
            end)
        ''')
        self.assertEqual(len(self.lua.globals().removed),2)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[1],'calories')"),100)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[2],'calories')"),307.5)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(source.data,'poisonPower')"),.4375)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.volume(removed[1])+HCRFluidLedger.volume(removed[2])"),.75)

    def test_untracked_native_milk_keeps_no_shadow_ledger_in_source(self):
        self.lua.execute('''
            function getGameTime() return {getWorldAgeHours=function() return 48 end} end
            HCRNativeMilk={snapshot=function() return {calories=1230,poisonPower=0} end}
            HCRFluidRecipeQuality.rules.Test.nativeMilk=true
            source.amount=2;source.tracked=0;source.data=HCRFluidLedger.empty()
            result,removed=HCRFluidRecipeQuality.perform(data,{},function() source.amount=1;return true end)
        ''')
        self.assertEqual(len(self.lua.globals().removed),1)
        self.assertIsNone(self.lua.globals().syncs)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[1],'calories')"),615)
        self.assertEqual(len(self.lua.eval('source.data.lots')),0)
