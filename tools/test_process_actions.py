"""Пошаговое объединение уксуса/сычужного фермента сохраняет uses и дозу."""
import unittest
import test_process_quality as base
from hcr_paths import LUA,read_text


class ProcessActions(unittest.TestCase):
    def setUp(self):
        base.ProcessQuality.setUp(self)
        self.lua.execute('''
            HCRFluidActions={wrap=function() end};ISConsolidateDrainable={}
            function drainable(kind,uses,delta,dose,quality)
                local item=stage(kind);item.uses=uses
                function item:IsDrainable() return true end
                function item:getCurrentUses() return self.uses end
                function item:setCurrentUses(n) self.uses=n end
                function item:getUseDelta() return delta end
                HCRProcessQuality.write(item,{dose=dose,quality=quality,detection=5},1,nil)
                return item
            end
            function action(a,b)
                return {drainable=a,intoItem=b,fromStart=a.uses*a:getUseDelta(),intoStart=b.uses*b:getUseDelta()}
            end
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_ProcessActions.lua'))

    def test_each_progress_step_conserves_units_and_exact_poison(self):
        self.lua.execute('''
            local P,A=HCRProcessQuality,HCRProcessActions
            a=drainable('HCRennet',3,.25,.875,'rotten')
            b=drainable('HCRennet',2,.25,.125,'fresh')
            transfer=action(a,b)
            for i=0,100 do
                A.advance(transfer,i/100)
                assert(a.uses+b.uses==5)
                assert(math.abs(P.read(a).dose+P.read(b).dose-1)<.000001)
            end
        ''')
        self.assertEqual(self.lua.globals().a.uses,1)
        self.assertEqual(self.lua.globals().b.uses,4)
        self.assertAlmostEqual(self.lua.eval('HCRProcessQuality.read(a).dose'),.875/3)
        self.assertEqual(self.lua.eval('HCRProcessQuality.read(b).quality'),'rotten')

    def test_cancelled_then_resumed_transfer_cannot_restore_original_dose(self):
        self.lua.execute('''
            local P,A=HCRProcessQuality,HCRProcessActions
            a=drainable('HCRennet',3,.25,.875,'stale')
            b=drainable('HCRennet',1,.25,.125,'fresh')
            local first=action(a,b)
            A.advance(first,.51);assert(a.uses==2 and b.uses==2)
            local second=action(a,b)
            A.advance(second,1);assert(a.uses==0 and b.uses==4)
            assert(a:getModData()[P.key]==nil)
            assert(P.read(b).quality=='stale')
        ''')
        self.assertAlmostEqual(self.lua.eval('HCRProcessQuality.read(b).dose'),1)

    def test_taint_crosses_consolidation_without_contaminating_an_unused_source(self):
        self.lua.execute('''
            local P,A=HCRProcessQuality,HCRProcessActions
            local a=drainable('HCRennet',3,.25,.875,'fresh')
            local b=drainable('HCRennet',1,.25,.125,'fresh')
            a:getModData()[P.key].tainted=true
            local first=action(a,b);A.advance(first,0)
            assert(not P.read(b).tainted)
            A.advance(first,.51)
            assert(P.read(a).tainted and P.read(b).tainted)
            A.advance(action(a,b),1)
            assert(P.read(b).tainted and a:getModData()[P.key]==nil)
        ''')

    def test_concurrent_stock_change_and_budget_limit_refuse_before_mutation(self):
        self.lua.execute('''
            a=drainable('HCRennet',3,.25,.875,'fresh')
            b=drainable('HCRennet',1,.25,.125,'fresh')
            transfer=action(a,b)
            HCRProcessActions.advance(transfer,.5)
            a.uses=1
            ok=pcall(HCRProcessActions.advance,transfer,1)
            assert(not ok and a.uses==1 and b.uses==2)
            a=drainable('HCRennet',3,.25,700000,'fresh')
            b=drainable('HCRennet',1,.25,700000,'fresh')
            ok=pcall(HCRProcessActions.advance,action(a,b),1)
            assert(not ok and a.uses==3 and b.uses==1)
        ''')


if __name__=='__main__':unittest.main()
