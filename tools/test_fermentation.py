"""Созревание меняет питание по стадии, сохраняя дозы и отдельные партии."""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime

SHARED = Path(__file__).resolve().parents[1] / 'common/media/lua/shared'


class Fermentation(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().package.path = SHARED.as_posix() + '/?.lua'
        self.lua.execute('''
            require 'HCR_Fermentation'
            L=HCRFluidLedger;F=HCRFermentationClock;B=HCRFermentation
            function snapshot(kind,quality)
                local vinegar=kind=='Hydrocraft.HCBarrelvinegar'
                local age=quality=='rotten' and 2 or quality=='stale' and 1 or 0
                return {calories=vinegar and 0 or 800,nativeAlcohol=vinegar and 0 or .12,
                    age=age,offAge=1,offAgeMax=2,canBeFrozen=false}
            end
            function must(start,volume,dose)
                local a=L.batch('HCRMustRed',volume,{calories=180,poisonPower=dose or .75,
                    poisonDetectionLevel=4,age=0,offAge=10,offAgeMax=20},start)
                a.lots[1].fermentation=F.new('Hydrocraft.HCBarrelgrape',start,start,true)
                return a
            end
        ''')

    def test_split_old_batch_rebases_nutrition_without_multiplying_poison(self):
        self.lua.execute('''
            local original=must(0,20,.875)
            local kept,portion=L.split(original,3,20)
            local wine,changed=B.plan(portion,336,true,snapshot)
            assert(changed and wine.lots[1].fluid=='HCRWineRed')
            assert(wine.lots[1].units==3 and wine.lots[1].basisLitres==1)
            assert(math.abs(L.budget(wine,'poisonPower')-.13125)<1e-9)
            assert(L.budget(wine,'calories')==2400)
            assert(wine.lots[1].food.poisonDetectionLevel==4)
            assert(portion.lots[1].fluid=='HCRMustRed' and original.lots[1].units==1)
            local wine2=B.plan(kept,336,true,snapshot)
            assert(math.abs(L.budget(wine2,'poisonPower')+L.budget(wine,'poisonPower')-.875)<1e-9)
        ''')

    def test_start_rebases_actual_fruit_portions_and_keeps_worst_quality(self):
        self.lua.execute('''
            local juice=L.batch('HCRJuiceGrape',4,{calories=120,poisonPower=.8,
                age=5,offAge=3,offAgeMax=7},0)
            juice.lots[1].units=.5
            local raw=B.start(juice,'Hydrocraft.HCBarrelgrape',100,snapshot)
            assert(raw.lots[1].basisLitres==8 and L.budget(raw,'calories')==60)
            assert(L.quality(raw)=='stale' and L.budget(raw,'poisonPower')==.4)
            local wine=B.plan(raw,436,true,snapshot)
            assert(L.budget(wine,'calories')==3200 and L.budget(wine,'poisonPower')==.4)
            assert(juice.lots[1].basisLitres==4 and not juice.lots[1].fermentation)
            assert(not pcall(B.start,raw,'Hydrocraft.HCBarrelgrape',200,snapshot))
        ''')

    def test_start_preserves_zero_marker_trace_poison(self):
        self.lua.execute('''
            local juice=L.batch('HCRJuiceGrape',.00001,{poisonPower=.875},0)
            juice.lots[1].litres=0;juice.lots[1].units=.25
            local raw=B.start(juice,'Hydrocraft.HCBarrelgrape',100,snapshot)
            local wine=B.plan(raw,436,true,snapshot)
            assert(wine.lots[1].litres==0 and math.abs(L.budget(wine,'poisonPower')-.21875)<1e-9)
            assert(math.abs(L.budget(wine,'calories')-.002)<1e-9)
        ''')

    def test_different_ages_can_share_must_wine_and_vinegar(self):
        self.lua.execute('''
            local mix=L.mix(L.mix(must(0,1,.2),must(400,2,.3)),must(700,3,.4))
            local out=B.plan(mix,800,true,snapshot)
            assert(out.lots[1].fluid=='HCRVinegar' and out.lots[2].fluid=='HCRWineRed'
                and out.lots[3].fluid=='HCRMustRed')
            assert(math.abs(L.budget(out,'poisonPower')-.9)<1e-9 and L.volume(out)==6)
            assert(L.budget(out,'calories')==1780)
        ''')

    def test_zero_volume_trace_and_rotten_quality_survive_two_stages(self):
        self.lua.execute('''
            local a=must(0,4,.8);a.lots[1].litres=0;a.lots[1].units=.3;a.lots[1].age=25
            local out=B.plan(a,800,true,snapshot)
            assert(out.lots[1].fluid=='HCRVinegar' and out.lots[1].litres==0)
            assert(L.quality(out)=='rotten' and math.abs(L.budget(out,'poisonPower')-.24)<1e-9)
            assert(out.lots[1].units==1.2 and out.lots[1].food.poisonPower==.2)
        ''')

    def test_repeated_observation_never_recreates_nutrition(self):
        self.lua.execute('''
            local wine=B.plan(must(0,4,.8),336,true,snapshot)
            local ready,changed=B.plan(wine,400,true,function() error('Unexpected replacement') end)
            assert(not changed and L.budget(ready,'calories')==3200)
            local away=B.plan(ready,400,false,snapshot)
            local later=B.plan(away,2000,false,snapshot)
            assert(later.lots[1].fluid=='HCRWineRed')
            assert(math.abs(L.budget(later,'poisonPower')-.8)<1e-9)
        ''')

    def test_unrelated_food_and_taint_remain_intact(self):
        self.lua.execute('''
            local a=must(0,4,.8);a.lots[1].food.tainted=true;a.lots[1].age=12
            local milk=L.batch('HCRMilk',.3,{age=3,offAge=4,offAgeMax=7,calories=50,poisonPower=.1},0)
            local out=B.plan(L.mix(a,milk),336,true,snapshot)
            assert(out.lots[1].food.tainted and L.quality({version=1,lots={out.lots[1]}})=='stale')
            assert(out.lots[2].age==3 and out.lots[2].food.calories==50 and out.lots[2].lastHour==0)
        ''')

    def test_future_components_include_all_distinct_stages_but_not_trace(self):
        self.lua.execute('''
            local a=must(0,4)
            local n,names=B.futureComponents(a,{Water=1,HCRMustRed=4,HCRWineRed=1})
            assert(n==4 and names.Water and names.HCRVinegar)
            a.lots[1].litres=0
            assert(B.futureComponents(a,{Water=1})==1)
            a.lots[1].fermentation=F.new('Hydrocraft.HCBarrelwine',0,0,false)
            a.lots[1].litres=1;a.lots[1].fluid='HCRWineRed'
            assert(B.futureComponents(a,{Water=1})==3)
        ''')

    def test_invalid_input_and_application_limit_fail_before_mutation(self):
        self.lua.execute('''
            local a=must(0,5000,.2)
            assert(not pcall(B.plan,a,336,true,snapshot))
            assert(a.lots[1].fluid=='HCRMustRed' and a.lots[1].units==1)
            a=must(0,1);a.lots[1].fluid='HCRMilk'
            assert(not pcall(B.plan,a,336,true,snapshot))
            a=must(0,.0000001,1)
            assert(not pcall(B.plan,a,336,true,snapshot))
        ''')

    def test_transfer_reserves_future_components_and_checks_target_filter(self):
        self.lua.execute('''
            HCRFluidTransform.contents=function(f) return f.parts end
            Fluid={Get=function(name) return {name=name,canBlendWith=function() return true end} end}
            local function vessel(parts,reject)
                return {parts=parts,getBlacklist=function() end,
                    getWhitelist=function() return reject and {allows=function(_,kind) return kind.name~=reject end} end}
            end
            local a=must(0,4)
            local target=vessel({{name='Water'}})
            local source=vessel({{name='HCRMustRed'}})
            assert(B.checkMixture(a,target,source))
            assert(not B.checkMixture(a,vessel({},'HCRVinegar'),source))
            target.parts={{name='Water'},{name='HCRMilk'},{name='HCRCoffee'},
                {name='HCRJuiceLemon'},{name='HCRJuiceLime'},{name='HCRJuiceApple'}}
            assert(not B.checkMixture(a,target,source))
            assert(a.lots[1].fluid=='HCRMustRed' and a.lots[1].fermentation.kind=='Hydrocraft.HCBarrelgrape')
            assert(B.checkMixture(L.empty(),nil,nil))
        ''')

    def test_virtual_tap_refuses_ninth_future_component_before_native_debit(self):
        self.lua.execute('''
            HCRFluidTransform.contents=function(f) return f.parts end
            Fluid={Get=function(name) return {getFluidTypeString=function() return name end,
                canBlendWith=function() return true end} end}
            target={parts={{name='HCRMustRed'},{name='HCRMilk'},{name='HCRCoffee'},
                {name='HCRJuiceLemon'},{name='HCRJuiceLime'},{name='HCRJuiceApple'}},
                getWhitelist=function() end,getBlacklist=function() end}
            tap={getFluidContainer=function() end,getPrimaryFluid=function() return Fluid.Get('Water') end,
                getUsesExternalWaterSource=function() return false end}
            ledger=must(0,1)
            assert(B.checkMixture(ledger,target,nil))
            assert(not B.checkMixture(ledger,target,nil,B.waterComponents(tap)))
            function require() end
        ''')
        self.lua.execute((SHARED / 'HCR_FluidQuality.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            local Q=HCRFluidQuality
            Q.fluid=function() return target end
            Q.active=function() return true end
            Q.capture=function() return {ledger=ledger} end
            local debited=false
            local ok=pcall(Q.addNative,{},nil,function() debited=true end,nil,tap)
            assert(not ok and not debited)
            -- Внешний бак очищает воду, а не скрывает остальные компоненты.
            local tank={getFluidContainer=function() return {parts={{name='TaintedWater'},{name='Beer'}}} end,
                getPrimaryFluid=function() return Fluid.Get('TaintedWater') end,
                getUsesExternalWaterSource=function() return false end}
            tap.getUsesExternalWaterSource=function() return true end
            tap.FindExternalWaterSource=function() return tank end
            local names=B.waterComponents(tap)
            assert(names.Water and names.Beer and not names.TaintedWater)
        ''')


if __name__ == '__main__':
    unittest.main()
