"""Пакетный разлив сохраняет реальные партии и не возвращает лишние кастрюли."""
import json
import re
import unittest
from apply_playability_fixes import blocks
from hcr_paths import LUA, REPO, SCRIPTS, read_text
import test_bar_fluids as bar


class MilkCocktails(unittest.TestCase):
    setUp = bar.BarFluids.setUp

    def test_multiple_bottles_split_each_budget_without_duplicate_source_vessel(self):
        self.lua.execute(read_text(LUA/'shared/HCR_MilkCocktailCatalog.lua'))
        self.lua.execute('''
            local L,Q,T=HCRFluidLedger,HCRFluidQuality,{}
            local ledger=L.batch('HCREggnog',2,{calories=731.5,poisonPower=.8125,age=9,offAge=8,offAgeMax=10},10)
            local outputs={}
            for i=1,2 do
                outputs[i]={fluid={amount=0,isEmpty=function(f) return f.amount==0 end,
                    addFluid=function(f,k,n) f.marker=k;f.amount=f.amount+n end},
                    getFullType=function() return 'Hydrocraft.HCEggnogbottleFluid' end}
            end
            local data={getRecipe=function() return {getName=function() return 'Make Eggnog Bottle' end} end,
                getAllCreatedItems=function() return list(outputs) end}
            T.contexts={[data]={actualFractions={},fluids={ledger}}}
            T.deferCreate=function() return false end;HCRFoodTransfers=T
            Q.rawAmount=function(f) return f.amount end
            Q.amounts=function(f) return {[f.marker]=f.amount} end
            Q.store=function(item,fluid,value) item.ledger=value end;Q.sync=function() end
            HCRBarDrinks.create(data,{})
            for _,item in ipairs(outputs) do
                assert(item.fluid.amount==1 and L.quality(item.ledger)=='stale')
                assert(L.budget(item.ledger,'calories')==731.5/2)
                assert(L.budget(item.ledger,'poisonPower')==.8125/2)
            end
            assert(L.volume(ledger)==2 and L.budget(ledger,'calories')==731.5)
        ''')

    def test_raw_egg_adaptation_does_not_clear_spoilage_or_poison_or_change_other_solids(self):
        self.lua.execute(read_text(LUA/'shared/HCR_MilkCocktailCatalog.lua'))
        self.lua.execute('''
            local script={containsItem=function(_,kind) return kind=='Egg' end}
            local data={getRecipe=function() return {
                getName=function() return 'Make Eggnog Pot' end,
                getInputs=function() return list({{},script}) end} end}
            local food={dangerousUncooked=true,poisonPower=.7,age=11,offAge=8,offAgeMax=10}
            local item={getScriptItem=function() return 'Egg' end}
            local result=HCRBarDrinks.solidSnapshot(data,item,food)
            assert(not result.dangerousUncooked and result.poisonPower==.7 and result.age==11)
            assert(food.dangerousUncooked)
            item.getScriptItem=function() return 'Sugar' end
            assert(HCRBarDrinks.solidSnapshot(data,item,food).dangerousUncooked)
        ''')

    def test_native_recipe_volumes_and_empty_destinations(self):
        catalog=json.loads((REPO/'tools/milk_cocktail_catalog.json').read_text(encoding='utf-8'))
        recipes={name:body for p in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(p),'craftRecipe')}
        self.assertEqual(len(catalog['families']),6)
        self.assertEqual(len(catalog['products']),6)
        for name,rule in catalog['products'].items():
            body=recipes[name]
            volume=sum(float(n) for n in re.findall(r'-fluid ([\d.]+)',body))
            self.assertAlmostEqual(volume,rule['litres'])
            self.assertNotIn('HCR42.recipe_hcpot',body)
            self.assertIn('mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty]',body)
            self.assertIn('OnCreate = HCRBarDrinks.create',body)
        self.assertEqual(catalog['products']['Make Eggnog Cuppa']['count'],4)
        self.assertIn('item 1 [Base.Chocolate] flags[ItemCount]',recipes['Make Eggnog Cuppa'])


if __name__=='__main__': unittest.main()
