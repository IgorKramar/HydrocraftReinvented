"""Native cooking removes the entire mixture; account actual component deltas once."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text


class FluidRecipeQuality(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            function list(a) return {size=function() return #a end,get=function(_,i) return a[i+1] end} end
            InputFlag={Unseal='Unseal',InheritUsesAndEmpty='InheritUsesAndEmpty'}
            script={isKeep=function() return true end,hasConsumeFromItem=function() return true end,
                hasCreateToItem=function() return false end,isReplace=function() return false end,
                hasFlag=function() return false end}
            source={amount=1,tracked=.5,data=nil}
            recipe={getName=function() return 'Test' end,getInputs=function() return list({script,script}) end}
            data={getRecipe=function() return recipe end,getInputItems=function() return list({source}) end}
            HCRFluidQuality={
                fluid=function(i) return i end,
                active=function(i) return i.data~=nil end,
                rawAmount=function(i) return i.amount end,
                amounts=function(i) return {Juice=i.tracked} end,
                capture=function(i)
                    return {item=i,fluid=i,ledger=i.data,amount=i.amount,amounts={Juice=i.tracked}}
                end,
                store=function(i,_,ledger) i.data=ledger end,
                sync=function() syncs=(syncs or 0)+1 end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidLedger.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_FluidRecipeQuality.lua'))
        self.lua.execute('''
            HCRFluidRecipeQuality.rules.Test={slots={[0]=true,[1]=true}}
            source.data=HCRFluidLedger.batch('Juice',.5,{calories=200,poisonPower=.875},0)
        ''')

    def test_mixed_native_consumption_keeps_exact_remaining_dose_and_counts_vessel_once(self):
        self.lua.execute('''
            result,removed=HCRFluidRecipeQuality.perform(data,{},function()
                source.amount=.8;source.tracked=.4;return true
            end)
        ''')
        self.assertTrue(self.lua.globals().result)
        self.assertEqual(len(self.lua.globals().removed),1)
        self.assertEqual(self.lua.globals().syncs,1)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(source.data,'poisonPower')"),.7)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[1],'poisonPower')"),.175)

    def test_pure_fermentation_input_rejects_dilution_without_changing_other_recipes(self):
        self.lua.execute('''
            Fluid={Water='Water',Get=function(s) return s end}
            function source:createFluidSample()
                return {size=function() return 2 end,getFluid=function(_,i) return i==0 and 'Juice' or 'Water' end,
                    release=function() end}
            end
            local rule=HCRFluidRecipeQuality.rules.Test
            rule.fluids={'Juice'}
            assert(HCRFluidRecipeQuality.compatible(recipe,source,0))
            rule.pure=true
            assert(not HCRFluidRecipeQuality.compatible(recipe,source,0))
            assert(source.amount==1 and source.tracked==.5)
        ''')

    def test_partial_native_failure_still_debits_consumed_quality(self):
        self.lua.execute('''
            ok=pcall(HCRFluidRecipeQuality.perform,data,{},function()
                source.amount=.8;source.tracked=.4;error('native interrupted')
            end)
        ''')
        self.assertFalse(self.lua.globals().ok)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(source.data,'poisonPower')"),.7)

    def test_unselected_candidate_is_not_written_or_synchronised(self):
        self.lua.execute('result,removed=HCRFluidRecipeQuality.perform(data,{},function() return false end)')
        self.assertFalse(self.lua.globals().result)
        self.assertEqual(len(self.lua.globals().removed),0)
        self.assertIsNone(self.lua.globals().syncs)

    def test_measured_mash_captures_only_matching_native_water_once(self):
        self.lua.execute('''
            local L,R=HCRFluidLedger,HCRFluidRecipeQuality
            function getGameTime() return {getWorldAgeHours=function() return 10 end} end
            Fluid={Water='Water'}
            HCRBarDrinks={waterSnapshot=function() return {calories=0,thirstChange=-.4} end}
            R.rules.Test={inputs={[0]={fluids={'Water'},nativeWater=true,pure=true}}}
            script.isAcceptsAnyItem=function() return true end
            script.getConsumeFromItemScript=function() return {isFluidMatch=function(_,i) return i.water end} end
            source.water=true;source.amount=20;source.tracked=0;source.data=L.empty()
            source.getSpecificFluidAmount=function(i) return i.amount end
            local wrong={amount=3,tracked=0,data=L.empty(),water=false}
            data.getInputItems=function() return list({source,wrong}) end
            local snapshots=R.capture(data)
            assert(#snapshots==1 and L.volume(snapshots[1].nativeWater)==20)
            local result,removed=R.perform(data,{},function() source.amount=1.5;return true end,snapshots)
            assert(result and #removed==1 and L.volume(removed[1])==18.5)
            assert(L.budget(removed[1],'calories')==0 and wrong.amount==3)
            assert(not syncs and source.amount==1.5)
        ''')

    def test_fermenting_mash_cannot_start_another_clock(self):
        self.lua.execute('''
            Fluid={Water='Water',Get=function(s) return s end}
            source.createFluidSample=function() return {size=function() return 1 end,
                getFluid=function() return 'Juice' end,release=function() end} end
            local rule=HCRFluidRecipeQuality.rules.Test;rule.fluids={'Juice'};rule.unfermented=true
            assert(HCRFluidRecipeQuality.compatible(recipe,source,0))
            -- capture реальной партии уже проверяет clock; здесь проверяется
            -- фильтрация native-кандидата до расхода и смены часов.
            source.data.lots[1].fermentation={kind='active'}
            assert(not HCRFluidRecipeQuality.compatible(recipe,source,0))
            assert(source.amount==1 and source.data.lots[1].fermentation.kind=='active')
        ''')

    def test_recipe_composition_preserves_unrelated_native_and_hcr_mixtures(self):
        self.lua.execute('''
            Fluid={Water='Water',Get=function(name) return name end}
            HCRFluidRecipeQuality.rules.Test.fluids={'Juice','Lime'}
            function source:createFluidSample()
                return {size=function() return #components end,
                    getFluid=function(_,i) return components[i+1] end,
                    release=function() released=true end}
            end
        ''')
        for kinds,expected in [(['Juice'],True),(['Juice','Water'],True),(['Juice','Lime'],True),
                               (['Juice','TaintedWater'],False),(['Juice','Brandy'],False),
                               (['Juice','HCRWhiskey'],False)]:
            self.lua.globals().components=self.lua.table_from(kinds)
            self.lua.globals().released=False
            self.assertEqual(self.lua.eval('HCRFluidRecipeQuality.compatible(recipe,source)'),expected)
            self.assertTrue(self.lua.globals().released)
        self.lua.execute('''
            components={'Juice','Water'}
            local trace=HCRFluidLedger.batch('HCRWhiskey',.01,{alcoholic=true},0)
            trace.lots[1].litres=0
            source.data=HCRFluidLedger.mix(source.data,trace)
        ''')
        self.assertFalse(self.lua.eval('HCRFluidRecipeQuality.compatible(recipe,source)'))

    def test_milk_and_alcohol_slots_keep_separate_whitelists_and_snapshot_policies(self):
        self.lua.execute('''
            function getGameTime() return {getWorldAgeHours=function() return 48 end} end
            Fluid={Water='Water',Get=function(name) return name end}
            local L=HCRFluidLedger
            HCRFluidRecipeQuality.rules.Test={inputs={
                [0]={fluids={'CowMilk'},nativeMilk=true},
                [1]={fluids={'Whiskey'},nativeWine='HCRWhiskey'}}}
            function nativeSource(kind,amount)
                local item={kind=kind,amount=amount,tracked=0,data=L.empty()}
                function item:createFluidSample()
                    return {size=function() return 1 end,getFluid=function() return self.kind end,release=function() end}
                end
                return item
            end
            milk=nativeSource('CowMilk',1);whisky=nativeSource('Whiskey',1)
            data.getInputItems=function(_,slot) return list({slot==0 and milk or whisky}) end
            HCRNativeMilk={snapshot=function(item)
                assert(item==milk,'Alcohol captured as milk');return {calories=615} end}
            HCRWineQuality={snapshot=function(item)
                assert(item==whisky,'Milk captured as alcohol');return {calories=2142,nativeAlcohol=.4} end}
            assert(HCRFluidRecipeQuality.compatible(recipe,milk,0))
            assert(not HCRFluidRecipeQuality.compatible(recipe,whisky,0))
            assert(HCRFluidRecipeQuality.compatible(recipe,whisky,1))
            assert(not HCRFluidRecipeQuality.compatible(recipe,milk,1))
            assert(not HCRFluidRecipeQuality.compatible(recipe,milk))
            assert(not HCRFluidRecipeQuality.allowed(recipe,2,script))
            captured=HCRFluidRecipeQuality.capture(data)
            removed=HCRFluidRecipeQuality.finish(captured,{})
            assert(#removed==0)
            milk.amount=.9;whisky.amount=.75
            removed=HCRFluidRecipeQuality.finish(captured,{})
        ''')
        self.assertEqual(len(self.lua.globals().captured),2)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[1],'calories')"),61.5)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[2],'calories')"),535.5)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(removed[2],'nativeAlcohol')"),.1)


if __name__=='__main__': unittest.main()
