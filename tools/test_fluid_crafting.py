"""Нативный refresh кандидатов не возвращает опасную жидкость в расход."""
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class FluidCrafting(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            function list(values)
                local a=values or {}
                function a:size() return #self end
                function a:get(i) return self[i+1] end
                function a:add(v) self[#self+1]=v end
                function a:clear() for i=#self,1,-1 do self[i]=nil end end
                return a
            end
            ArrayList={new=function() return list() end}
            InputFlag={Unseal='Unseal',InheritUsesAndEmpty='InheritUsesAndEmpty'}
            HCRFluidQuality={fluid=function(i) return i end,active=function(i) return i.tracked end}
            HCRFluidActions={
                guard=function(class,methods,check)
                    local old=class.performRecipe
                    class.performRecipe=function(self) if check(self) then return old(self) end return false end
                end,
                wrap=function(class,method,handler)
                    local old=class[method]
                    class[method]=function(self) return handler(self,function() return old(self) end) end
                end}
            tracked={tracked=true,kind='water',amount=.1}
            clean={kind='water',amount=.4}
            pot={tracked=true,kind='pot',amount=1}
            consume={isKeep=function() return true end,hasConsumeFromItem=function() return true end,
                hasCreateToItem=function() return false end,isReplace=function() return false end,
                hasFlag=function() return false end,
                canUseItem=function(_,item) return item.kind=='water' and item.amount>0 end}
            keep={isKeep=function() return true end,hasConsumeFromItem=function() return false end,
                hasCreateToItem=function() return false end,isReplace=function() return false end,
                hasFlag=function() return false end,
                canUseItem=function(_,item) return item.kind=='pot' end}
            scripts=list({consume,keep}); selected={list({tracked}),list({pot})}
            recipe={getInputs=function() return scripts end}
            data={getRecipe=function() return recipe end,getInputItems=function(_,i) return selected[i+1] end,
                canConsumeInputs=function(_,resources,candidates)
                    candidates=candidates or selected[1]
                    for _,item in ipairs(candidates) do if item==clean then return true end end
                    return false
                end,
                perform=function(_,character,resources,candidates)
                    if fail then error('native failure') end
                    candidates=candidates or selected[1]
                    for _,item in ipairs(candidates) do
                        if item.kind=='water' then item.amount=item.amount-.1 end
                    end
                    performed=true; return true
                end}
            logic={getRecipeData=function() return data end,getPlayer=function() return {} end,
                getSourceResources=function() return list() end,getContainers=function() return list() end,
                isContainersAccessible=function() return true end,
                isManualSelectInputs=function() return manual or false end,
                getAllItems=function(self) return self.all end,
                -- PZ 42.21 всегда пересобирает candidates перед фактическим perform.
                updateFloorContainer=function(self) self.all=list({tracked,clean,pot}); refreshed=true end,
                getCreatedOutputItems=function() outputs=true end,all=list({tracked,clean,pot})}
            function logic:performCurrentRecipe()
                self:updateFloorContainer()
                return data:perform({},nil,self.all,nil)
            end
            ISHandcraftAction={performRecipe=function(self)
                if self.logic:performCurrentRecipe() then self.logic:getCreatedOutputItems(list()) end
            end}
            action={logic=logic,character={}}
        ''')
        self.lua.execute((ROOT/'common/media/lua/shared/HCR_FluidCrafting.lua').read_text(encoding='utf-8'))

    def test_refreshed_candidates_are_filtered_at_actual_native_perform(self):
        self.lua.execute('ISHandcraftAction.performRecipe(action)')
        self.assertTrue(self.lua.globals().refreshed)
        self.assertTrue(self.lua.globals().performed)
        self.assertAlmostEqual(self.lua.globals().tracked.amount, .1)
        self.assertAlmostEqual(self.lua.globals().clean.amount, .3)
        self.assertTrue(self.lua.eval('action.logic==logic'))
        self.assertTrue(self.lua.globals().outputs)

    def test_safe_keep_tool_remains_available_in_auto_mode(self):
        self.lua.execute('restore=HCRFluidCrafting.prepareSafeInputs(logic)')
        self.assertTrue(self.lua.eval('selected[1]:size()==1 and selected[1]:get(0)==clean'))
        self.assertTrue(self.lua.eval('selected[2]:size()==3 and selected[2]:get(2)==pot'))
        self.lua.execute('restore()')
        self.assertTrue(self.lua.eval('selected[1]:get(0)==tracked and selected[2]:get(0)==pot'))

    def test_manual_consumption_refused_but_keep_tool_allowed(self):
        self.lua.execute('manual=true')
        self.assertFalse(self.lua.eval('HCRFluidCrafting.check(logic)'))
        self.lua.execute('selected[1]=list({clean})')
        self.assertTrue(self.lua.eval('HCRFluidCrafting.check(logic)'))

    def test_logic_restored_after_native_error(self):
        self.lua.execute('fail=true; ok=pcall(ISHandcraftAction.performRecipe,action)')
        self.assertFalse(self.lua.globals().ok)
        self.assertTrue(self.lua.eval('action.logic==logic'))
        self.assertTrue(self.lua.eval('selected[1]:get(0)==tracked'))

    def test_test_only_queue_reservations_cannot_make_tracked_item_safe(self):
        self.lua.execute('consume.canUseItem=function() return false end; ISHandcraftAction.performRecipe(action)')
        self.assertTrue(self.lua.globals().performed)
        self.assertAlmostEqual(self.lua.globals().tracked.amount, .1)

    def test_unseal_keep_slot_cannot_rewrite_tracked_container(self):
        self.lua.execute("keep.hasFlag=function(_,flag) return flag=='Unseal' end; manual=true; selected[1]=list({clean})")
        self.assertFalse(self.lua.eval('HCRFluidCrafting.check(logic)'))

    def test_beer_pack_filters_empty_and_changed_cans_before_auto_consumption(self):
        self.lua.execute('''
            recipe.getName=function() return 'Pack Beer' end
            HCRBeerCatalog={packing={['Pack Beer']='beer'}}
            HCRBeerQuality={catalog=HCRBeerCatalog,
                packingInput=function(_,slot,script,item) return slot==0 and item.factory==true end}
            tracked.factory=true
            clean.factory=false -- Пустая банка не активна, но упаковка её тоже исключает.
            local restore=HCRFluidCrafting.prepareSafeInputs(logic)
            assert(selected[1]:size()==1 and selected[1]:get(0)==tracked)
            restore();assert(selected[1]:size()==1 and selected[1]:get(0)==tracked)
            manual=true;selected[1]=list({clean})
            assert(not HCRFluidCrafting.check(logic))
        ''')

    def test_food_budget_rejection_precedes_native_outputs_and_consumption(self):
        for manual in (False,True):
            with self.subTest(manual=manual):
                self.lua.globals().manual=manual
                self.lua.execute('''
                    selected[1]=list({clean})
                    HCRFoodTransfers={checkCraft=function() return false end}
                    ok=pcall(ISHandcraftAction.performRecipe,action)
                ''')
                self.assertTrue(self.lua.globals().ok)
                self.assertIsNone(self.lua.globals().performed)
                self.assertIsNone(self.lua.globals().outputs)
                self.assertAlmostEqual(self.lua.globals().clean.amount,.4)
                self.assertTrue(self.lua.eval('action.logic==logic'))

    def world_fixture(self):
        self.lua.execute('''
            ComponentType={FluidContainer='fluid'}
            GameEntityFactory={TransferComponent=function(from,to)
                if from.fail then return end
                to.component=from.component;from.component=nil
            end}
            function worldItem()
                local world={component={},getFluidContainer=function(self) return self.component end}
                local item={world=world,getWorldItem=function(self) return self.world end,
                    getFluidContainer=function(self) return self.component end,
                    getContainer=function() return nil end}
                return item,world,world.component
            end
            first,w1,f1=worldItem();second,w2,f2=worldItem()
            logic.all=list({first,second});selected[1]=list({first,second})
            HCRFluidQuality.sync=function(item)
                assert(w1.component==f1 and w2.component==f2,'publish before restoring all')
                syncs=(syncs or 0)+1
            end
        ''')

    def test_world_components_restore_once_after_nested_scopes(self):
        self.world_fixture()
        self.lua.execute('''
            restore=HCRFluidCrafting.borrowWorldFluids(logic)
            assert(first.component==f1 and second.component==f2 and not w1.component)
            inner=HCRFluidCrafting.borrowWorldFluids(logic);inner()
            assert(first.component==f1 and second.component==f2)
            HCRFluidQuality.craftFluidOwners[first].dirty=true
            HCRFluidQuality.craftFluidOwners[second].dirty=true
            restore();restore()
        ''')
        self.assertEqual(self.lua.globals().syncs,2)
        self.assertTrue(self.lua.eval('w1.component==f1 and w2.component==f2 and not first.component and not second.component'))
        self.assertTrue(self.lua.eval('next(HCRFluidQuality.craftFluidOwners)==nil'))

    def test_failed_native_transfer_restores_previous_borrowed_components(self):
        self.world_fixture()
        self.lua.execute('w2.fail=true;ok=pcall(HCRFluidCrafting.borrowWorldFluids,logic)')
        self.assertFalse(self.lua.globals().ok)
        self.assertTrue(self.lua.eval('w1.component==f1 and w2.component==f2 and not first.component and not second.component'))
        self.assertTrue(self.lua.eval('next(HCRFluidQuality.craftFluidOwners)==nil'))

    def test_native_untracked_world_source_is_published_only_for_actual_craft(self):
        self.world_fixture()
        self.lua.execute('restore=HCRFluidCrafting.borrowWorldFluids(logic);restore()')
        self.assertIsNone(self.lua.globals().syncs)
        self.lua.execute('restore=HCRFluidCrafting.borrowWorldFluids(logic,true);restore()')
        self.assertEqual(self.lua.globals().syncs,2)

    def test_publish_error_does_not_leave_other_components_borrowed(self):
        self.world_fixture()
        self.lua.execute('''
            restore=HCRFluidCrafting.borrowWorldFluids(logic)
            HCRFluidQuality.craftFluidOwners[first].dirty=true
            HCRFluidQuality.craftFluidOwners[second].dirty=true
            HCRFluidQuality.sync=function() error('network failure') end
            ok=pcall(restore)
        ''')
        self.assertFalse(self.lua.globals().ok)
        self.assertTrue(self.lua.eval('w1.component==f1 and w2.component==f2 and not first.component and not second.component'))
        self.assertTrue(self.lua.eval('next(HCRFluidQuality.craftFluidOwners)==nil'))

    def test_world_component_restores_after_native_recipe_throws(self):
        self.world_fixture()
        self.lua.execute('''
            selected[1]=list({clean});logic.all=list({tracked,clean,pot,first})
            logic.updateFloorContainer=function(self) end
            fail=true;ok=pcall(ISHandcraftAction.performRecipe,action)
        ''')
        self.assertFalse(self.lua.globals().ok)
        self.assertTrue(self.lua.eval('w1.component==f1 and not first.component and action.logic==logic'))

    def test_milk_limit_error_precedes_native_output_and_consumption(self):
        self.lua.execute('''
            HCRFluidActions.refuse=function(self) self.hcrFluidRefused=true;return false end
            HCRMilkChains={check=function() return true end,
                preflight=function() return false end}
            ok=pcall(ISHandcraftAction.performRecipe,action)
        ''')
        self.assertTrue(self.lua.globals().ok)
        self.assertTrue(self.lua.globals().action.hcrFluidRefused)
        self.assertIsNone(self.lua.globals().performed)
        self.assertIsNone(self.lua.globals().outputs)
        self.assertAlmostEqual(self.lua.globals().clean.amount,.4)


if __name__ == '__main__':
    unittest.main()
