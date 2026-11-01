"""Допустимые по отдельности партии не должны теряться при объединении."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text


class MilkChainLimits(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            HCRFluidQuality={}
            HCRFluidEffects={prepare=function() end}
            HCRMilkChainProducts={test={name='Bottle Milk',litres=4}}
            data={getRecipe=function() return {getName=function() return 'Bottle Milk' end} end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidLedger.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_MilkChains.lua'))

    def test_two_valid_sources_above_lot_limit_refused_without_changing_either(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            a=L.empty();b=L.empty()
            for i=1,80 do
                a=L.mix(a,L.batch('HCRMilk',.025,{calories=i},0))
                b=L.mix(b,L.batch('HCRMilk',.025,{calories=100+i},0))
            end
            before=L.budget(a,'calories')+L.budget(b,'calories')
            ok=HCRMilkChains.preflight(data,{{ledger=a},{ledger=b}})
            assert(L.volume(a)>1.9999 and L.volume(b)>1.9999)
            assert(L.budget(a,'calories')+L.budget(b,'calories')==before)
        ''')
        self.assertFalse(self.lua.globals().ok)
        self.assertEqual(len(self.lua.globals().a.lots),80)
        self.assertEqual(len(self.lua.globals().b.lots),80)

    def test_two_valid_sources_above_application_limit_refused(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            a=L.batch('HCRMilk',2,{calories=1},0);a.lots[1].units=3000
            b=L.batch('HCRMilk',2,{calories=2},0);b.lots[1].units=3000
            L.validate(a);L.validate(b)
            ok=HCRMilkChains.preflight(data,{{ledger=a},{ledger=b}})
        ''')
        self.assertFalse(self.lua.globals().ok)

    def test_native_and_tracked_legal_mixture_passes(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            a=L.batch('HCRMilk',2,{calories=1200,poisonPower=.875},0)
            b=L.batch('HCRMilk',2,{calories=1230},0)
            ok=HCRMilkChains.preflight(data,{{ledger=a,nativeMilk=b}})
        ''')
        self.assertTrue(self.lua.globals().ok)
