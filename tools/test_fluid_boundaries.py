"""Жидкости не теряют партии в native действиях, не умеющих хранить качество."""
import re
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime

SHARED = Path(__file__).resolve().parents[1] / 'common/media/lua/shared'


class FluidBoundaries(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        actions = (SHARED / 'HCR_FluidActions.lua').read_text(encoding='utf-8')
        boundaries = (SHARED / 'HCR_FluidBoundaries.lua').read_text(encoding='utf-8')
        self.lua.execute('''
            function require() end
            function isClient() return client or false end
            function isServer() return false end
            Hook={AutoDrink={Add=function() end}}; Events={}
            Fluid={Water="Water",TaintedWater="TaintedWater"}
            function instanceof() return false end
            HCRFluidQuality={
                fluid=function(i) return i and i.fluid end,
                active=function(i) return i and i.tracked or false end,
                item=function(i) return i end}
            fluid={isEmpty=function() return false end,isFull=function() return false end,
                getAmount=function() return 1 end,contains=function() return true end}
            item={tracked=true,fluid=fluid,getFluidContainer=function() return fluid end}
            plain={fluid=fluid,getFluidContainer=function() return fluid end}
            list={size=function() return 1 end,get=function() return item end}
            inv={getItems=function() return list end}
            character={getInventory=function() return inv end,hasFullInventory=function() return false end}
        ''')
        classes = set(re.findall(r'\bIS[A-Za-z0-9]+\b', actions + boundaries))
        for name in classes:
            self.lua.execute(f'''{name}=setmetatable({{isValid=function() return not nativeInvalid end}},{{__index=function()
                return function() calls=(calls or 0)+1;return "native" end end}})''')
        self.lua.execute(actions)
        self.lua.execute(boundaries)

    def test_portable_sinks_refuse_before_mutation_on_client_and_server(self):
        routes = [('ISWaterPlantAction', 'complete', 'item'),
                  ('ISGiveWaterToAnimal', 'update', 'item'),
                  ('ISAddWaterToTrough', 'updateAddingWater', 'itemFrom'),
                  ('ISGatherBloodFromAnimal', 'updateBucket', 'bucket'),
                  ('ISDrinkFromBottle', 'drink', 'item'),
                  ('ISDisinfect', 'complete', 'alcohol'),
                  ('ISCleanBlood', 'complete', 'cleaner'),
                  ('ISCleanGraffiti', 'complete', 'cleaner'),
                  ('ISPutOutFire', 'useItem', 'item')]
        for client in (False, True):
            self.lua.globals().client = client
            for cls, method, field in routes:
                with self.subTest(client=client, action=cls):
                    self.lua.execute(f'calls=0; a={{{field}=item}}; result={cls}.{method}(a)')
                    self.assertFalse(self.lua.globals().result)
                    self.assertEqual(self.lua.globals().calls, 0)
                    self.lua.execute(f'b={{{field}=plain}}; result={cls}.{method}(b)')
                    self.assertEqual(self.lua.globals().result, 'native')
                    self.assertEqual(self.lua.globals().calls, 1)

    def test_soap_list_and_automatic_vehicle_water_do_not_bypass_guard(self):
        for expression in ('ISWashClothing.complete({soaps=list})',
                           'ISWashClothing.useSoap({soaps=list})',
                           'ISWashVehicle.removeBlood({character=character})'):
            self.lua.execute('calls=0; result=' + expression)
            self.assertFalse(self.lua.globals().result)
            self.assertEqual(self.lua.globals().calls, 0)

    def test_in_flight_native_packets_do_not_cancel_authoritative_liquid_actions(self):
        self.lua.execute('''
            HCRFluidQuality.capture=function() error('Volume packet arrived before modData') end
            HCRFluidQuality.checkTransfer=function() error('One endpoint is still awaiting modData') end
            a={item=item,isStarted=function() return started end}
        ''')
        for cls in ('ISDrinkFluidAction', 'ISFluidTransferAction'):
            for client, started, native_invalid, expected in (
                    (True, True, False, True), (True, False, False, False),
                    (False, True, False, False), (True, True, True, False)):
                with self.subTest(action=cls, client=client, started=started, native_invalid=native_invalid):
                    self.lua.globals().client = client
                    self.lua.globals().started = started
                    self.lua.globals().nativeInvalid = native_invalid
                    self.assertEqual(self.lua.eval(f'{cls}.isValid(a)'), expected)

    def test_server_rejects_bad_ledger_before_native_drinking_even_after_start(self):
        self.lua.execute('''
            client=false;calls=0
            HCRFluidQuality.remove=function() error('Authoritative ledger mismatch') end
            a={item=item,isStarted=function() return true end}
            result=ISDrinkFluidAction.updateEat(a,1)
        ''')
        self.assertFalse(self.lua.globals().result)
        self.assertEqual(self.lua.globals().calls, 0)
        self.assertTrue(self.lua.globals().a.hcrFluidRefused)


if __name__ == '__main__':
    unittest.main()
