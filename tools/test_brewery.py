"""Новая пивоварня: реальный остаток, независимые часы, порча и хмель."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, SCRIPTS, read_text
from apply_playability_fixes import blocks


class Brewery(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().package.path=(LUA/'shared').as_posix()+'/?.lua'
        self.lua.execute('''
            require 'HCR_Fermentation'
            function require() end
            function getGameTime() return {getWorldAgeHours=function() return 0 end} end
            L=HCRFluidLedger;F=HCRFermentation;C=HCRBreweryCatalog
            active='Hydrocraft.HCRWheatWortBatch';ready='Hydrocraft.HCRWheatBeerBatch'
            function profile(kind,quality)
                return {calories=500,carbohydrates=36,proteins=4,lipids=0,nativeAlcohol=.05,
                    age=quality=='rotten' and 30 or quality=='stale' and 14 or 0,
                    offAge=14,offAgeMax=30,canBeFrozen=false}
            end
        ''')
        for name in ('HCR_BrewedDrinkRules','HCR_BrewedDrinks'):
            self.lua.execute(read_text(LUA/f'shared/{name}.lua'))

    def test_partial_wort_retains_actual_food_and_raw_cannot_start(self):
        self.lua.execute('''
            local B=HCRBrewedDrinks;local rule=B.rules['Start Wheat Beer Fermentation']
            local food={baseHunger=-.15,hungChange=-.075,calories=137,poisonPower=.625}
            assert(not pcall(B.portion,rule,food))
            food.cooked=true
            local half=B.portion(rule,food)
            assert(L.volume(half)==.75 and L.budget(half,'calories')==137 and L.budget(half,'poisonPower')==.625)
            food.hungChange=-.0015
            local small=B.portion(rule,food)
            assert(math.abs(L.volume(small)-.015)<1e-10 and L.budget(small,'calories')==137)
            assert(B.TestCookedOrNotFood({IsFood=function() return false end}),'Yeast must pass OnTest')
            assert(not B.TestCookedOrNotFood({IsFood=function() return true end,isCooked=function() return false end,isBurnt=function() return false end}))
        ''')

    def test_two_ages_after_pouring_keep_independent_deadlines_and_no_extra_nutrition(self):
        self.lua.execute('''
            local a=F.start(L.batch('HCRBeerWort',.75,{calories=137,poisonPower=.625,
                age=10,offAge=2,offAgeMax=4,tainted=true,burnt=true},0),active,0,profile)
            local b=F.start(L.batch('HCRBeerWort',1.5,{calories=750,poisonPower=.125},10),active,10,profile)
            local kept,moved=L.split(a,.25,.75)
            local combined=L.mix(moved,b)
            local before,changed=F.plan(combined,167.999,false,profile)
            assert(not changed)
            local first,changed=F.plan(before,168,false,profile)
            assert(changed and first.lots[1].fluid=='HCRBeer' and first.lots[2].fluid=='HCRBeerWort')
            assert(first.lots[1].fermentation.kind==ready and first.lots[2].fermentation.kind==active)
            assert(L.volume(first)==1.75 and first.lots[1].food.burnt and first.lots[1].food.tainted)
            assert(L.quality(first)=='rotten')
            local final=F.plan(first,178,false,profile)
            assert(final.lots[2].fluid=='HCRBeer')
            assert(math.abs(L.budget(final,'calories')-875)<1e-8)
            assert(math.abs(L.budget(final,'nativeAlcohol')-.0875)<1e-8)
            assert(math.abs(L.budget(final,'poisonPower')-(.625/3+.125))<1e-8)
            assert(math.abs(L.budget(final,'poisonPower')+L.budget(kept,'poisonPower')-.75)<1e-8)
            local late,changed=F.plan(final,10000,true,profile)
            assert(not changed and late.lots[1].fermentation.kind==ready)
            assert(not pcall(F.start,first,active,168,profile),'Restarting age must fail')
            local n,names=F.futureComponents(combined)
            assert(n==2 and names.HCRBeer and names.HCRBeerWort)
        ''')

    def test_foraging_registration_keeps_native_normal_items_and_season(self):
        self.lua.execute('''
            forageSystem={worldSprites={wildPlants='native-plants'},addForageDef=function(name,def)
                forageName=name;forageDef=def
            end}
            Events={preAddForageDefs={Add=function(fn) register=fn end}}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_BreweryForage.lua'))
        self.lua.execute('''
            assert(forageDef==nil);register()
            assert(forageName=='HCRHops' and forageDef.type=='Hydrocraft.HCHops')
            assert(forageDef.skill==4 and forageDef.minCount==1 and forageDef.maxCount==2)
            assert(forageDef.months[1]==8 and forageDef.months[3]==10 and #forageDef.months==3)
            assert(forageDef.categories[1]=='WildHerbs' and #forageDef.spawnFuncs==0)
            assert(forageDef.zones.Forest and forageDef.zones.FarmLand)
        ''')

    def test_native_cook_burn_and_one_vessel_one_yeast_use(self):
        script=read_text(SCRIPTS/'HydrocraftReinvented/HCR_Brewery.txt')
        items={n:b for _,_,n,b in blocks(script,'item')}
        raw=items['HCRWheatWortPot']
        self.assertNotIn('ReplaceOnCooked',raw)
        self.assertIn('MinutesToCook = 60,',raw)
        self.assertIn('MinutesToBurn = 120,',raw)
        recipes={n:b for _,_,n,b in blocks(script,'craftRecipe')}
        prepare=recipes['Prepare Wheat Wort']
        self.assertIn('-fluid 1.5 [Water]',prepare)
        self.assertIn('item 30 [Hydrocraft.HCWheat],',prepare)
        self.assertIn('item 1 [Hydrocraft.HCHops],',prepare)
        finish=recipes['Start Wheat Beer Fermentation']
        self.assertIn('item 1 [Base.Yeast],',finish)
        self.assertEqual(finish.count('item 1 Base.Pot,'),1)
        self.assertNotIn('mode:keep',finish)


if __name__ == '__main__':
    unittest.main()
