"""Брожение, дробный уксус и native алкоголь сохраняют качество и бюджет."""
import unittest
from hcr_paths import LUA, SCRIPTS, read_text
from apply_playability_fixes import blocks
import test_process_quality as base


class WineQuality(unittest.TestCase):
    setUp=base.ProcessQuality.setUp
    def test_mead_sake_producers_are_closed_without_changing_legacy_food_classes(self):
        items={name:body for path in SCRIPTS.rglob('*.txt')
               for _,_,name,body in blocks(read_text(path),'item')}
        recipes={name:body for path in SCRIPTS.rglob('*.txt')
                 for _,_,name,body in blocks(read_text(path),'craftRecipe')}
        for kind,name in [('HCMead','Make Bottle of Mead'),('HCSake','Make Bottle of Sake')]:
            self.assertRegex(items[kind],r'ItemType\s*=\s*base:food')
            self.assertIn('item 20 Base.Whiskey,',recipes[name])
            for recipe,body in recipes.items():
                self.assertNotRegex(body,r'Hydrocraft\.'+kind+r'\b',recipe)

    def test_bottling_uses_hc_prototype_not_factory_whisky_nutrition(self):
        self.lua.execute('''
            function instanceItem(kind)
                local f=food(kind=='Hydrocraft.HCMead' and 356 or 39,-.2,20)
                f.fresh=1000000000;f.rotten=1000000000
                return f
            end
            HCRFluidEffects={snapshot=function(f)
                return {calories=f:getCalories(),dose=HCRFoodQuality.dose(f),
                    quality=HCRFoodQuality.quality(f),baseline=f:getBaseHunger()}
            end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_WineQuality.lua'))
        self.lua.execute('''
            for _,kind in ipairs({'Mead','Sake'}) do
            for _,quality in ipairs({'fresh','stale','rotten'}) do
                local rule=HCRWineQuality.outputs['Make Bottle of '..kind]
                local result=HCRWineQuality.bottledSnapshot(rule,{},
                    {dose=3.25,quality=quality,detection=4,tainted=true})
                assert(result.tainted)
                assert(result.calories==(kind=='Mead' and 356 or 39))
                assert(result.dose==3.25/20 and result.quality==quality and result.baseline==-.2)
            end end
        ''')
    def test_fermentation_has_ready_window_and_offline_catchup(self):
        self.lua.execute(read_text(LUA/'shared/HCR_TimedDefinitions.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_TimedItems.lua'))
        resolve=self.lua.globals().HCRTimed.resolve
        for source,ready in [('grape','wine'),('grapegreen','winewhite'),('honey','mead'),('rice','sake')]:
            prefix='Hydrocraft.HCBarrel'
            self.assertEqual(resolve(prefix+source,10,345.999)[0],prefix+source)
            self.assertEqual(resolve(prefix+source,10,346),(prefix+ready,346))
            self.assertEqual(resolve(prefix+source,10,681.999)[0],prefix+ready)
            self.assertEqual(resolve(prefix+source,10,1000),(prefix+'vinegar',682))

    def test_bottling_does_not_publish_a_factory_entity_snapshot_before_final_contents(self):
        self.lua.execute('''
            HCRFluidEffects={prepare=function(l) HCRFluidLedger.validate(l) end}
            HCRFluidQuality={fluid=function(i) return i.fluid end,
                rawAmount=function(f) return f.amount end,
                amounts=function(f) return {[f.kind]=f.amount} end,
                store=function(i,f,l) assert(f.kind=='HCRMead');i.ledger=l end,
                sync=function(i) assert(i.fluid.canEmpty and i.ledger);published=(published or 0)+1 end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_WineQuality.lua'))
        self.lua.execute('''
            function HCRWineQuality.bottledSnapshot(rule,fluid,state)
                return {calories=356,poisonPower=state.dose/rule.count}
            end
            local outputs={}
            for i=1,20 do
                local f={amount=1,kind='Whiskey',canEmpty=false}
                function f:unseal() error('Unsafe early entity snapshot') end
                function f:setCanPlayerEmpty(value) self.canEmpty=value end
                function f:Empty() assert(self.canEmpty);self.amount=0 end
                function f:addFluid(kind,amount) assert(self.amount==0);self.kind=kind;self.amount=amount end
                outputs[i]={fluid=f,getFullType=function() return 'Base.Whiskey' end}
            end
            local d=data({},outputs)
            function d:getRecipe() return {getName=function() return 'Make Bottle of Mead' end} end
            assert(HCRWineQuality.finish({quality='fresh',dose=3.25},d,nil))
            assert(published==20)
        ''')

    def test_plain_rotten_grapes_force_quality_on_normal_bucket(self):
        self.lua.execute('''
            source=food(200,-.2,20);source.age=20
            target=stage('HCWoodenbucketgrape')
            d=data({input({source},1,true,false)},{target})
            state=HCRFoodTransfers.captureCraft(d,false,true)
            HCRFoodTransfers.finishCreate(state,d,nil)
        ''')
        self.assertEqual(self.lua.eval('HCRProcessQuality.read(target).quality'),'rotten')

    def test_partial_vinegar_use_debits_actual_remaining_budget(self):
        self.lua.execute('''
            source=stage('unused');source.getFullType=function() return 'Base.Vinegar2' end
            source.getCurrentUses=function() return 7 end
            HCRProcessQuality.write(source,{dose=.875,quality='stale',detection=4},1,nil)
            output=food(0,-.2,20)
            d=data({input({source},2,false,false)},{output})
            state=HCRFoodTransfers.captureCraft(d)
            HCRFoodTransfers.finishCreate(state,d,nil)
            HCRProcessQuality.remaining(state)
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(output)'),.25)
        self.assertAlmostEqual(self.lua.eval('HCRProcessQuality.read(source).dose'),.625)
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(output)'),'stale')

    def test_fermentation_preserves_floor_without_raw_mash_one_day_expiry(self):
        self.lua.execute('''
            source=stage('HCBarrelhoney')
            HCRProcessQuality.write(source,{dose=3.25,quality='stale',detection=7},1,nil)
            now=24*20
        ''')
        self.assertEqual(self.lua.eval('HCRProcessQuality.read(source).quality'),'stale')
        self.assertAlmostEqual(self.lua.eval('HCRProcessQuality.read(source).dose'),3.25)

    def test_native_alcohol_scales_with_sips_and_stays_out_of_food_setters(self):
        self.lua.execute('''
            ledger=HCRFluidLedger.batch('HCRWineRed',1,{nativeAlcohol=.12,calories=481},0)
            kept,used=HCRFluidLedger.split(ledger,.25,1)
        ''')
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(used,'nativeAlcohol')"),.03)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(kept,'nativeAlcohol')"),.09)
        self.assertAlmostEqual(self.lua.eval("HCRFluidLedger.budget(used,'calories')"),120.25)
        with self.assertRaises(Exception):
            self.lua.execute("HCRFluidLedger.batch('HCRWineRed',1,{nativeAlcohol=-1},0)")

    def test_four_native_glasses_preserve_diluted_wine_budget(self):
        self.lua.execute('''
            HCRFluidEffects={prepare=function(l) HCRFluidLedger.validate(l) end}
            HCRFluidQuality={fluid=function(i) return i.fluid end,
                amounts=function(f) return {HCRWineRed=f.amount} end,
                store=function(i,f,l) i.ledger=l end,sync=function() end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_WineQuality.lua'))
        self.lua.execute('''
            local L=HCRFluidLedger
            local wine=L.batch('HCRWineRed',1,{nativeAlcohol=.12,calories=481,poisonPower=.875},0)
            local _,portion=L.split(wine,.6,1)
            local water=L.batch('HCRWineRed',.4,{nativeAlcohol=0,thirstChange=-.04},0)
            local outputs={}
            for i=1,4 do
                local f={amount=0,isEmpty=function(self) return self.amount==0 end,
                    addFluid=function(self,name,amount) self.amount=self.amount+amount end}
                outputs[i]={fluid=f,getFullType=function() return 'Hydrocraft.HCWineglassFluid' end}
            end
            local d=data({},outputs)
            d.getRecipe=function() return {getName=function() return 'Pour Wine' end} end
            HCRWineQuality.glasses({fluids={portion,water}},d,nil)
            alcohol,calories,dose,litres=0,0,0,0
            for _,item in ipairs(outputs) do
                alcohol=alcohol+L.budget(item.ledger,'nativeAlcohol')
                calories=calories+L.budget(item.ledger,'calories')
                dose=dose+L.budget(item.ledger,'poisonPower')
                litres=litres+item.fluid.amount
                assert(item.fluid.amount==.25)
            end
        ''')
        for key,value in [('alcohol',.072),('calories',288.6),('dose',.525),('litres',1)]:
            self.assertAlmostEqual(self.lua.globals()[key],value)


if __name__=='__main__': unittest.main()
