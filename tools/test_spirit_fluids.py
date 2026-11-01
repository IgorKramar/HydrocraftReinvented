"""Полная цепочка спиртного и запреты, которые нельзя обойти переливанием."""
import json
import re
import unittest
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from apply_playability_fixes import blocks
import test_fluid_recipe_quality as quality
import test_fluid_crafting as crafting
import test_wine_quality as wine


class SpiritClosure(unittest.TestCase):
    def test_migrated_food_ids_have_no_live_recipe_edges(self):
        catalog=json.loads((REPO/'tools/spirit_fluid_catalog.json').read_text(encoding='utf-8'))
        self.assertEqual(len(catalog['families']),36)
        recipes={name:body for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'craftRecipe')}
        items={name:body for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'item')}
        for old,spec in catalog['families'].items():
            self.assertRegex(items[old.split('.')[1]],r'ItemType\s*=\s*base:food')
            self.assertRegex(items[spec['target'].split('.')[1]],r'ItemType\s*=\s*base:normal')
            for name,body in recipes.items(): self.assertNotRegex(body,re.escape(old)+r'\b',name)
        for name,rule in catalog['pours'].items():
            self.assertEqual((rule['count'],rule['litres']),(1,.1))
            self.assertIn('-fluid 0.1 [',recipes[name])
        for name,rule in catalog['consumers'].items():
            self.assertIn('-fluid '+('1' if name.startswith('Make Monkey Tail Pot') else '0.1')+' [',recipes[name])
            for index,slot in rule['inputs'].items():
                if name!='Mix Margarita' and not name.startswith('Make Monkey Tail Pot') and not (name=='Mix Long Island Iced Tea' and index=='2'): self.assertEqual(slot['exact'],.1)
                if slot.get('nativeSink'): self.assertIn('mode:destroy flags[ItemCount;ItemIsFluid;HandcraftOnly]',recipes[name])
                for marker in slot['fluids']: self.assertIn(marker,recipes[name])
        for name in catalog['emptyRecipes']:
            self.assertIn('Hydrocraft.HCVodkaFluid',recipes[name])
            self.assertNotIn('Hydrocraft.HCMezcalFluid]',recipes[name].split('outputs')[0])


class SpiritEligibility(unittest.TestCase):
    setUp=quality.FluidRecipeQuality.setUp
    # Только новые тесты; родительский setup предоставляет настоящий ledger.
    def test_cooking_rejects_domestic_vodka_and_legacy_glasses_even_as_traces(self):
        self.lua.execute(read_text(LUA/'shared/HCR_AlcoholPortions.lua'))
        self.lua.execute('''
            local R,A,L=HCRFluidRecipeQuality,HCRAlcoholPortions,HCRFluidLedger
            R.rules.Test=A.rules['Prepare Spirit for Cooking']
            Fluid={Water='Water',Get=function(k) return k end}
            function source:createFluidSample()
                return {size=function() return 1 end,getFluid=function() return 'HCRVodka' end,release=function() end}
            end
            local retail=L.batch('HCRVodka',1,{sourceType='Hydrocraft.HCVodka1'},0)
            source.data=retail
            assert(R.compatible(recipe,source,0))
            for _,kind in ipairs({'Hydrocraft.HCVodka','Hydrocraft.HCDrinkglasstallvodka'}) do
                local trace=L.batch('HCRVodka',.001,{sourceType=kind},0)
                trace.lots[1].litres=0
                source.data=L.mix(retail,trace)
                assert(not R.compatible(recipe,source,0),kind)
            end
        ''')


class SpiritEmptyGuard(unittest.TestCase):
    setUp=crafting.FluidCrafting.setUp
    def test_empty_requirement_also_sees_untracked_world_owned_liquid_without_consume_slot(self):
        self.lua.execute('''
            InputFlag.IsEmpty='IsEmpty'
            function HCRFluidQuality.rawAmount(i) return i.amount end
            tracked.tracked=false;pot.tracked=false;clean.amount=0
            consume.isKeep=function() return false end
            consume.hasConsumeFromItem=function() return false end
            consume.hasFlag=function(_,flag) return flag=='IsEmpty' end
            manual=true
            assert(not HCRFluidCrafting.check(logic))
            assert(tracked.amount==.1 and not performed)
            manual=false
            local restore=HCRFluidCrafting.prepareSafeInputs(logic)
            assert(selected[1]:size()==1 and selected[1]:get(0)==clean)
            restore()
        ''')


class SpiritPour(unittest.TestCase):
    setUp=wine.WineQuality.setUp
    def test_one_tenth_litre_does_not_inherit_fixed_395_calories(self):
        self.lua.execute('''
            HCRFluidEffects={prepare=function(l) HCRFluidLedger.validate(l) end}
            HCRFluidQuality={fluid=function(i) return i.fluid end,
                amounts=function(f) return {HCRGin=f.amount} end,
                store=function(i,f,l) i.ledger=l end,sync=function() end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_WineQuality.lua'))
        self.lua.execute('''
            local L,W=HCRFluidLedger,HCRWineQuality
            W.rules.Test={target='Glass',count=1,litres=.1}
            local bottle=L.batch('HCRGin',1,{calories=2142,poisonPower=.875,hungChange=-.2,baseHunger=-.2,alcoholic=true,alcoholPower=2},0)
            local kept,part=L.split(bottle,.1,1)
            local f={amount=0,isEmpty=function(self) return self.amount==0 end,
                addFluid=function(self,_,a) self.amount=self.amount+a end}
            local item={fluid=f,getFullType=function() return 'Glass' end}
            local d=data({},{item});d.getRecipe=function() return {getName=function() return 'Test' end} end
            W.glasses({fluids={part}},d,nil)
            assert(math.abs(L.budget(item.ledger,'calories')-214.2)<1e-8)
            assert(math.abs(L.budget(item.ledger,'poisonPower')-.0875)<1e-8)
            assert(math.abs(L.budget(kept,'calories')-1927.8)<1e-8)
            assert(item.ledger.lots[1].food.baseHunger==-.2 and f.amount==.1)
        ''')


if __name__=='__main__': unittest.main()
