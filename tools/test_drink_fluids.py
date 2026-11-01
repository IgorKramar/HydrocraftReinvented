"""Сохранение порций напитков и качества фруктов в новых соках."""
import json
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
from build_juice_catalog import catalogue

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / 'common/media/lua/shared'


class DrinkFluids(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('function require() end; function isClient() return false end; function isServer() return false end')
        self.lua.execute((SHARED/'HCR_FluidLedger.lua').read_text(encoding='utf-8'))
        self.lua.execute('HCRDrinkFamilies={}')
        self.lua.execute((SHARED/'HCR_MashCatalog.lua').read_text(encoding='utf-8'))

    def test_partial_migration_uses_own_reference_and_rejects_unknown_portions(self):
        self.lua.execute((SHARED/'HCR_DrinkMigrations.lua').read_text(encoding='utf-8'))
        remaining = self.lua.globals().HCRDrinkMigrations.remaining
        for base, current, expected in [(-.8, -.8, 1), (-.8, -.2, .25), (-.01, -.005, .5),
                                         (0, -.1, None), (-.8, .2, None), (-.8, -1, None),
                                         (-.8, float('nan'), None), (-.8, 0, None)]:
            item = self.lua.table_from({'getBaseHunger': lambda _, b=base: b,
                                        'getHungChange': lambda _, h=current: h})
            self.assertEqual(remaining(item), expected)

    def test_enabled_families_have_production_and_no_legacy_recipe_consumers(self):
        catalog = catalogue()
        self.assertEqual(len(catalog), 88)
        enabled = {kind for kind, spec in catalog.items() if spec['enabled']}
        self.assertEqual(len(enabled), 88)
        rules = json.loads((ROOT/'tools/juice_recipe_rules.json').read_text(encoding='utf-8'))
        self.assertEqual({r['sourceFood'] for r in rules.values()},
                         {kind for kind in enabled if not catalog[kind].get('lootOnly')})
        from apply_playability_fixes import blocks
        for path in (ROOT/'common/media/scripts').rglob('*.txt'):
            for _, _, name, body in blocks(path.read_text(encoding='utf-8-sig'), 'craftRecipe'):
                for kind in enabled:
                    self.assertNotIn(kind+']', body, (path.name, name))
                    self.assertNotIn(kind+';', body, (path.name, name))

    def test_zero_hunger_thirst_reference_is_explicit_and_does_not_rescale_nutrition(self):
        self.lua.execute((SHARED/'HCR_DrinkMigrations.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            local spec={remaining='native-zero-hunger-thirst'}
            local item={base=0,hunger=0,thirst=-.05,calories=731.5}
            function item:getBaseHunger() return self.base end
            function item:getHungChange() return self.hunger end
            function item:getThirstChangeUnmodified() return self.thirst end
            function item:getScriptItem() return {getThirstChange=function() return -10 end} end
            local M=HCRDrinkMigrations
            assert(M.remaining(item)==nil and M.remaining(item,{})==nil)
            assert(M.remaining(item,spec)==.5 and item.calories==731.5)
            for _,value in ipairs({0,.01,-.2,0/0}) do
                item.thirst=value;assert(M.remaining(item,spec)==nil)
            end
            item.thirst=-.1;item.hunger=-.05
            assert(M.remaining(item,spec)==nil)
        ''')

    def test_unknown_remaining_portion_defers_without_throwing_on_each_inventory_tick(self):
        self.lua.execute('''
            HCRFluidQuality={fluid=function() return nil end}
            HCRDrinkFamilies={['Hydrocraft.HCAguaardiente']={enabled=true,litres=1,remaining='native-zero-hunger-thirst'}}
            source={getFullType=function() return 'Hydrocraft.HCAguaardiente' end,
                IsFood=function() return true end,getBaseHunger=function() return 0 end,
                getHungChange=function() return 0 end,getThirstChangeUnmodified=function() return .1 end,
                getScriptItem=function() return {getThirstChange=function() return -10 end} end}
            warnings=0;function print() warnings=warnings+1 end
            function instanceItem() error('Deferred migration must not create replacement') end
            local originalAssert=assert
            function assert(value,...)
                if not value then error('No failed assert is allowed in expected deferral') end
                return originalAssert(value,...)
            end
        ''')
        self.lua.execute((SHARED/'HCR_DrinkMigrations.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            for i=1,3 do
                assert(HCRDrinkMigrations.newReplacement(source,function() error('Must not modify source') end)==nil)
            end
            assert(warnings==1)
        ''')

    def recipes(self):
        self.lua.execute('''
            HCRJuiceRecipeRules={}
            HCRFluidQuality={fluid=function(i) return i.fluid end,
                active=function(i) return i.tracked or false end}
            HCRFluidEffects={snapshot=function(food) return HCRFluidLedger.copy(food.snapshot) end,
                prepare=function(l) HCRFluidLedger.validate(l) end}
            function getGameTime() return {getWorldAgeHours=function() return 100 end} end
            HCRFood={getConsumedFoodFractions=function() return portions end}
            HCRFoodTransfers={deferCreate=function() return false end,
                foodSnapshot=function(_,food) return HCRFluidEffects.snapshot(food) end}
        ''')
        self.lua.execute('HCRDrinkFamilies={}')
        self.lua.execute((SHARED/'HCR_SoftDrinkCatalog.lua').read_text(encoding='utf-8'))
        self.lua.execute((SHARED/'HCR_DrinkVessels.lua').read_text(encoding='utf-8'))
        self.lua.execute((SHARED/'HCR_DrinkRecipes.lua').read_text(encoding='utf-8'))

    def test_fruit_freshness_is_not_reset_by_juicing(self):
        self.recipes()
        age = self.lua.globals().HCRDrinkRecipes.juiceAge
        self.assertAlmostEqual(age(5, 10, 20, 3, 7), 1.5)
        self.assertAlmostEqual(age(15, 10, 20, 3, 7), 5)
        self.assertGreaterEqual(age(21, 10, 20, 3, 7), 7)

    def test_batch_yield_is_independent_of_vessel_size(self):
        rules=json.loads((ROOT/'tools/juice_recipe_rules.json').read_text(encoding='utf-8'))
        apple=[rule for rule in rules.values() if rule['fluid']=='HCRJuiceApple']
        self.assertEqual(len(apple),6)
        for rule in apple:
            self.assertEqual(rule['batchLitres'],.5 if rule['target']=='Base.Mugl' else 1)
            self.assertGreater(rule['batchLitres']-(rule['count']-1)*rule['litres'],0)
            self.assertLessEqual(rule['batchLitres'],rule['count']*rule['litres']+.000001)
        mayo=next(r for r in apple if r['target']=='Base.MayonnaiseEmpty')
        self.assertEqual(mayo['count'],5)

    def test_fruit_portions_keep_nutrition_and_fractional_poison_in_same_vessel(self):
        self.recipes()
        self.lua.execute('''
            rule={target="Base.PopBottle",litres=2,fluid="HCRJuiceApple",sourceFood="Hydrocraft.HCPopbottleapplejuice",
                vesselSlot=0,freshDays=3,rottenDays=7}
            local f={amount=0,capacity=2}
            function f:isEmpty() return self.amount==0 end
            function f:getCapacity() return self.capacity end
            function f:addFluid(_,amount) self.amount=self.amount+amount end
            vessel={fluid=f,getFullType=function() return "Base.PopBottle" end}
            local slot={getAppliedItemsCount=function() return 1 end,getAppliedItem=function() return vessel end}
            local script={}
            local scripts={get=function() return script end}
            local recipe={getInputs=function() return scripts end}
            data={getRecipe=function() return recipe end,getDataForInputScript=function() return slot end}
            local a={updateAge=function() end,snapshot={age=15,offAge=10,offAgeMax=20,calories=200,poisonPower=3}}
            local b={updateAge=function() end,snapshot={age=0,offAge=10,offAgeMax=20,calories=300,poisonPower=0}}
            portions={[a]=.5,[b]=1}
            HCRFluidQuality.rawAmount=function() return f.amount end
            HCRFluidQuality.amounts=function() return {HCRJuiceApple=f.amount} end
            HCRFluidQuality.store=function(item,fluid,ledger)
                assert(item==vessel and fluid==f); saved=ledger
            end
            HCRFluidQuality.sync=function() end
            HCRDrinkRecipes.create(rule,data,{})
        ''')
        ledger = self.lua.globals().saved
        core = self.lua.globals().HCRFluidLedger
        self.assertEqual(core.volume(ledger), 2)
        self.assertEqual(core.budget(ledger, 'calories'), 400)
        self.assertEqual(core.budget(ledger, 'poisonPower'), 1.5)
        self.assertEqual(core.quality(ledger), 'stale')

    def test_full_or_tracked_vessel_is_not_eligible(self):
        self.recipes()
        self.lua.execute('''
            rule={target="Base.PopBottle",litres=2}
            item={getFullType=function() return "Base.PopBottle" end,
                fluid={isEmpty=function() return false end,getCapacity=function() return 2 end}}
        ''')
        self.assertFalse(self.lua.eval('HCRDrinkRecipes.test(rule,item)'))
        self.lua.execute('item.fluid.isEmpty=function() return true end; item.tracked=true')
        self.assertFalse(self.lua.eval('HCRDrinkRecipes.test(rule,item)'))


if __name__ == '__main__':
    unittest.main()
