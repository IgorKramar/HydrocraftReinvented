"""Измеряемая брага: исходные рецептуры, остатки, независимые часы и бюджеты."""
import json
import re
import unittest
from lupa.lua51 import LuaRuntime
from apply_playability_fixes import blocks
from hcr_paths import LUA, REPO, SCRIPTS, read_text


class MashChains(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().package.path=(LUA/'shared').as_posix()+'/?.lua'
        self.lua.execute('''
            require 'HCR_Fermentation'
            L=HCRFluidLedger;B=HCRFermentation;F=HCRFermentationClock;C=HCRMashCatalog
            function stable(kind,quality)
                return {age=quality=='rotten' and 2 or quality=='stale' and 1 or 0,
                    offAge=1,offAgeMax=2,canBeFrozen=false}
            end
            function make(kind,start)
                local marker=B.stages[kind].marker
                local mash=L.batch(marker,1.5,{calories=731,poisonPower=.875,
                    age=12,offAge=3,offAgeMax=7,tainted=true},start)
                return B.start(L.mix(mash,L.batch('Water',18.5,{calories=0},start)),kind,start,stable)
            end
        ''')

    def test_all_eight_new_clocks_keep_mash_budgets_and_stop_at_readiness(self):
        self.lua.execute('''
            local count=0
            for active,rule in pairs(C.transitions) do
                count=count+1
                local raw=make(active,100)
                assert(L.volume(raw)==20 and L.budget(raw,'calories')==731)
                local before,changed=B.plan(raw,435.999,true,stable)
                assert(not changed and before.lots[1].fermentation.kind==active)
                local ready,changed=B.plan(before,436,true,function() error('Do not replace mash nutrition') end)
                assert(changed and ready.lots[1].fermentation.kind==rule.target)
                assert(ready.lots[1].fluid==B.stages[rule.target].marker)
                assert(L.budget(ready,'calories')==731 and L.budget(ready,'poisonPower')==.875)
                assert(L.quality(ready)=='rotten' and ready.lots[1].food.tainted)
                local final,changed=B.plan(ready,100000,false,stable)
                assert(not changed and final.lots[1].fermentation.kind==rule.target)
                assert(F.new(rule.target,0,100000,true).kind==rule.target)
                local n,names=B.futureComponents(raw)
                assert(n==2 and names[B.stages[active].marker] and names[B.stages[rule.target].marker])
                assert(raw.lots[1].fermentation.kind==active)
            end
            assert(count==8)
        ''')

    def test_different_ages_pouring_and_rollback_cannot_reset_or_duplicate(self):
        self.lua.execute('''
            local kind='Hydrocraft.HCRFermentPotato'
            local a,b=make(kind,0),make(kind,100)
            local kept,moved=L.split(a,5,20)
            local mixed=L.mix(moved,b)
            local ready=B.plan(mixed,336,false,stable)
            assert(ready.lots[1].fermentation.kind=='Hydrocraft.HCBarrelpotato')
            assert(ready.lots[3].fermentation.kind==kind)
            assert(math.abs(L.budget(ready,'calories')+L.budget(kept,'calories')-1462)<1e-9)
            assert(math.abs(L.budget(ready,'poisonPower')+L.budget(kept,'poisonPower')-1.75)<1e-9)
            local rollback=F.advance(ready.lots[3].fermentation,10,true)
            assert(F.advance(rollback,109.999,true).kind==kind)
            assert(F.advance(rollback,110,true).kind=='Hydrocraft.HCBarrelpotato')
            assert(not pcall(B.start,ready,kind,336,stable))
        ''')

    def test_ten_cooked_ids_migrate_only_the_remaining_volume_without_cooked_flag(self):
        self.lua.execute('''
            function require() end
            function isClient() return false end
            function isServer() return false end
            function getGameTime() return {getWorldAgeHours=function() return 100 end} end
            HCRDrinkFamilies={}
            HCRFluidQuality={fluid=function(i) return i.fluid end,rawAmount=function(f) return f.amount end,
                store=function(i,f,ledger) i.ledger=ledger end}
            HCRFluidEffects={snapshot=function(i) return L.copy(i.food) end}
            function instanceItem(kind)
                assert(kind=='Base.Pot')
                local fluid={amount=0,getCapacity=function() return 3 end,
                    Empty=function(f) f.amount=0 end,addFluid=function(f,marker,amount) f.amount=amount end}
                return {fluid=fluid,md={},getModData=function(i) return i.md end}
            end
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_DrinkMigrations.lua'))
        self.lua.execute('''
            local count=0
            for kind,spec in pairs(C.families) do
                count=count+1
                for _,fraction in ipairs({1,.5,.01}) do
                    local source={food={calories=137,poisonPower=.625,age=5,offAge=2,offAgeMax=4,tainted=true},
                        getFullType=function() return kind end,IsFood=function() return true end,
                        getBaseHunger=function() return -.3 end,getHungChange=function() return -.3*fraction end,
                        updateAge=function() end,isCustomName=function() return false end,
                        isCooked=function() return false end,isBurnt=function() return false end}
                    local target=assert(HCRDrinkMigrations.newReplacement(source,function(_,t) t.copied=true end))
                    assert(target.copied and math.abs(target.fluid.amount-.5*fraction)<1e-9)
                    assert(L.budget(target.ledger,'calories')==137 and L.budget(target.ledger,'poisonPower')==.625)
                    assert(L.quality(target.ledger)=='rotten' and target.ledger.lots[1].food.tainted)
                    source.getFullType=function() return kind:gsub('cooked$','') end
                    assert(HCRDrinkMigrations.newReplacement(source)==nil)
                end
            end
            assert(count==10)
        ''')

    def test_source_requirements_and_unrelated_inputs_are_preserved(self):
        sources=json.loads(read_text(REPO/'tools/mash_chains_sources.json'))['recipes']
        catalog=json.loads(read_text(REPO/'tools/mash_chains.json'))
        recipes={name:body for file in ('HCR_Distillery.txt','HCR_Winemaking.txt')
                 for _,_,name,body in blocks(read_text(SCRIPTS/'HydrocraftReinvented'/file),'craftRecipe')}
        def field(body,key):
            match=re.search(r'(?m)^\s*'+key+r'\s*=\s*(.*?),\s*$',body)
            return match[1] if match else None
        for name,source in sources.items():
            before,after=source['body'],recipes[name]
            for key in ('time','Tags','category','SkillRequired','xpAward','NeedToBeLearn'):
                self.assertEqual(field(before,key),field(after,key),(name,key))
            if name in catalog['products']:
                self.assertIn('-fluid 1.5 ['+catalog['products'][name]['marker']+'] mode:primary,',after)
                self.assertIn('-fluid 18.5 [Water] mode:primary,',after)
                self.assertIn('[Hydrocraft.HCWoodenbarrelFluid] mode:keep flags[ItemCount;ItemIsFluid;IsEmpty]',after)
                self.assertNotIn('OnCreate',after)
                self.assertNotRegex(after.split('outputs')[1],r'\bitem\b')
            else:
                a=before
                if name in catalog['prepare']:
                    a=a.replace('[Base.Pot] mode:destroy flags[ItemCount]',
                                '[Base.Pot] mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty]')
                else:
                    a=re.sub(r'OnCreate\s*=\s*HCR42.recipe_hcwoodenbarrel,','',a)
                    marker=catalog['consumers'][name]['inputs']['0']['fluids'][0]
                    a=re.sub(r'item 1 \[Hydrocraft.HCBarrel\w+\],',
                             'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly], -fluid 20 ['+marker+'] mode:primary,',a)
                self.assertEqual(re.sub(r'\s+','',a),re.sub(r'\s+','',after),name)


if __name__=='__main__':unittest.main()
