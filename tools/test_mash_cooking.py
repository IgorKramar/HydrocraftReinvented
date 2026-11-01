"""Граница приготовления не восстанавливает съеденное и не очищает яд."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text
from test_food_quality import MOCKS


class MashCooking(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        for name in ('HCR_MashCatalog','HCR_FoodQuality','HCR_MashCooking'):
            self.lua.execute(read_text(LUA/f'shared/{name}.lua'))
        self.lua.execute('''
            function instanceItem(kind)
                local f=fixture();f.fresh=1;f.rotten=kind:find('potato') and 3 or 1;return f
            end
            function sample(kind,quality,burnt)
                local f=fixture();f.kind=kind;f.hunger=-.15;f.base=-.3;f.calories=137
                f.cooked=not burnt;f.burnt=burnt or false
                function f:isCooked() return self.cooked end
                function f:isBurnt() return self.burnt end
                HCRFoodQuality.store(f,.625);HCRFoodQuality.setQuality(f,quality);HCRFoodQuality.setTainted(f)
                f.cookingTime=121
                return f
            end
            HCRFluidEffects.snapshot=function(f)
                HCRFoodQuality.reconcile(f)
                return {calories=f.calories,hungChange=f.hunger,baseHunger=f.base,
                    cooked=f.cooked,burnt=f.burnt,dangerousUncooked=true,
                    poisonPower=HCRFoodQuality.dose(f),tainted=HCRFoodQuality.tainted(f)}
            end
        ''')

    def test_actual_remaining_nutrition_quality_and_native_heat_for_every_raw_kind(self):
        self.lua.execute('''
            for kind,spec in pairs(HCRMashCatalog.raw) do for _,quality in ipairs({'fresh','stale','rotten'}) do
                local f=sample(kind,quality)
                local food=HCRMashCooking.snapshot(f,spec)
                assert(food.calories==137 and food.hungChange/food.baseHunger==.5)
                assert(food.poisonPower==.625 and not food.tainted)
                assert(not food.cooked and not food.dangerousUncooked and f.cooked)
                assert(HCRFoodQuality.quality(f)==quality)
                assert(f.rotten==(kind:find('potato') and 3 or 1))
                f.age=f.age+.5;local age=f.age
                HCRMashCooking.snapshot(f,spec);assert(f.age==age,'Repeated boundary reset freshness')
            end end
        ''')

    def test_burnt_saved_stock_keeps_burning_and_unheated_raw_is_untouched(self):
        self.lua.execute('''
            local kind='Hydrocraft.HCPofake'
            local untouched=sample(kind,'fresh');HCRMashCooking.OnCooked(untouched)
            assert(not untouched.data.HCRMashCooked160)
            kind='Hydrocraft.HCPotofpotatomash'
            local f=sample(kind,'rotten',true)
            local food=HCRMashCooking.snapshot(f,HCRMashCatalog.raw[kind])
            assert(food.burnt and food.calories==137 and food.poisonPower==.625)
            local raw=sample(kind,'fresh');raw.cooked=false;raw.burnt=false;raw.cookingTime=0
            HCRMashCooking.OnCooked(raw)
            assert(raw.fresh==3 and raw.rotten==7 and raw.age==0 and not raw.data.HCRMashCooked160)
        ''')


if __name__=='__main__':unittest.main()
