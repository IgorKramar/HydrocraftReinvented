"""Regressions for B42 portions, split outputs and food duplication.

Uses Lua 5.1 via lupa. Engine consumption/order was checked against 42.21;
the mocks below only supply that API, they do not consume items themselves.
"""
import re
import unittest
from pathlib import Path

from lupa.lua51 import LuaRuntime
from test_food_quality import MOCKS as QUALITY_MOCKS

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / 'common/media/lua/server'
SCRIPTS = ROOT / 'common/media/scripts/HydrocraftReinvented'

MOCKS = r'''
function list(items)
    return {size=function() return #items end, get=function(_,i) return items[i+1] end}
end
function food(calories, hunger, uses)
    local f={calories=calories, carbs=calories/10, lipids=calories/20,
             proteins=calories/25, hunger=hunger, base=hunger, uses=uses, age=3, poison=7, data={}}
    function f:IsFood() return true end
    f.container={contains=function(_,item) return item==f end}
    function f:getContainer() return self.container end
    function f:getWorldItem() return self.world end
    function f:updateAge() end
    function f:getFullType() return "Hydrocraft.Food" end
    function f:getCurrentUses() return self.uses end
    function f:getReplaceOnUse() return self.replacement end
    function f:getModData() return self.data end
    function f:getPoisonPower() return self.poison end
    function f:setPoisonPower(value) self.poison=value end
    function f:getPoisonDetectionLevel() return self.detection or -1 end
    function f:setPoisonDetectionLevel(value) self.detection=value end
    function f:getAge() return self.age end
    function f:setAge(value) self.age=value end
    function f:getOffAge() return self.fresh or 5 end
    function f:setOffAge(value) self.fresh=value end
    function f:getOffAgeMax() return self.rotten or 8 end
    function f:setOffAgeMax(value) self.rotten=value end
    function f:isTainted() return self.tainted or false end
    function f:setTainted(value) self.tainted=value end
    function f:getReplaceOnCooked() return nil end
    function f:getCookingTime() return self.cookingTime or 0 end
    function f:isCookable() return self.cookable or false end
    function f:getMinutesToCook() return 20 end
    local fields={Calories="calories", Carbohydrates="carbs", Lipids="lipids",
                  Proteins="proteins", HungChange="hunger", BaseHunger="base"}
    for suffix, field in pairs(fields) do
        f["get"..suffix]=function(self) return self[field] end
        f["set"..suffix]=function(self, value) self[field]=value end
    end
    function f:copyFoodFromSplit(source, count)
        self.copiedSource=source; self.divisor=count
        self.calories=source.calories/count; self.hunger=source.hunger/count
        self.age=source.age; self.poison=source.poison
    end
    return f
end
function tool()
    local item={IsFood=function() return false end, getFullType=function() return "Base.Tool" end,
            getCurrentUses=function() return 1 end,getWorldItem=function() return nil end}
    item.getContainer=function() return {contains=function(_,candidate) return candidate==item end} end
    return item
end
function input(items, amount, whole, keep, scale)
    local script={items=items, amount=amount, whole=whole, keep=keep, scale=scale or 1}
    function script:isKeep() return self.keep end
    function script:isItemCount() return self.whole end
    function script:isVariableAmount() return false end
    function script:getIntAmount() return self.amount end
    function script:getRelativeScale(_) return self.scale end
    return script
end
function data(scripts, outputs)
    local d={scripts=scripts, outputs=outputs}
    function d:getRecipe()
        return {getInputs=function() return list(scripts) end, getName=function() return "Test" end}
    end
    function d:getDataForInputScript(script)
        return {getAppliedItemsCount=function() return #script.items end,
                getAppliedItem=function(_,i) return script.items[i+1] end}
    end
    function d:getAllCreatedItems() return list(outputs) end
    function d:getInputItems(slot) return list(scripts[slot+1].items) end
    function d:getAllConsumedItems()
        local items={}
        for _, script in ipairs(scripts) do
            if not script.keep then for _,item in ipairs(script.items) do items[#items+1]=item end end
        end
        return list(items)
    end
    return d
end
'''


class FoodCallbacks(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(QUALITY_MOCKS)
        self.lua.execute((LUA.parent/'shared/HCR_FoodQuality.lua').read_text(encoding='utf-8'))
        self.lua.execute(MOCKS)
        self.lua.execute((LUA / 'HCR_FoodBridge.lua').read_text(encoding='utf-8'))

    def test_partial_oil_contributes_only_consumed_uses(self):
        self.lua.execute('''
            oil=food(1000,-0.10,10); potato=food(80,-0.08,8); result=food(0,0,1)
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.MakeFrenchFries",
                data({input({tool()},1,true,true),input({potato},1,true,false),
                      input({oil},1,false,false)}, {result}),nil)
        ''')
        self.assertAlmostEqual(self.lua.globals().result.calories, 180)
        self.assertAlmostEqual(self.lua.globals().result.hunger, -0.09)
        self.assertEqual(self.lua.globals().oil.calories, 1000)  # engine consumes later

    def test_two_partly_eaten_whole_potatoes_and_butter(self):
        self.lua.execute('''
            a=food(40,-0.04,4); b=food(80,-0.08,8); butter=food(600,-0.12,12)
            result=food(0,0,1)
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.MakeCreamyMashedPotatoes",
                data({input({a,b},2,true,false),input({butter},1,false,false)}, {result}),nil)
        ''')
        self.assertAlmostEqual(self.lua.globals().result.calories, 170)
        self.assertAlmostEqual(self.lua.globals().result.hunger, -0.13)

    def test_quantity_spans_more_than_one_food_item(self):
        self.lua.execute('''
            a=food(100,-0.02,2); b=food(300,-0.06,6); result=food(0,0,1)
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.GenericFood",
                data({input({a,b},3,false,false)}, {result}),nil)
        ''')
        self.assertAlmostEqual(self.lua.globals().result.calories, 150)
        self.assertAlmostEqual(self.lua.globals().result.hunger, -0.03)

    def test_kept_food_does_not_contribute_nutrition(self):
        self.lua.execute('''
            garnish=food(900,-0.09,9); ingredient=food(100,-0.10,10); result=food(0,0,1)
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.GenericFood",
                data({input({garnish},1,true,true),input({ingredient},1,true,false)}, {result}),nil)
        ''')
        self.assertEqual(self.lua.globals().result.calories, 100)

    def test_every_cheese_piece_inherits_actual_food_and_age(self):
        self.lua.execute('''
            cheese=food(480,-0.48,48); cheese.age=8; outputs={}
            for i=1,8 do outputs[i]=food(999,-1,1) end
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.CutIntoEightPieces",
                data({input({tool()},1,true,true),input({cheese},1,true,false)}, outputs),nil)
        ''')
        pieces = self.lua.globals().outputs
        self.assertEqual(sum(pieces[i].calories for i in range(1, 9)), 480)
        for i in range(1, 9):
            self.assertEqual(pieces[i].calories, 60)
            self.assertEqual(pieces[i].age, 8)
            self.assertAlmostEqual(self.lua.globals().HCRFoodQuality.dose(pieces[i]),7/8)
            self.assertEqual(pieces[i].poison,1)
            self.assertEqual(pieces[i].divisor, 8)

    def test_nonfood_outputs_do_not_divide_nutrition(self):
        self.lua.execute('''
            source=food(240,-0.24,24); a=food(0,0,1); b=food(0,0,1)
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.CutIntoTwoPieces",
                data({input({source},1,true,false)}, {tool(),a,b}),nil)
        ''')
        self.assertEqual(self.lua.globals().a.calories, 120)
        self.assertEqual(self.lua.globals().b.calories, 120)

    def test_unknown_callback_is_left_to_legacy_bridge(self):
        self.assertFalse(self.lua.eval('HCRFood.tryOnCreate("Hunt",nil,nil)'))

    def test_live_aggregation_recipes_do_not_discard_nutritious_fluids(self):
        # Fluid consumption occurs during performCurrentRecipe, before OnCreate.
        # Current fixed-nutrition milk/liquor recipes do not use this aggregator.
        # Any future nutritious-fluid aggregation route needs an actual native
        # consumed-fluid sample integration before it may pass this guard.
        from apply_playability_fixes import blocks
        names = {'GenericFood', 'BakePotato', 'MakePotatoPancakes',
                 'MakePlainMashedPotatoes', 'MakeCreamyMashedPotatoes',
                 'MakeFrenchFries', 'MakeBowlofCereal'}
        for path in SCRIPTS.glob('*.txt'):
            for _, _, recipe, body in blocks(path.read_text(encoding='utf-8-sig'), 'craftRecipe'):
                on_create = re.search(r'OnCreate\s*=\s*HCR42\.Hydrocraft_OnCreate_(\w+)', body)
                if not on_create or on_create[1] not in names:
                    continue
                for fluid in re.findall(r'-fluid\s+[\d.]+\s+\[([^]]+)\]', body):
                    with self.subTest(recipe=recipe):
                        self.assertEqual(fluid, 'Water')

    def test_every_legacy_complex_food_callback_uses_native_amounts(self):
        for name in ('BakePotato', 'MakePotatoPancakes', 'MakePlainMashedPotatoes',
                     'MakeCreamyMashedPotatoes', 'MakeFrenchFries', 'MakeBowlofCereal'):
            with self.subTest(callback=name):
                self.lua.execute('ingredient=food(80,-0.08,8); result=food(0,0,1)')
                handled = self.lua.eval('function(name) return HCRFood.tryOnCreate(name, '
                                        'data({input({ingredient},1,true,false)}, {result}),nil) end')(
                                            'Hydrocraft.OnCreate.' + name)
                self.assertTrue(handled)
                self.assertEqual(self.lua.globals().result.calories, 80)

    def test_paper_bag_preserves_food_and_returns_one_pan(self):
        self.lua.execute((LUA / 'Food/Functions.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            source=food(350,-0.35,35); source.age=9; result=food(0,0,1)
            function source:getFullType() return "Hydrocraft.HCFries" end
            function source:getActualWeight() return 0.3 end
            function source:getScriptItem() return {getDisplayName=function() return "Fries" end} end
            function source:getUnhappyChange() return 1 end
            function source:getBoredomChange() return 2 end
            function source:getStressChange() return 3 end
            function result:copyFoodFrom(other) self:copyFoodFromSplit(other,1) end
            function result:setName(value) self.name=value end
            function result:setUnhappyChange(value) end
            function result:setBoredomChange(value) end
            function result:setStressChange(value) end
            function result:setCustomWeight(value) end
            function result:setWeight(value) self.weight=value end
            function result:setActualWeight(value) self.actualWeight=value end
            bag={IsFood=function() return false end,
                 getFullType=function() return "Base.PaperBag" end,
                 getActualWeight=function() return 0.1 end}
            InventoryItemFactory={CreateItem=function(_) return {getActualWeight=function() return 1 end} end}
            pans=0
            player={getInventory=function() return {AddItem=function() pans=pans+1 end} end}
            HCRecipe.OnCreate.TransferToPaperBag_GiveRoastingPan(list({source,bag}),result,player)
        ''')
        result = self.lua.globals().result
        self.assertEqual(result.calories, 350)
        self.assertEqual(result.age, 9)
        self.assertEqual(result.poison, 7)
        self.assertAlmostEqual(result.actualWeight, 0.1)
        self.assertEqual(self.lua.globals().pans, 1)

    def test_partial_sauce_does_not_return_bowl_and_whole_sauce_does(self):
        self.lua.execute('''
            partial=food(200,-0.20,20); partial.replacement="Bowl"
            whole=food(200,-0.20,20); whole.replacement="Base.Bowl"
            bowls=0
            player={getInventory=function() return {AddItem=function(_,ft)
                assert(ft=="Base.Bowl"); bowls=bowls+1 end} end}
            HCRFood.returnContainer(data({input({partial},1,false,false),
                                         input({whole},1,true,false)},{}),player,"Base.Bowl")
        ''')
        self.assertEqual(self.lua.globals().bowls, 1)

    def test_multiple_partial_uses_empty_one_bowl_only_once(self):
        self.lua.execute('''
            sauce=food(100,-0.10,10); sauce.replacement="Bowl"; bowls=0
            player={getInventory=function() return {AddItem=function() bowls=bowls+1 end} end}
            HCRFood.returnContainer(data({input({sauce},5,false,false),
                                         input({sauce},5,false,false)},{}),player,"Base.Bowl")
        ''')
        self.assertEqual(self.lua.globals().bowls, 1)

    def test_two_portions_return_one_original_pot(self):
        self.lua.execute('''
            source=food(240,-0.24,24); source.replacement="Base.Pot"
            a=food(0,0,1); b=food(0,0,1); pots=0
            player={getInventory=function() return {AddItem=function(_,ft)
                assert(ft=="Base.Pot"); pots=pots+1 end} end}
            HCRFood.tryOnCreate("Hydrocraft.OnCreate.CutIntoTwoPieces",
                data({input({source},1,true,false)}, {a,b}),player)
        ''')
        self.assertEqual(self.lua.globals().pots, 1)

    def test_legacy_bowls_callback_respects_native_consumption_metadata(self):
        self.lua.execute((LUA / 'HCExtra.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            a=food(100,-0.10,10); a.replacement="Bowl"
            b=food(100,-0.10,10); b.replacement="Bowl"; bowls=0
            player={getInventory=function() return {AddItem=function() bowls=bowls+1 end} end}
            HCRecipeBowls(list({a,b}),nil,player,
                data({input({a},1,false,false),input({b},1,true,false)},{}))
        ''')
        self.assertEqual(self.lua.globals().bowls, 1)

    def test_bottling_returns_normal_barrel_but_not_a_partial_drainable(self):
        self.lua.execute((LUA / 'HCExtra.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            barrels=0
            player={getInventory=function() return {AddItem=function() barrels=barrels+1 end} end}
            normal={getFullType=function() return 'Hydrocraft.HCBarrelwine' end,IsDrainable=function() return false end}
            drainable={getFullType=function() return 'Hydrocraft.HCBarrelOtherMod' end,IsDrainable=function() return true end}
            recipe_hcwoodenbarrel(list({drainable}),nil,player)
            assert(barrels==0)
            recipe_hcwoodenbarrel(list({normal}),nil,player)
        ''')
        self.assertEqual(self.lua.globals().barrels, 1)

    def test_food_tag_ingredients_are_consumed(self):
        for path in SCRIPTS.glob('*.txt'):
            text = path.read_text(encoding='utf-8-sig')
            self.assertIsNone(re.search(r'item\s+\d+\s+tags\[(Egg|Potato)\]\s+mode:keep', text), path.name)

    def test_mashed_potato_splitting_consumes_whole_food(self):
        text = (SCRIPTS / 'HCR_Food Taters.txt').read_text(encoding='utf-8-sig')
        for source in ('HCMashedpotatosplain', 'HCMashedpotatoscreamy'):
            self.assertIn('item 1 [Hydrocraft.' + source + '] flags[ItemCount]', text)


if __name__ == '__main__':
    unittest.main(verbosity=2)
