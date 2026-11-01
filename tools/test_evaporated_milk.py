"""Разбавление остатка концентрата сохраняет объём и реальные свойства Food."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,read_text


class EvaporatedMilk(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            function getGameTime() return {getWorldAgeHours=function() return 10 end} end
            function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
            HCRMilkChainProducts={test={name='Dilute',litres=1,count=1,foodSlot=0,
                foodLitres=.3,variableYield=true,outputTarget='Base.Milk'}}
            HCRFluidQuality={fluid=function(item) return item.fluid end,
                rawAmount=function(fluid) return fluid.amount end,
                amounts=function(fluid) return {HCRMilk=fluid.amount} end,
                store=function(item,fluid,ledger) item.ledger=ledger end,sync=function() end}
            HCRFluidEffects={prepare=function(ledger) HCRFluidLedger.validate(ledger) end}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_FluidLedger.lua'))
        self.lua.execute(read_text(LUA/'shared/HCR_MilkChains.lua'))
        self.lua.execute('''
            function fixture(remaining)
                local L=HCRFluidLedger
                -- Modified nutrition/poison must not be scaled twice.
                local snapshot={baseHunger=-.3,hungChange=-.3*remaining,calories=137,
                    poisonPower=.875,age=9,offAge=2,offAgeMax=4,tainted=true}
                local uses=math.floor(30*remaining)
                local food={getCurrentUses=function() return uses end}
                local applied={getAppliedItemsCount=function() return 1 end,getAppliedItem=function() return food end}
                local target={getFullType=function() return 'Base.Milk' end,fluid={amount=0,
                    getCapacity=function() return 1 end,Empty=function(f) f.amount=0 end,
                    addFluid=function(f,k,v) f.amount=f.amount+v end}}
                local data={getRecipe=function() return {getName=function() return 'Dilute' end,
                    getInputs=function() return list({{}}) end} end,
                    getDataForInputScript=function() return applied end,
                    getAllCreatedItems=function() return list({target}) end}
                local water=L.batch('HCRMilk',.7,{calories=0},10)
                HCRFood={getConsumedFoodFractions=function() return {[food]=1} end}
                HCRFoodTransfers={contexts={[data]={fluids={water}}},
                    foodSnapshot=function() return snapshot end,
                    consumedUses=function() return uses end,deferCreate=function() return false end}
                function isClient() return false end
                return data,target,water,snapshot
            end
        ''')

    def test_full_half_and_small_remainders_conserve_modified_budgets(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            for _,fraction in ipairs({1,.5,.01}) do
                local data,target,water=fixture(fraction)
                assert(HCRMilkChains.preflight(data,{{ledger=water}}))
                HCRMilkChains.create(HCRMilkChainProducts.test,data,{})
                assert(math.abs(target.fluid.amount-(.7+.3*fraction))<.000001)
                assert(math.abs(L.volume(target.ledger)-target.fluid.amount)<.000001)
                assert(math.abs(L.budget(target.ledger,'calories')-137)<.000001)
                assert(math.abs(L.budget(target.ledger,'poisonPower')-.875)<.000001)
                assert(L.quality(target.ledger)=='rotten')
                local tainted=false;for _,lot in ipairs(target.ledger.lots) do tainted=tainted or lot.food.tainted end
                assert(tainted)
                assert(L.volume(water)==.7,'Input ledger changed')
            end
        ''')

    def test_invalid_or_unknown_food_remainder_refuses_before_creation(self):
        self.lua.execute('''
            for _,fraction in ipairs({0,-.1,1.01}) do
                local data,target,water=fixture(fraction)
                assert(not pcall(HCRMilkChains.preflight,data,{{ledger=water}}))
                assert(target.fluid.amount==0 and HCRFluidLedger.volume(water)==.7)
            end
            local data,target,water,snapshot=fixture(.5)
            snapshot.baseHunger=nil
            assert(not pcall(HCRMilkChains.preflight,data,{{ledger=water}}))
            assert(target.fluid.amount==0 and HCRFluidLedger.volume(water)==.7)
        ''')
