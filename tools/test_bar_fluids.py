"""Бар: состав, замкнутые recipe edges и независимые входы спирта/смесей."""
import json
import re
import unittest
from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from build_water_catalog import props
from hcr_paths import LUA, REPO, SCRIPTS, read_text


class BarFluids(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end; HCRDrinkFamilies={}
            function getGameTime() return {getWorldAgeHours=function() return 10 end} end
            HCRFluidQuality={fluid=function(item) return item.fluid end}
            HCRFluidEffects={snapshot=function(item) return item.food end,
                prepare=function(ledger) HCRFluidLedger.validate(ledger) end}
            function instanceItem() return {fluid={getCapacity=function() return 1 end,isEmpty=function() return true end}} end
            function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
        ''')
        for name in ('HCR_FluidLedger','HCR_BarCatalog','HCR_BrewedDrinks','HCR_BarDrinks'):
            self.lua.execute(read_text(LUA/f'shared/{name}.lua'))

    def test_mixer_retains_consumed_juice_water_and_solid_budgets(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            local juice=L.batch('HCRJuiceTomato',.08,{calories=51.5,poisonPower=.175,age=8,offAge=3,offAgeMax=7},10)
            local water=L.batch('Water',.02,{thirstChange=-.02},10)
            local solid={food={calories=200,poisonPower=.5,age=0,offAge=3,offAgeMax=7},fraction=.125}
            result=HCRBarDrinks.compose({juice,water},{solid},'HCRBloodyMaryMixer',.1)
            assert(L.matches(result,{HCRBloodyMaryMixer=.1}))
            assert(L.quality(result)=='rotten')
            assert(math.abs(L.budget(result,'calories')-76.5)<1e-8)
            assert(math.abs(L.budget(result,'poisonPower')-.2375)<1e-8)
            assert(not pcall(HCRBarDrinks.compose,{juice},{solid},'HCRBloodyMaryMixer',1))
            local kept,used=L.split(result,.025,.1)
            assert(math.abs(L.budget(used,'poisonPower')-.059375)<1e-8)
            assert(math.abs(L.budget(kept,'calories')-57.375)<1e-8)
            assert(juice.lots[1].fluid=='HCRJuiceTomato' and solid.food.calories==200)
        ''')

    def test_catalog_closes_old_ids_and_preserves_loading_classes(self):
        catalog=json.loads((REPO/'tools/bar_fluid_catalog.json').read_text(encoding='utf-8'))
        items={name:props(body) for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'item')}
        recipes={name:body for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'craftRecipe')}
        self.assertEqual(len(catalog['families']),6)
        for kind,spec in catalog['families'].items():
            self.assertEqual(items[kind.split('.')[1]]['itemtype'],'base:drainable' if spec.get('unitLitres') else 'base:food')
            self.assertEqual(items[spec['target'].split('.')[1]]['itemtype'],'base:normal')
            for name,body in recipes.items(): self.assertNotRegex(body,re.escape(kind)+r'\b',name)
        for name,rule in catalog['products'].items():
            self.assertEqual(rule['litres'],.1)
            self.assertIn('OnCreate = HCRBarDrinks.create',recipes[name])

    def test_native_pruned_tail_keeps_all_food_units_in_actual_output_volume(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            for _,diluted in ipairs({false,true}) do
                local parts={L.batch('HCRJuiceLemon',diluted and .08 or .10005,{calories=123.5,poisonPower=.875},10)}
                if diluted then parts[2]=L.batch('Water',.02005,{thirstChange=-.02005},10) end
                local result=HCRBarDrinks.compose(parts,{},'HCRLemonMixer',.1)
                assert(math.abs(L.volume(result)-.1)<1e-8)
                assert(L.budget(result,'calories')==123.5 and L.budget(result,'poisonPower')==.875)
                assert(result.lots[1].units==1)
            end
        ''')

    def test_auto_selection_ignores_unrelated_food_but_preflights_real_solid_candidates(self):
        self.lua.execute('''
            local items={}
            for i=1,129 do
                items[i]={food={age=i,offAge=3,offAgeMax=7},IsFood=function() return true end,
                    getFullType=function() return 'Base.OtherFood' end,updateAge=function() end}
            end
            local name='Make Lemon Mixer'
            local data={getRecipe=function() return {getName=function() return name end} end,
                getInputItems=function() return list(items) end}
            assert(HCRBarDrinks.plan(data,{}))
            name='Make Bloody Mary Mixer';assert(HCRBarDrinks.plan(data,{}))
            for _,item in ipairs(items) do item.getFullType=function() return 'Base.Salt' end end
            assert(not HCRBarDrinks.plan(data,{}),'Real excessive solid batches should refuse')
        ''')

    def test_modifier_rules_merge_without_losing_native_whisky_or_other_slots(self):
        self.lua.execute('''
            HCRFluidRecipeRules={['Mix Martini']={inputs={[1]={fluids={'HCRGin'},nativeSink=true,exact=.1}}}}
            HCRSpiritCatalog={consumers={['Mix Manhattan']={inputs={[1]={fluids={'HCRWhiskey','Whiskey'},nativeSink=true,exact=.1,nativeWine='HCRWhiskey'}}}}}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidRecipeQuality.lua'))
        self.lua.execute('''
            local R=HCRFluidRecipeQuality.rules
            assert(R['Mix Martini'].inputs[1].exact==.1)
            assert(R['Mix Martini'].inputs[2].fluids[1]=='HCRBitters')
            assert(R['Mix Martini'].inputs[3].fluids[1]=='HCRVermouth')
            assert(R['Mix Manhattan'].inputs[1].nativeWine=='HCRWhiskey')
            assert(R['Mix Long Island Iced Tea'].inputs[3].fluids[1]=='HCRLemonMixer')
            assert(R['Mix Long Island Iced Tea'].inputs[4].fluids[1]=='HCRLimeMixer')
        ''')

    def test_bar_capture_skips_native_ineligible_auto_fluid_candidates(self):
        self.lua.execute('''
            InputFlag={};Fluid={Water='Water'};HCRFluidRecipeRules={}
            local candidate={isKeep=function() return true end,hasConsumeFromItem=function() return true end,
                hasCreateToItem=function() return false end,isReplace=function() return false end,
                hasFlag=function() return false end,isAcceptsAnyItem=function() return false end,
                containsItem=function(_,kind) return kind=='Bottle' end,
                getConsumeFromItemScript=function() return {isFluidMatch=function(_,f) return f.kind=='Juice' end} end}
            function source(kind,container)
                return {fluid={kind=kind,getSpecificFluidAmount=function() return 0 end},
                    getScriptItem=function() return container end}
            end
            juice=source('Juice','Bottle');water=source('Water','Bottle');wrong=source('Juice','WrongVessel')
            local sources={juice,water,wrong}
            for i=1,129 do sources[#sources+1]=source('Water','Bottle') end
            data={getRecipe=function() return {getName=function() return 'Make Lemon Mixer' end,
                getInputs=function() return list({candidate,candidate}) end} end,
                getInputItems=function() return list(sources) end}
            HCRFluidQuality.active=function() return true end
            HCRFluidQuality.capture=function(item) assert(item==juice);return {ledger=HCRFluidLedger.empty()} end
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidRecipeQuality.lua'))
        self.lua.execute('''
            HCRFluidRecipeQuality.rules['Make Lemon Mixer']={inputs={[0]={fluids={'Juice'}},[1]={fluids={'Juice'}}}}
            local captured=HCRFluidRecipeQuality.capture(data)
            assert(#captured==1,'Only the actually eligible donor is counted, once')
        ''')


if __name__=='__main__': unittest.main()
