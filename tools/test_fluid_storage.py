"""World swap не оставляет второй наблюдатель под прежним factory ID."""
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime


class FluidStorage(unittest.TestCase):
    def setUp(self):
        lua=LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            function require() end
            function isClient() return false end
            function isServer() return false end
            function getNumActivePlayers() return 0 end
            function instanceof() return false end
            callbacks={}
            Events={}
            for _,name in ipairs({'LoadGridsquare','OnFillContainer','OnTick','EveryTenMinutes','OnSave'}) do
                local event=name
                Events[name]={Add=function(fn) callbacks[event]=fn end}
            end
            square={getX=function() return 1 end,getY=function() return 1 end,getZ=function() return 0 end}
            function getCell() return {getGridSquare=function() return square end} end
            world={getSquare=function() return square end}
            env={cold=false,freezer=false,powered=false,temperature=1}
            data={quality={storage=env}}
            item={id=1,getID=function(self) return self.id end,getModData=function() return data end,
                getOutermostContainer=function() return nil end,getWorldItem=function() return world end}
            HCRFluidQuality={key='quality',environment=function() return env end,fluid=function() return {} end,
                capture=function() return {ledger={storage=env}} end,
                store=function(i,f,ledger) stores=(stores or 0)+1;data.quality=ledger;HCRFluidQuality.watch(i,true) end,
                syncStorage=function() syncs=(syncs or 0)+1 end}
        ''')
        path=Path(__file__).resolve().parents[1]/'common/media/lua/server/HCR_FluidStorage.lua'
        lua.execute(path.read_text(encoding='utf-8'))
        self.lua=lua

    def test_changed_world_item_id_does_not_repeat_storage_sync(self):
        lua=self.lua
        lua.execute('''
            HCRFluidQuality.watch(item)
            item.id=71
            env={cold=true,freezer=false,powered=true,temperature=.2}
            callbacks.OnTick();callbacks.OnTick();callbacks.OnTick()
        ''')
        self.assertEqual(lua.globals().syncs,1)

    def test_normal_process_clock_is_observed_when_moved_out_of_cold_storage(self):
        lua=self.lua
        lua.execute('''
            data.quality=nil
            data.process={clock={storage={cold=true,freezer=false,powered=true,temperature=.2}}}
            HCRProcessQuality={key='process',checkpoint=function(i)
                checkpoints=(checkpoints or 0)+1
                data.process.clock.storage=env
                HCRFluidQuality.watch(i,true)
            end}
            HCRFluidQuality.watch(item)
            callbacks.OnTick();callbacks.OnTick()
        ''')
        self.assertEqual(lua.globals().checkpoints,1)
        self.assertIsNone(lua.globals().syncs)

    def test_grid_power_change_checkpoints_even_without_generator_change(self):
        self.lua.execute('''
            env.operationalPowered=false;env.gridPowered=false
            HCRFluidQuality.watch(item)
            env.operationalPowered=true;env.gridPowered=true
            callbacks.OnTick();callbacks.OnTick()
        ''')
        self.assertEqual(self.lua.globals().syncs,1)

    def test_loaded_item_is_reconciled_once_then_periodic_save_is_quiet(self):
        self.lua.execute('''
            HCRFluidQuality.watch(item)
            assert(HCRFluidQuality.storageUnobserved(item))
            callbacks.OnTick()
            assert(not HCRFluidQuality.storageUnobserved(item))
            callbacks.OnTick();callbacks.OnTick()
            callbacks.EveryTenMinutes();callbacks.OnSave()
        ''')
        self.assertEqual(self.lua.globals().stores,3)
        self.assertEqual(self.lua.globals().syncs,1)


if __name__=='__main__':
    unittest.main()
