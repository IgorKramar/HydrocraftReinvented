"""Питание в прошлом не переписывается текущим состоянием холодильника."""
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]/'common/media/lua/shared'


class FluidCooling(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            SandboxVars={FridgeFactor=3,FoodRotSpeed=3}
            cutoff=-1;sinceApo=1
            function getSandboxOptions() return {getElecShutModifier=function() return cutoff end,
                getTimeSinceApo=function() return sinceApo end} end
            function getCell() error('Historical power must not be queried again') end
        ''')
        for name in ('HCR_FluidLedger','HCR_FluidCooling','HCR_FluidQuality'):
            self.lua.execute((ROOT/(name+'.lua')).read_text(encoding='utf-8'))
        self.lua.execute('''
            local L=HCRFluidLedger
            function fixture(generator,operational,grid,freezer)
                local env={cold=true,freezer=freezer or false,powered=generator,
                    operationalPowered=operational,gridPowered=grid,temperature=operational and .2 or 1,
                    x=1,y=2,z=0}
                local ledger=L.batch('HCRMilk',1,{age=0,offAge=4,offAgeMax=7,canBeFrozen=false},100)
                ledger.storage=L.copy(env)
                HCRFluidQuality.environment=function() return env end
                return ledger,env
            end
        ''')

    def test_generator_on_preserves_previous_seven_warm_days(self):
        self.lua.execute('''
            local ledger,env=fixture(false,false,false)
            env.powered=true;env.operationalPowered=true;env.temperature=.2
            local result=HCRFluidQuality.age({},ledger,268)
            assert(math.abs(result.lots[1].age-7)<1e-9)
            result=HCRFluidQuality.age({},result,292)
            assert(math.abs(result.lots[1].age-7.2)<1e-9)
            assert(ledger.lots[1].age==0)
        ''')

    def test_generator_off_preserves_previous_seven_cold_days(self):
        self.lua.execute('''
            local ledger,env=fixture(true,true,false)
            env.powered=false;env.operationalPowered=false;env.temperature=1
            local result=HCRFluidQuality.age({},ledger,268)
            assert(math.abs(result.lots[1].age-1.4)<1e-9)
            result=HCRFluidQuality.age({},result,292)
            assert(math.abs(result.lots[1].age-2.4)<1e-9)
        ''')

    def test_grid_cutoff_splits_saved_interval_on_reload(self):
        self.lua.execute('''
            cutoff=5
            local ledger,env=fixture(false,true,true)
            env.operationalPowered=false;env.gridPowered=false;env.temperature=1
            local result=HCRFluidQuality.age({},ledger,148)
            assert(math.abs(result.lots[1].age-(20*.2+28)/24)<1e-9)
        ''')

    def test_unpowered_exterior_freezer_keeps_native_age_fallback_without_freezing(self):
        self.lua.execute('''
            cutoff=20
            local ledger,env=fixture(false,false,false,true)
            ledger.lots[1].food.canBeFrozen=true
            local result=HCRFluidQuality.age({},ledger,124)
            assert(math.abs(result.lots[1].age-.2)<1e-9)
            assert(not result.lots[1].food.frozen)
            assert(result.lots[1].food.freezingTime==0)
        ''')

    def test_grid_freezer_thaws_after_known_cutoff(self):
        self.lua.execute('''
            cutoff=5
            local ledger,env=fixture(false,true,true,true)
            ledger.lots[1].food.canBeFrozen=true
            env.operationalPowered=false;env.gridPowered=false;env.temperature=1
            local result=HCRFluidQuality.age({},ledger,144)
            assert(not result.lots[1].food.frozen)
            assert(result.lots[1].food.freezingTime==0)
            assert(math.abs(result.lots[1].age-(4*.2+22.5)/24)<1e-9)
        ''')

    def test_generator_keeps_freezer_running_after_grid_cutoff(self):
        self.lua.execute('''
            cutoff=5
            local ledger=fixture(true,true,true,true)
            ledger.lots[1].food.canBeFrozen=true
            local result=HCRFluidQuality.age({},ledger,144)
            assert(result.lots[1].food.frozen)
            assert(math.abs(result.lots[1].age-4*.2/24)<1e-9)
        ''')

    def test_late_apocalypse_freezer_thaws_at_physical_cutoff(self):
        self.lua.execute('''
            sinceApo=2;cutoff=35
            local ledger,env=fixture(false,true,true,true)
            ledger.lots[1].food.canBeFrozen=true
            ledger.lots[1].food.frozen=true;ledger.lots[1].food.freezingTime=100
            env.operationalPowered=false;env.gridPowered=false;env.temperature=1
            HCRFluidQuality.storageUnobserved=function() return true end
            local result=HCRFluidQuality.age({},ledger,124)
            assert(not result.lots[1].food.frozen)
            assert(result.lots[1].food.freezingTime==0)
            -- Свет отключён на120h, но native age fallback действует до840h.
            assert(math.abs(result.lots[1].age-2.5*.2/24)<1e-9)
            assert(ledger.lots[1].food.frozen)
        ''')

    def test_late_apocalypse_keeps_native_fridge_age_fallback(self):
        self.lua.execute('''
            sinceApo=2;cutoff=35
            local ledger,env=fixture(false,true,true)
            env.operationalPowered=false;env.gridPowered=false;env.temperature=1
            local result=HCRFluidQuality.age({},ledger,864)
            assert(math.abs(result.lots[1].age-(740*.2+24)/24)<1e-9)
        ''')

    def test_late_apocalypse_partial_thaw_and_generator_override(self):
        self.lua.execute('''
            sinceApo=2;cutoff=35
            local ledger,env=fixture(false,true,true,true)
            ledger.lots[1].food.canBeFrozen=true
            ledger.lots[1].food.frozen=true;ledger.lots[1].food.freezingTime=100
            env.operationalPowered=false;env.gridPowered=false;env.temperature=1
            local result=HCRFluidQuality.age({},ledger,120.75)
            assert(result.lots[1].food.frozen and result.lots[1].age==0)
            assert(math.abs(result.lots[1].food.freezingTime-50)<1e-9)
            ledger.storage.powered=true
            result=HCRFluidQuality.age({},ledger,124)
            assert(result.lots[1].food.frozen and result.lots[1].age==0)
            assert(result.lots[1].food.freezingTime==100)
        ''')

    def test_generator_loss_during_unloaded_gap_is_not_assumed_cold(self):
        self.lua.execute('''
            local ledger,env=fixture(true,true,false,true)
            ledger.lots[1].food.canBeFrozen=true
            ledger.lots[1].food.frozen=true;ledger.lots[1].food.freezingTime=100
            env.powered=false;env.operationalPowered=false;env.temperature=1
            HCRFluidQuality.storageUnobserved=function() return true end
            local result=HCRFluidQuality.age({},ledger,268)
            assert(not result.lots[1].food.frozen)
            assert(math.abs(result.lots[1].age-(168-1.5)/24)<1e-9)
            assert(ledger.storage.powered==true)
        ''')

    def test_periodic_known_checkpoint_limits_unobserved_gap(self):
        self.lua.execute('''
            local ledger,env=fixture(true,true,false)
            ledger=HCRFluidQuality.age({},ledger,267)
            env.powered=false;env.operationalPowered=false;env.temperature=1
            HCRFluidQuality.storageUnobserved=function() return true end
            local result=HCRFluidQuality.age({},ledger,268)
            assert(math.abs(result.lots[1].age-(167*.2+1)/24)<1e-9)
        ''')


if __name__=='__main__':
    unittest.main()
