"""Исходные сроки HC, перенос партии и независимые часы при смешивании."""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime

LUA = Path(__file__).resolve().parents[1] / 'common/media/lua/shared'


class FermentationClock(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('function require() end')
        for name in ('HCR_TimedDefinitions', 'HCR_MashCatalog', 'HCR_FermentationClock', 'HCR_FluidLedger'):
            self.lua.execute((LUA / (name + '.lua')).read_text(encoding='utf-8-sig'))
        self.lua.execute('F=HCRFermentationClock; L=HCRFluidLedger')

    def test_all_four_original_chains_and_exact_boundaries(self):
        self.lua.execute('''
            for _,pair in ipairs({{'grape','wine'},{'grapegreen','winewhite'},
                {'honey','mead'},{'rice','sake'}}) do
                local raw='Hydrocraft.HCBarrel'..pair[1]
                local ready='Hydrocraft.HCBarrel'..pair[2]
                local a=F.new(raw,100,435.999,true);assert(a.kind==raw)
                local b,changed=F.advance(a,436,true);assert(changed and b.kind==ready and b.startedAt==436)
                local c=F.advance(b,771.999,true);assert(c.kind==ready)
                local d=F.advance(c,772,true);assert(d.kind=='Hydrocraft.HCBarrelvinegar' and d.startedAt==772)
                assert(a.kind==raw and a.startedAt==100)
            end
        ''')

    def test_unloaded_catchup_matches_observed_steps(self):
        self.lua.execute('''
            local initial=F.new('Hydrocraft.HCBarrelgrape',100,100,true)
            local one=F.advance(initial,1500,true)
            local many=initial
            for t=101,1500 do many=F.advance(many,t,true) end
            assert(one.kind==many.kind and one.startedAt==many.startedAt and one.lastHour==many.lastHour)
        ''')

    def test_must_finishes_in_portable_vessel_without_souring(self):
        self.lua.execute('''
            local a=F.new('Hydrocraft.HCBarrelgrape',0,300,true)
            local moved=F.advance(a,300,false)
            local bottled=F.advance(moved,1000,false)
            assert(bottled.kind=='Hydrocraft.HCBarrelwine' and bottled.startedAt==1000)
            local back=F.advance(bottled,1000,true)
            assert(F.advance(back,1335,true).kind=='Hydrocraft.HCBarrelwine')
            assert(F.advance(back,1336,true).kind=='Hydrocraft.HCBarrelvinegar')
        ''')

    def test_pouring_wine_out_and_back_does_not_reset_aging(self):
        self.lua.execute('''
            local wine=F.new('Hydrocraft.HCBarrelwine',100,200,true)
            local away=F.advance(wine,200,false)
            local back=F.advance(away,1000,true)
            assert(back.lastHour-back.startedAt==100)
            assert(F.advance(back,1235.999,true).kind=='Hydrocraft.HCBarrelwine')
            assert(F.advance(back,1236,true).kind=='Hydrocraft.HCBarrelvinegar')
        ''')

    def test_previous_storage_applies_to_elapsed_interval(self):
        self.lua.execute('''
            local a=F.new('Hydrocraft.HCBarrelwine',10,20,true)
            local b=F.advance(a,346,false)
            assert(b.kind=='Hydrocraft.HCBarrelvinegar')
            local c=F.new('Hydrocraft.HCBarrelwine',10,20,false)
            local d=F.advance(c,500,true)
            assert(d.kind=='Hydrocraft.HCBarrelwine' and d.startedAt==500)
        ''')

    def test_clock_rollback_preserves_accumulated_time(self):
        self.lua.execute('''
            local a=F.new('Hydrocraft.HCBarrelgrape',100,200,true)
            local b=F.advance(a,10,true)
            assert(b.lastHour-b.startedAt==100 and b.kind==a.kind)
            assert(F.advance(b,245.999,true).kind==a.kind)
            assert(F.advance(b,246,true).kind=='Hydrocraft.HCBarrelwine')
        ''')

    def test_split_and_mix_keep_independent_clocks_and_poison(self):
        self.lua.execute('''
            local a=L.batch('HCRMustRed',4,{calories=800,poisonPower=.75},400)
            a.lots[1].fermentation=F.new('Hydrocraft.HCBarrelgrape',100,400,true)
            local b=L.copy(a)
            b.lots[1].fermentation=F.new('Hydrocraft.HCBarrelgrape',200,400,true)
            local mixed=L.mix(a,b);assert(#mixed.lots==2)
            local kept,moved=L.split(mixed,2,8)
            assert(#moved.lots==2 and #kept.lots==2)
            assert(moved.lots[1].fermentation.startedAt==100 and moved.lots[2].fermentation.startedAt==200)
            assert(math.abs(L.budget(moved,'poisonPower')-.375)<.000001)
            assert(math.abs(L.budget(kept,'poisonPower')-1.125)<.000001)
            assert(F.advance(moved.lots[1].fermentation,436,true).kind=='Hydrocraft.HCBarrelwine')
            assert(F.advance(moved.lots[2].fermentation,436,true).kind=='Hydrocraft.HCBarrelgrape')
            assert(#L.mix(a,L.copy(a)).lots==1)
            b.lots[1].fermentation=nil;assert(#L.mix(a,b).lots==2)
        ''')

    def test_invalid_saved_metadata_is_rejected(self):
        self.lua.execute('''
            local good=F.new('Hydrocraft.HCBarrelgrape',0,10,true)
            for _,change in ipairs({{'version',2},{'kind','unknown'},{'lastHour',0/0},
                {'startedAt',11},{'barrel','yes'}}) do
                local bad=L.copy(good);bad[change[1]]=change[2]
                assert(not pcall(F.validate,bad))
                local ledger=L.batch('HCRMustRed',1,{},10);ledger.lots[1].fermentation=bad
                assert(not pcall(L.validate,ledger))
            end
        ''')


if __name__ == '__main__':
    unittest.main()
