"""Conservation across native-style handcraft, evolved replacement and partial ingredients."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, read_text
from test_food_quality import MOCKS as QUALITY
from test_food_callbacks import MOCKS as FOOD


class FoodTransfers(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(QUALITY)
        self.lua.execute(read_text(LUA/'shared/HCR_FoodQuality.lua'))
        self.lua.execute(FOOD)
        self.lua.execute(read_text(LUA/'server/HCR_FoodBridge.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_FoodConsumption.lua'))
        self.lua.execute('''
            ISHandcraftAction={performRecipe=function(self)
                self.logic:getRecipeData():luaCallOnCreate(self.character)
                self.logic:getRecipeData():processDestroyAndUsedItems(self.character)
            end}
            ISAddItemInRecipe={isValidStart=function() return true end,isValid=function() return true end,complete=function(self)
                self.baseItem=self.recipe:addItem(self.baseItem,self.usedItem,self.character)
                return true
            end}
            function instanceItem() return food(0,0,1) end
            character={getFullName=function() return 'Private test' end}
            function evolvedItem(calories,hunger,dose)
                local f=food(calories,hunger,20)
                f.container={}
                function f:getContainer() return self.container end
                function f:isCooked() return self.cooked or false end
                function f:isSpice() return self.spice or false end
                function f:getReplaceOnUse() return nil end
                if dose then HCRFoodQuality.store(f,dose) end
                return f
            end
            function recipe(fraction,replace,remove,poisonOnly)
                local r={}
                function r:getFullResultItem() return 'Base.Salad' end
                function r:getItemRecipe() return not poisonOnly and {getUse=function() return 10 end} or nil end
                function r:addItem(base,used)
                    assert(used.data[HCRFoodQuality.key]==nil,'Sidecar could leak into empty dish')
                    if replace then base=evolvedItem(0,0) end
                    for _,key in ipairs({'calories','proteins','carbs','lipids'}) do
                        used[key]=used[key]*(1-fraction)
                    end
                    used.hunger=used.hunger*(1-fraction/(used.cooked and not used.spice and 1.3 or 1))
                    if remove then used.container=nil end
                    return base
                end
                return r
            end
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FoodTransfers.lua'))

    def test_legacy_zero_hunger_aguardiente_refuses_without_changing_dish_or_source(self):
        self.lua.execute('''
            base=evolvedItem(100,-.1,.2);used=evolvedItem(2150,0,.8)
            function used:getFullType() return 'Hydrocraft.HCAguaardiente' end
            HCRFoodQuality.setQuality(used,'rotten')
            local r=recipe(1,true,true)
            function r:addItem() error('Unsafe native division reached') end
            action={recipe=r,baseItem=base,usedItem=used,character=character}
            for _,name in ipairs({'isValidStart','isValid','complete'}) do
                assert(ISAddItemInRecipe[name](action)==false,name)
            end
            assert(HCRFoodTransfers.addIngredient(r,base,used,character)==base)
            assert(action.baseItem==base and action.recipe==r)
            assert(base.calories==100 and used.calories==2150 and used:getContainer())
            assert(HCRFoodQuality.quality(base)=='fresh' and HCRFoodQuality.quality(used)=='rotten')
            assert(HCRFoodQuality.dose(base)==.2 and HCRFoodQuality.dose(used)==.8)
        ''')

    def test_aguardiente_guard_retains_poison_and_modified_hunger_but_blocks_zero_hunger_spice(self):
        self.lua.execute('''
            used=evolvedItem(2150,0,.8)
            function used:getFullType() return 'Hydrocraft.HCAguaardiente' end
            assert(HCRFoodTransfers.canAddIngredient(recipe(0,false,false,true),used))
            local negative={getItemRecipe=function() return {getUse=function() return -1 end} end}
            assert(HCRFoodTransfers.canAddIngredient(negative,used))
            used.spice=true;assert(not HCRFoodTransfers.canAddIngredient(recipe(1),used))
            used.spice=false;used.hunger=-.1
            assert(HCRFoodTransfers.canAddIngredient(recipe(1),used))
            used.hunger=0;function used:getFullType() return 'Base.OtherModDrink' end
            assert(HCRFoodTransfers.canAddIngredient(recipe(1),used))
        ''')

    def test_handcraft_without_callback_keeps_poison_and_restores_logic(self):
        self.lua.execute('''
            source=food(200,-.2,20);source.detection=10;source.data.addedPoisonBy='Private test'
            HCRFoodQuality.store(source,.875)
            result=food(300,-.3,30)
            d=data({input({source},1,true,false)},{result})
            function d:luaCallOnCreate() end
            function d:processDestroyAndUsedItems() source.poison=0;source.used=true;source.container=nil;source.uses=0 end
            logic={getRecipeData=function() return d end}
            action={logic=logic,character=character}
            ISHandcraftAction.performRecipe(action)
            assert(action.logic==logic and source.used)
        ''')
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(result)'),.875)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(source)'),0)
        self.assertEqual(self.lua.globals().result.calories,300)
        self.assertEqual(self.lua.globals().result.detection,10)
        self.assertEqual(self.lua.globals().result.data.addedPoisonBy,'Private test')

    def test_partial_craft_counts_all_poisoned_inputs_once_and_preserves_remainder(self):
        self.lua.execute('''
            tracked=food(200,-.2,20);HCRFoodQuality.store(tracked,.875)
            ordinary=food(80,-.08,8);ordinary.poison=2
            a=food(10,-.01,1);b=food(10,-.01,1)
            d=data({input({tracked},5,false,false),input({ordinary},4,false,false)},{a,b})
            state=HCRFoodTransfers.captureCraft(d)
            HCRFoodTransfers.finishCreate(state,d,character)
            HCRFoodTransfers.remaining(state,character)
        ''')
        dose=self.lua.eval('HCRFoodQuality.dose')
        g=self.lua.globals()
        self.assertAlmostEqual(dose(g.a)+dose(g.b)+dose(g.tracked)+dose(g.ordinary),2.875)
        self.assertAlmostEqual(dose(g.tracked),.875*.75)

    def test_fractional_hunger_uses_actual_32_percent_in_poison_and_nutrition(self):
        self.lua.execute('''
            source=food(400,-.125,12);HCRFoodQuality.store(source,1.25)
            result=food(999,-1,1)
            d=data({input({source},4,false,false)},{result})
            function d:luaCallOnCreate()
                HCRFood.tryOnCreate('Hydrocraft.OnCreate.GenericFood',self,character)
                assert(result.calories==999,'Nutrition must wait for actual native consumption')
            end
            function d:processDestroyAndUsedItems()
                source.calories=272;source.carbs=27.2;source.lipids=13.6;source.proteins=10.88
                source.hunger=-.085;source.uses=8
            end
            ISHandcraftAction.performRecipe({logic={getRecipeData=function() return d end},character=character})
        ''')
        self.assertAlmostEqual(self.lua.globals().result.calories,128)
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(result)'),.4)
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(source)'),.85)
        self.assertAlmostEqual(self.lua.globals().result.hunger,-.04)

    def test_full_removal_transfers_fractional_tail(self):
        self.lua.execute('''
            source=food(400,-.125,12);HCRFoodQuality.store(source,1.25)
            result=food(999,-1,1)
            d=data({input({source},12,false,false)},{result})
            function d:luaCallOnCreate() HCRFood.tryOnCreate('Hydrocraft.OnCreate.GenericFood',self,character) end
            function d:processDestroyAndUsedItems()
                source.calories=16;source.hunger=-.005;source.uses=0;source.container=nil
            end
            ISHandcraftAction.performRecipe({logic={getRecipeData=function() return d end},character=character})
        ''')
        self.assertEqual(self.lua.globals().result.calories,400)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(result)'),1.25)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(source)'),0)

    def test_actual_hashset_order_ignores_unused_rotten_candidate(self):
        self.lua.execute('''
            a=food(1000,-.02,2);HCRFoodQuality.store(a,10);HCRFoodQuality.setQuality(a,'rotten')
            b=food(300,-.06,6);HCRFoodQuality.store(b,3)
            result=food(999,-1,1)
            d=data({input({a,b},3,false,false)},{result})
            function d:luaCallOnCreate() HCRFood.tryOnCreate('Hydrocraft.OnCreate.GenericFood',self,character) end
            function d:processDestroyAndUsedItems()
                b.calories=150;b.carbs=15;b.lipids=7.5;b.proteins=6;b.hunger=-.03;b.uses=3
            end
            ISHandcraftAction.performRecipe({logic={getRecipeData=function() return d end},character=character})
        ''')
        self.assertEqual(self.lua.globals().result.calories,150)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(result)'),1.5)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(a)'),10)
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(result)'),'fresh')
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(a)'),'rotten')

    def test_ground_partial_food_is_present_without_inventory_container(self):
        self.lua.execute('''
            source=food(400,-.125,12);source.container=nil
            source.world={getWorldObjectIndex=function() return 0 end}
            local entries=HCRFoodConsumption.capture(data({input({source},4,false,false)},{}))
            source.hunger=-.085;source.uses=8
            actual=HCRFoodConsumption.measure(entries)[source]
        ''')
        self.assertAlmostEqual(self.lua.globals().actual,.32)

    def test_zero_hunger_retained_food_does_not_create_native_unchanged_nutrition(self):
        self.lua.execute('''
            source=food(400,0,4);HCRFoodQuality.store(source,2)
            result=food(999,-1,1)
            d=data({input({source},1,false,false)},{result})
            function d:luaCallOnCreate() HCRFood.tryOnCreate('Hydrocraft.OnCreate.GenericFood',self,character) end
            function d:processDestroyAndUsedItems() source.uses=3 end
            ISHandcraftAction.performRecipe({logic={getRecipeData=function() return d end},character=character})
        ''')
        self.assertEqual(self.lua.globals().result.calories,0)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(result)'),.5)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(source)'),1.5)

    def test_float_truncation_does_not_count_an_extra_consumed_use(self):
        self.lua.execute('''
            source=food(300,-.03,3)
            local entries=HCRFoodConsumption.capture(data({input({source},1,false,false)},{}))
            source.hunger=-.019999999552965164;source.uses=1
            HCRFoodConsumption.measure(entries)
            used=entries[source].used
        ''')
        self.assertAlmostEqual(self.lua.globals().used,1,places=6)

    def test_evolved_replacement_preserves_base_dose_and_actual_fraction(self):
        self.lua.execute('''
            base=evolvedItem(200,-.2,.375);used=evolvedItem(400,-.4,1.25)
            r=recipe(.25,true,false)
            action={recipe=r,baseItem=base,usedItem=used,character=character}
            ISAddItemInRecipe.complete(action)
            assert(action.recipe==r and action.baseItem~=base)
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(action.baseItem)'),.375+1.25*.25)
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(used)'),1.25*.75)

    def test_evolved_taint_reaches_new_dish_and_partial_ingredient(self):
        self.lua.execute('''
            base=evolvedItem(200,-.2);used=evolvedItem(400,-.4)
            used:setTainted(true) -- native ingress ещё без sidecar.
            local r=recipe(.25,true,false);local native=r.addItem
            function r:addItem(base,used,character)
                assert(used.data[HCRFoodQuality.taintKey]==nil,'Taint leaked to empty replacement')
                return native(self,base,used,character)
            end
            result=HCRFoodTransfers.addIngredient(r,base,used,character)
            result.tainted=false;used.tainted=false -- native network serialization.
            HCRFoodQuality.reconcile(result);HCRFoodQuality.reconcile(used)
            assert(result:isTainted() and used:isTainted())
        ''')

    def test_craft_taint_uses_actual_consumption_and_clears_empty_container_metadata(self):
        self.lua.execute('''
            source=food(400,-.4,40);source:setTainted(true) -- native ingress.
            local d=data({input({source},1,true,false)},{food(200,-.2,20)})
            local entries=HCRFoodConsumption.capture(d,false)
            HCRFoodConsumption.clearFood(entries)
            assert(source.data[HCRFoodQuality.taintKey]==nil)
            source.uses=20;source.hunger=-.2
            local state={entries=entries,tracked=true,fluids={}}
            HCRFoodTransfers.actualCraft(state,d)
            HCRFoodConsumption.restoreFood(entries)
            HCRFoodTransfers.finishCreate(state,d)
            assert(state.tainted and HCRFoodQuality.tainted(d.outputs[1]))
            assert(HCRFoodQuality.tainted(source))
        ''')

    def test_last_ingredient_use_transfers_remainder_even_when_native_numbers_remain(self):
        self.lua.execute('''
            base=evolvedItem(100,-.1,.2);used=evolvedItem(400,-.4,.8)
            result=HCRFoodTransfers.addIngredient(recipe(.25,false,true),base,used,character)
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(result)'),1)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(used)'),0)

    def test_retained_cooking_mead_keeps_strength_even_without_quality_sidecars(self):
        self.lua.execute(read_text(LUA/'shared/HCR_AlcoholPortions.lua'))
        for dose in (0,.875):
            with self.subTest(dose=dose):
                self.lua.globals().dose=dose
                self.lua.execute('''
                    base=evolvedItem(0,0,0);used=evolvedItem(142.4,-.08,dose)
                    function used:getFullType() return 'Hydrocraft.HCRCookingMead' end
                    used.baseHunger=-.2
                    function used:getBaseHunger() return self.baseHunger end
                    function used:setBaseHunger(n) self.baseHunger=n end
                    local r=recipe(.7,true,false)
                    local add=r.addItem
                    function r:addItem(base,used,character)
                        used:setBaseHunger(used:getBaseHunger()+.056)
                        return add(self,base,used,character)
                    end
                    result=HCRFoodTransfers.addIngredient(r,base,used,character)
                ''')
                self.assertAlmostEqual(self.lua.eval('2*used:getHungChange()/used:getBaseHunger()'),.24)
                self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(used)'),dose*.3)
                self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(result)'),dose*.7)

    def test_cooked_zero_nutrition_and_spice_fallback_use_correct_native_fractions(self):
        for spice in (False,True):
            with self.subTest(spice=spice):
                self.lua.globals().spice=spice
                self.lua.execute('''
                    base=evolvedItem(0,-.1,.2);used=evolvedItem(0,-.4,.8)
                    used.cooked=true;used.spice=spice
                    result=HCRFoodTransfers.addIngredient(recipe(.25,false,false),base,used,character)
                ''')
                self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(result)'),.4)
                self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(used)'),.6)

    def test_poison_only_addition_transfers_all_dose_without_consuming_nutrition(self):
        self.lua.execute('''
            base=evolvedItem(100,-.1,.2);used=evolvedItem(400,-.4,.8)
            HCRFoodQuality.setQuality(used,'rotten')
            result=HCRFoodTransfers.addIngredient(recipe(0,false,false,true),base,used,character)
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRFoodQuality.dose(result)'),1)
        self.assertEqual(self.lua.eval('HCRFoodQuality.dose(used)'),0)
        self.assertEqual(self.lua.globals().used.calories,400)
        self.assertEqual(self.lua.eval('used.data[HCRFoodQuality.qualityKey].state'),'rotten')

    def test_rotten_tracked_ingredient_cannot_be_laundered_by_native_evolved_replacement(self):
        self.lua.execute('''
            base=evolvedItem(100,-.1);used=evolvedItem(400,-.4)
            HCRFoodQuality.setQuality(used,'rotten')
            result=HCRFoodTransfers.addIngredient(recipe(.25,true,false),base,used,character)
        ''')
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(result)'),'rotten')
        self.assertEqual(self.lua.eval('HCRFoodQuality.quality(used)'),'rotten')

    def test_drink_callback_receives_scoped_quality_and_exception_cleans_context(self):
        self.lua.execute('''
            source=food(200,-.2,20);HCRFoodQuality.store(source,.875)
            d=data({input({source},1,true,false)},{})
            function d:luaCallOnCreate()
                observed=HCRFoodTransfers.contexts[self].dose
                error('callback interrupted')
            end
            logic={getRecipeData=function() return d end}
            action={logic=logic,character=character}
            ok=pcall(ISHandcraftAction.performRecipe,action)
        ''')
        self.assertFalse(self.lua.globals().ok)
        self.assertEqual(self.lua.globals().observed,.875)
        self.assertIsNone(self.lua.eval('HCRFoodTransfers.contexts[d]'))
        self.assertTrue(self.lua.eval('action.logic==logic'))


if __name__=='__main__': unittest.main()
