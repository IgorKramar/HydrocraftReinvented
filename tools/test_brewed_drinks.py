"""Заваривание сохраняет текущий остаток; молочный кофе не создаёт объём."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text


class BrewedDrinks(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('function require() end; function getGameTime() return {getWorldAgeHours=function() return 10 end} end')
        for name in ('HCR_FluidLedger','HCR_BrewedDrinkRules','HCR_BrewedDrinks'):
            self.lua.execute(read_text(LUA/f'shared/{name}.lua'))

    def test_dissolved_sugar_keeps_actual_portion_without_creating_liquid(self):
        self.lua.execute('''
            local L,B=HCRFluidLedger,HCRBrewedDrinks
            local coffee=L.batch('HCRCoffee',.2,{calories=3,poisonPower=.125},10)
            local sugar=B.solid({calories=100,poisonPower=.5,age=8,offAge=3,offAgeMax=7},.125,'HCRCoffeeSweet')
            result=L.mix(B.combine({coffee},'HCRCoffeeSweet',.2),sugar)
            assert(L.volume(result)==.2 and L.quality(result)=='rotten')
            local kept,used=L.split(result,.05,.2)
            assert(math.abs(L.budget(used,'calories')-3.875)<.000001)
            assert(math.abs(L.budget(used,'poisonPower')-.046875)<.000001)
            assert(math.abs(L.budget(kept,'calories')-11.625)<.000001)
            assert(L.matches(result,{HCRCoffeeSweet=.2}))
        ''')

    def test_partial_cooked_stock_uses_current_values_once(self):
        self.lua.execute('''
            local B=HCRBrewedDrinks
            result=B.portion(B.rules['Finish Brewing Black Coffee'],
                {hungChange=-.04,baseHunger=-.1,cooked=true,calories=123,poisonPower=.375})
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRFluidLedger.volume(result)'),.08)
        self.assertEqual(self.lua.eval("HCRFluidLedger.budget(result,'calories')"),123)
        self.assertEqual(self.lua.eval("HCRFluidLedger.budget(result,'poisonPower')"),.375)

    def test_raw_refused_and_burnt_retained_without_reheating_or_restoring_nutrition(self):
        self.lua.execute('''
            local B=HCRBrewedDrinks;local rule=B.rules['Finish Brewing Coffee Kettle']
            local source={hungChange=-.2,baseHunger=-.2,cooked=false,calories=10}
            assert(not pcall(B.portion,rule,source))
            source.burnt=true;result=B.portion(rule,source)
            assert(result.lots[1].food.burnt and not result.lots[1].food.cooked)
            assert(source.calories==10 and result.lots[1].food.calories==10)
        ''')

    def test_milk_mix_conserves_budgets_and_worst_expiry_without_fixed_output_bonus(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            local coffee=L.batch('HCRCoffee',.1,{calories=1.5,fatigueChange=-.075,poisonPower=.125},10)
            local milk=L.batch('HCRMilk',.1,{calories=61.5,poisonPower=.25,age=4,offAge=3,offAgeMax=7},10)
            result=HCRBrewedDrinks.combine({coffee,milk},'HCRCoffeeMilk',.2)
            assert(L.quality(result)=='stale' and coffee.lots[1].fluid=='HCRCoffee')
            assert(not pcall(HCRBrewedDrinks.combine,{coffee,milk},'HCRCoffeeMilk',1.4))
        ''')
        for field,expected in [('calories',63),('fatigueChange',-.075),('poisonPower',.375)]:
            self.assertAlmostEqual(self.lua.eval(f"HCRFluidLedger.budget(result,'{field}')"),expected)

    def test_partial_soy_requires_heating_and_retains_its_own_expiry(self):
        self.lua.execute('''
            local B,L=HCRBrewedDrinks,HCRFluidLedger
            local rule=B.rules['Finish Preparing Soy Milk']
            local source={hungChange=-.12,baseHunger=-.3,calories=164,
                age=16,offAge=15,offAgeMax=30,poisonPower=.375}
            assert(not pcall(B.portion,rule,source))
            source.cooked=true
            local result=B.portion(rule,source)
            assert(math.abs(L.volume(result)-.4)<.000001)
            assert(L.budget(result,'calories')==164 and L.budget(result,'poisonPower')==.375)
            assert(L.quality(result)=='stale')
            assert(result.lots[1].fluid=='HCRMilkSoy')
            assert(result.lots[1].food.offAge==15 and result.lots[1].food.offAgeMax==30)
        ''')
