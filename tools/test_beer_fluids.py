"""Пиво: перепаковка не обнуляет состав, дозу или историю начатой банки."""
import json
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, SCRIPTS, read_text
from apply_playability_fixes import blocks


class BeerFluids(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            function isClient() return false end
            function isServer() return false end
            function getGameTime() return {getWorldAgeHours=function() return 100 end} end
            HCRDrinkFamilies={}; HCRFluidEffects={}; Fluid={Get=function(s) return s end}
        ''')
        for name in ('HCR_FluidLedger', 'HCR_FluidQuality', 'HCR_BeerFamilies', 'HCR_BeerQuality'):
            self.lua.execute(read_text(LUA/f'shared/{name}.lua'))
        self.lua.execute('''
            L,Q,B=HCRFluidLedger,HCRFluidQuality,HCRBeerQuality
            Q.transport={HCRBeer=true}
            Q.environment=function() return {cold=false,freezer=false,powered=false,temperature=1} end
            function array(values)
                return {size=function() return #values end,get=function(_,i) return values[i+1] end}
            end
            function instanceItem(kind)
                local f={amount=0,kind='HCRBeer',mixture=false}
                function f:getCapacity() return .3 end
                function f:isEmpty() return self.amount==0 end
                function f:isMixture() return self.mixture end
                function f:getPrimaryFluid() return self.kind end
                function f:getSpecificFluidAmount(kind) return self.kind==kind and self.amount or 0 end
                function f:createFluidSample() return {getAmount=function() return self.amount end,release=function() end} end
                function f:addFluid(kind,amount) self.kind=kind;self.amount=self.amount+amount end
                function f:getRainCatcher() return 0 end
                function f:setRainCatcher() end
                local item={kind=kind,fluid=f,data={}}
                function item:getFullType() return self.kind end
                function item:getFluidContainer() return self.fluid end
                function item:getModData() return self.data end
                function item:getSpices() return nil end
                function item:haveExtraItems() return self.extra end
                return item
            end
            function HCRFluidEffects.snapshot(item)
                return {sourceType=item.kind,age=0,heat=1,hungChange=-.05,baseHunger=-.05,
                    calories=215,carbohydrates=13,proteins=2.5,lipids=0,poisonPower=0,
                    offAge=1000000000,offAgeMax=1000000000,alcoholic=true,alcoholPower=2}
            end
            function HCRFluidEffects.prepare(ledger) L.validate(ledger) end
            function fresh()
                local item=instanceItem('Hydrocraft.HCBeercan1Fluid')
                item.fluid.amount=.3
                Q.store(item,item.fluid,L.batch('HCRBeer',.3,HCRFluidEffects.snapshot(instanceItem('Hydrocraft.HCBeercan1')),0))
                B.mark(item)
                return item
            end
            function data(name,inputs,outputs)
                return {getRecipe=function() return {getName=function() return name end} end,
                    getInputItems=function() return array(inputs or {}) end,
                    getAllCreatedItems=function() return array(outputs or {}) end}
            end
        ''')

    def test_factory_accepts_ordinary_age_and_heat(self):
        self.lua.execute('''
            local item=fresh();assert(B.factory(item))
            local lot=item.data[Q.key].lots[1];lot.age=600;lot.food.age=600;lot.food.heat=2
            Q.store(item,item.fluid,item.data[Q.key]);assert(B.factory(item))
        ''')

    def test_changed_or_malformed_contents_cannot_be_repacked(self):
        for change in (
            "lot.food.poisonPower=.125", "lot.food.calories=214", "lot.food.burnt=true",
            "lot.food.sourceType='Hydrocraft.HCBeercan2'", "lot.food.offAgeMax=1;lot.age=2",
            "lot.units=.5", "lot.basisLitres=.15", "item.fluid.amount=.15",
            "item.fluid.mixture=true", "item.fluid.kind='Water'", "lot.food.calories=0/0",
        ):
            with self.subTest(change=change):
                self.lua.execute('local item=fresh();local lot=item.data[Q.key].lots[1];'+change+';assert(not B.factory(item))')

    def test_pour_then_refill_does_not_restore_factory_stamp(self):
        self.lua.execute('''
            local item=fresh();local original=L.copy(item.data[Q.key])
            local half=L.split(original,.15,.3);item.fluid.amount=.15
            Q.store(item,item.fluid,half);assert(not item.data[B.key])
            item.fluid.amount=.3;Q.store(item,item.fluid,original)
            assert(not B.factory(item))
        ''')

    def test_emptying_clears_stamp_and_quality(self):
        self.lua.execute('''
            local item=fresh();item.fluid.amount=0;Q.store(item,item.fluid,L.empty())
            assert(not item.data[B.key] and not item.data[Q.key])
        ''')

    def test_legacy_extras_do_not_gain_factory_stamp(self):
        self.lua.execute('''
            local item=fresh();item.data[B.key]=nil
            local source=instanceItem('Hydrocraft.HCBeercan1');source.extra=true
            B.mark(item,source);assert(not B.factory(item))
        ''')

    def test_pack_preflight_checks_six_and_wrong_brand(self):
        self.lua.execute('''
            local items={};for i=1,6 do items[i]=fresh() end
            assert(B.preflight(data('Pack Beer',items)))
            items[6]=nil;assert(not pcall(B.preflight,data('Pack Beer',items)))
            items[6]=fresh();items[6].kind='Hydrocraft.HCBeercan2Fluid'
            assert(not pcall(B.preflight,data('Pack Beer',items)))
        ''')

    def test_factory_exception_is_limited_to_counted_pack_input(self):
        self.lua.execute('''
            InputFlag={ItemCount='ItemCount'}
            local recipe={getName=function() return 'Pack Beer' end}
            local script={hasFlag=function(_,flag) return flag=='ItemCount' end,
                isKeep=function() return false end,hasConsumeFromItem=function() return false end,
                hasCreateToItem=function() return false end,isReplace=function() return false end}
            local item=fresh()
            assert(B.packingInput(recipe,0,script,item))
            assert(not B.packingInput(recipe,1,script,item))
            assert(not B.packingInput({getName=function() return 'Other recipe' end},0,script,item))
            script.hasConsumeFromItem=function() return true end
            assert(not B.packingInput(recipe,0,script,item))
        ''')

    def test_unpack_all_brands_conserves_serving_budgets(self):
        self.lua.execute('''
            for name,rule in pairs(HCRBeerCatalog.unpacking) do
                local outputs={};for i=1,6 do outputs[i]=instanceItem(rule.target) end
                local craft=data(name,{},outputs);assert(B.preflight(craft));assert(B.finish({},craft,nil))
                local volume,calories,carbs,protein=0,0,0,0
                for _,item in ipairs(outputs) do
                    assert(B.factory(item));local ledger=item.data[Q.key]
                    volume=volume+L.volume(ledger);calories=calories+L.budget(ledger,'calories')
                    carbs=carbs+L.budget(ledger,'carbohydrates');protein=protein+L.budget(ledger,'proteins')
                end
                assert(math.abs(volume-1.8)<.000001 and calories==1290 and carbs==78 and protein==15)
            end
        ''')

    def test_all_legacy_classes_retained_and_pack_outputs_native(self):
        config=json.loads(Path('tools/beer_fluid_catalog.json').read_text())
        items={};recipes={}
        for path in SCRIPTS.rglob('*.txt'):
            text=read_text(path)
            items.update({name:body for _,_,name,body in blocks(text,'item')})
            recipes.update({name:body for _,_,name,body in blocks(text,'craftRecipe')})
        self.assertEqual(len(config['families']),18)
        self.assertEqual(len(config['unpacking']),10)
        for source,spec in config['families'].items():
            self.assertIn('base:food',items[source.split('.')[1]])
            target=items[spec['target'].split('.')[1]]
            self.assertIn('Capacity = 0.3,',target)
            self.assertNotIn('fluids',target)
        for name,rule in config['unpacking'].items():
            self.assertIn('item 6 '+rule['target']+',',recipes[name])


if __name__=='__main__': unittest.main(verbosity=2)
